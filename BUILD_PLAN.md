# Build Plan: Splitwise MVP (Flutter + Firebase)

This build plan outlines the product analysis, scope, technical architecture, and development stages for building a beautiful, fully functional Splitwise clone in 3 days.

---

## 1. Product Research
* **How We Studied Splitwise:**
  * Analyzed core features: User balances, direct expenses, group expenses, settlements ("Settle Up"), expense categories, and debt simplification ("Simplify Debts").
  * Studied the mathematical balance calculation: how each transaction affects individual and group-wide net balances.
* **What We Learned:**
  * At its core, Splitwise is a ledger. Every expense has a payer who adds a positive credit to their ledger, and split members who add a negative debit.
  * Direct 1-on-1 expenses can be modeled like group expenses but with a `groupId = null` and a direct friend association.
  * High-quality UX is essential. Splitwise has clear green (you are owed) and orange (you owe) signifiers, clean transaction streams, and simple modal dialogs.
* **Workflows Identified:**
  * Auth (Sign Up / Login).
  * Dashboard (Overall balances summary, groups list, friends list, quick-add expense button).
  * Group Details (Group members, scrollable history of expenses/settlements, debt summary, basic analytics chart).
  * Add Expense (Description, amount, payer, split strategy picker - Equal, Exact, Percent, Shares).
  * Settle Up (Record payment between two users via cash or mock online UPI payment).
* **Product Assumptions Made:**
  * Trust-based: No dispute resolutions or invoice validation required.
  * Single currency: INR (₹) simplifies calculations and UI.
  * Registration claims: A user can add an email that isn't registered yet; a "placeholder" is created, which can be claimed later.

---

## 2. Final Scope
### What We Chose to Build
1. **User Authentication:** Email + Password signup/login with Firebase Auth.
2. **Dashboard Screen:** High-fidelity dashboard displaying overall balance stats, groups, and friends.
3. **Groups & Friends management:** Group creation, member search by email, placeholder accounts for invitations.
4. **Expense System:** Detailed expense creator supporting **Equal, Exact, Percentage, and Shares** splits.
5. **On-the-fly Balance Calculation:** Accurate ledger parsing to calculate who owes who.
6. **Simplify Debts Algorithm:** Greedy algorithm to minimize transactions.
7. **Settle Up flow:** Cash and mock UPI payments.
8. **Basic Analytics:** Interactive expense pie-chart inside group dashboards.
9. **Rich Aesthetics:** Modern Flutter design with dark/light themes, smooth transitions, custom charts, and glassmorphic cards.
10. **Deployment:** Flutter Web deployed to Firebase Hosting.

### What We Chose Not to Build
* Multi-currency support (postponed).
* OCR / Receipt Scanning (out of scope for 3-day timeline).
* Real payment gateways (Mock payment only).
* Chat / comments on expenses.
* Push notifications.

### Why This is Achievable in 3 Days
* **Firebase Backend:** Using Firebase Auth and Firestore removes the need to build a custom database backend, write authentication microservices, or configure servers/Docker.
* **On-the-fly Ledger Calculations:** Computing balances in-memory from queried logs prevents database sync complexity.
* **Pre-scoped MVP:** Removing push notifications and real payment integrations allows focusing 100% on the core ledger logic and the premium UI.

---

## 3. Architecture

### Tech Stack
* **Frontend:** Flutter (Dart) for high-performance responsive web/mobile UI.
* **Backend & Database:** Firebase Auth & Cloud Firestore.
* **State Management:** Provider pattern in Flutter.
* **Deployment:** Firebase Hosting (fast CDN and instant deployment).

### Database Schema (Firestore)
* `/users`: Document per registered/placeholder user.
* `/users/{userId}/friends`: Friend records.
* `/groups`: Group information and list of member details.
* `/expenses`: Transaction log for expenses and settlements.

### API / Firestore Rules Design
Since we use Firebase SDK directly in Flutter, our "API" is the Firestore query interface.
* **Fetch Groups:** `firestore.collection('groups').where('members', arrayContains: currentUserId)`
* **Fetch Group Expenses:** `firestore.collection('expenses').where('groupId', '==', groupId).orderBy('createdAt', descending: true)`
* **Fetch Direct Expenses:** `firestore.collection('expenses').where('groupId', '==', null).where('members', arrayContains: currentUserId)`

### Frontend Structure (Flutter App Structure)
```
lib/
├── main.dart                 # App Entry Point & Theme Configuration
├── models/
│   ├── user_model.dart       # User & Placeholder models
│   ├── group_model.dart      # Group model
│   ├── expense_model.dart    # Expense & Split details
│   └── settlement_model.dart # Settlement details
├── services/
│   ├── auth_service.dart     # Firebase Authentication service
│   ├── db_service.dart       # Firestore read/write & query operations
│   └── debt_service.dart     # Simplify Debts & Balance calculation logic
├── providers/
│   ├── auth_provider.dart    # Authentication state
│   └── app_provider.dart     # Group, Expense, and Friend states
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── widgets/
│   │       ├── balance_card.dart
│   │       └── group_list_item.dart
│   ├── group/
│   │   ├── group_detail_screen.dart
│   │   ├── create_group_screen.dart
│   │   └── widgets/
│   │       ├── expense_history_list.dart
│   │       └── debt_simplification_card.dart
│   ├── expense/
│   │   ├── add_expense_screen.dart
│   │   └── widgets/
│   │       └── split_strategy_selector.dart
│   └── settlement/
│       └── settle_up_screen.dart
└── utils/
    ├── constants.dart        # Currency (INR) and Theme Styling constants
    └── helpers.dart          # Rounding and formatting helpers
```

---

## 4. AI Collaboration Process
* **How the AI Instructed / Interviewed:**
  * The AI started by posing detailed questions across 6 core areas (goals, scope, database, auth, stack, edge cases).
* **How the User Answered:**
  * Selected Flutter + Firebase.
  * Defined core MVP flow (Register/Login -> Dashboard -> Group creation -> Expense splits -> Settle Up -> Balances).
  * Selected specific split strategies (Equal, Exact, Percent, Shares) and required a "Simplify Debts" implementation.
  * Specified single currency (INR) and manual settlement flows.
  * Standardized edge case handling (last user gets rounding remainder, soft deletes only, leaving group restricted).
* **Evolution of the Plan:**
  * Upgraded backend choice from custom server to Firebase to hit the 3-day deadline.
  * Defined schema mapping for Firestore, adding denormalized metadata (`memberDetails` in Groups) to prevent Firestore N+1 query limits.

---

## 5. Tradeoffs & Decisions
* **Ledger Computations:** In-memory recalculation of balances on load rather than triggering database updates for each transaction. Highly robust against concurrency but requires pagination/limits for huge transaction lists.
* **Placeholder Accounts:** When adding a new member by email, a placeholder is auto-created. This prevents blocking group actions for unregistered users, but requires a clean email-linking script on sign-up.
* **No Real-Time Gateways:** Settle Up works virtually. This speeds up compliance and development, but relies on users self-reporting.
* **No Edit after Settlement:** To prevent complex audit discrepancies, expenses cannot be edited if group balances have been altered by settlements.
