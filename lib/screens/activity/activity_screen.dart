import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/models/activity_model.dart';
import 'package:splitwise/utils/constants.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatActivityDate(DateTime date) {
    final now = DateTime.now();
    final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Today, $hour:$minute';
    } else if (isYesterday) {
      return 'Yesterday, $hour:$minute';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[date.month - 1];
      return '${date.day} $monthStr, $hour:$minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final authProv = context.watch<AuthProvider>();
    final currentUserId = authProv.user?.uid ?? '';

    // Filter activities by search query
    final filteredActivities = appProv.activities.where((act) {
      if (_searchQuery.isEmpty) return true;
      final desc = act.metadata['description']?.toString().toLowerCase() ?? '';
      final gName = act.metadata['groupName']?.toString().toLowerCase() ?? '';
      final fName = act.metadata['friendName']?.toString().toLowerCase() ?? '';
      final actor = act.metadata['actorName']?.toString().toLowerCase() ?? '';
      final target = act.metadata['targetName']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return desc.contains(query) || gName.contains(query) || fName.contains(query) || actor.contains(query) || target.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppConstants.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppConstants.textPrimary),
            onPressed: () {
              // Toggle search bar or show dialog
              showModalBottomSheet(
                context: context,
                backgroundColor: AppConstants.cardDark,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Search Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search by description, name, group...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            prefixIcon: const Icon(Icons.search, color: AppConstants.accentTeal),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white30),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                                Navigator.pop(ctx);
                              },
                            ),
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
                            setState(() => _searchQuery = val);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.premiumGradient,
        ),
        child: filteredActivities.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_none_outlined, size: 64, color: Colors.white24),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty ? 'No matches found' : 'No activity logged yet',
                      style: const TextStyle(color: AppConstants.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchQuery.isNotEmpty ? 'Try adjusting your search criteria' : 'Activities will appear here as you split bills',
                      style: const TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => appProv.loadDashboardData(currentUserId),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: filteredActivities.length,
                  separatorBuilder: (ctx, idx) => const Divider(color: Colors.white10, height: 24),
                  itemBuilder: (ctx, idx) {
                    final act = filteredActivities[idx];
                    return Dismissible(
                      key: Key(act.activityId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppConstants.debitOrange.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        final actId = act.activityId;
                        await appProv.deleteActivity(currentUserId, actId);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Activity deleted'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: _buildActivityTile(act, currentUserId),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildActivityTile(ActivityModel act, String currentUserId) {
    // 1. Choose Main Icon and badge based on activity metadata
    IconData mainIcon = Icons.receipt_long;
    Color iconBgColor = AppConstants.accentIndigo;
    IconData? badgeIcon;
    Color badgeBgColor = Colors.orange;

    final String type = act.activityType;
    final String customMessage = act.metadata['message'] ?? '';

    if (type == 'group_create') {
      mainIcon = Icons.group_add;
      iconBgColor = const Color(0xFF3B82F6); // Blue
      badgeIcon = Icons.add;
      badgeBgColor = Colors.teal;
    } else if (type == 'group_delete') {
      mainIcon = Icons.delete_sweep_outlined;
      iconBgColor = Colors.redAccent;
      badgeIcon = Icons.close;
      badgeBgColor = Colors.red;
    } else if (type == 'member_add') {
      mainIcon = Icons.person;
      iconBgColor = const Color(0xFF8B5CF6); // Purple
      badgeIcon = Icons.person_add;
      badgeBgColor = Colors.orange;
    } else if (type == 'expense_delete') {
      mainIcon = Icons.delete_forever;
      iconBgColor = Colors.white24;
      badgeIcon = Icons.close;
      badgeBgColor = Colors.red;
    } else if (type == 'expense_add') {
      final paidBy = act.metadata['paidBy'];
      if (paidBy == currentUserId) {
        // You paid / lent
        mainIcon = Icons.receipt_long;
        iconBgColor = AppConstants.creditGreen;
        badgeIcon = Icons.arrow_upward;
        badgeBgColor = Colors.teal;
      } else {
        // Someone else paid, you owe
        mainIcon = Icons.receipt_long;
        iconBgColor = AppConstants.debitOrange;
        badgeIcon = Icons.arrow_downward;
        badgeBgColor = Colors.amber;
      }
    } else if (type == 'settlement') {
      final payerId = act.metadata['payerId'];
      final receiverId = act.metadata['receiverId'];
      
      if (payerId == currentUserId) {
        // You paid someone (sent)
        mainIcon = Icons.payment;
        iconBgColor = AppConstants.debitOrange;
        badgeIcon = Icons.arrow_upward;
        badgeBgColor = Colors.red;
      } else if (receiverId == currentUserId) {
        // You received payment (got paid)
        mainIcon = Icons.account_balance_wallet;
        iconBgColor = AppConstants.creditGreen;
        badgeIcon = Icons.arrow_downward;
        badgeBgColor = Colors.teal; // Replaced Colors.emerald to be safe
      } else {
        mainIcon = Icons.monetization_on;
        iconBgColor = Colors.white24;
        badgeIcon = Icons.check;
        badgeBgColor = Colors.grey;
      }
    } else if (type == 'reminder') {
      mainIcon = Icons.notifications_active;
      iconBgColor = const Color(0xFFF59E0B);
      badgeIcon = Icons.alarm;
      badgeBgColor = Colors.orange;
    }

    // 2. Generate Title and Subtitle dynamically relative to currentUserId
    final String gName = act.metadata['groupName']?.toString() ?? '';
    final isActorSelf = act.actorId == currentUserId;
    final actorName = isActorSelf ? 'You' : (act.metadata['actorName'] ?? 'Someone');
    final String groupContext = act.groupId != null ? ' in the group "$gName"' : '';
    final String directFriendContext = act.friendId != null ? ' with "${act.metadata['friendName'] ?? 'Friend'}"' : '';

    List<TextSpan> titleSpans = [];
    String subtitleText = "";
    Color subtitleColor = AppConstants.textSecondary;

    if (type == 'group_create') {
      titleSpans = [
        TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: ' created the group '),
        TextSpan(text: '"$gName"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: '.'),
      ];
    } else if (type == 'group_delete') {
      titleSpans = [
        TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: ' deleted the group '),
        TextSpan(text: '"$gName"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: '.'),
      ];
      subtitleText = 'Group deleted';
      subtitleColor = AppConstants.debitOrange;
    } else if (type == 'member_add') {
      final isTargetSelf = act.targetId == currentUserId;
      final targetName = isTargetSelf ? 'you' : (act.metadata['targetName'] ?? 'someone');
      
      titleSpans = [
        TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: ' added '),
        TextSpan(text: targetName, style: TextStyle(fontWeight: FontWeight.bold, color: isTargetSelf ? AppConstants.accentTeal : Colors.white)),
        TextSpan(text: act.groupId != null ? ' to the group ' : ' as a friend'),
        if (act.groupId != null)
          TextSpan(text: '"$gName"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: '.'),
      ];
    } else if (type == 'expense_add') {
      final desc = act.metadata['description'] ?? 'expense';
      final double amount = (act.metadata['amount'] as num?)?.toDouble() ?? 0.0;
      final splits = act.metadata['splits'] as Map<String, dynamic>? ?? {};

      titleSpans = [
        TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: ' added '),
        TextSpan(text: '"$desc"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        TextSpan(text: groupContext.isNotEmpty ? groupContext : directFriendContext),
        const TextSpan(text: '.'),
      ];

      // Calculate financial impact
      final paidBy = act.metadata['paidBy'];
      if (paidBy == currentUserId) {
        // You paid
        final double youOwed = (splits[currentUserId]?['owedAmount'] as num?)?.toDouble() ?? 0.0;
        final double youLent = amount - youOwed;
        if (youLent > 0.01) {
          subtitleText = 'You get back ${AppConstants.currencySymbol}${youLent.toStringAsFixed(2)}';
          subtitleColor = AppConstants.creditGreen;
        } else {
          subtitleText = 'You paid ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
          subtitleColor = AppConstants.textPrimary;
        }
      } else {
        // Someone else paid
        final double youOwe = (splits[currentUserId]?['owedAmount'] as num?)?.toDouble() ?? 0.0;
        if (youOwe > 0.01) {
          subtitleText = 'You owe ${AppConstants.currencySymbol}${youOwe.toStringAsFixed(2)}';
          subtitleColor = AppConstants.debitOrange;
        } else {
          subtitleText = 'Not involved';
          subtitleColor = AppConstants.textSecondary;
        }
      }
    } else if (type == 'settlement') {
      final payerId = act.metadata['payerId'];
      final receiverId = act.metadata['receiverId'];
      final double amount = (act.metadata['amount'] as num?)?.toDouble() ?? 0.0;

      final isPayerSelf = payerId == currentUserId;
      final isReceiverSelf = receiverId == currentUserId;

      final pName = isPayerSelf ? 'You' : (act.metadata['paidByName'] ?? 'Someone');
      final rName = isReceiverSelf ? 'You' : (act.metadata['receiverName'] ?? 'Someone');

      titleSpans = [
        TextSpan(text: pName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: ' recorded a payment to '),
        TextSpan(text: rName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        TextSpan(text: groupContext.isNotEmpty ? groupContext : directFriendContext),
        const TextSpan(text: '.'),
      ];

      if (isPayerSelf) {
        subtitleText = 'You sent ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
        subtitleColor = AppConstants.debitOrange;
      } else if (isReceiverSelf) {
        subtitleText = 'You received ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
        subtitleColor = AppConstants.creditGreen;
      } else {
        subtitleText = 'Recorded payment of ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
        subtitleColor = AppConstants.textSecondary;
      }
    } else if (type == 'expense_delete') {
      final desc = act.metadata['description'] ?? 'expense';
      titleSpans = [
        TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const TextSpan(text: ' deleted '),
        TextSpan(text: '"$desc"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        TextSpan(text: groupContext.isNotEmpty ? groupContext : directFriendContext),
        const TextSpan(text: '.'),
      ];
      subtitleText = 'Deleted';
      subtitleColor = AppConstants.debitOrange;
    } else if (type == 'reminder') {
      final double amount = (act.metadata['amount'] as num?)?.toDouble() ?? 0.0;
      final isActorSelf = act.actorId == currentUserId;
      final senderName = isActorSelf ? 'You' : (act.metadata['actorName'] ?? 'Someone');
      final receiverName = isActorSelf ? (act.metadata['friendName'] ?? 'Friend') : 'you';

      if (isActorSelf) {
        titleSpans = [
          const TextSpan(text: 'You', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const TextSpan(text: ' reminded '),
          TextSpan(text: receiverName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const TextSpan(text: ' to settle their balance.'),
        ];
        if (customMessage.isEmpty) {
          if (amount > 0.01) {
            subtitleText = 'They owe you ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
            subtitleColor = AppConstants.creditGreen;
          } else if (amount < -0.01) {
            subtitleText = 'You owe them ${AppConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}';
            subtitleColor = AppConstants.debitOrange;
          }
        }
      } else {
        titleSpans = [
          TextSpan(text: senderName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const TextSpan(text: ' reminded '),
          const TextSpan(text: 'you', style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.accentTeal)),
          const TextSpan(text: ' to settle your balance.'),
        ];
        if (customMessage.isEmpty) {
          if (amount > 0.01) {
            subtitleText = 'You owe them ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
            subtitleColor = AppConstants.debitOrange;
          } else if (amount < -0.01) {
            subtitleText = 'They owe you ${AppConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}';
            subtitleColor = AppConstants.creditGreen;
          }
        }
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Avatar Icon with Stacked Corner Badge
        Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconBgColor.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(mainIcon, color: iconBgColor.withOpacity(0.9), size: 24),
            ),
            if (badgeIcon != null)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    color: AppConstants.backgroundDark,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: badgeBgColor,
                    child: Icon(badgeIcon, color: Colors.black, size: 10),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Texts Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, height: 1.3),
                  children: titleSpans,
                ),
              ),
              if (subtitleText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitleText,
                  style: TextStyle(fontSize: 13, color: subtitleColor, fontWeight: FontWeight.bold),
                ),
              ],
              if (customMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    '"$customMessage"',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                _formatActivityDate(act.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.white24),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
