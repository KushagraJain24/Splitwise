# Build Plan - Splitwise Clone App 💸

This document details the development lifecycle, product decisions, architectural schema, AI pair-programming process, and engineering tradeoffs made during the creation of this Splitwise clone.

---

## 1. Product Research

### How We Studied Splitwise
We analyzed the core features of the official Splitwise mobile and web applications, paying close attention to:
- **Ledger Balances:** How Splitwise represents who owes whom, focusing on group vs. individual balances.
- **Settlement Workflows:** The mechanics of recording payments, simplifying debts, and settling up.
- **User Invitation Pipeline:** How users invite contacts by email or phone numbers, how mock accounts are set up, and how these invite histories are merged when real profiles are registered.
- **Expense Creation Forms:** Split equations (equal, exact value), currency inputs, category labels, and date records.

### Key Learnings
- **Debts are Relational:** A single person owes money across multiple groups and direct relationships. Merely summing balances per group/friend separately results in duplicates and confusion.
- **Casing & Formats Cause Fragmentation:** If users register with mixed-case emails (e.g. `User@Example.com`) or variations in phone prefixes (`+91`, `0`, or without country codes), standard database queries fail. Data must be sanitized upon model initialization.
- **Claiming History requires Cascading Updates:** When a placeholder user becomes a real registered user, all group memberships, transaction logs, payers, split keys, and direct relationships must migrate to the new UID.

### Product Assumptions
- **USD base schema:** All db transactions are stored in USD internally, allowing real-time currency conversions when fetching INR/EUR rates.
- **Offline first:** Speed is a key metric. Local caching of data via `SharedPreferences` ensures instant rendering on boot.

---

## 2. Final Scope

### In Scope
- **Dynamic Group Customization:**
  - **Trip / Family:** Normal group splitting, balances tab, and charts tab.
  - **Self:** Personal budget logger that tracks personal purchases without splits.
  - **No Expense:** Simplifies transaction aggregation (direct 1-on-1 balances).
- **Group Notes 📝:** Option to share, read, and write persistent group announcements.
- **Cross-Group Settlements:** A single settlement action distributed across mutual group debts first before direct debts.
- **Linking & Self-Healing:** Seamless link between email and last-10-digit phone variations, with automated duplicate merging.
- **Aesthetic Premium UI:** Animated splash page, curated dark gradients, glassmorphism, illustration avatars, and gold notification center indicators.

### Out of Scope
- **Real Payment Integrations:** Standard UPI/card payments are replaced with mock manual settlement records.
- **Optical Character Recognition (OCR):** Receipt scanning is excluded.
- **Real-Time Push Notifications:** Replaced with localized in-app reminders logged to activity feeds.

---

## 3. Architecture

### Tech Stack
- **Frontend Framework:** Flutter & Dart (Single codebase for Web, Android, iOS).
- **State Management:** Provider (highly reactive, lightweight).
- **Database & Auth:** Firebase Auth & Cloud Firestore.
- **Local Storage:** SharedPreferences (Offline caching).

### Database Schema (Firestore)
- **`users` Collection:**
  - `uid` (String), `email` (String - always lowercase), `displayName` (String), `phone` (String - sanitized digits), `photoUrl` (String), `isPlaceholder` (Boolean), `createdAt` (Timestamp).
  - Subcollection `friends`: Holds user document structures representing reciprocal friendships.
- **`groups` Collection:**
  - `groupId` (String), `name` (String), `description` (String), `createdBy` (String), `createdAt` (Timestamp), `members` (Array of UIDs), `memberDetails` (Map of UID keys to displayName, email, isPlaceholder), `type` (String: TRIP/FAMILY/SELF/NO_EXPENSE), `deletedAt` (Timestamp).
  - Subcollection `notes`: `noteId` (String), `content` (String), `createdBy` (String), `createdByName` (String), `createdAt` (Timestamp).
- **`expenses` Collection:**
  - `expenseId` (String), `groupId` (String? - null for direct), `friendId` (String? - for direct), `description` (String), `amount` (Double - stored in USD), `paidBy` (String), `splitType` (String), `splits` (Map of UID keys to SplitDetail map), `isSettlement` (Boolean), `createdAt` (Timestamp), `createdBy` (String), `deletedAt` (Timestamp).

---

## 4. AI Collaboration Process

### AI Instruction Style
We used a sequential pair-programming approach:
1. **Planning Phase:** Outlining new features using markdown `implementation_plan.md` plans before coding to ensure complete alignments.
2. **Modular Edits:** Editing distinct layers (models first, database services second, provider state manager third, UI fourth).
3. **Continuous Testing:** Running automated testing (`flutter test`) at the end of every change to prevent code regressions.

### Context Maintenance
- The **`AI_CONTEXT.md`** file was continuously updated at the end of each session. This ensured a persistent changelog, design rules, and schema decisions were propagated across compilation Compacts.

---

## 5. Tradeoffs & Simplifications

- **USD Base Schema:** Simplifies ledger calculations. Instead of handling multiple currencies inside the database splits, all transactions are stored in USD and converted to INR/EUR values at runtime using active rates.
- **Subcollection Querying fallbacks:** Since Firestore lacks case-insensitive indexing, we implemented case-insensitive checks in Dart, fetching placeholder profiles and performing secondary string evaluations on the client-side.
- **Manual Web Contacts:** Native contact queries are supported on Android and iOS, but falls back to manual browser-native custom contact staging on Desktop/Web to bypass package constraints.
- **Future Improvements:** With more time, we would implement cloud functions to batch update claimed placeholders instead of performing client-side Firestore batches.
