# Firestore data guide

**Goal:** One checklist with checklist items. All users see the same checklist. The **completed** flag is per user per checklist item. Checklist items are stored **once** (no duplication).

---

## 1. Schema overview

| What | Where | Duplicated? |
|------|--------|-------------|
| **Checklist items** (title, description, url, order) | `checklists` → doc `global` → collection `items` | **No.** Single source of truth. All users read from here. |
| **Per-user completion** (isComplete per user per item) | `user_checklist` (top-level collection) | N/A. Only completion state is stored here; no copy of title, description, url, or order. |

So: **Checklist items** live only under `checklists/global/items`. **Completion** is stored in `user_checklist` as one document per (user, checklist, item) with just `userId`, `checklistId`, `itemId`, `isComplete`, `completedAt`, and optionally `createdAt`. No part of the checklist items table is duplicated.

---

## 2. Find your user's UID

- Firebase Console → your project → **Build** → **Authentication** → **Users**.
- **User UID** column = the value used in `user_checklist.userId`.

---

## 3. Checklist items (single checklist – no duplication)

**Path:** `checklists` → document **`global`** → collection **`items`**

Add these once. Every user sees the same items.

1. Firestore → **Start collection** (or use existing).
2. **Collection ID:** `checklists`  
   **Document ID:** `global`  
   Create the document.
3. Open `global` → **Add collection** → **Collection ID:** `items`
4. Add documents inside `items`. Each document = one checklist row.

**Fields per checklist item doc:**

| Field        | Type   | Required | Example |
|-------------|--------|----------|---------|
| `title`     | string | Yes      | `"Complete FAFSA"` |
| `description` | string | No     | `"Submit the FAFSA..."` |
| `url`       | string | No       | `"https://studentaid.gov/fafsa"` |
| `order`     | number | Yes      | `1`, `2`, `3` (sort order) |

Use any **Document ID** you want (e.g. `item1`, `item2`). The app uses this as `itemId` when storing completion in `user_checklist`.

---

## 4. Per-user completion (`user_checklist` – associative table)

**Path:** Collection **`user_checklist`** (top-level)

The app reads/writes here. Each document = one (user, checklist, item) with **only** the completion state. Checklist item content (title, description, url, order) is **not** stored here; it stays only in `checklists/global/items`.

- **Document ID:** `{userId}_{checklistId}_{itemId}` (e.g. `abc123_global_item1`). The app sets this when the user checks/unchecks.
- **Fields:**

| Field         | Type     | Required | Notes |
|---------------|----------|----------|--------|
| `userId`      | string   | Yes      | Firebase Auth UID |
| `checklistId` | string   | Yes      | `global` (for the single checklist) |
| `itemId`      | string   | Yes      | Same as document ID in `checklists/global/items` |
| `isComplete`  | boolean  | Yes      | `true` or `false` |
| `completedAt` | timestamp| No       | Set when checked |
| `createdAt`   | timestamp| No       | Optional; app sets on first write |

The app creates/updates these when the user checks/unchecks. You normally don't add them by hand.

**Composite index:** The app queries `user_checklist` by `userId` and `checklistId`. Deploy indexes with:

```bash
firebase deploy --only firestore:indexes
```

using the project's `firestore.indexes.json`, or create the index when Firebase prompts you from the app.

---

## 5. Quick checklist

- [ ] Get your **Auth UID** from Authentication → Users.
- [ ] Create **`checklists`** → **`global`** → **`items`** and add at least one item with `title`, `order` (and optionally `description`, `url`). This is the **only** place checklist items are stored.
- [ ] Deploy **Firestore rules** and **indexes** (`firestore.rules`, `firestore.indexes.json`) so the app can read checklist items and read/write `user_checklist`.
- [ ] Completion: the app creates/updates **`user_checklist`** docs when the user checks/unchecks. No duplication of checklist items.

Result: one checklist, one set of items, completion per user per item. Code and data guide match.
