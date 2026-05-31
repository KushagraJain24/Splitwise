import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/screens/group/group_detail_screen.dart';
import 'package:splitwise/screens/group/create_group_screen.dart';
import 'package:splitwise/screens/expense/add_expense_screen.dart';
import 'package:splitwise/screens/activity/activity_screen.dart';
import 'package:splitwise/screens/settlement/settle_up_screen.dart';
import 'package:splitwise/screens/friends/friend_detail_screen.dart';
import 'package:splitwise/utils/app_avatars.dart';
import 'package:splitwise/utils/constants.dart';
import 'package:splitwise/utils/invite_helper.dart';

import 'package:splitwise/widgets/saving_overlay.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String _friendsFilter = 'ALL'; // ALL, SETTLED, I_OWE, OWE_ME

  void _addFriendDialog(BuildContext context, String currentUserId) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    UserModel? foundUser;
    String searchResultText = "";
    bool isSearching = false;

    bool isValidEmailOrPhone(String text) {
      final cleanText = text.trim();
      if (cleanText.isEmpty) return false;
      if (cleanText.contains('@')) {
        return true;
      }
      return RegExp(r'^\+?[0-9\s\-()]{7,15}$').hasMatch(cleanText);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppConstants.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
              title: const Text('Add Friend', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      style: const TextStyle(color: AppConstants.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Email or Phone Number',
                        labelStyle: const TextStyle(color: AppConstants.textSecondary),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: AppConstants.accentTeal),
                          onPressed: () async {
                            if (!isValidEmailOrPhone(emailController.text)) return;
                            setState(() {
                              isSearching = true;
                              foundUser = null;
                              searchResultText = "";
                            });
                            final user = await ctx.read<AppProvider>().searchUserByEmail(emailController.text);
                            setState(() {
                              isSearching = false;
                              if (user != null) {
                                foundUser = user;
                                nameController.text = user.displayName;
                                searchResultText = "User found: ${user.displayName}";
                              } else {
                                searchResultText = "User not registered. Enter name to invite:";
                              }
                            });
                          },
                        ),
                      ),
                      validator: (val) => (val == null || !isValidEmailOrPhone(val)) ? 'Enter a valid email or phone number' : null,
                    ),
                    const SizedBox(height: 16),
                    if (searchResultText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          searchResultText,
                          style: TextStyle(
                            color: foundUser != null ? AppConstants.creditGreen : AppConstants.accentIndigo,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (foundUser == null && searchResultText.isNotEmpty)
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: AppConstants.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Friend Name',
                          labelStyle: TextStyle(color: AppConstants.textSecondary),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter a name' : null,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppConstants.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentTeal, foregroundColor: Colors.black),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final appProv = ctx.read<AppProvider>();
                      final emailOrPhone = emailController.text.trim();
                      if (foundUser != null) {
                        await appProv.addFriend(currentUserId, foundUser!);
                      } else {
                        // Invite as placeholder
                        await appProv.inviteUser(emailOrPhone, nameController.text.trim(), currentUserId);
                        if (context.mounted) {
                          InviteHelper.showInviteChannelsDialog(context, emailOrPhone);
                        }
                      }
                      if (context.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Add Friend'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final appProvider = context.watch<AppProvider>();
    final currentUser = authProvider.user!;

    final List<Widget> pages = [
      _buildGroupsPage(appProvider, currentUser),
      _buildFriendsPage(appProvider, currentUser),
      const ActivityScreen(),
      _buildAccountPage(authProvider, appProvider, currentUser),
    ];

    return SavingOverlay(
      isSaving: appProvider.isSaving,
      message: 'Processing request...',
      child: Scaffold(
        body: pages[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: AppConstants.cardDark,
            selectedItemColor: AppConstants.accentTeal,
            unselectedItemColor: AppConstants.textSecondary,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.group_outlined),
                activeIcon: Icon(Icons.group),
                label: 'Groups',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Friends',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.show_chart_outlined),
                activeIcon: Icon(Icons.show_chart),
                label: 'Activity',
              ),
              BottomNavigationBarItem(
                icon: Opacity(
                  opacity: 0.6,
                  child: AppAvatars.buildAvatar(
                    photoUrl: currentUser.photoUrl,
                    displayName: currentUser.displayName,
                    radius: 12,
                  ),
                ),
                activeIcon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppConstants.accentTeal, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: AppAvatars.buildAvatar(
                      photoUrl: currentUser.photoUrl,
                      displayName: currentUser.displayName,
                      radius: 10.5,
                    ),
                  ),
                ),
                label: 'Account',
              ),
            ],
          ),
        ),
        floatingActionButton: _currentIndex == 3
            ? null
            : FloatingActionButton.extended(
                heroTag: 'fabAddExpense',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Add expense'),
                backgroundColor: AppConstants.accentTeal,
                foregroundColor: Colors.black,
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  // 1. Groups Page
  Widget _buildGroupsPage(AppProvider appProv, UserModel currentUser) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppConstants.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildBellIconButton(appProv, currentUser),
          IconButton(
            icon: const Icon(Icons.group_add, color: AppConstants.accentTeal),
            tooltip: 'Create Group',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.premiumGradient,
        ),
        child: RefreshIndicator(
          onRefresh: () => appProv.loadDashboardData(currentUser.uid),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildCompactBalanceCard(appProv),
              const SizedBox(height: 8),
              appProv.groups.isEmpty
                  ? _buildEmptyState('No groups yet', 'Create a group to start splitting bills.')
                  : ListView.builder(
                      itemCount: appProv.groups.length,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (ctx, index) {
                        final group = appProv.groups[index];
                        final userBalance = appProv.getGroupOffsetBalance(group.groupId);

                        return Card(
                          color: AppConstants.cardDark.withOpacity(0.6),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(groupId: group.groupId),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: group.type == 'SELF' 
                                  ? AppConstants.accentTeal.withOpacity(0.2) 
                                  : (group.type == 'NO_EXPENSE' ? Colors.pink.withOpacity(0.2) : AppConstants.accentIndigo.withOpacity(0.2)),
                              child: Icon(
                                group.type == 'SELF' 
                                    ? Icons.person 
                                    : (group.type == 'NO_EXPENSE' 
                                        ? Icons.money_off 
                                        : (group.type == 'FAMILY' ? Icons.home : Icons.airplanemode_active)),
                                color: group.type == 'SELF' 
                                    ? AppConstants.accentTeal 
                                    : (group.type == 'NO_EXPENSE' ? Colors.pinkAccent : AppConstants.accentIndigo),
                              ),
                            ),
                            title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                            subtitle: Text(group.description, style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                            trailing: _buildBalanceIndicator(userBalance),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Friends Page
  Widget _buildFriendsPage(AppProvider appProv, UserModel currentUser) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppConstants.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildBellIconButton(appProv, currentUser),
          IconButton(
            icon: const Icon(Icons.person_add, color: AppConstants.accentTeal),
            tooltip: 'Add Friend',
            onPressed: () => _addFriendDialog(context, currentUser.uid),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.premiumGradient,
        ),
        child: RefreshIndicator(
          onRefresh: () => appProv.loadDashboardData(currentUser.uid),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildCompactBalanceCard(appProv),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 12),
              appProv.friends.isEmpty
                  ? _buildEmptyState('No friends yet', 'Add friends by email to split direct expenses.')
                  : () {
                      final filtered = _getFilteredFriends(appProv.friends, appProv, currentUser.uid);
                      if (filtered.isEmpty) {
                        return _buildEmptyState('No friends found', 'Try changing the filter option above.');
                      }
                      return ListView.builder(
                        itemCount: filtered.length,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemBuilder: (ctx, index) {
                          final friend = filtered[index];
                          final balance = appProv.getFriendTotalBalance(currentUser.uid, friend.uid);

                          return Card(
                            color: AppConstants.cardDark.withOpacity(0.6),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FriendDetailScreen(friend: friend),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  children: [
                                    // 1. Avatar
                                    AppAvatars.buildAvatar(
                                      photoUrl: friend.photoUrl,
                                      displayName: friend.displayName,
                                      radius: 20,
                                    ),
                                    const SizedBox(width: 12),

                                    // 2. Name & Email/Phone (takes remaining space)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friend.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            friend.email.isNotEmpty ? friend.email : (friend.phone ?? ''),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // 3. Balance Indicator & Settle Button (right side, aligned center vertically)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildBalanceIndicator(balance),
                                        if (balance.abs() > 0.01) ...[
                                          const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: () {
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
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppConstants.accentTeal,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Settle',
                                                style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }(),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Account Page
  Widget _buildAccountPage(AuthProvider authProv, AppProvider appProv, UserModel currentUser) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppConstants.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppConstants.debitOrange),
            tooltip: 'Logout',
            onPressed: () {
              _showLogoutConfirmationDialog(context, authProv);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.premiumGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // User profile header card
            Card(
              color: Colors.white.withOpacity(0.02),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final selectedId = await AppAvatars.showAvatarPicker(context);
                        if (selectedId != null && context.mounted) {
                          await context.read<AuthProvider>().updateAvatar(selectedId);
                        }
                      },
                      child: Stack(
                        children: [
                          AppAvatars.buildAvatar(
                            photoUrl: currentUser.photoUrl,
                            displayName: currentUser.displayName,
                            radius: 36,
                            backgroundColor: AppConstants.accentTeal.withOpacity(0.15),
                            initialsStyle: const TextStyle(
                              color: AppConstants.accentTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
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
                    const SizedBox(height: 16),
                    Text(
                      currentUser.displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.email,
                      style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap avatar to change',
                      style: const TextStyle(fontSize: 11, color: Colors.white24),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Large glass balance card
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: AppConstants.glassDecoration(
                    color: Colors.white,
                    opacity: 0.05,
                    borderRadius: 16.0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR TOTAL NET BALANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${appProv.overallNet >= 0 ? "+" : ""}${AppConstants.currencySymbol}${appProv.overallNet.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: appProv.overallNet >= 0 ? AppConstants.creditGreen : AppConstants.debitOrange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('You are owed', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${AppConstants.currencySymbol}${appProv.overallOwed.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.creditGreen),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 32, color: Colors.white10),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('You owe', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${AppConstants.currencySymbol}${appProv.overallOwe.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.debitOrange),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Currency Settings Card
                      Card(
                        color: Colors.white.withOpacity(0.02),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppConstants.accentTeal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.currency_exchange, color: AppConstants.accentTeal),
                          ),
                          title: const Text('Currency Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Active: ${appProv.selectedCurrency} (${appProv.currencySymbol})\n1 USD = ${appProv.usdToInrRate.toStringAsFixed(1)} INR | ${appProv.usdToEurRate.toStringAsFixed(2)} EUR',
                            style: const TextStyle(color: AppConstants.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppConstants.textSecondary),
                          onTap: () => _showCurrencySettingsBottomSheet(context, appProv, currentUser),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencySettingsBottomSheet(BuildContext context, AppProvider appProv, UserModel currentUser) {
    String localCurrency = appProv.selectedCurrency;
    final inrController = TextEditingController(text: appProv.usdToInrRate.toString());
    final eurController = TextEditingController(text: appProv.usdToEurRate.toString());
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.currency_exchange, color: AppConstants.accentTeal, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Currency Settings',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Select Primary Currency',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['INR', 'USD', 'EUR'].map((curr) {
                          final isSel = localCurrency == curr;
                          String sym = '₹';
                          if (curr == 'USD') sym = '\$';
                          if (curr == 'EUR') sym = '€';

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                localCurrency = curr;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSel ? AppConstants.accentTeal : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSel ? Colors.transparent : Colors.white10),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    sym,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.black : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    curr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.black54 : AppConstants.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Update Exchange Rates (Base: USD)',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: inrController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: '1 USD to INR Rate',
                          labelStyle: TextStyle(color: AppConstants.textSecondary),
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(color: Colors.white),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter rate';
                          if (double.tryParse(value) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: eurController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: '1 USD to EUR Rate',
                          labelStyle: TextStyle(color: AppConstants.textSecondary),
                          prefixText: '€ ',
                          prefixStyle: TextStyle(color: Colors.white),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter rate';
                          if (double.tryParse(value) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.accentTeal,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final usdToInr = double.parse(inrController.text);
                              final usdToEur = double.parse(eurController.text);
                              
                              Navigator.pop(ctx);
                              
                              await appProv.updateCurrencySettings(
                                userId: currentUser.uid,
                                currency: localCurrency,
                                usdToInr: usdToInr,
                                usdToEur: usdToEur,
                              );
                            }
                          },
                          child: const Text('Save Currency Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context, AuthProvider authProv) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppConstants.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
          title: const Row(
            children: [
              Icon(Icons.logout_outlined, color: AppConstants.debitOrange),
              SizedBox(width: 12),
              Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of your account?',
            style: TextStyle(color: AppConstants.textSecondary),
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
                Navigator.pop(ctx);
                await authProv.signOut();
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final filters = {
      'ALL': 'All',
      'SETTLED': 'Settled',
      'I_OWE': 'I owe',
      'OWE_ME': 'Owed to me',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final isSelected = _friendsFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? Colors.black : AppConstants.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: AppConstants.accentTeal,
              backgroundColor: Colors.white.withOpacity(0.03),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _friendsFilter = entry.key;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  List<UserModel> _getFilteredFriends(List<UserModel> friends, AppProvider appProv, String currentUserId) {
    if (_friendsFilter == 'ALL') return friends;

    return friends.where((friend) {
      final balance = appProv.getFriendTotalBalance(currentUserId, friend.uid);
      switch (_friendsFilter) {
        case 'SETTLED':
          return balance.abs() <= 0.01;
        case 'I_OWE':
          return balance < -0.01;
        case 'OWE_ME':
          return balance > 0.01;
        default:
          return true;
      }
    }).toList();
  }

  // Compact horizontal balance bar for Groups and Friends lists
  Widget _buildCompactBalanceCard(AppProvider appProv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL BALANCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppConstants.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${appProv.overallNet >= 0 ? "+" : ""}${AppConstants.currencySymbol}${appProv.overallNet.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: appProv.overallNet >= 0 ? AppConstants.creditGreen : AppConstants.debitOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Owed', style: TextStyle(fontSize: 9, color: AppConstants.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${AppConstants.currencySymbol}${appProv.overallOwed.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.creditGreen, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Owe', style: TextStyle(fontSize: 9, color: AppConstants.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${AppConstants.currencySymbol}${appProv.overallOwe.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.debitOrange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textSecondary)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white30), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceIndicator(double balance) {
    if (balance > 0.01) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('you are owed', style: TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
          Text(
            '${AppConstants.currencySymbol}${balance.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.creditGreen),
          ),
        ],
      );
    } else if (balance < -0.01) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('you owe', style: TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
          Text(
            '${AppConstants.currencySymbol}${balance.abs().toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.debitOrange),
          ),
        ],
      );
    } else {
      return const Text(
        'settled up',
        style: TextStyle(fontSize: 12, color: Colors.white24),
      );
    }
  }

  void _showRemindersBottomSheet(BuildContext context, AppProvider appProv, UserModel currentUser) {
    final reminders = appProv.activities.where((act) => act.activityType == 'reminder' && act.targetId == currentUser.uid).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handlebar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: AppConstants.accentTeal, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Reminders Received',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (reminders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none_outlined, size: 48, color: Colors.white24),
                        SizedBox(height: 12),
                        Text(
                          'No reminders yet',
                          style: TextStyle(color: AppConstants.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reminders.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final r = reminders[index];
                      final senderName = r.metadata['actorName'] ?? 'Someone';
                      final message = r.metadata['message'] ?? 'Please settle up your balance.';
                      final date = r.createdAt;
                      
                      // Format date (simple)
                      final hour = date.hour.toString().padLeft(2, '0');
                      final minute = date.minute.toString().padLeft(2, '0');
                      final dateStr = '${date.day}/${date.month} $hour:$minute';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withOpacity(0.15),
                          child: const Icon(Icons.alarm, color: Colors.amber),
                        ),
                        title: Text(
                          senderName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: const TextStyle(color: Colors.white24, fontSize: 10),
                            ),
                          ],
                        ),
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

  Widget _buildBellIconButton(AppProvider appProv, UserModel currentUser) {
    final unreadCount = appProv.getUnreadRemindersCount(currentUser.uid);
    final hasUnread = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            hasUnread ? Icons.notifications_active_outlined : Icons.notifications_outlined,
            color: AppConstants.accentTeal,
          ),
          tooltip: 'Reminders',
          onPressed: () async {
            await appProv.markRemindersAsRead(currentUser.uid);
            if (mounted) {
              _showRemindersBottomSheet(context, appProv, currentUser);
            }
          },
        ),
        if (hasUnread)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Center(
                child: Text(
                  '+${unreadCount > 9 ? 9 : unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
