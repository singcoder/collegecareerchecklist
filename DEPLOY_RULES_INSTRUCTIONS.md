# Fix "caller does not have permission" – publish Firestore rules

The error is from **Firestore Security Rules** blocking the `user_checklist` query. After recreating the schema, the rules in your Firebase project may have been reset. Publish the rules below.

---

## Steps

1. Open **[Firebase Console](https://console.firebase.google.com)** and select project **college-and-career-checklist**.
2. Go to **Build** → **Firestore Database**.
3. Open the **Rules** tab.
4. **Replace all** the rules in the editor with the rules below (copy the entire block).
5. Click **Publish**.

---

## Rules to paste

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /checklists/global/items/{itemId} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /user_checklist/{docId} {
      allow read, write: if request.auth != null
        && (resource == null
             ? request.resource.data.userId == request.auth.uid
             : resource.data.userId == request.auth.uid
               && (request.resource == null
                    || request.resource.data.userId == request.auth.uid));
    }
  }
}
```

---

After publishing, try registering or signing in again. The app will be able to read `checklists/global/items` and query/write `user_checklist` for the signed-in user.
