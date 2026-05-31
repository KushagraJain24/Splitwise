# AI Context: Splitwise Clone MVP

This document serves as the single source of truth for the project. It tracks product goals, scope, requirements, architectural decisions, API designs, schemas, and implementation history.

---

## 1. Product Understanding & Goals
* **Core Value Prop:** A simplified, high-fidelity clone of Splitwise for logging expenses, dividing bills, tracking group balances, and recording settlements.
* **Target Audience:** Young adults (20–35), primarily flatmates, travel groups, or friend groups.
* **Trust Assumption:** All users are trusted. No approval flows are required to add expenses or record settlements.
* **Currency:** Multi-currency support: INR (₹), USD ($), and EUR (€). Stored in a USD base currency schema with customizable exchange rates updated dynamically from the Account settings page.

---

## 2. Product Scope
### In Scope (MVP)
* **User Authentication:** Email & password-based signup, login, and logout powered by Firebase Auth.
* **Dashboard / Main Screen:**
  * Displays overall balance summary: "You owe ₹X" (coral) and "You are owed ₹Y" (emerald), using a net balance per person across all groups.
  * Navigation links to Groups, Friends, Activity Log, and Balance Analytics.
* **Group Management:**
  * Create a group with a name, description, and group members.
  * Add group members by searching for registered emails, or select from existing contacts.
  * Auto-create "placeholder" users for non-registered email addresses. When a user registers with that email, they claim the placeholder history.
* **Direct 1-on-1 Expenses:** Create direct expenses with a friend outside of any group.
* **Expense Management:**
  * Add expenses inside a group or directly with a friend.
  * Record details: description, amount, payer (who paid), date, and splits.
  * Support multiple split strategies:
    * **Equal:** Total divided evenly among selected members.
    * **Exact:** Specify exact amounts owed per member (must sum to total).
    * **Percentage:** Specify percentage owed per member (must sum to 100%).
    * **Shares:** Specify share weights per member (e.g., Alice 2 shares, Bob 1 share).
  * Soft delete expenses (mark as deleted to preserve audit trails). Editing/updating settled or partially settled expenses is disabled.
* **Settle Up & Cross-Group Settlements:**
  * Record a manual payment between two members.
  * Options: Record as a virtual Cash payment, or simulate an Online (mock UPI/Netbanking) payment.
  * **Settle Net Balance (Cross-Group):** Let users pay a net offset amount that the backend automatically distributes to outstanding mutual group debts.
* **Balance & Debt Calculation:**
  * On-the-fly balance calculation from raw expenses and settlements.
  * **Debt Simplification Algorithm:** Greedy debt minimization (minimizes the total number of transactions required to settle up within a group).
  * **Net Balance Per Person:** Automatically aggregates and nets balances for the same individual across all groups + direct friend debts.
* **Multi-Currency Support:** Support INR, USD, EUR with custom rate settings.
* **Analytics & Visuals:**
  * Basic interactive charts for expenses inside a group (e.g., category-wise breakdown or over-time trend).
  * Rich dashboard layout with glassmorphic cards, smooth micro-animations, and modern typography.

### Out of Scope
* OCR / Receipt scanning.
* Real-time payment gateway integration (mock UPI/cash settlement only).
* Recurring expenses.
* Real-time chat or comments on expenses.
* Push/Email notifications.

---

## 3. Implementation Decisions & Tech Stack
* **Frontend Framework:** Flutter Web/Mobile (built with Flutter SDK 3.38.5, Dart 3.10.4).
* **State Management:** Provider (simple, reactive, robust for MVPs).
* **Backend & Database:** Firebase (Firebase Auth for authentication, Cloud Firestore for real-time relational-like data storage).
* **Styling & Aesthetics:** Premium custom dark/light theme, Outfit/Inter typography, smooth gradients, custom painters for charts, and glassmorphism styling via Flutter's `BackdropFilter` and `BoxDecoration`.
* **Deployment Plan:** Flutter Web built and hosted on Firebase Hosting (offering fast CDN, HTTPS, and seamless integration with the database/auth environment).
* **Testing:** Manual browser verification and verification scripts.

