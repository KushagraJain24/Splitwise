import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise/services/debt_service.dart';
import 'package:splitwise/models/expense_model.dart';

void main() {
  group('DebtService - Splitting Calculations', () {
    test('Equal Split - Divides evenly with remainder on last person', () {
      final splits = DebtService.calculateSplits(
        totalAmount: 10.00,
        members: ['alice', 'bob', 'charlie'],
        splitType: 'EQUAL',
        splitValues: {},
      );

      expect(splits['alice'], 3.33);
      expect(splits['bob'], 3.33);
      expect(splits['charlie'], 3.34);
      expect(splits.values.reduce((a, b) => a + b), 10.00);
    });

    test('Exact Split - Allocates exact values and absorbs penny adjustments', () {
      final splits = DebtService.calculateSplits(
        totalAmount: 15.00,
        members: ['alice', 'bob'],
        splitType: 'EXACT',
        splitValues: {'alice': 5.00, 'bob': 10.00},
      );

      expect(splits['alice'], 5.00);
      expect(splits['bob'], 10.00);
    });

    test('Percentage Split - Divides according to percent and handles rounding', () {
      final splits = DebtService.calculateSplits(
        totalAmount: 10.00,
        members: ['alice', 'bob', 'charlie'],
        splitType: 'PERCENT',
        splitValues: {'alice': 33.3, 'bob': 33.3, 'charlie': 33.4},
      );

      expect(splits['alice'], 3.33);
      expect(splits['bob'], 3.33);
      expect(splits['charlie'], 3.34);
    });

    test('Shares Split - Splits proportionally based on shares', () {
      final splits = DebtService.calculateSplits(
        totalAmount: 100.00,
        members: ['alice', 'bob', 'charlie'],
        splitType: 'SHARES',
        splitValues: {'alice': 2, 'bob': 1, 'charlie': 1},
      );

      expect(splits['alice'], 50.00);
      expect(splits['bob'], 25.00);
      expect(splits['charlie'], 25.00);
    });
  });

  group('DebtService - Balance Computations', () {
    test('Calculates on-the-fly balances correctly from expenses', () {
      // Alice paid 900, split equally among Alice, Bob, Charlie (300 each)
      final expense = ExpenseModel(
        expenseId: 'exp1',
        groupId: 'g1',
        description: 'Dinner',
        amount: 900.00,
        paidBy: 'alice',
        splitType: 'EQUAL',
        splits: {
          'alice': SplitDetail(owedAmount: 300.00),
          'bob': SplitDetail(owedAmount: 300.00),
          'charlie': SplitDetail(owedAmount: 300.00),
        },
        createdAt: DateTime.now(),
        createdBy: 'alice',
      );

      final netBalances = DebtService.calculateNetBalances(
        memberUids: ['alice', 'bob', 'charlie'],
        transactions: [expense],
      );

      // Alice is owed 900 - 300 = +600
      expect(netBalances['alice'], 600.00);
      // Bob owes 300 = -300
      expect(netBalances['bob'], -300.00);
      // Charlie owes 300 = -300
      expect(netBalances['charlie'], -300.00);
    });

    test('Calculates balances correctly with settlement transactions', () {
      // Alice paid 300, split equally among Alice, Bob, Charlie (100 each)
      final expense = ExpenseModel(
        expenseId: 'exp1',
        groupId: 'g1',
        description: 'Dinner',
        amount: 300.00,
        paidBy: 'alice',
        splitType: 'EQUAL',
        splits: {
          'alice': SplitDetail(owedAmount: 100.00),
          'bob': SplitDetail(owedAmount: 100.00),
          'charlie': SplitDetail(owedAmount: 100.00),
        },
        createdAt: DateTime.now(),
        createdBy: 'alice',
      );

      // Bob pays Alice 100 to settle up
      final settlement = ExpenseModel(
        expenseId: 'settle1',
        groupId: 'g1',
        description: 'Settle Up Payment',
        amount: 100.00,
        paidBy: 'bob',
        splitType: 'EXACT',
        splits: {
          'alice': SplitDetail(owedAmount: 100.00),
          'bob': SplitDetail(owedAmount: 0.00),
        },
        isSettlement: true,
        createdAt: DateTime.now(),
        createdBy: 'bob',
      );

      final netBalances = DebtService.calculateNetBalances(
        memberUids: ['alice', 'bob', 'charlie'],
        transactions: [expense, settlement],
      );

      // Alice should be owed 100 (300 - 100 split - 100 settlement received = 100)
      expect(netBalances['alice'], 100.00);
      // Bob should be settled up (0)
      expect(netBalances['bob'], 0.00);
      // Charlie should still owe 100 (-100)
      expect(netBalances['charlie'], -100.00);
    });

    test('User scenario: 3 people split 300, one settles 100, other should still owe 100', () {
      final members = ['alice', 'bob', 'charlie'];
      final expense = ExpenseModel(
        expenseId: 'exp_300',
        groupId: 'g1',
        description: 'Trip Expense',
        amount: 300.00,
        paidBy: 'alice',
        splitType: 'EQUAL',
        splits: {
          'alice': SplitDetail(owedAmount: 100.00),
          'bob': SplitDetail(owedAmount: 100.00),
          'charlie': SplitDetail(owedAmount: 100.00),
        },
        createdAt: DateTime.now(),
        createdBy: 'alice',
      );

      final settlement = ExpenseModel(
        expenseId: 'settle_100',
        groupId: 'g1',
        description: 'Settle Up Bob',
        amount: 100.00,
        paidBy: 'bob',
        splitType: 'EXACT',
        splits: {
          'alice': SplitDetail(owedAmount: 100.00),
          'bob': SplitDetail(owedAmount: 0.00),
        },
        isSettlement: true,
        createdAt: DateTime.now(),
        createdBy: 'bob',
      );

      final netBalances = DebtService.calculateNetBalances(
        memberUids: members,
        transactions: [expense, settlement],
      );

      expect(netBalances['alice'], 100.00);
      expect(netBalances['bob'], 0.00);
      expect(netBalances['charlie'], -100.00);
    });
  });

  group('DebtService - Debt Simplification', () {
    test('Simplifies A->B and B->C into A->C', () {
      // Alice owes Bob 10, Bob owes Charlie 10.
      // Net balances: Alice = -10, Bob = 0, Charlie = +10.
      final netBalances = {
        'alice': -10.00,
        'bob': 0.00,
        'charlie': 10.00,
      };

      final txs = DebtService.simplifyDebts(netBalances);

      expect(txs.length, 1);
      expect(txs[0].from, 'alice');
      expect(txs[0].to, 'charlie');
      expect(txs[0].amount, 10.00);
    });

    test('Simplifies complex circular debts to empty list if net is zero', () {
      // Alice owes Bob 10, Bob owes Charlie 10, Charlie owes Alice 10.
      // Net balance is 0 for everyone.
      final netBalances = {
        'alice': 0.00,
        'bob': 0.00,
        'charlie': 0.00,
      };

      final txs = DebtService.simplifyDebts(netBalances);

      expect(txs.isEmpty, true);
    });

    test('Simplifies multiple debtors and creditors greedily', () {
      // Alice owes 100, Bob owes 50, Charlie is owed 150
      final netBalances = {
        'alice': -100.00,
        'bob': -50.00,
        'charlie': 150.00,
      };

      final txs = DebtService.simplifyDebts(netBalances);

      expect(txs.length, 2);
      // The exact ordering depends on greedy search:
      // Alice pays Charlie 100
      // Bob pays Charlie 50
      final aliceToCharlie = txs.firstWhere((t) => t.from == 'alice' && t.to == 'charlie');
      final bobToCharlie = txs.firstWhere((t) => t.from == 'bob' && t.to == 'charlie');

      expect(aliceToCharlie.amount, 100.00);
      expect(bobToCharlie.amount, 50.00);
    });
  });
}
