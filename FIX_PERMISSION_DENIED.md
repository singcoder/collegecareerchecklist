# Fix PERMISSION_DENIED – Firestore rules

Both **user_checklist** and **checklists/global/items** are being denied. Do the following in order.

---

## 1. Pick the correct database

Firebase can have **more than one** Firestore database. The app uses the **(default)** database.

- In **Firebase Console** → **Build** → **Firestore Database**.
- At the top of the page, check for a **database selector** (e.g. “(default)” or a database name).
- **Select “(default)”** (the default database). If you recreated data in a different database, the app will not see it and rules there don’t apply to the app.

---

## 2. Open Rules for (default)

- Still in **Firestore Database**, open the **Rules** tab.
- If there is a database dropdown in the Rules tab, choose **(default)**.
- You should see the rules editor for the **(default)** database.

---

## 3. Paste and publish minimal rules

Replace **everything** in the rules editor with this (copy exactly, no extra spaces at start/end):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /checklists/global/items/{itemId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    match /user_checklist/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

- Click **Publish**.
- Wait for “Rules published” (or similar).

---

## 4. Confirm data is in (default)

Your checklist data must be in the **(default)** database.

- In the **Data** tab (or **Firestore** data view), ensure the database selector is **(default)**.
- Navigate: **checklists** → **global** → **items** and confirm your 2 documents are there.
- If they are under a different database, either move/recreate them under **(default)** or the app will not see them and rules for that other database don’t apply to the app.

---

## 5. Test the app

- Fully close the app (swipe away or stop from IDE).
- Run again and sign in (or register).

If it still fails:

- In the Rules tab, confirm the published rules **exactly** match what you pasted (no extra `match` blocks, no typo like `checklist` instead of `checklists`).
- Confirm again you are editing and publishing rules for the **(default)** database.

---

## 6. Optional: use the stricter rules again

After the minimal rules work, you can switch back to the stricter **user_checklist** rule (users can only read/write their own documents). The content is in your project’s **firestore.rules** file. Copy that full file into the Rules editor for **(default)** and **Publish** again.