---

## 4. Database Schema (Firestore)

### `users` (Collection)
```json
{
  "uid": "USER_UID_1",
  "email": "alice@example.com",
  "displayName": "Alice Smith",
  "photoUrl": "https://...",
  "isPlaceholder": false,
  "createdAt": "TIMESTAMP"
}
```

### `users/{userId}/friends` (Subcollection)
```json
{
  "uid": "USER_UID_2",
  "email": "bob@example.com",
  "displayName": "Bob Jones",
  "createdAt": "TIMESTAMP"
}
```

### `groups` (Collection)
```json
{
  "groupId": "GROUP_ID_1",
  "name": "Flat 202",
  "description": "Rent and utilities",
  "createdBy": "USER_UID_1",
  "createdAt": "TIMESTAMP",
  "members": ["USER_UID_1", "USER_UID_2"],
  "memberDetails": {
    "USER_UID_1": {
      "displayName": "Alice Smith",
      "email": "alice@example.com",
      "isPlaceholder": false
    },
    "USER_UID_2": {
      "displayName": "Bob Jones",
      "email": "bob@example.com",
      "isPlaceholder": false
    }
  }
}
```

### `expenses` (Collection)
```json
{
  "expenseId": "EXPENSE_ID_1",
  "groupId": "GROUP_ID_1",
  "friendId": null,
  "description": "Electricity Bill",
  "amount": 1200.00,
  "paidBy": "USER_UID_1",
  "splitType": "EQUAL",
  "splits": {
    "USER_UID_1": {
      "owedAmount": 600.00,
      "exactValue": 600.00
    },
    "USER_UID_2": {
      "owedAmount": 600.00,
      "exactValue": 600.00
    }
  },
  "isSettlement": false,
  "createdAt": "TIMESTAMP",
  "createdBy": "USER_UID_1",
  "deletedAt": null
}
```

### `settlements` (Collection)
```json
{
  "settlementId": "SETTLEMENT_ID_1",
  "groupId": "GROUP_ID_1",
  "friendId": null,
  "payerId": "USER_UID_2",
  "receiverId": "USER_UID_1",
  "amount": 600.00,
  "paymentMethod": "CASH",
  "createdAt": "TIMESTAMP",
  "deletedAt": null
}
```

### `activities` (Collection)
```json
{
  "activityId": "ACTIVITY_ID_1",
  "groupId": "GROUP_ID_1",
  "friendId": null,
  "activityType": "expense_add",
  "userIds": ["USER_UID_1", "USER_UID_2"],
  "actorId": "USER_UID_1",
  "targetId": null,
  "metadata": {
    "description": "Dinner at Beach Cafe",
    "amount": 1500.00,
    "paidBy": "USER_UID_1",
    "paidByName": "Alice Smith",
    "groupName": "Goa Trip 2026 🌴"
  },
  "createdAt": "TIMESTAMP"
}
```

---

## 5. Key Algorithms & Engineering Logic

### Balance Calculation (On-The-Fly)
To find the balance between users:
1. Query active expenses (`deletedAt == null`) and settlements for the target context (group or direct friend).
2. For each expense:
   * Payer (`paidBy`) is credited the full `amount`.
   * For each member in `splits`, they are debited the `owedAmount`.
3. For each settlement:
   * Payer (`payerId`) is credited the `amount`.
   * Receiver (`receiverId`) is debited the `amount`.
4. Net balance for user $U$ = $\sum \text{Credits} - \sum \text{Debits}$.

