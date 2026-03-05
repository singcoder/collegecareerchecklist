# Firestore schema – create in Firebase

Use this to build the structure in **Firestore Database** in the Firebase Console.

---

## 1. Checklist items (one checklist, shared by all users)

**Create once.** All users read from here.

| Step | In Firebase Console |
|------|---------------------|
| Collection | **`checklists`** |
| Document ID | **`global`** |
| Subcollection | **`items`** (add from inside the `global` document) |

**Inside `checklists` → `global` → `items`**, add one document per checklist item:

| Document ID | Field | Type | Example value |
|-------------|--------|------|----------------|
| (e.g. `item1`) | `title` | string | `Complete FAFSA` |
| | `description` | string | `Submit the Free Application for Federal Student Aid` |
| | `url` | string | `https://studentaid.gov/fafsa` |
| | `order` | number | `1` |

Add more items (e.g. `item2`, `item3`) with `order` 2, 3, … for sort order.

---

## 2. Per-user completion (associative table)

**Collection only.** No parent document. Create the collection from the Firestore root.

| Step | In Firebase Console |
|------|---------------------|
| Collection | **`user_checklist`** (top-level; “Start collection” at DB root) |

**Inside `user_checklist`**, the app creates documents when users check/uncheck. Each document:

| Document ID | Field | Type | Example value |
|-------------|--------|------|----------------|
| `{userId}_global_{itemId}` | `userId` | string | (Firebase Auth UID) |
| e.g. `abc123_global_item1` | `checklistId` | string | `global` |
| | `itemId` | string | `item1` |
| | `isComplete` | boolean | `true` or `false` |
| | `completedAt` | timestamp | (when checked) |
| | `createdAt` | timestamp | (optional) |

You don’t need to create these by hand; the app creates them. If you add one manually for testing, use Document ID = `{your-uid}_global_{itemId}` and the fields above.

---

## Quick copy-paste reference

**Collection 1:** `checklists`  
→ Document: `global`  
→ Subcollection: `items`  
→ Each doc in `items`: `title` (string), `description` (string), `url` (string), `order` (number)

**Collection 2:** `user_checklist` (top-level)  
→ Each doc: `userId` (string), `checklistId` (string), `itemId` (string), `isComplete` (boolean), `completedAt` (timestamp), `createdAt` (timestamp)

---

## Visual layout

```
Firestore root
├── checklists (collection)
│   └── global (document)
│       └── items (subcollection)
│           ├── item1  { title, description, url, order }
│           ├── item2  { title, description, url, order }
│           └── ...
│
└── user_checklist (collection)
    ├── {uid}_global_item1  { userId, checklistId, itemId, isComplete, completedAt, createdAt }
    ├── {uid}_global_item2  { ... }
    └── ...
```
