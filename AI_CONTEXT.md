# AI Context: Splitwise Clone MVP

This document serves as the single source of truth for the project. It tracks product goals, scope, requirements, architectural decisions, API designs, schemas, and implementation history. It is designed to be detailed enough for any developer or AI agent to rebuild the same app and arrive at a similar codebase.

---

## 1. Product Understanding & Goals
* **Core Value Prop:** A simplified, high-fidelity clone of Splitwise for logging expenses, dividing bills, tracking group balances, and recording settlements.
* **Target Audience:** Young adults (20–35), primarily flatmates, travel groups, or friend groups.
* **Trust Assumption:** All users are trusted. No approval flows are required to add expenses or record settlements.
* **Currency:** Multi-currency support: INR (₹), USD ($), and EUR (€). Stored in a USD base currency schema with customizable exchange rates updated dynamically from the Account settings page.

---

## 2. Product Scope

### In Scope (MVP)
* **User Authentication:** Email & password-based signup, login, and Google Sign-In (using the singleton `GoogleSignIn.instance.authenticate()` flow).
* **Dashboard / Main Screen:** Displays overall balance summary: "You owe ₹X" (coral) and "You are owed ₹Y" (emerald), using a net balance per person across all groups, with quick shortcuts to notification feeds.
* **Group Management:** Create groups with custom types (**Trip**, **Family**, **Self**, **No Expense**) and add members. Auto-create "placeholder" users for non-registered email/phone contacts, claiming history upon real profile registration.
* **Direct 1-on-1 Expenses:** Create direct expenses with a friend outside of any group.
* **Expense Management:** Add expenses inside a group or directly with a friend. Supports multiple split strategies (Equal, Exact, Shares, Percentage) and soft-deletion.
* **Settle Up & Cross-Group Settlements:** Record cash/UPI settlements. Automatically distribute global settlements across mutual group debts first before direct debts.
* **Group Notes:** Shared announcements visible to everyone in the group with author tags and timestamps.
* **In-App Reminders:** Notify friends about outstanding balances, appearing with badge counts on a dashboard notification bell icon.

### Out of Scope
* Real payment gateway integration (UPI redirection/SMS launching are supported via WhatsApp mock templates).
* OCR/Receipt scanning.
* Real-time push notifications (replaced with local in-app activity logs).

---

## 3. User Stories

1. **Authentication:** As a user, I want to sign up with email/password or login via Google so that I can access my personalized dashboard.
2. **Phone Linkage Onboarding:** As a new Google Sign-In user, I want to register my phone number during setup so that my historical placeholder transactions (created when friends invited me via my phone number) are claimed automatically.
3. **Group Creation:** As a user, I want to create a group (Trip, Family, Self, or No Expense) and invite friends by email or phone so we can start logging expenses.
4. **Expense Log:** As a group member, I want to add an expense with a description, amount, payer, and split strategy (Equal, Exact, Shares, Percentage) so that everyone's dues are calculated.
5. **Group Notes:** As a group member, I want to pin important notes so that everyone in the group has visibility on key instructions.
6. **Reminders:** As a creditor, I want to send an in-app balance reminder to a friend so that they are notified when they open their dashboard.
7. **Settle Up:** As a debtor, I want to settle my net cross-group balance with a friend using Cash or Mock Online methods so that our balances resolve to zero.

---

## 4. Engineering Requirements

### Functional
- Math calculations must resolve split offsets to exactly two decimal places, charging the remainder of fractions to the last member in the split list.
- All stored transactions must be converted into USD using active exchange rates for schema consistency, converting back to selected display currency in the UI.

### Non-Functional
- **Offline Cache:** Render groups and balances instantly on launch from SharedPreferences cache, pulling Firestore updates in the background.
- **Visuals:** Follow a premium glassmorphic dark-mode palette utilizing subtle micro-animations, custom cartoon avatars, and Outfit/Inter typography.

---

## 5. Implementation Decisions & Tech Stack
* **Frontend Framework:** Flutter SDK 3.38.5 / Dart 3.10.4.
* **State Management:** Provider pattern with `AppProvider` managing lists, currency rates, loading overlays, and note states.
* **Backend & Database:** Firebase Authentication + Cloud Firestore.
* **Styling & Aesthetics:** Premium glassmorphic cards, custom painters for Donut charts, and Outfit typography.
* **Deployment Plan:** Hosted on Firebase Hosting (Fast CDN, SSL configuration, domain mapping).

---

