import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/models/expense_model.dart';
import 'package:splitwise/models/group_model.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/models/group_note_model.dart';
import 'package:splitwise/services/debt_service.dart';
import 'package:splitwise/screens/expense/add_expense_screen.dart';
import 'package:splitwise/screens/settlement/settle_up_screen.dart';
import 'package:splitwise/utils/constants.dart';
import 'package:splitwise/utils/contacts_helper.dart';
import 'package:splitwise/utils/invite_helper.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, String>> _customWebContacts = [];

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    // Find matching group to decide tab length
    final group = appProvider.groups.firstWhere(
      (g) => g.groupId == widget.groupId,
      orElse: () => GroupModel(
        groupId: widget.groupId,
        name: '',
        description: '',
        createdBy: '',
        createdAt: DateTime.now(),
        members: [],
        memberDetails: {},
      ),
    );
    int tabLength = 3;
    if (group.type == 'SELF') {
      tabLength = 1;
    } else if (group.type == 'NO_EXPENSE') {
      tabLength = 2;
    }
    _tabController = TabController(length: tabLength, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user!;

    // Find the current group
    GroupModel? tempGroup;
    for (var g in appProvider.groups) {
      if (g.groupId == widget.groupId) {
        tempGroup = g;
        break;
      }
    }

    if (tempGroup == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Details')),
        body: const Center(child: Text('Group not found')),
      );
    }
    final group = tempGroup;

    final List<ExpenseModel> expenses;
    final Map<String, double> balances;
    final List<SimplifiedTransaction> simplifiedDebts;
    final GroupModel displayGroup;

    if (group.type == 'NO_EXPENSE') {
      final List<ExpenseModel> directExps = [];
      final Map<String, double> netBalances = {};
      double currentUserNetBalance = 0.0;

      final Map<String, GroupMemberDetail> dynMemberDetails = {
        currentUser.uid: GroupMemberDetail(
          displayName: currentUser.displayName,
          email: currentUser.email,
          isPlaceholder: false,
        ),
      };

      final List<String> dynMembers = [currentUser.uid];

      for (var friend in appProvider.friends) {
        final b = appProvider.getFriendBalance(currentUser.uid, friend.uid);
        if (b.abs() > 0.01) {
          dynMembers.add(friend.uid);
          dynMemberDetails[friend.uid] = GroupMemberDetail(
            displayName: friend.displayName,
            email: friend.email,
            isPlaceholder: friend.isPlaceholder,
          );
          netBalances[friend.uid] = -b;
          currentUserNetBalance += b;

          final friendExps = appProvider.getDirectExpensesList(friend.uid);
          directExps.addAll(friendExps.where((e) => e.deletedAt == null));
        }
      }

      netBalances[currentUser.uid] = currentUserNetBalance;
      directExps.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expenses = directExps;
      balances = netBalances;
      simplifiedDebts = DebtService.simplifyDebts(netBalances);

      displayGroup = GroupModel(
        groupId: group.groupId,
        name: group.name,
        description: group.description,
        createdBy: group.createdBy,
        createdAt: group.createdAt,
        members: dynMembers,
        memberDetails: dynMemberDetails,
        type: group.type,
      );
    } else {
      expenses = appProvider.getGroupExpensesList(widget.groupId);
      balances = appProvider.getGroupBalances(widget.groupId);
      simplifiedDebts = appProvider.getGroupSimplifiedDebts(widget.groupId);
      displayGroup = group;
    }

    // Calculate total spent in group (ignoring settlements and soft-deleted items)
    final double totalSpent = expenses
        .where((e) => e.deletedAt == null && !e.isSettlement)
        .fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppConstants.textPrimary)),
            Text(group.description, style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (group.type != 'SELF' && group.type != 'NO_EXPENSE')
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Add Member',
              onPressed: () {
                _showAddMemberBottomSheet(context, displayGroup, currentUser.uid);
              },
            ),
          if (group.type != 'SELF')
            IconButton(
              icon: const Icon(Icons.add_road),
              tooltip: 'Settle up',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettleUpScreen(
                      groupId: group.type == 'NO_EXPENSE' ? null : group.groupId,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.note_alt_outlined, color: AppConstants.accentTeal),
            tooltip: 'Notes',
            onPressed: () {
              _showNotesBottomSheet(context, group, currentUser);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppConstants.debitOrange),
            tooltip: 'Delete Group',
            onPressed: () {
              _confirmDeleteGroupDialog(context, group);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.premiumGradient,
        ),
        child: Column(
          children: [
            // Sub-header for group stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL GROUP EXPENSES', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppConstants.textSecondary)),
                        Text(
                          '${AppConstants.currencySymbol}${totalSpent.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.accentTeal),
                        ),
                      ],
                    ),
                  ),
                  if (group.type != 'SELF') ...[
                    const SizedBox(width: 8),
                    _buildMyBalanceCard(balances[currentUser.uid] ?? 0.0),
                  ],
                ],
              ),
            ),

            if (group.type == 'SELF') ...[
              Expanded(
                child: _buildExpensesTab(expenses, displayGroup, currentUser.uid),
              ),
            ] else if (group.type == 'NO_EXPENSE') ...[
              TabBar(
                controller: _tabController,
                indicatorColor: AppConstants.accentTeal,
                labelColor: AppConstants.accentTeal,
                unselectedLabelColor: AppConstants.textSecondary,
                tabs: const [
                  Tab(text: 'EXPENSES'),
                  Tab(text: 'SETTLE'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExpensesTab(expenses, displayGroup, currentUser.uid),
                    _buildSettleTab(balances, displayGroup, currentUser.uid),
                  ],
                ),
              ),
            ] else ...[
              TabBar(
                controller: _tabController,
                indicatorColor: AppConstants.accentTeal,
                labelColor: AppConstants.accentTeal,
                unselectedLabelColor: AppConstants.textSecondary,
                tabs: const [
                  Tab(text: 'EXPENSES'),
                  Tab(text: 'BALANCES'),
                  Tab(text: 'CHARTS'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExpensesTab(expenses, displayGroup, currentUser.uid),
                    _buildBalancesTab(balances, simplifiedDebts, displayGroup, currentUser.uid),
                    _buildChartsTab(expenses, displayGroup),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: group.type == 'NO_EXPENSE'
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(groupId: group.groupId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Group Expense'),
              backgroundColor: AppConstants.accentTeal,
              foregroundColor: Colors.black,
            ),
    );
  }

  Widget _buildSettleTab(Map<String, double> balances, GroupModel group, String currentUserId) {
    final friendsWithBalance = group.members.where((uid) => uid != currentUserId).toList();

    if (friendsWithBalance.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: AppConstants.creditGreen, size: 48),
            SizedBox(height: 12),
            Text(
              'No outstanding direct expenses! All friends are settled.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppConstants.creditGreen, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: friendsWithBalance.length,
      itemBuilder: (context, index) {
        final friendUid = friendsWithBalance[index];
        final detail = group.memberDetails[friendUid];
        final balance = balances[friendUid] ?? 0.0;

        Color balanceColor = Colors.white30;
        String balanceText = "Settled up";
        if (balance > 0.01) {
          balanceColor = AppConstants.creditGreen;
          balanceText = "owes you ${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}";
        } else if (balance < -0.01) {
          balanceColor = AppConstants.debitOrange;
          balanceText = "you owe them ${AppConstants.currencySymbol}${balance.abs().toStringAsFixed(2)}";
        }

        return Card(
          color: Colors.white.withOpacity(0.02),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail?.displayName ?? 'Friend',
                        style: const TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        balanceText,
                        style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Settle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentTeal,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettleUpScreen(
                          groupId: null,
                          preFilledPayerId: balance < -0.01 ? currentUserId : friendUid,
                          preFilledReceiverId: balance < -0.01 ? friendUid : currentUserId,
                          preFilledAmount: balance.abs(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteGroupDialog(BuildContext context, GroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppConstants.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppConstants.debitOrange),
              SizedBox(width: 12),
              Text('Delete Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete the group "${group.name}"? This action cannot be undone.',
            style: const TextStyle(color: AppConstants.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.debitOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final currentUserId = context.read<AuthProvider>().user!.uid;
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Pop GroupDetailScreen
                await context.read<AppProvider>().deleteGroup(group.groupId, currentUserId);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Group "${group.name}" was successfully deleted.'),
                      backgroundColor: AppConstants.debitOrange,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyBalanceCard(double balance) {
    Color balanceColor = Colors.white30;
    String balanceText = "You are settled up";
    if (balance > 0.01) {
      balanceColor = AppConstants.creditGreen;
      balanceText = "You are owed ${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}";
    } else if (balance < -0.01) {
      balanceColor = AppConstants.debitOrange;
      balanceText = "You owe ${AppConstants.currencySymbol}${balance.abs().toStringAsFixed(2)}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: balanceColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: balanceColor.withOpacity(0.2), width: 1),
      ),
      child: Text(
        balanceText,
        style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildExpensesTab(List<ExpenseModel> expenses, GroupModel group, String currentUserId) {
    final activeExpenses = expenses.where((e) => e.deletedAt == null).toList();

    if (activeExpenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text('No expenses logged yet.', style: TextStyle(color: AppConstants.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: activeExpenses.length,
      itemBuilder: (ctx, idx) {
        final exp = activeExpenses[idx];
        final payerName = group.memberDetails[exp.paidBy]?.displayName ?? 'Someone';
        final isSelfPayer = exp.paidBy == currentUserId;

        // Calculate current user's stake in this expense
        final double myShare = exp.splits[currentUserId]?.owedAmount ?? 0.0;
        final bool isParticipant = exp.splits.containsKey(currentUserId);

        return Card(
          color: AppConstants.cardDark.withOpacity(0.5),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: exp.isSettlement
                      ? AppConstants.creditGreen.withOpacity(0.15)
                      : AppConstants.accentIndigo.withOpacity(0.15),
                  child: Icon(
                    exp.isSettlement ? Icons.payment : Icons.shopping_bag_outlined,
                    color: exp.isSettlement ? AppConstants.creditGreen : AppConstants.accentIndigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exp.description,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: exp.isSettlement ? Colors.white70 : AppConstants.textPrimary,
                          decoration: exp.isSettlement ? TextDecoration.none : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exp.isSettlement
                            ? '$payerName settled debt'
                            : 'Paid by $payerName • ${exp.splitType}',
                        style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${AppConstants.currencySymbol}${exp.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (!exp.isSettlement)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            isSelfPayer
                                ? 'you lent ${AppConstants.currencySymbol}${(exp.amount - myShare).toStringAsFixed(2)}'
                                : isParticipant
                                    ? 'you owe ${AppConstants.currencySymbol}${myShare.toStringAsFixed(2)}'
                                    : 'not involved',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelfPayer
                                  ? AppConstants.creditGreen
                                  : isParticipant
                                      ? AppConstants.debitOrange
                                      : AppConstants.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppConstants.debitOrange),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _confirmDeleteDialog(context, exp.expenseId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteDialog(BuildContext context, String expenseId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppConstants.cardDark,
          title: const Text('Delete Expense?', style: TextStyle(color: AppConstants.textPrimary)),
          content: const Text(
            'Are you sure you want to delete this expense? This will soft-delete the transaction and restore the ledger state.',
            style: TextStyle(color: AppConstants.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.debitOrange, foregroundColor: Colors.white),
              onPressed: () async {
                final currentUser = context.read<AuthProvider>().user!;
                await context.read<AppProvider>().softDeleteExpense(
                      expenseId: expenseId,
                      currentUserId: currentUser.uid,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBalancesTab(
    Map<String, double> balances,
    List<SimplifiedTransaction> simplifiedDebts,
    GroupModel group,
    String currentUserId,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // 1. Live Balances Header
        const Text(
          'INDIVIDUAL NET BALANCES',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 12),

        // List net balance per user
        ...group.members.map((memberUid) {
          final detail = group.memberDetails[memberUid];
          final balance = balances[memberUid] ?? 0.0;
          final isSelf = memberUid == currentUserId;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSelf ? 'You (${detail?.displayName})' : (detail?.displayName ?? 'User'),
                  style: TextStyle(fontWeight: isSelf ? FontWeight.bold : FontWeight.normal, color: AppConstants.textPrimary),
                ),
                Text(
                  '${balance >= 0.01 ? "+" : ""}${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: balance > 0.01
                        ? AppConstants.creditGreen
                        : balance < -0.01
                            ? AppConstants.debitOrange
                            : Colors.white24,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 32),

        // 2. Simplified Debts Title
        const Text(
          'SIMPLIFIED DEBTS (GREEDY SETTLEMENT)',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 12),

        if (simplifiedDebts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppConstants.creditGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.creditGreen.withOpacity(0.1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppConstants.creditGreen, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Everyone is fully settled up! No transactions are required.',
                    style: TextStyle(color: AppConstants.creditGreen, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              ],
            ),
          )
        else
          ...simplifiedDebts.map((tx) {
            final fromUser = group.memberDetails[tx.from]?.displayName ?? 'Someone';
            final toUser = group.memberDetails[tx.to]?.displayName ?? 'Someone';
            final isSelfDebtor = tx.from == currentUserId;
            final isSelfCreditor = tx.to == currentUserId;

            return Card(
              color: Colors.white.withOpacity(0.03),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_circle_right_outlined, color: AppConstants.accentIndigo, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: AppConstants.textPrimary, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: fromUser,
                                  style: TextStyle(fontWeight: isSelfDebtor ? FontWeight.bold : FontWeight.normal),
                                ),
                                const TextSpan(text: ' owes '),
                                TextSpan(
                                  text: toUser,
                                  style: TextStyle(fontWeight: isSelfCreditor ? FontWeight.bold : FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppConstants.currencySymbol}${tx.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.accentTeal),
                          ),
                        ],
                      ),
                    ),
                    // Quick Settle Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.accentTeal,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettleUpScreen(
                              groupId: group.type == 'NO_EXPENSE' ? null : group.groupId,
                              preFilledPayerId: tx.from,
                              preFilledReceiverId: tx.to,
                              preFilledAmount: tx.amount,
                            ),
                          ),
                        );
                      },
                      child: const Text('Settle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildChartsTab(List<ExpenseModel> expenses, GroupModel group) {
    // 1. Calculate contributions per user (only active, non-settlement expenses)
    final Map<String, double> contributions = {
      for (var m in group.members) m: 0.0,
    };

    double activeTotal = 0.0;

    for (var exp in expenses) {
      if (exp.deletedAt != null || exp.isSettlement) continue;
      contributions[exp.paidBy] = (contributions[exp.paidBy] ?? 0.0) + exp.amount;
      activeTotal += exp.amount;
    }

    if (activeTotal <= 0) {
      return const Center(
        child: Text('Add expenses to see statistical distributions.', style: TextStyle(color: AppConstants.textSecondary)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Glassmorphic container containing Donut Chart
          ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              color: Colors.white.withOpacity(0.03),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'EXPENSE CONTRIBUTIONS BY MEMBER',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Custom Donut Chart Painter
                  SizedBox(
                    height: 200,
                    width: 200,
                    child: CustomPaint(
                      painter: DonutChartPainter(
                        contributions: contributions,
                        totalAmount: activeTotal,
                        memberColors: _getMemberColors(group.members),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Chart Legends
                  ...group.members.map((memberUid) {
                    final detail = group.memberDetails[memberUid];
                    final paid = contributions[memberUid] ?? 0.0;
                    final percent = (paid / activeTotal) * 100;
                    final color = _getMemberColors(group.members)[memberUid] ?? Colors.grey;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              detail?.displayName ?? 'Member',
                              style: const TextStyle(fontSize: 13, color: AppConstants.textPrimary),
                            ),
                          ),
                          Text(
                            '${AppConstants.currencySymbol}${paid.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.textPrimary),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Generate distinct colored markers for members
  Map<String, Color> _getMemberColors(List<String> members) {
    final List<Color> palette = [
      AppConstants.accentTeal,
      AppConstants.accentIndigo,
      Colors.pinkAccent,
      Colors.amber,
      Colors.lightGreenAccent,
      Colors.deepPurpleAccent,
    ];

    final Map<String, Color> colors = {};
    for (int i = 0; i < members.length; i++) {
      colors[members[i]] = palette[i % palette.length];
    }
    return colors;
  }

  Future<List<Map<String, String>>> _fetchDeviceContacts() async {
    final List<Map<String, String>> fallbackContacts = [
      {'name': 'Papa ❤️', 'email': 'papa@example.com'},
      {'name': 'Mummy 🌸', 'email': 'mummy@example.com'},
      {'name': 'Sis 👧', 'email': 'sis@example.com'},
      {'name': 'Charlie Brown 🐕', 'email': 'charlie@example.com'},
      {'name': 'Dave Miller 🎸', 'email': 'dave@example.com'},
      {'name': 'Eve Adams 🎨', 'email': 'eve@example.com'},
    ];

    try {
      final List<Map<String, String>> contacts = List.from(_customWebContacts);

      if (kIsWeb) {
        contacts.addAll(fallbackContacts);
        return contacts;
      }

      final permission = await FlutterContacts.requestPermission(readonly: true);
      if (!permission) {
        if (contacts.isNotEmpty) {
          return contacts;
        }
        return [{'error': 'permission_denied'}];
      }

      final deviceContacts = await FlutterContacts.getContacts(withProperties: true);
      for (var c in deviceContacts) {
        final name = c.displayName.trim();
        if (name.isEmpty) continue;

        String? email;
        if (c.emails.isNotEmpty) {
          email = c.emails.first.address.trim();
        } else if (c.phones.isNotEmpty) {
          email = c.phones.first.number.trim();
        }

        if (email != null && email.isNotEmpty) {
          if (!contacts.any((wc) => wc['email']!.toLowerCase() == email!.toLowerCase())) {
            contacts.add({
              'name': name,
              'email': email,
            });
          }
        }
      }

      if (contacts.isEmpty) {
        return [{'error': 'no_contacts'}];
      }
      return contacts;
    } catch (e) {
      debugPrint("Error fetching device contacts: $e");
      if (_customWebContacts.isNotEmpty) {
        return _customWebContacts;
      }
      return [{'error': 'no_contacts'}];
    }
  }

  void _showAddMemberBottomSheet(BuildContext context, GroupModel group, String currentUserId) {
    final appProvider = context.read<AppProvider>();
    final emailController = TextEditingController();
    final List<UserModel> newMembers = [];
    String? searchError;
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void searchAndAddMember() async {
              final email = emailController.text.trim().toLowerCase();
              if (email.isEmpty || !email.contains('@')) {
                setSheetState(() => searchError = "Enter a valid email");
                return;
              }

              // Check if already in group
              final alreadyInGroup = group.memberDetails.values.any((d) => d.email.toLowerCase() == email);
              if (alreadyInGroup) {
                setSheetState(() => searchError = "User is already in this group");
                return;
              }

              if (newMembers.any((m) => m.email.toLowerCase() == email)) {
                setSheetState(() => searchError = "User is already staged to add");
                return;
              }

              setSheetState(() {
                isSearching = true;
                searchError = null;
              });

              final user = await appProvider.searchUserByEmail(email);

              if (user != null) {
                setSheetState(() {
                  newMembers.add(user);
                  emailController.clear();
                  isSearching = false;
                });
              } else {
                // User not found, show invite placeholder prompt
                setSheetState(() => isSearching = false);
                _showInviteDialogForGroup(ctx, email, group.name, (invitedUser) {
                  setSheetState(() {
                    newMembers.add(invitedUser);
                    emailController.clear();
                  });
                });
              }
            }

            void addContact(String email, String name) async {
              // Check if already in group
              final alreadyInGroup = group.memberDetails.values.any((d) => d.email.toLowerCase() == email.toLowerCase());
              if (alreadyInGroup) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$name is already a member of this group"),
                    backgroundColor: AppConstants.debitOrange,
                  ),
                );
                return;
              }

              if (newMembers.any((m) => m.email.toLowerCase() == email.toLowerCase())) {
                return;
              }

              final matchFriends = appProvider.friends.where((f) => f.email.toLowerCase() == email.toLowerCase());

              if (matchFriends.isNotEmpty) {
                setSheetState(() {
                  newMembers.add(matchFriends.first);
                });
              } else {
                final tempUser = UserModel(
                  uid: 'temp_${DateTime.now().millisecondsSinceEpoch}_$email',
                  email: email,
                  displayName: name,
                  isPlaceholder: true,
                  createdAt: DateTime.now(),
                );
                setSheetState(() {
                  newMembers.add(tempUser);
                });

                // Invite as placeholder in the background
                final placeholder = await appProvider.inviteUser(email, name, currentUserId);
                setSheetState(() {
                  final idx = newMembers.indexWhere((m) => m.uid == tempUser.uid);
                  if (idx != -1) {
                    newMembers[idx] = placeholder;
                  }
                });
                if (mounted) {
                  InviteHelper.showInviteChannelsDialog(context, email, groupName: group.name);
                }
              }
            }

            void showFriendsSelector() {
              final searchController = TextEditingController();
              String query = "";

              showModalBottomSheet(
                context: ctx,
                backgroundColor: AppConstants.cardDark,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (friendsCtx) {
                  return StatefulBuilder(
                    builder: (context, setFriendsState) {
                      final filteredFriends = appProvider.friends.where((f) {
                        final inGroup = group.members.contains(f.uid) || group.memberDetails.values.any((d) => d.email.toLowerCase() == f.email.toLowerCase());
                        if (inGroup) return false;
                        final isAlreadyStaged = newMembers.any((m) => m.email.toLowerCase() == f.email.toLowerCase() && m.uid != f.uid);
                        if (isAlreadyStaged) return false;

                        final matchQuery = f.displayName.toLowerCase().contains(query.toLowerCase()) ||
                            f.email.toLowerCase().contains(query.toLowerCase());
                        return matchQuery;
                      }).toList();

                      return Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(friendsCtx).viewInsets.bottom + 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 const Text(
                                   'Select from Friends',
                                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                 ),
                                 if (newMembers.isNotEmpty)
                                   IconButton(
                                     icon: const Icon(Icons.check, color: AppConstants.accentTeal),
                                     onPressed: () => Navigator.pop(friendsCtx),
                                   ),
                               ],
                             ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search friends...',
                                hintStyle: const TextStyle(color: Colors.white30),
                                prefixIcon: const Icon(Icons.search, color: AppConstants.accentTeal),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.white10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppConstants.accentTeal),
                                ),
                              ),
                              onChanged: (val) {
                                setFriendsState(() => query = val);
                              },
                            ),
                            const SizedBox(height: 16),
                            filteredFriends.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: Text('No eligible friends found', style: TextStyle(color: AppConstants.textSecondary)),
                                    ),
                                  )
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 250),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredFriends.length,
                                      itemBuilder: (context, index) {
                                        final friend = filteredFriends[index];
                                        final isSelected = newMembers.any((m) => m.uid == friend.uid);

                                        return CheckboxListTile(
                                          activeColor: AppConstants.accentTeal,
                                          checkColor: Colors.black,
                                          title: Text(friend.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          subtitle: Text(friend.email, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                          value: isSelected,
                                          onChanged: (val) {
                                            setFriendsState(() {
                                              if (val == true) {
                                                newMembers.add(friend);
                                              } else {
                                                newMembers.removeWhere((m) => m.uid == friend.uid);
                                              }
                                            });
                                            setSheetState(() {});
                                          },
                                        );
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            }

            void showContactsSelector() {
              showModalBottomSheet(
                context: ctx,
                backgroundColor: AppConstants.cardDark,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (contactsCtx) {
                  return _GroupDetailContactsSelectorSheet(
                    fetchContacts: _fetchDeviceContacts,
                    customWebContacts: _customWebContacts,
                    group: group,
                    newMembers: newMembers,
                    onContactTapped: (email, name) {
                      addContact(email, name);
                      setSheetState(() {});
                    },
                    onCustomContactAdded: (email, name) {
                      addContact(email, name);
                      setSheetState(() {});
                    },
                  );
                },
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Group Members',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppConstants.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Add member by email',
                            labelStyle: const TextStyle(color: AppConstants.textSecondary),
                            errorText: searchError,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppConstants.accentTeal),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.accentTeal,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSearching ? null : searchAndAddMember,
                          child: isSearching
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.people_outline, color: AppConstants.accentTeal, size: 18),
                          label: const Text('Add Friends', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: showFriendsSelector,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.contact_phone_outlined, color: AppConstants.accentTeal, size: 18),
                          label: const Text('Add Contacts', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: showContactsSelector,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (newMembers.isNotEmpty) ...[
                    const Text(
                      'MEMBERS TO ADD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: newMembers.map<Widget>((member) {
                        return Chip(
                          backgroundColor: AppConstants.accentTeal.withOpacity(0.1),
                          label: Text(
                            member.displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onDeleted: () {
                            setSheetState(() {
                              newMembers.removeWhere((m) => m.uid == member.uid);
                            });
                          },
                          deleteIconColor: AppConstants.debitOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: newMembers.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await context.read<AppProvider>().addMembersToGroup(
                                    groupId: group.groupId,
                                    newMembers: newMembers,
                                    currentUserId: currentUserId,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Added ${newMembers.length} member(s) to group!"),
                                    backgroundColor: AppConstants.creditGreen,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.accentTeal,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white10,
                        disabledForegroundColor: AppConstants.textSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('ADD TO GROUP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInviteDialogForGroup(BuildContext parentCtx, String email, String groupName, Function(UserModel) onInvited) {
    final nameController = TextEditingController();
    bool isSavingLocal = false;
    showDialog(
      context: parentCtx,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppConstants.cardDark,
              title: const Text('Invite Friend', style: TextStyle(color: AppConstants.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This email/phone ($email) is not registered yet. Invite them as a placeholder member so they can be added to your group!',
                    style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (isSavingLocal)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: CircularProgressIndicator(color: AppConstants.accentTeal),
                      ),
                    )
                  else
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppConstants.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Friend Full Name',
                        labelStyle: TextStyle(color: AppConstants.textSecondary),
                      ),
                    ),
                ],
              ),
              actions: isSavingLocal
                  ? []
                  : [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                        },
                        child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentTeal, foregroundColor: Colors.black),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          setDialogState(() {
                            isSavingLocal = true;
                          });

                          final currentUserId = context.read<AuthProvider>().user!.uid;
                          final placeholder = await context.read<AppProvider>().inviteUser(email, name, currentUserId);

                          onInvited(placeholder);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            InviteHelper.showInviteChannelsDialog(context, email, groupName: groupName);
                          }
                        },
                        child: const Text('Invite & Add'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _showNotesBottomSheet(BuildContext context, GroupModel group, UserModel currentUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // Trigger initial load
        Provider.of<AppProvider>(ctx, listen: false).loadGroupNotes(group.groupId);
        final noteController = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Group Notes 📝',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppConstants.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Consumer<AppProvider>(
                    builder: (context, appProvider, child) {
                      if (appProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator(color: AppConstants.accentTeal));
                      }
                      if (appProvider.currentGroupNotes.isEmpty) {
                        return const Center(
                          child: Text(
                            'No notes yet. Add one below to keep everyone informed!',
                            style: TextStyle(color: AppConstants.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: appProvider.currentGroupNotes.length,
                        itemBuilder: (context, index) {
                          final note = appProvider.currentGroupNotes[index];
                          final isMe = note.createdBy == currentUser.uid;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isMe ? 'You' : note.createdByName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.accentTeal,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _formatNoteTime(note.createdAt),
                                          style: const TextStyle(
                                            color: AppConstants.textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () {
                                              appProvider.deleteGroupNote(group.groupId, note.noteId);
                                            },
                                            child: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: AppConstants.debitOrange,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  note.content,
                                  style: const TextStyle(
                                    color: AppConstants.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: noteController,
                        style: const TextStyle(color: AppConstants.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Add an important note...',
                          hintStyle: const TextStyle(color: AppConstants.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppConstants.accentTeal),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<AppProvider>(
                      builder: (context, appProvider, child) {
                        return appProvider.isSaving
                            ? const CircularProgressIndicator(color: AppConstants.accentTeal)
                            : IconButton(
                                icon: const Icon(Icons.send, color: AppConstants.accentTeal),
                                onPressed: () {
                                  final text = noteController.text.trim();
                                  if (text.isNotEmpty) {
                                    appProvider.addGroupNote(
                                      group.groupId,
                                      text,
                                      currentUser.uid,
                                      currentUser.displayName,
                                    );
                                    noteController.clear();
                                    FocusScope.of(context).unfocus();
                                  }
                                },
                              );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatNoteTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<String, double> contributions;
  final double totalAmount;
  final Map<String, Color> memberColors;

  DonutChartPainter({
    required this.contributions,
    required this.totalAmount,
    required this.memberColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 24.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;

    contributions.forEach((uid, paid) {
      if (paid <= 0) return;
      final sweepAngle = (paid / totalAmount) * 2 * math.pi;
      paint.color = memberColors[uid] ?? Colors.grey;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    });

    // Draw inner text
    final textPainter = TextPainter(
      text: TextSpan(
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        text: 'TOTAL\n',
        children: [
          TextSpan(
            text: '${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) => true;
}

class _GroupDetailContactsSelectorSheet extends StatefulWidget {
  final Future<List<Map<String, String>>> Function() fetchContacts;
  final List<Map<String, String>> customWebContacts;
  final GroupModel group;
  final List<UserModel> newMembers;
  final void Function(String email, String name) onContactTapped;
  final void Function(String email, String name) onCustomContactAdded;

  const _GroupDetailContactsSelectorSheet({
    required this.fetchContacts,
    required this.customWebContacts,
    required this.group,
    required this.newMembers,
    required this.onContactTapped,
    required this.onCustomContactAdded,
  });

  @override
  State<_GroupDetailContactsSelectorSheet> createState() => _GroupDetailContactsSelectorSheetState();
}

class _GroupDetailContactsSelectorSheetState extends State<_GroupDetailContactsSelectorSheet> {
  late Future<List<Map<String, String>>> _contactsFuture;
  final _searchController = TextEditingController();
  final _customNameController = TextEditingController();
  final _customEmailPhoneController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _contactsFuture = widget.fetchContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customNameController.dispose();
    _customEmailPhoneController.dispose();
    super.dispose();
  }

  bool _isValidEmailOrPhone(String input) {
    if (input.contains('@')) {
      return input.length >= 5 && input.indexOf('@') > 0 && input.indexOf('@') < input.length - 1;
    } else {
      final clean = input.replaceAll(RegExp(r'[+\-\s()&]'), '');
      return clean.isNotEmpty && RegExp(r'^\d+$').hasMatch(clean) && clean.length >= 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: _contactsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppConstants.accentTeal),
                  const SizedBox(height: 16),
                  Text("Loading contacts...", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ],
              ),
            ),
          );
        }

        final contacts = snapshot.data ?? [];
        final bool hasError = contacts.length == 1 && contacts.first.containsKey('error');
        final String? errorCode = hasError ? contacts.first['error'] : null;

        final displayContacts = List<Map<String, String>>.from(contacts);
        for (var wc in widget.customWebContacts) {
          if (!displayContacts.any((c) => c['email']!.toLowerCase() == wc['email']!.toLowerCase())) {
            displayContacts.insert(0, wc);
          }
        }

        final filteredContacts = displayContacts.where((c) {
          if (c.containsKey('error')) return false;
          final name = c['name']!.toLowerCase();
          final email = c['email']!.toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        final bool showContactsList = !hasError || filteredContacts.isNotEmpty;

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Invite from Contacts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppConstants.accentTeal),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchQuery = '';
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          widget.newMembers.isNotEmpty ? Icons.check : Icons.close,
                          color: widget.newMembers.isNotEmpty ? AppConstants.accentTeal : AppConstants.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_isSearching)
                Text(
                  kIsWeb
                      ? 'Select a mock contact (Running in Web Sandbox)'
                      : 'Select a contact from your device phonebook.',
                  style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search contacts by name or phone/email...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: AppConstants.accentTeal, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white30, size: 16),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.02),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppConstants.accentTeal),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              const SizedBox(height: 12),

              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Can't find contact?", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        if (isWebContactsSupported())
                          TextButton.icon(
                            onPressed: () async {
                              final imported = await getBrowserContacts();
                              if (imported.isNotEmpty) {
                                for (var ic in imported) {
                                  final name = ic['name']!;
                                  final email = ic['email']!;
                                  if (!widget.customWebContacts.any((wc) => wc['email']!.toLowerCase() == email.toLowerCase())) {
                                    widget.customWebContacts.add(ic);
                                  }
                                  widget.onCustomContactAdded(email, name);
                                }
                                setState(() {});
                              }
                            },
                            icon: const Icon(Icons.import_contacts, size: 14, color: AppConstants.accentTeal),
                            label: const Text('Import', style: TextStyle(fontSize: 11, color: AppConstants.accentTeal)),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Name',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                              border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.accentTeal)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _customEmailPhoneController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Email/Phone',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                              border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.accentTeal)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppConstants.accentTeal, size: 28),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            final name = _customNameController.text.trim();
                            final emailOrPhone = _customEmailPhoneController.text.trim();
                            if (name.isEmpty || emailOrPhone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Enter a name and email/phone"),
                                  backgroundColor: AppConstants.debitOrange,
                                ),
                              );
                              return;
                            }
                            if (!_isValidEmailOrPhone(emailOrPhone)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Enter a valid email or phone number (min 7 digits)"),
                                  backgroundColor: AppConstants.debitOrange,
                                ),
                              );
                              return;
                            }
                            final email = emailOrPhone.toLowerCase();
                            if (!widget.customWebContacts.any((wc) => wc['email']!.toLowerCase() == email)) {
                              widget.customWebContacts.add({
                                'name': name,
                                'email': email,
                              });
                            }
                            widget.onCustomContactAdded(email, name);
                            _customNameController.clear();
                            _customEmailPhoneController.clear();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: !showContactsList
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            errorCode == 'permission_denied'
                                ? 'Contacts permission was denied.\nPlease enable access in your device settings.'
                                : 'No contacts matching your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: errorCode == 'permission_denied'
                                  ? AppConstants.debitOrange
                                  : AppConstants.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          if (contact.containsKey('error')) return const SizedBox.shrink();
                          final name = contact['name']!;
                          final email = contact['email']!;
                          final isAlreadyInGroup = widget.group.memberDetails.values.any((d) => d.email.toLowerCase() == email.toLowerCase());
                          final isStaged = widget.newMembers.any((m) => m.email.toLowerCase() == email.toLowerCase());

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppConstants.accentTeal.withOpacity(0.1),
                              child: Text(name.isNotEmpty ? name[0] : 'C', style: const TextStyle(color: AppConstants.accentTeal, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(name, style: TextStyle(color: isAlreadyInGroup ? AppConstants.textSecondary : Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              isAlreadyInGroup ? 'Already in group' : email,
                              style: TextStyle(color: isAlreadyInGroup ? AppConstants.textSecondary.withOpacity(0.5) : Colors.white30, fontSize: 12),
                            ),
                            trailing: isAlreadyInGroup
                                ? const Icon(Icons.check, color: AppConstants.textSecondary)
                                : isStaged
                                    ? const Icon(Icons.check_circle, color: AppConstants.accentTeal)
                                    : const Icon(Icons.add_circle_outline, color: AppConstants.textSecondary),
                            onTap: isAlreadyInGroup
                                ? null
                                : () {
                                    widget.onContactTapped(email, name);
                                    setState(() {});
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
