import os
import base64
import json
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, firestore

# ===== Decode Firebase service account from Base64 =====
service_account_base64 = os.environ.get("FIREBASE_SERVICE_ACCOUNT")
if not service_account_base64:
    raise ValueError("FIREBASE_SERVICE_ACCOUNT env variable not set")

service_account_json = base64.b64decode(service_account_base64)
service_account_info = json.loads(service_account_json)

# ===== Initialize Firebase =====
cred = credentials.Certificate(service_account_info)
firebase_admin.initialize_app(cred)
db = firestore.client()

# ===== Rental processing logic =====
def process_rentals():
    try:
        rentals_ref = db.collection("rentals")
        docs = rentals_ref.stream()

        now = datetime.now(timezone.utc)
        today = datetime(year=now.year, month=now.month, day=now.day, tzinfo=timezone.utc)

        batch = db.batch()
        for doc in docs:
            rental = doc.to_dict()
            doc_ref = doc.reference

            rented_since = rental.get("rentedSince")
            available_from = rental.get("availableFrom")
            status = rental.get("status")

            if rented_since:
                rented_since_dt = datetime.fromisoformat(rented_since)
            else:
                rented_since_dt = None

            if available_from:
                available_from_dt = datetime.fromisoformat(available_from)
            else:
                available_from_dt = None

            # ===== Auto status update logic =====
            if status == "To Be Vacant" and available_from_dt:
                if available_from_dt <= today:
                    print(f"Rental {doc.id} changing status To Be Vacant → Vacant")
                    batch.update(doc_ref, {
                        "status": "Vacant",
                        "availableFrom": None
                    })

            # ===== Auto delete logic =====
            if rented_since_dt:
                diff_days = (today - datetime(rented_since_dt.year, rented_since_dt.month, rented_since_dt.day, tzinfo=timezone.utc)).days
                if diff_days >= 5:
                    print(f"Rental {doc.id} rented {diff_days} days ago → Deleting")
                    batch.delete(doc_ref)

        batch.commit()
        print("Rental status update and cleanup complete!")
    except Exception as e:
        print("Error processing rentals:", e)

# Run manually if executed directly
if __name__ == "__main__":
    process_rentals()
