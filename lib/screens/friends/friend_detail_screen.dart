import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/models/expense_model.dart';
import 'package:splitwise/models/group_model.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/screens/expense/add_expense_screen.dart';
import 'package:splitwise/screens/settlement/settle_up_screen.dart';
import 'package:splitwise/utils/app_avatars.dart';
import 'package:splitwise/utils/constants.dart';
import 'package:splitwise/utils/invite_helper.dart';
import 'package:splitwise/widgets/saving_overlay.dart';

class FriendDetailScreen extends StatelessWidget {
  final UserModel friend;
  const FriendDetailScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final appProv = context.watch<AppProvider>();
    final currentUser = authProv.user!;

    final balance = appProv.getFriendTotalBalance(currentUser.uid, friend.uid);
    final allExpenses = appProv.getFriendAllExpenses(currentUser.uid, friend.uid);

    // Shared groups
    final sharedGroups = appProv.groups
        .where((g) => g.members.contains(currentUser.uid) && g.members.contains(friend.uid))
        .toList();

    return SavingOverlay(
      isSaving: appProv.isSaving,
      message: 'Processing changes...',
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppConstants.premiumGradient),
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, currentUser, appProv, balance),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance + Actions
                      _buildBalanceBanner(context, currentUser, appProv, balance),
                      const SizedBox(height: 20),

                      // Quick Actions Row
                      _buildQuickActions(context, currentUser, appProv, balance),
                      const SizedBox(height: 28),

                      // Shared Groups chips
                      if (sharedGroups.isNotEmpty) ...[
                        _buildSectionLabel('SHARED GROUPS'),
                        const SizedBox(height: 10),
                        _buildSharedGroupChips(sharedGroups),
                        const SizedBox(height: 28),
                      ],

                      // Transaction timeline
                      _buildSectionLabel('TRANSACTIONS'),
                      const SizedBox(height: 12),
                      allExpenses.isEmpty
                          ? _buildEmptyTransactions()
                          : _buildTransactionList(allExpenses, currentUser, appProv, sharedGroups),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sliver App Bar ────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(
    BuildContext context,
    UserModel currentUser,
    AppProvider appProv,
    double balance,
  ) {
    // Get latest friend data from appProv (may have been updated)
    final latestFriend = appProv.friends.firstWhere(
      (f) => f.uid == friend.uid,
      orElse: () => friend,
    );

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          tooltip: 'Edit name',
          icon: const Icon(Icons.edit_outlined, color: AppConstants.accentTeal),
          onPressed: () => _showEditNameDialog(context, currentUser, appProv, latestFriend),
        ),
        IconButton(
          tooltip: 'Delete friend',
          icon: const Icon(Icons.person_remove_outlined, color: AppConstants.debitOrange),
          onPressed: () => _showDeleteConfirmation(context, currentUser, appProv, latestFriend),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1E38)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Profile content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Tappable avatar
                GestureDetector(
                  onTap: () => _changeAvatar(context, currentUser, appProv, latestFriend),
                  child: Stack(
                    children: [
                      AppAvatars.buildAvatar(
                        photoUrl: latestFriend.photoUrl,
                        displayName: latestFriend.displayName,
                        radius: 40,
                        backgroundColor: AppConstants.accentTeal.withOpacity(0.2),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppConstants.accentTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  latestFriend.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                if ((latestFriend.email.isNotEmpty || latestFriend.phone != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      latestFriend.email.isNotEmpty
                          ? latestFriend.email
                          : latestFriend.phone ?? '',
                      style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Balance Banner ────────────────────────────────────────────────────────
  Widget _buildBalanceBanner(
    BuildContext context,
    UserModel currentUser,
    AppProvider appProv,
    double balance,
  ) {
    final isSettled = balance.abs() <= 0.01;
    final isOwed = balance > 0.01;

    final latestFriend = appProv.friends.firstWhere(
      (f) => f.uid == friend.uid,
      orElse: () => friend,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: (isSettled
                    ? Colors.white
                    : (isOwed ? AppConstants.creditGreen : AppConstants.debitOrange))
                .withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isSettled
                      ? Colors.white
                      : (isOwed ? AppConstants.creditGreen : AppConstants.debitOrange))
                  .withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSettled
                          ? 'All settled up!'
                          : isOwed
                              ? '${latestFriend.displayName} owes you'
                              : 'You owe ${latestFriend.displayName}',
                      style: TextStyle(
                        color: isSettled
                            ? Colors.white38
                            : (isOwed ? AppConstants.creditGreen : AppConstants.debitOrange),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSettled ? '${AppConstants.currencySymbol}0.00' : '${AppConstants.currencySymbol}${balance.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isSettled
                            ? Colors.white30
                            : (isOwed ? AppConstants.creditGreen : AppConstants.debitOrange),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSettled)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentTeal,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettleUpScreen(
                          groupId: null,
                          preFilledPayerId: balance < 0 ? currentUser.uid : friend.uid,
                          preFilledReceiverId: balance < 0 ? friend.uid : currentUser.uid,
                          preFilledAmount: balance.abs(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Settle', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick Action Buttons ──────────────────────────────────────────────────
  Widget _buildQuickActions(
      BuildContext context, UserModel currentUser, AppProvider appProv, double balance) {
    final latestFriend = appProv.friends.firstWhere(
      (f) => f.uid == friend.uid,
      orElse: () => friend,
    );
    final contactFor = latestFriend.email.isNotEmpty
        ? latestFriend.email
        : (latestFriend.phone ?? '');

    return Row(
      children: [
        _buildActionChip(
          icon: Icons.add_circle_outline,
          label: 'Add Expense',
          color: AppConstants.accentIndigo,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddExpenseScreen(directFriend: latestFriend),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _buildActionChip(
          icon: Icons.notifications_outlined,
          label: 'Send Reminder',
          color: const Color(0xFFF59E0B),
          onTap: () {
            if (balance.abs() <= 0.01) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No balance to remind about!'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            _showReminderCustomDialog(context, currentUser, appProv, latestFriend, balance);
          },
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared Groups Chips ───────────────────────────────────────────────────
  Widget _buildSharedGroupChips(List<GroupModel> groups) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: groups.map((g) {
          IconData icon;
          Color color;
          switch (g.type) {
            case 'FAMILY':
              icon = Icons.home_rounded;
              color = Colors.amber;
              break;
            case 'SELF':
              icon = Icons.person;
              color = AppConstants.accentTeal;
              break;
            case 'NO_EXPENSE':
              icon = Icons.money_off;
              color = Colors.pinkAccent;
              break;
            default:
              icon = Icons.airplanemode_active_rounded;
              color = AppConstants.accentIndigo;
          }
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(g.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Transaction List ──────────────────────────────────────────────────────
  Widget _buildTransactionList(
    List<ExpenseModel> expenses,
    UserModel currentUser,
    AppProvider appProv,
    List<GroupModel> sharedGroups,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final exp = expenses[index];
        return _buildTransactionTile(exp, currentUser, appProv, sharedGroups);
      },
    );
  }

  Widget _buildTransactionTile(
    ExpenseModel exp,
    UserModel currentUser,
    AppProvider appProv,
    List<GroupModel> sharedGroups,
  ) {
    final isSelf = exp.paidBy == currentUser.uid;
    final userSplit = exp.splits[currentUser.uid]?.owedAmount ?? 0.0;
    final isSettlement = exp.isSettlement;

    // Find group name if group expense
    String? groupName;
    if (exp.groupId != null) {
      final g = sharedGroups.firstWhere(
        (g) => g.groupId == exp.groupId,
        orElse: () => GroupModel(
          groupId: '', name: 'Group', description: '', createdBy: '',
          createdAt: DateTime.now(), members: [], memberDetails: {},
        ),
      );
      groupName = g.name.isNotEmpty ? g.name : null;
    }

    IconData icon;
    Color iconColor;
    if (isSettlement) {
      icon = Icons.check_circle_rounded;
      iconColor = AppConstants.accentTeal;
    } else if (groupName != null) {
      icon = Icons.group_outlined;
      iconColor = AppConstants.accentIndigo;
    } else {
      icon = Icons.receipt_long_outlined;
      iconColor = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Description + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exp.description,
                  style: const TextStyle(
                    color: AppConstants.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${groupName != null ? "$groupName • " : ""}${isSelf ? "You paid" : "They paid"} • ${_formatDate(exp.createdAt)}',
                  style: const TextStyle(color: AppConstants.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Amount
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${AppConstants.currencySymbol}${exp.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppConstants.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (!isSettlement && userSplit > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      isSelf ? '+${AppConstants.currencySymbol}${(exp.amount - userSplit).toStringAsFixed(0)}' : '-${AppConstants.currencySymbol}${userSplit.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isSelf ? AppConstants.creditGreen : AppConstants.debitOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: Colors.white12),
          SizedBox(height: 12),
          Text('No transactions yet', style: TextStyle(color: AppConstants.textSecondary, fontSize: 14)),
          SizedBox(height: 4),
          Text('Add an expense to get started', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: AppConstants.textSecondary,
      ),
    );
  }

  // ── Dialogs / Actions ─────────────────────────────────────────────────────

  Future<void> _changeAvatar(
    BuildContext context,
    UserModel currentUser,
    AppProvider appProv,
    UserModel latestFriend,
  ) async {
    final selectedId = await AppAvatars.showAvatarPicker(context);
    if (selectedId != null && context.mounted) {
      await appProv.updateFriendAvatar(currentUser.uid, latestFriend.uid, selectedId);
    }
  }

  void _showEditNameDialog(
    BuildContext context,
    UserModel currentUser,
    AppProvider appProv,
    UserModel latestFriend,
  ) {
    final controller = TextEditingController(text: latestFriend.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text('Edit Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter nickname',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppConstants.accentTeal),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentTeal,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != latestFriend.displayName) {
                Navigator.pop(ctx);
                await appProv.updateFriendDisplayName(currentUser.uid, latestFriend.uid, newName);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    UserModel currentUser,
    AppProvider appProv,
    UserModel latestFriend,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text('Remove Friend?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove ${latestFriend.displayName}? Your shared expenses will remain in history.',
          style: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.debitOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              await appProv.removeFriend(currentUser.uid, latestFriend.uid);
              if (context.mounted) {
                Navigator.pop(context); // go back to friends tab
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showReminderCustomDialog(
    BuildContext context,
    UserModel currentUser,
    AppProvider appProv,
    UserModel latestFriend,
    double balance,
  ) {
    final String defaultMsg = balance > 0.01
        ? "Hey, you owe me ${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}. Please settle up when you can!"
        : "Hey, I owe you ${AppConstants.currencySymbol}${balance.abs().toStringAsFixed(2)}. Let me know when you want to settle up!";

    final controller = TextEditingController(text: defaultMsg);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppConstants.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Text('Send Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customize your reminder message:',
                style: TextStyle(color: AppConstants.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppConstants.accentTeal),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentTeal,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final message = controller.text.trim();
                if (message.isNotEmpty) {
                  Navigator.pop(ctx);
                  await appProv.sendInAppReminder(
                    currentUserId: currentUser.uid,
                    friendId: latestFriend.uid,
                    amount: balance,
                    message: message,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reminder sent to ${latestFriend.displayName}!'),
                        backgroundColor: AppConstants.accentTeal,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}
