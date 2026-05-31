import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/models/group_model.dart';
import 'package:splitwise/models/expense_model.dart';
import 'package:splitwise/services/db_service.dart';
import 'package:splitwise/services/auth_service.dart';
import 'package:splitwise/providers/app_provider.dart';

void main() {
  setUpAll(() {
    AuthService(); // Seeds mock users in DbService
  });

  group('AppProvider - Friend Total Balance and Distributed Settlements', () {
    test('Calculates friend total balance combining direct and group debts, and distributes settlement', () async {
      final appProvider = AppProvider();
      
      // Clear out mock expenses first to ensure fresh test state
      DbService.mockExpenses.clear();

      // Alice, Bob, Charlie are in 'goa_trip_id' group.
      // Let's load the data for Alice
      await appProvider.loadDashboardData('alice_uid');

      // 1. Check initial balances (should be 0)
      expect(appProvider.getFriendTotalBalance('alice_uid', 'bob_uid'), 0.0);

      // 2. Add an expense of 300 paid by Alice in Goa Trip group (EQUAL split: 100 each)
      final expense = ExpenseModel(
        expenseId: 'exp_goa_300',
        groupId: 'goa_trip_id',
        description: 'Goa Food',
        amount: 300.0,
        paidBy: 'alice_uid',
        splitType: 'EQUAL',
        splits: {
          'alice_uid': SplitDetail(owedAmount: 100.0),
          'bob_uid': SplitDetail(owedAmount: 100.0),
          'charlie_uid': SplitDetail(owedAmount: 100.0),
        },
        createdAt: DateTime.now(),
        createdBy: 'alice_uid',
      );
      await appProvider.addExpense(expense, 'alice_uid');

      // 3. Verify total balance between Alice and Bob
      // Alice is owed 100.0 by Bob.
      expect(appProvider.getFriendTotalBalance('alice_uid', 'bob_uid'), 100.0);
      // Bob owes Alice 100.0.
      expect(appProvider.getFriendTotalBalance('bob_uid', 'alice_uid'), -100.0);

      // 4. Perform a global/direct settlement: Bob settles his 100.0 with Alice
      // Payer is Bob, receiver is Alice.
      await appProvider.settleUp(
        groupId: null, // Global
        friendId: 'alice_uid',
        payerId: 'bob_uid',
        receiverId: 'alice_uid',
        amount: 100.0,
        paymentMethod: 'CASH',
        currentUserId: 'bob_uid',
      );

      // 5. Verify that it was distributed to the Goa Trip group and balances are now 0.0
      expect(appProvider.getFriendTotalBalance('alice_uid', 'bob_uid'), 0.0);
      expect(appProvider.getFriendTotalBalance('bob_uid', 'alice_uid'), 0.0);

      // Verify the group-specific balance is also settled (0.0)
      final groupBalances = appProvider.getGroupBalances('goa_trip_id');
      expect(groupBalances['bob_uid'], 0.0);
    });
  });
}
