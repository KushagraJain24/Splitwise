import 'package:splitwise/utils/constants.dart';

class SimplifiedTransaction {
  final String from; // Debtor (pays money)
  final String to;   // Creditor (receives money)
  final double amount;

  SimplifiedTransaction({
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  String toString() => '$from pays $to: ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
}

class DebtService {
  /// Rounds a double to two decimal places
  static double round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  /// Calculates the exact splits based on the selected strategy and handles rounding errors.
  /// The last member absorbs the penny rounding remainder.
  static Map<String, double> calculateSplits({
    required double totalAmount,
    required List<String> members,
    required String splitType, // EQUAL, EXACT, PERCENT, SHARES
    required Map<String, double> splitValues, // uid -> value (amount, percent, or share weight)
  }) {
    if (members.isEmpty || totalAmount <= 0) return {};

    final Map<String, double> result = {};

    switch (splitType) {
      case 'EQUAL':
        final double base = round(totalAmount / members.length);
        double runningSum = 0.0;
        for (int i = 0; i < members.length - 1; i++) {
          result[members[i]] = base;
          runningSum += base;
        }
        // Last person pays the remainder
        result[members.last] = round(totalAmount - runningSum);
        break;

      case 'EXACT':
        // Values are exact amounts
        double runningSum = 0.0;
        for (int i = 0; i < members.length - 1; i++) {
          final val = round(splitValues[members[i]] ?? 0.0);
          result[members[i]] = val;
          runningSum += val;
        }
        result[members.last] = round(totalAmount - runningSum);
        break;

      case 'PERCENT':
        // Values are percentages (e.g. 33.33)
        double runningSum = 0.0;
        for (int i = 0; i < members.length - 1; i++) {
          final double percentage = splitValues[members[i]] ?? 0.0;
          final double val = round((totalAmount * percentage) / 100.0);
          result[members[i]] = val;
          runningSum += val;
        }
        result[members.last] = round(totalAmount - runningSum);
        break;

      case 'SHARES':
        // Values are share weights (e.g. 2, 1, 1)
        final double totalShares = splitValues.values.fold(0.0, (sum, val) => sum + val);
        if (totalShares <= 0) {
          // Fallback to equal split if total shares is invalid
          return calculateSplits(
            totalAmount: totalAmount,
            members: members,
            splitType: 'EQUAL',
            splitValues: {},
          );
        }

        double runningSum = 0.0;
        for (int i = 0; i < members.length - 1; i++) {
          final double shares = splitValues[members[i]] ?? 0.0;
          final double val = round((totalAmount * shares) / totalShares);
          result[members[i]] = val;
          runningSum += val;
        }
        result[members.last] = round(totalAmount - runningSum);
        break;

      default:
        // Default to EQUAL
        return calculateSplits(
          totalAmount: totalAmount,
          members: members,
          splitType: 'EQUAL',
          splitValues: {},
        );
    }

    return result;
  }

  /// Computes the net balance (Credit - Debit) for all group members on-the-fly.
  /// Positive value: User is owed money.
  /// Negative value: User owes money.
  static Map<String, double> calculateNetBalances({
    required List<String> memberUids,
    required List<dynamic> transactions, // Can be ExpenseModel or SettlementModel
  }) {
    final Map<String, double> netBalances = {
      for (var uid in memberUids) uid: 0.0,
    };

    for (var tx in transactions) {
      if (tx.deletedAt != null) continue; // Skip soft-deleted items

      // 1. Expense flow
      if (tx.isSettlement == false) {
        final String payer = tx.paidBy;
        final double totalAmount = tx.amount;

        // Credit the payer
        if (netBalances.containsKey(payer)) {
          netBalances[payer] = round(netBalances[payer]! + totalAmount);
        }

        // Debit each split participant
        tx.splits.forEach((uid, splitDetail) {
          if (netBalances.containsKey(uid)) {
            netBalances[uid] = round(netBalances[uid]! - splitDetail.owedAmount);
          }
        });
      }
      // 2. Settlement flow
      else {
        final String payer = tx.paidBy; // The debtor who settles their debt
        final String receiver = tx.splits.keys.firstWhere(
          (key) => key != payer,
          orElse: () => '',
        ); // The creditor who receives it
        final double amount = tx.amount;

        if (payer.isNotEmpty && receiver.isNotEmpty) {
          if (netBalances.containsKey(payer)) {
            netBalances[payer] = round(netBalances[payer]! + amount);
          }
          if (netBalances.containsKey(receiver)) {
            netBalances[receiver] = round(netBalances[receiver]! - amount);
          }
        }
      }
    }

    return netBalances;
  }

  /// Simplifies debts using a greedy algorithm.
  /// Minimizes the number of transactions needed to settle all balances.
  static List<SimplifiedTransaction> simplifyDebts(Map<String, double> netBalances) {
    // Filter non-zero balances
    final List<MapEntry<String, double>> creditors = [];
    final List<MapEntry<String, double>> debtors = [];

    netBalances.forEach((uid, balance) {
      final roundedBalance = round(balance);
      if (roundedBalance > 0.01) {
        creditors.add(MapEntry(uid, roundedBalance));
      } else if (roundedBalance < -0.01) {
        debtors.add(MapEntry(uid, roundedBalance));
      }
    });

    final List<SimplifiedTransaction> transactions = [];

    // Greedy matching
    int cIdx = 0;
    int dIdx = 0;

    // Work on copies of balances to prevent mutating parameters
    final List<double> creditorBalances = creditors.map((e) => e.value).toList();
    final List<double> debtorBalances = debtors.map((e) => e.value.abs()).toList();

    while (cIdx < creditors.length && dIdx < debtors.length) {
      final String creditorUid = creditors[cIdx].key;
      final String debtorUid = debtors[dIdx].key;

      final double creditLeft = creditorBalances[cIdx];
      final double debtLeft = debtorBalances[dIdx];

      final double settleAmount = round(creditLeft < debtLeft ? creditLeft : debtLeft);

      if (settleAmount > 0.01) {
        transactions.add(
          SimplifiedTransaction(
            from: debtorUid,
            to: creditorUid,
            amount: settleAmount,
          ),
        );
      }

      creditorBalances[cIdx] = round(creditorBalances[cIdx] - settleAmount);
      debtorBalances[dIdx] = round(debtorBalances[dIdx] - settleAmount);

      if (creditorBalances[cIdx] <= 0.01) {
        cIdx++;
      }
      if (debtorBalances[dIdx] <= 0.01) {
        dIdx++;
      }
    }

    return transactions;
  }
}
