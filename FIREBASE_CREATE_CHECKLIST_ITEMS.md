# How to create "checklists → global → items" in Firebase

In Firestore, a **subcollection** is a collection that lives **inside** a document. You don’t “link” them; you create the document first, then add a collection **from that document**. The subcollection **is** the collection named `items` under the `global` document.

---

## What “items” is

- **`items`** is the **name** of the subcollection.
- It’s the list of checklist rows (each row = one document with `title`, `description`, `url`, `order`).
- It’s “under” the `global` document so the path is: **checklists** (collection) → **global** (document) → **items** (subcollection).

So: **“link the global document to the subcollection”** = create the `global` document, then add a collection with ID **`items`** from inside that document.

---

## Step-by-step in Firebase Console

### 1. Create the collection `checklists`

1. Open [Firebase Console](https://console.firebase.google.com) → your project.
2. Go to **Build** → **Firestore Database**.
3. Click **Start collection** (or **+ Start collection**).
4. **Collection ID:** type `checklists`.
5. Click **Next**.

---

### 2. Create the document `global` (inside `checklists`)

You’re now adding the first document to `checklists`. This document will be the “container” for the `items` subcollection.

1. **Document ID:** choose **Specify ID** and type `global`.
2. You can add a dummy field (e.g. field name `_`, type string, value `x`) so Firestore lets you save, or use **Add field** then delete it if the UI requires a field. Some UIs allow creating an empty document.
3. Click **Save**.

You now have: **checklists** → **global** (one document).

---

### 3. Add the subcollection `items` (inside the `global` document)

The subcollection is created **from the document**, not from the collection.

1. In the Firestore data view, **click the `global` document** (under `checklists`).
2. The right-hand (or bottom) panel shows the document. Look for an option such as:
   - **Start collection**, or  
   - **Add subcollection**, or  
   - A **+** or **Add collection** near “Subcollections” or under the document.
3. Click that and enter **Collection ID:** `items`.
4. Click **Next** (or equivalent).

You now have: **checklists** → **global** → **items** (empty subcollection).

---

### 4. Add the first checklist item (document inside `items`)

You’re now adding a document **to the `items` subcollection**.

1. **Document ID:** e.g. `item1` (or **Auto-ID** if you prefer).
2. **Fields** (Add field for each):

   | Field        | Type   | Value (example)        |
   |-------------|--------|-------------------------|
   | `title`     | string | `Complete FAFSA`        |
   | `description` | string | `Submit the FAFSA`   |
   | `url`       | string | `https://studentaid.gov/fafsa` |
   | `order`     | number | `1`                     |

3. Save.

You now have: **checklists** → **global** → **items** → **item1** (and any more items you add).

---

## How they’re “linked”

- **Collection** `checklists` holds **documents** (we have one: `global`).
- **Document** `global` can have **subcollections** (we added one: `items`).
- **Subcollection** `items` holds **documents** (e.g. `item1`, `item2`) — those are the checklist rows.

So:

- **“Link global document to the subcollection”** = add a subcollection with ID **`items`** to the **`global`** document (steps 2 and 3 above).
- **“What is the subcollection items?”** = the collection named **`items`** under **`global`** that holds the checklist item documents (each with `title`, `description`, `url`, `order`).

No separate “link” step; the link is that `items` is created **under** the `global` document in the Console.
