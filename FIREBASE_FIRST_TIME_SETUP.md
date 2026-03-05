# First-time Firebase setup – what needs to be in Firebase

Use this for **first-time creation** of the schema and data. Do these once per project.

---

## 1. Authentication

- **Firebase Console** → **Build** → **Authentication** → **Sign-in method**.
- Enable **Email/Password** (the app uses this for sign-in and register).
- No user records needed upfront; users are created when they register in the app.

---

## 2. Firestore – structure and data

### 2a. Checklist items (required – app needs at least one item)

Create this so the app has something to show. All users share this; no duplication.

| Where | What to do |
|-------|------------|
| **Collection** | Create collection **`checklists`** |
| **Document** | Create document with ID **`global`** (inside `checklists`) |
| **Subcollection** | Inside `global`, add subcollection **`items`** |
| **Documents in `items`** | Add at least one document (e.g. Document ID **`item1`**) with these **fields**: |

**Fields for each document in `checklists` → `global` → `items`:**

| Field | Type | Required | Example |
|-------|------|----------|---------|
| `title` | string | Yes | `Complete FAFSA` |
| `description` | string | No | `Submit the FAFSA` |
| `url` | string | No | `https://studentaid.gov/fafsa` |
| `order` | number | Yes | `1` |

Add more items (e.g. `item2`, `item3`) with different `order` values if you want.

### 2b. Per-user completion (no manual data needed)

- **Collection** | Create **top-level** collection **`user_checklist`** (from Firestore root, “Start collection”).
- **Documents** | Leave empty. The app creates documents here when users check/uncheck items (document ID format: `{userId}_global_{itemId}`).

So for first-time setup you only **create the empty `user_checklist` collection**; no initial documents required.

---

## 3. Firestore – Security rules

Put these rules in **Firestore** → **Rules** (or deploy from the project’s `firestore.rules`).

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

Then click **Publish**.

---

## 4. Firestore – Composite index (for `user_checklist` query)

The app queries `user_checklist` by `userId` and `checklistId`. Firestore needs a composite index.

**Option A – Let Firebase prompt you**

1. Run the app and sign in, then open the checklist (or check an item).
2. If the index is missing, the error in the app or in the Firebase Console will include a **link to create the index**. Open it and click **Create index**.

**Option B – Create index in Console**

1. **Firestore** → **Indexes** → **Composite** → **Create index**.
2. **Collection ID:** `user_checklist`
3. **Fields:**  
   - `userId` – Ascending  
   - `checklistId` – Ascending  
4. **Query scope:** Collection  
5. Create the index.

**Option C – Deploy from project (if you use Firebase CLI)**

From the project folder (where `firestore.indexes.json` lives):

```bash
firebase deploy --only firestore:indexes
```

---

## 5. Checklist – what must exist before the app works

| Item | Where | Required? |
|------|--------|-----------|
| Email/Password sign-in enabled | Authentication → Sign-in method | Yes |
| Collection `checklists` | Firestore | Yes |
| Document `global` | `checklists` | Yes |
| Subcollection `items` | `checklists/global` | Yes |
| At least one document in `items` with `title`, `order` | `checklists/global/items` | Yes (app shows “No checklist items” otherwise) |
| Collection `user_checklist` | Firestore (top-level) | Yes (can be empty) |
| Security rules (above) | Firestore → Rules | Yes |
| Composite index on `userId` + `checklistId` | Firestore → Indexes | Yes (needed when app queries completion) |

---

## 6. Summary – minimal first-time data

**You must create:**

1. **Auth:** Enable Email/Password.
2. **Firestore:**  
   - `checklists` → `global` → `items` → **at least one item doc** with `title`, `order` (and optionally `description`, `url`).  
   - Empty collection **`user_checklist`**.
3. **Rules:** Paste and publish the rules in §3.
4. **Index:** Create the composite index on `user_checklist` (§4) before or when the app first runs.

**You do not create:** Any documents in `user_checklist` (the app creates them when users check items). No user documents in Firestore (users live in Auth only).
