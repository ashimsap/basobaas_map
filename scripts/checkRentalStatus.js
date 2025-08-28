const admin = require("firebase-admin");
const { createClient } = require("@supabase/supabase-js");
const serviceAccount = require("../serviceAccountKey.json");

// ===== Firebase Setup =====
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ===== Supabase Setup =====
const supabaseUrl = "https://cccljhxlvmizkugxgoxi.supabase.co"; // your Supabase project URL
const supabaseKey = process.env.SERVICE_ROLE_KEY; // from GitHub Secrets
const supabase = createClient(supabaseUrl, supabaseKey);

// ===== Helper: Convert Supabase URL → path =====
function getSupabasePathFromUrl(url) {
  try {
    const u = new URL(url);
    const idx = u.pathname.indexOf("/rental-images/");
    if (idx !== -1) {
      return u.pathname.substring(idx + "/rental-images/".length);
    }
    return null;
  } catch {
    return null;
  }
}

// ===== Main Job =====
async function processRentals() {
  try {
    const rentalsRef = db.collection("rentals");
    const snapshot = await rentalsRef.get();

    const now = new Date();

    // Nepal time conversion
    const nepalOffset = 5 * 60 + 45;
    const utc = now.getTime() + now.getTimezoneOffset() * 60000;
    const nepalTime = new Date(utc + nepalOffset * 60 * 1000);

    const today = new Date(nepalTime.getFullYear(), nepalTime.getMonth(), nepalTime.getDate());

    const batch = db.batch();

    for (const doc of snapshot.docs) {
      const rental = doc.data();
      const docRef = doc.ref;

      const rentedSince = rental.rentedSince ? new Date(rental.rentedSince) : null;
      const availableFrom = rental.availableFrom ? new Date(rental.availableFrom) : null;

      // ======== Auto status update logic ========
      if (rental.status === "To Be Vacant" && availableFrom) {
        if (availableFrom <= today) {
          console.log(`Rental ${doc.id} changing status To Be Vacant → Vacant`);
          batch.update(docRef, {
            status: "Vacant",
            availableFrom: null,
          });
        }
      }

      // ======== Auto delete logic ========
      if (rentedSince) {
        const diffDays =
          (today -
            new Date(rentedSince.getFullYear(), rentedSince.getMonth(), rentedSince.getDate())) /
          (1000 * 60 * 60 * 24);

        if (diffDays >= 5) {
          console.log(`Rental ${doc.id} rented ${diffDays} days ago → Deleting`);

          // 1. Queue Firestore deletion
          batch.delete(docRef);

          // 2. Delete images from Supabase if exist
          if (rental.images && Array.isArray(rental.images)) {
            const paths = rental.images
              .map((url) => getSupabasePathFromUrl(url))
              .filter(Boolean);

            if (paths.length > 0) {
              console.log(`Deleting Supabase images for rental ${doc.id}:`, paths);
              const { error } = await supabase.storage.from("rental-images").remove(paths);

              if (error) {
                console.error(`❌ Supabase deletion failed for ${doc.id}`, error);
              } else {
                console.log(`✅ Supabase images deleted for ${doc.id}`);
              }
            }
          }
        }
      }
    }

    await batch.commit();
    console.log("Rental status update and cleanup complete!");
  } catch (error) {
    console.error("Error processing rentals:", error);
  }
}

// Run manually if executed directly
if (require.main === module) {
  processRentals();
}

module.exports = processRentals;