### Debt Simplification Algorithm (Greedy Debt Minimizer)
Given the net balances of all group members:
1. Filter out users with zero net balance.
2. Separate users into Creditors (net balance > 0) and Debtors (net balance < 0).
3. While Creditors and Debtors list is not empty:
   * Find the largest debtor $D$ (most negative balance) and largest creditor $C$ (most positive balance).
   * Calculate transaction amount: $T = \min(|B_D|, B_C)$.
   * Record that $D$ pays $C$ the amount $T$.
   * $B_D \leftarrow B_D + T$.
   * $B_C \leftarrow B_C - T$.
   * Remove any user from list whose balance reaches 0.
4. Return the list of simplified transactions.

---

## 6. Edge Cases & Safety Rules
* **Rounding Errors:** When dividing $10.00 equally among 3 users:
  * Splitting calculation: $10.00 / 3 = 3.3333...$
  * User 1: 3.33, User 2: 3.33.
  * The final (last) member gets charged the remainder: $10.00 - (3.33 + 3.33) = 3.34$.
  * All splits are rounded to exactly 2 decimal places.
* **Settled Expense Modification:** Editing an expense that is already settled (either fully or partially) is **disabled**.
* **Leaving a Group:** A user cannot leave a group if they have a non-zero net balance (either they owe money or are owed money).

---

## 7. Trade-offs & Limitations
* **On-the-fly Computation:** Balance queries scale with the number of transactions. For a 3-day MVP, this avoids out-of-sync cache errors and simplifies the backend. If transaction volume becomes massive, we would implement aggregated/cached balances or Firestore Cloud Functions.
* **Soft Deletes:** Deletes only mark `deletedAt = timestamp`. They are excluded from active calculations but remain in the database.
* **No Real Payments:** Transactions are recorded manually or via simulated flow; no real UPI/Stripe integrations.

---