## 6. Frontend Structure
```
/lib
  /models
    - activity_model.dart
    - expense_model.dart
    - group_model.dart
    - group_note_model.dart
    - user_model.dart
  /providers
    - app_provider.dart
    - auth_provider.dart
  /screens
    /auth
      - login_screen.dart
      - signup_screen.dart
      - phone_setup_screen.dart
    /dashboard
      - dashboard_screen.dart
      - activity_screen.dart
      - notification_center_sheet.dart
    /group
      - group_detail_screen.dart
      - create_group_screen.dart
    /expense
      - add_expense_screen.dart
    /settlement
      - settle_up_screen.dart
  /services
    - auth_service.dart
    - db_service.dart
    - debt_service.dart
  /utils
    - constants.dart
    - invite_helper.dart
  - main.dart
```

---

## 7. Database Schema (Firestore)

### `users` (Collection)
```json
{
  "uid": "USER_UID_1",
  "email": "alice@example.com",
  "displayName": "Alice Smith",
  "photoUrl": "avatar:boy1",
  "phone": "9876543210",
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
  "photoUrl": "avatar:girl2",
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
    "USER_UID_1": { "displayName": "Alice Smith", "email": "alice@example.com", "isPlaceholder": false },
    "USER_UID_2": { "displayName": "Bob Jones", "email": "bob@example.com", "isPlaceholder": false }
  },
  "type": "TRIP",
  "deletedAt": null
}
```

### `groups/{groupId}/notes` (Subcollection)
```json
{
  "noteId": "NOTE_ID_1",
  "groupId": "GROUP_ID_1",
  "content": "Buy milk today",
  "createdBy": "USER_UID_1",
  "createdByName": "Alice Smith",
  "createdAt": "TIMESTAMP"
}
```

### `expenses` (Collection)
```json
{
  "expenseId": "EXPENSE_ID_1",
  "groupId": "GROUP_ID_1",
  "friendId": null,
  "description": "Electricity Bill",
  "amount": 12.63,
  "paidBy": "USER_UID_1",
  "splitType": "EQUAL",
  "splits": {
    "USER_UID_1": { "owedAmount": 6.31, "exactValue": null },
    "USER_UID_2": { "owedAmount": 6.32, "exactValue": null }
  },
  "isSettlement": false,
  "createdAt": "TIMESTAMP",
  "createdBy": "USER_UID_1",
  "deletedAt": null
}
```

---

## 8. API Design

### `DbService` Interface
- `Future<UserModel?> getUserProfile(String uid)`
- `Future<void> claimPlaceholderHistory(String placeholderUid, String newRealUid)`
- `Future<UserModel?> searchUserByPhone(String phone)`
- `Future<UserModel?> searchUserByEmail(String email)`
- `Future<List<GroupNoteModel>> getGroupNotes(String groupId)`
- `Future<void> addGroupNote(GroupNoteModel note)`

### `AppProvider` Interface
- `Future<void> loadDashboardData(String currentUserId)`
- `Future<void> addExpense(ExpenseModel expense, String currentUserId)`
- `Future<void> settleUp({required String debtorId, required String creditorId, required double amount, String? groupId})`
- `Future<void> addGroupNote(String groupId, String content, String userId, String userName)`

---

## 9. Deployment Plan
1. **Firebase Configuration:** Setup Cloud Firestore rules and indexes.
2. **Build Release Bundle:** Run `flutter build web --release`.
3. **Firebase Hosting Deploy:** Initialize and deploy with `firebase deploy --only hosting`.

---

## 10. Testing Plan

### Unit Testing
- Located in `/test/` directory. Run `flutter test`.
- Algorithms under validation: Greedy debt simplification (`debt_service_test.dart`), splitting mathematics, cross-group settlements payment distribution, and group note creation (`group_notes_test.dart`).

### Manual Testing
- Google Sign-In cancellation checking (silently abort flow).
- Case-insensitivity validation (input email in camel case `SajJan@Example.com` and verify history claim).
- Phone number matching (invite with `+919876543210`, verify link with `9876543210`).

---

## 11. Trade-Offs & Known Limitations
- **Client-Side Calculations:** Balances computed dynamically on-the-fly to prevent database replication bugs. Can be slow with thousands of transactions.
- **Offline Mode Fallback:** If Firebase is not configured, a setup warning displays prompting user validation before falling back to local Mock Mode.
- **Web Contacts Fallback:** Native contacts sheets use iOS/Android permissions. On Desktop/Web build versions, the interface displays an inline custom text contacts selector.

---

## 12. Prompts and AI Response Strategies
When instructing the AI assistant, follow these prompt formats:
- **Refinement Prompts:** *"Refactor [file] to add [feature] using the Provider pattern, checking for compilation correctness at the end."*
- **Error Resolution Prompts:** *"During Google Sign-In, cancellation exception [code] is showing on screen. Silence this error in [file] and return null."*
- **Aesthetic Direction:** *"Redesign the notes display card inside the bottom sheet to match the dark glassmorphism theme, adding 5px padding and 0.05 opacity."*

---

## 13. Development Timeline & Logs

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
