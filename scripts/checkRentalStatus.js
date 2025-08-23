const admin = require("firebase-admin");

// Initialize Firebase with the service account JSON
const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRentalStatus() {
  try {
    const postsRef = db.collection("posts");
    const snapshot = await postsRef.get();

    const now = new Date();
    const batch = db.batch();

    snapshot.forEach((doc) => {
      const post = doc.data();
      const docRef = doc.ref;

      // Update "To Be Vacant" → "Vacant"
      if (post.status === "To Be Vacant" && post.availableFrom) {
        const availableDate = new Date(post.availableFrom);
        if (now >= availableDate) {
          batch.update(docRef, { status: "Vacant" });
        }
      }

      // Delete posts 5 days after rentedSince
      if (post.status === "Rented" && post.rentedSince) {
        const rentedDate = new Date(post.rentedSince);
        const diffTime = now - rentedDate;
        const diffDays = diffTime / (1000 * 60 * 60 * 24);
        if (diffDays >= 5) {
          batch.delete(docRef);
        }
      }
    });

    await batch.commit();
    console.log("Rental status check complete!");
  } catch (error) {
    console.error("Error checking rental statuses:", error);
  }
}

// Run the function if executed directly
if (require.main === module) {
  checkRentalStatus();
}

module.exports = checkRentalStatus;
