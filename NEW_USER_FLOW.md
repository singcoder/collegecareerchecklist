# What the code does when we add a new user

---

## 1. User taps "Sign in / Register" with new email/password

**Where:** `EmailPasswordSignInScreen` → `_signInOrRegister()`

1. **Try sign-in first**  
   `FirebaseAuth.instance.signInWithEmailAndPassword(email, password)`  
   For a new user, Auth returns an error (e.g. `invalid-credential` or `user-not-found`).

2. **Treat as new user and create account**  
   On that error, the code calls  
   `FirebaseAuth.instance.createUserWithEmailAndPassword(email, password)`  
   Firebase **Authentication** creates the user (email + UID).  
   **No Firestore write happens here.** The app does not create a user document in Firestore at signup.

3. **Auth state updates**  
   `authStateChanges()` emits the new `User`, so `AuthGate` rebuilds and shows `ChecklistScreen` instead of the sign-in screen.

---

## 2. New user lands on the checklist screen

**Where:** `ChecklistScreen` (user is already signed in; `FirebaseAuth.instance.currentUser!` has the new UID)

1. **Load checklist items (shared, read-only)**  
   The app subscribes to  
   `checklists/global/items`  
   and lists all documents ordered by `order`.  
   Same data for every user; no per-user copy.

2. **Load this user’s completion state**  
   The app queries  
   `user_checklist`  
   where `userId == currentUser.uid` and `checklistId == 'global'`.  
   **For a brand-new user this returns no documents.**  
   So `completionMap` is empty and every item is shown as **not completed** (checkbox unchecked).

3. **No Firestore write**  
   Merely opening the checklist does **not** create any document in `user_checklist`.  
   The new user is not “created” in Firestore at this step; only Auth knows about them.

---

## 3. New user checks or unchecks an item

**Where:** `ChecklistScreen` → checkbox `onChanged` → `_updateCompletion()`

1. **One doc per (user, checklist, item)**  
   Document ID: `{userId}_global_{itemId}`  
   e.g. `abc123_global_item1`.

2. **Write to Firestore**  
   The code does a **set with merge** on that document with:
   - `userId` = current user’s UID  
   - `checklistId` = `'global'`  
   - `itemId` = the checklist item’s document ID  
   - `isComplete` = `true` or `false`  
   - `completedAt` = server timestamp when checked, `null` when unchecked  
   - `createdAt` = server timestamp (set/updated on write)

3. **When it’s created**  
   The **first time** this user toggles that item, that `user_checklist` document is **created**.  
   Later toggles only **update** the same document.  
   So “adding a new user” in Firestore happens **lazily**: the first time they change a completion state.

---

## Summary

| When | What the code does | Firestore |
|------|--------------------|-----------|
| **New user registers** | Sign-in fails → `createUserWithEmailAndPassword` | No Firestore write. User exists only in **Firebase Auth**. |
| **New user opens checklist** | Read `checklists/global/items`; query `user_checklist` by `userId` + `checklistId` | Read-only. No `user_checklist` docs yet for this user. |
| **New user checks/unchecks an item** | `_updateCompletion()` sets/merges one doc in `user_checklist` | **First write** for this user: create (or update) one doc per item they touch. |

So: **adding a new user** in the app means creating them in **Auth** only; their presence in **Firestore** is only in **`user_checklist`**, and only when they first interact with a checklist item (one doc per item they toggle).