## 8. Development Timeline & Logs
* **2026-05-29 (Scoping):** Initial project interview completed. Requirements and scoping finalized. Firebase and Flutter selected. AI_CONTEXT.md initialized.
* **2026-05-29 (Execution):** Completed full Flutter app structure with local/mock DB fallback. Upgraded Firebase dependency constraints to major versions (`firebase_core: ^4.9.0`, `firebase_auth: ^6.5.1`, `cloud_firestore: ^6.4.1`) to resolve static web compilation mismatches. Successfully ran the full test suite with 9 passing tests (algorithms + widget smoke checks) and compiled release build for production web (`build/web`).
* **2026-05-29 (Expansion):** Implemented pairwise dues display on Settle Up page featuring real-time direct/simplified balance summaries and Autofill "Use this" action. Added a bottom navigation bar layout dividing Groups, Friends, Activity Feed, and Account settings. Implemented native Splitwise-looking Activity feed screen with custom avatars, action-type stacked corner badges, bold names, and colored ledger impact status lines. Verified compilation, passing test suite (9/9), and completed static production web release build.
* **2026-05-29 (Selectors & Custom Logos):** Integrated 'Add Friends' stateful checklist and 'Add Contacts' mock phonebook sheet into the group creation interface, allowing instant placeholder invites. Refactored the Activity feed custom avatars to dynamically resolve context-specific and balance-relative logos (Green receipt for lending, Orange for owing, green down-arrow for payments received, orange up-arrow for payments sent, purple person for additions, and blue group-add for creations). Verified tests and compiled release builds.
* **2026-05-29 (Add Member to Group):** Implemented "+ Member" feature for existing groups. Extended `DbService` with dual-mode `addMembersToGroup` database update operations and automatic reciprocal friendship establishment. Extended `AppProvider` with stateful `addMembersToGroup` triggers, loading status, and `member_add` activity feed logging. Integrated "+ Member" action button in `GroupDetailScreen` AppBar along with interactive bottom sheets (email search, invite dialogs, staged list chips, friends check-off list, and mock contacts sheet). Added unit test suite validating persistence and auto-friendship logic.
* **2026-05-29 (Firebase Connection):** Connected the Flutter app with actual Firebase database (Cloud Firestore) and authentication (Firebase Auth). Added `lib/firebase_options.dart` config template, integrated DefaultFirebaseOptions in `lib/main.dart`, registered Google Services plugin in `android/settings.gradle.kts` and applied it in `android/app/build.gradle.kts`. Removed the Evaluator Sandbox quick demo login panel from the login interface to mandate actual credential signins/signups. Implemented a beautiful setup warning onboarding overlay if Firebase is unconfigured, allowing users to proceed offline. Updated widget test suite with scrolling and tapping bypass simulation checks to confirm complete compilation correctness.
* **2026-05-29 (Google Auth & Conf Dialogs):** Added Google Sign-In support in v7+ API style using the singleton `GoogleSignIn.instance.authenticate()` flow. Configured automatic placeholder history claiming when registering or signing in via Google with a previously invited email. Map raw Firebase Auth `FirebaseAuthException` error codes into clear, user-friendly messages for the SnackBar. Built a dark-mode styled glassmorphic confirmation popup dialog for the sign out process. Verified all unit and widget tests pass, and compiled production web releases.
* **2026-05-29 (Auth Fixes, Group Deletion, and Native Contacts):** Fixed login page refresh and Google sign-in loop bugs by introducing `isInitialized` status tracking in `AuthProvider` (ensures auth wrapper stays mounted during transitions) and returning a temporary `UserModel` when Firestore profile is not yet written during stream listener check. Implemented Group Soft-Deletion (`deletedAt` field, database/provider deletion methods, delete group button in group details page, and custom activity feed log with red sweep icon). Integrated native device contacts using `flutter_contacts` on Android and iOS (added permissions, requested runtime access, loaded names and emails/numbers), while maintaining a safe fallback to mock contacts on Web/Desktop. Checked that all 13 unit/widget tests compile and pass successfully.
* **2026-05-29 (Password visibility & Inline login error):** Added a toggleable eye icon in the password field for both login and signup screens. Re-routed authentication error messages from SnackBar displays into an inline, custom warning container rendered directly below the fields inside the cards. Mapped Google Sign-in exception code 16 / Account reauth failures to a helpful setup instruction directing the developer to configure SHA-1 fingerprints in the Firebase Console.
* **2026-05-29 (Logo, Splash Page, Offline-First Auth Caching & Contacts Enhancements):** Overwrote default assets logo with the new generated app logo. Created a premium dark-mode animated `SplashScreen` with fade-in/scale-up entry and set it as the initial page. Implemented SharedPreferences-based offline-first authentication cache in `AuthProvider` to eliminate login screen flashes on startup and allow instant dashboard access. Added robust Firestore network error fallbacks in `onAuthStateChanged` stream in `AuthService` to prevent unexpected offline logouts. Enhanced contact selection bottom sheets in both `CreateGroupScreen` and `GroupDetailScreen` to support custom inline contact creation (Name + Email + "+") and HTML5 browser-native contact selection. Added and configured `flutter_launcher_icons` to replace the default Flutter app launcher icons with our custom branding logo for Android and iOS. Verified all 13 tests pass and compiled release web builds.
* **2026-05-29 (Contacts Permission Android Fix):** Fixed Android runtime contacts permission request logic by passing `readonly: true` in `FlutterContacts.requestPermission()`. This aligns requests with the declared `READ_CONTACTS` permission inside `AndroidManifest.xml`, resolving the issue where the OS immediately dismissed the permission dialog and reported "permission not given" because `WRITE_CONTACTS` was implicitly requested.
* **2026-05-29 (Direct/Group Expense Calculation Fix):** Fixed a dashboard balance calculation error where the total net balance and owed amounts were double-counted for group members who were also friends. Added safety checks to `DbService.getExpenses` to filter out non-null and non-empty `groupId` elements for direct friend listings.
* **2026-05-29 (Active Invite Channels & Visual Cleanups):** Removed the "Pending Invite" state visual indicators from the dashboard friends view list. Standardized the display to render invited friends identically to normal friends using the premium teal palette. Integrated email and phone validation inside the "Add Friend" dialog to support non-email inputs. Configured dynamic channel integration popup dialogs using `url_launcher` (opening the user's mail client for emails, and prompting SMS or WhatsApp for phone numbers) when adding new placeholder contacts or adding them directly to groups.
* **2026-05-30 (Phone Setup & History Merging):** Expanded `UserModel` with a `phone` field. Added custom phone field to `SignupScreen`. Implemented a glassmorphic `PhoneSetupScreen` overlay in `AuthWrapper` prompting users logging in/registering without a phone number to link their mobile profile. Configured automated background claiming that queries placeholders matching either email or phone, merging matching invites and group history immediately upon number verification. Optimized the contacts picker selection responsiveness by caching selections via local temporary placeholders. Preserved native contact formats by sanitizing wa.me and sms launch queries to remove invalid formatting.
* **2026-05-30 (Expense Description Suggestions):** Added interactive quick-suggestion chips under the description field on the Add Expense screen. Predefined categories include 'Food & Drinks', 'Transportation', 'Accommodation', 'Activities', and 'Shopping'. Each chip displays with a corresponding icon and highlights if it matches the current description text. Selection updates the text field and moves the cursor to the end, while listening to text controller changes to dynamically sync active selections.
* **2026-05-30 (Settlement & Calculation Fixes):** Fixed a bug in `SettleUpScreen` where direct friend settlements omitted the `friendId` parameter when saving, resulting in a database schema mismatch. Corrected settlement calculations to ensure that recording a settlement within a group does not dynamically alter or re-split past expenses. Added a unit test validating 3-way split settlements.
* **2026-05-30 (Cross-Group Friend Balances & Distributed Settlements):** Enhanced the Friends tab in the dashboard to show the combined total net balance (direct 1-on-1 + mutual group simplified debts) with each friend, rather than just direct balances. Added a "Settle" action button shortcut on each friend's list tile to open the pre-filled settlement form. Implemented automatic payment distribution in `AppProvider.settleUp` for global settlements, settling mutual group simplified debts first and storing any remainder as a direct settlement. Created a unit test to verify distribution correctness.
* **2026-05-30 (Friends Filter, UI Redesign, and Overflow Fixes):** Added premium ChoiceChips on the Friends page to filter contacts dynamically (All, Settled, I owe, Owed to me). Overhauled the friends list tile layout into a space-efficient custom vertical action card preventing long emails/names from wrapping to multiple lines. Resolved the horizontal overflow warnings on the Settle Up Screen by wrapping columns in Expanded and setting DropdownButtons to fill parent widths.
* **2026-05-30 (Group Types Redesign & Detail Screen):** Redesigned the group creation screen to allow choosing from four group types: **Trip**, **Family**, **Self**, and **No Expense** in a 2x2 outlined layout. The members addition section is hidden for Self and No Expense. Added dynamic direct friend transaction aggregation for No Expense groups in the group details screen, hiding the Add Member, Settle Up, and Add Expense buttons conditionally.
* **2026-05-30 (Add Expense Screen Redesign):** Overhauled the Add Expense screen to feature a custom Split Context bottom sheet showing Groups and Friends in separate sections. Replaced dropdowns and button rows with inline text-linked selectors (`Paid by [you] and split [equally]`) that open picker sheets, placed an interactive Category Box next to the description, and integrated date selection.
* **2026-05-30 (Specialized Group Icons & Screen Customizations):** Configured distinct colored icons based on group type: `Icons.person` for **Self**, `Icons.money_off` for **No Expense**, `Icons.home` for **Family**, and `Icons.airplanemode_active` for **Trip**. Modified the group details screen layout to completely remove tabs/charts and balance cards for **Self** groups (rendering a simplified single expense list and total spent), and to show a simplified two-tab system (**Expenses** and **Settle**) for **No Expense** groups listing friends with direct outstanding balances and quick settle shortcuts.
* **2026-05-30 (Add Expense Cleanups & Contact Selectors):** Refined Add Expense screen by removing the inline Date selector row, renaming the description input hint text from "Enter a description" to "Description", and replacing the "Amount (₹)" input label with a cleaner placeholder hint "₹". Integrated auto-unfocus calls on text fields before displaying bottom sheets to prevent keyboard collision bugs. Upgraded contacts and friends sheet selectors in `CreateGroupScreen` and `GroupDetailScreen` to conditionally render a checkmark tick button on the top right only when at least one selection is made, closing the modal on tap, while keeping the close icon active when the selection is empty. Verified all unit tests pass (17/17).
* **2026-05-30 (Keyboard Fix - Bottom Sheets):** Fixed a recurring keyboard re-appearance bug on the Add Expense screen where tapping split/payer/context chips would briefly dismiss then re-show the keyboard after the bottom sheet closed. Root cause: when `Navigator.pop(ctx)` dismisses the sheet, Flutter's focus engine automatically restores focus to the last-active text field. Fix: added explicit `FocusNode` instances for description and amount fields, created a `_dismissKeyboard()` helper, and called `_dismissKeyboard()` both **before** each sheet opens AND **after** via `.then((_) => _dismissKeyboard())` on every `showModalBottomSheet` call.
* **2026-05-30 (Lazy Loading & Dashboard Offline Caching):** Implemented SharedPreferences-based local caching for all dashboard data (Groups, Friends, Activities, and direct/group expenses). The dashboard now uses a cache-first approach to render UI instantly, performing database fetches in the background and updating cache and UI dynamically. Created a custom glassmorphic `SavingOverlay` widget with a blurred backdrop to provide visual feedback and prevent user interactions during save/write operations (`createGroup`, `deleteGroup`, `addMembersToGroup`, `addFriend`, `removeFriend`, `addExpense`, `softDeleteExpense`, `settleUp`). Adjusted submit button states to check `appProv.isSaving`. Verified all 16 tests compile and pass successfully.
* **2026-05-30 (UI Fixes, In-App Reminders, Activity Swiping & Cartoon Avatars):** Wrapped SavingOverlay glass dialog in Material to fix double yellow outlines under loading text. Implemented in-app reminders logged directly to user activity feeds in place of external email/SMS channels, styled with custom gold alert indicators. Enabled swipe-to-delete on items in the Activity screen using Dismissible widgets linked to database and cache deletions. Replaced text-based emoji avatars with 8 premium cartoon illustration avatar pngs registered as assets in pubspec.yaml. Verified all unit and widget tests pass (16/16).
* **2026-05-30 (Custom Reminders Dialog & Bell Icon Notification Center):** Integrated a customized input dialog prompting the user for custom message text when sending a reminder, pre-filled with the default balance reminder message. Rendered customized reminder messages inside premium italicized quote bubbles in the activity log. Integrated a notification bell icon into the Groups and Friends dashboard app bars opening a bottom sheet listing all received in-app reminders. Verified all tests compile and pass successfully.
* **2026-05-30 (Reminders Badge & Subtitle Cleanup):** Implemented dynamic badge counting (+1 up to +9) sequentially for received reminders on the dashboard notification bell icon, clearing it automatically on tap. Configured activity logs to hide the default "They owe you ₹X" subtitle block when a custom reminder message is present. Verified all tests compile and pass successfully.
* **2026-05-30 (Multi-Currency & Exchange Rates):** Implemented multi-currency support (INR, USD, EUR) using a USD base currency schema. All database records (expenses, settlements, reminders) are stored in USD and converted to the active currency on load. Added interactive Currency Settings under the Account section to switch currencies and edit exchange rates, updating the overall layout. Replaced all hardcoded ₹ symbols with AppConstants.currencySymbol dynamically. Verified all tests pass.
* **2026-05-30 (Cross-Group Settlement & Overflow Fixes):** Implemented "Net Balance Per Person" calculation across all groups and direct friend debts. Recomputed dashboard overall totals by netting balances per person instead of summing group/direct totals independently. Renamed the individual settlement choice to "Settle Net Balance (Cross-Group)" and updated outstanding dues display. Replaced the inline Row in Add Expense screen with a Wrap widget to prevent layout overflows. Verified all tests pass.
* **2026-05-30 (Account Tab Avatar & Reciprocal Claiming Fixes):** Replaced the static Account icon in the bottom navigation bar with the user's custom premium cartoon avatar. Programmed active state with a thin teal border and inactive state with a 60% opacity. Refactored the registration and Google sign-in methods in `AuthService` to run `claimPlaceholderHistory` AFTER the profile is created, guaranteeing correct profile details exist. Upgraded `claimPlaceholderHistory` in Firestore to migrate the `friends` subcollection (moving friends list to the new user and updating all reciprocal friend records). Verified all tests pass.
* **2026-05-30 (Optimistic Avatars & Onboarding Load Fix):** Enhanced avatar changes to update the UI instantly (via memory and SharedPreferences cache) and write to the database in the background without blocking the UI. Configured `getFriends` in `DbService` to dynamically load friends' latest profiles in parallel, propagating avatar changes immediately to others. Resolved the onboarding empty groups/friends bug by setting `_lastLoadedUid = null` during the `PhoneSetupScreen` flow, forcing a complete dashboard reload upon completing phone linkage. Verified all tests pass.
* **2026-05-30 (Google Sign-In Casing Fix & Self-Healing Claiming):** Resolved a case-sensitivity mismatch bug in Google Sign-In where emails were stored exactly as returned by Google (causing subsequent case-sensitive email queries by friends to fail and create duplicate placeholder accounts). Fixed by lowercasing the Google Sign-In emails. Implemented `findPlaceholderForEmailOrPhone` query in `DbService` and integrated a background self-healing database check inside `loadDashboardData` in `AppProvider` to automatically scan for and claim any unclaimed placeholder history matching the active user's email/phone, ensuring past duplicates (like Sajjan's) are successfully merged and claimed when logging in or viewing the dashboard. Claimed placeholders are now deleted from the users collection. Verified all tests pass.
* **2026-05-30 (Full Database Claiming & Index-Free Search):** Expanded the self-healing DB checker to perform index-free email searches in Firestore (filtering by placeholder status in memory) to prevent index issues. Upgraded `claimPlaceholderHistory` in Firestore mode to migrate the entire `expenses` collection, modifying payers, split stakes, and direct friend references for all group-based and direct 1-on-1 expenses associated with the placeholder UID. Verified all tests pass.
* **2026-05-30 (Phone/Email Linking, Case-Insensitive Matching, & Sign-In Cancellation Fixes):** Standardized `UserModel` constructor and `fromMap` factory to automatically lowercase emails and sanitize phone numbers (keeping only digits). Implemented flexible phone number matching (using last 10 digits) in memory and Firestore queries using `whereIn` phone variations (`last10`, `91$last10`, `+91$last10`, `0$last10`). Added fallback checks for case-insensitive email matching. Fixed Google Sign-In cancellation to silently fail without showing error popups by mapping cancellation exceptions to a `null` error message. Verified all tests pass (17/17).
* **2026-05-31 (Group Notes Feature):** Introduced Group Notes functionality. Created the `GroupNoteModel` data structure. Modified `DbService` and `AppProvider` to support adding, loading, and deleting notes from groups, with mock and Firebase Firestore database integration. Added a Notes icon button to every group's AppBar in `GroupDetailScreen` that triggers a premium bottom sheet list displaying user notes, author info, and relative post times, along with inline note creation capabilities. Verified all 17 tests pass successfully.
