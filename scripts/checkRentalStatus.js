const admin = require("firebase-admin");
const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function processRentals() {
  try {
    const rentalsRef = db.collection("rentals");
    const snapshot = await rentalsRef.get();

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); // ignore time
    const batch = db.batch();

    snapshot.forEach((doc) => {
      const rental = doc.data();
      const docRef = doc.ref;

      const rentedSince = rental.rentedSince ? new Date(rental.rentedSince) : null;
      const availableFrom = rental.availableFrom ? new Date(rental.availableFrom) : null;

      // ======== Auto status update logic ========
      if (rental.status === "To Be Vacant" && availableFrom) {
        // If availableFrom is today or past, mark as Vacant
        if (availableFrom <= today) {
          console.log(`Rental ${doc.id} changing status To Be Vacant → Vacant`);
          batch.update(docRef, {
            status: "Vacant",
            availableFrom: null
          });
        }
      }

      // ======== Auto delete logic ========
      if (rentedSince) {
        const diffDays = (today - new Date(rentedSince.getFullYear(), rentedSince.getMonth(), rentedSince.getDate())) / (1000 * 60 * 60 * 24);
        if (diffDays >= 5) {
          console.log(`Rental ${doc.id} rented ${diffDays} days ago → Deleting`);
          batch.delete(docRef);
        }
      }
    });

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
