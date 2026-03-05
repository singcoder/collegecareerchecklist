# "items" vs "checklist item" – clarification

**Short answer:** There is **no** Firestore collection named `checklist_item`. **`items`** is the only collection name. **"Checklist item"** is just the idea of "one row in the checklist." In the database, one checklist item = **one document inside the `items` subcollection**.

---

## In Firestore (what actually exists)

| Name in Firebase | What it is |
|------------------|------------|
| **`items`** | The **subcollection** under `checklists/global`. Path: `checklists` → `global` → **`items`**. |
| (nothing called `checklist_item`) | There is no collection or path named `checklist_item`. |

So in the Console you only create and use **`items`**.

---

## Concept vs collection name

| Term we use in docs | Meaning |
|---------------------|--------|
| **"checklist item"** | One row in the checklist (one task: title, description, url, order). A **concept**. |
| **`items`** | The Firestore **subcollection** where those rows are stored. Each **document** in `items` is one checklist item. |

So:

- **Collection name in Firestore:** **`items`** (under `checklists/global`).
- **One checklist item** = one document in that **`items`** subcollection (e.g. doc id `item1` with fields `title`, `description`, `url`, `order`).

---

## How it fits together

- **checklists / global / items**  
  - Here we store the **definition** of each checklist row (title, description, url, order).  
  - One document = one **checklist item**.  
  - The **collection** is named **`items`**; we often call each doc a "checklist item."

- **user_checklist**  
  - Stores per-user completion.  
  - Each doc has **`itemId`**, which is the **document ID** of one of the docs in **`items`** (e.g. `item1`).  
  - So `itemId` points to a **checklist item** that lives in the **`items`** subcollection.

---

## Summary

- Use **`items`** in Firebase: that’s the only collection name for checklist rows.
- **"Checklist item"** = one of those rows = one document in **`items`**.
- Don’t create or look for a collection called **`checklist_item`**; it doesn’t exist in this schema.
