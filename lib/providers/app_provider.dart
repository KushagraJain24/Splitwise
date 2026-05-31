import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/models/group_model.dart';
import 'package:splitwise/models/expense_model.dart';
import 'package:splitwise/models/activity_model.dart';
import 'package:splitwise/models/group_note_model.dart';
import 'package:splitwise/services/db_service.dart';
import 'package:splitwise/services/debt_service.dart';
import 'package:splitwise/utils/constants.dart';

class AppProvider extends ChangeNotifier {
  final DbService _dbService = DbService();

  List<GroupModel> _groups = [];
  List<UserModel> _friends = [];
  List<GroupNoteModel> _currentGroupNotes = [];
  bool _isLoading = false;
  bool _isSaving = false;

  // Cached expenses: groupId -> List<ExpenseModel>
  final Map<String, List<ExpenseModel>> _groupExpenses = {};
  // Cached direct expenses: friendId -> List<ExpenseModel>
  final Map<String, List<ExpenseModel>> _directExpenses = {};
  // Offset group balances (for Group list page dashboard calculations)
  final Map<String, double> _groupOffsetBalances = {};

  // Balances
  double _overallOwed = 0.0; // People owe you
  double _overallOwe = 0.0;  // You owe people

  List<ActivityModel> _activities = [];
  DateTime? _lastViewedRemindersTime;

  String _selectedCurrency = 'INR';
  double _usdToInrRate = 95.0;
  double _usdToEurRate = 0.85;

  // Getters
  List<GroupModel> get groups => _groups;
  List<UserModel> get friends => _friends;
  List<GroupNoteModel> get currentGroupNotes => _currentGroupNotes;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  double get overallOwed => _overallOwed;
  double get overallOwe => _overallOwe;
  double get overallNet => DebtService.round(_overallOwed - _overallOwe);
  List<ActivityModel> get activities => _activities;
  DateTime? get lastViewedRemindersTime => _lastViewedRemindersTime;
  String get selectedCurrency => _selectedCurrency;
  double get usdToInrRate => _usdToInrRate;
  double get usdToEurRate => _usdToEurRate;
  double getGroupOffsetBalance(String groupId) => _groupOffsetBalances[groupId] ?? 0.0;

  String get currencySymbol {
    if (_selectedCurrency == 'USD') return '\$';
    if (_selectedCurrency == 'EUR') return '€';
    return '₹';
  }

  double convertUsdToSelected(double usdVal) {
    if (_selectedCurrency == 'USD') return usdVal;
    if (_selectedCurrency == 'INR') return usdVal * _usdToInrRate;
    if (_selectedCurrency == 'EUR') return usdVal * _usdToEurRate;
    return usdVal;
  }

  double convertSelectedToUsd(double selectedVal) {
    if (_selectedCurrency == 'USD') return selectedVal;
    if (_selectedCurrency == 'INR') return selectedVal / _usdToInrRate;
    if (_selectedCurrency == 'EUR') return selectedVal / _usdToEurRate;
    return selectedVal;
  }

  ExpenseModel _convertExpenseToSelected(ExpenseModel exp) {
    final Map<String, SplitDetail> convertedSplits = {};
    exp.splits.forEach((uid, split) {
      convertedSplits[uid] = SplitDetail(
        owedAmount: convertUsdToSelected(split.owedAmount),
        exactValue: split.exactValue != null ? convertUsdToSelected(split.exactValue!) : null,
      );
    });

    return ExpenseModel(
      expenseId: exp.expenseId,
      groupId: exp.groupId,
      friendId: exp.friendId,
      description: exp.description,
      amount: convertUsdToSelected(exp.amount),
      paidBy: exp.paidBy,
      splitType: exp.splitType,
      splits: convertedSplits,
      isSettlement: exp.isSettlement,
      createdAt: exp.createdAt,
      createdBy: exp.createdBy,
      deletedAt: exp.deletedAt,
    );
  }

  ExpenseModel _convertExpenseToUsd(ExpenseModel exp) {
    final Map<String, SplitDetail> convertedSplits = {};
    exp.splits.forEach((uid, split) {
      convertedSplits[uid] = SplitDetail(
        owedAmount: convertSelectedToUsd(split.owedAmount),
        exactValue: split.exactValue != null ? convertSelectedToUsd(split.exactValue!) : null,
      );
    });

    return ExpenseModel(
      expenseId: exp.expenseId,
      groupId: exp.groupId,
      friendId: exp.friendId,
      description: exp.description,
      amount: convertSelectedToUsd(exp.amount),
      paidBy: exp.paidBy,
      splitType: exp.splitType,
      splits: convertedSplits,
      isSettlement: exp.isSettlement,
      createdAt: exp.createdAt,
      createdBy: exp.createdBy,
      deletedAt: exp.deletedAt,
    );
  }

  ActivityModel _convertActivityToSelected(ActivityModel act) {
    final Map<String, dynamic> convertedMetadata = Map<String, dynamic>.from(act.metadata);
    if (convertedMetadata.containsKey('amount')) {
      convertedMetadata['amount'] = convertUsdToSelected((convertedMetadata['amount'] as num).toDouble());
    }
    if (convertedMetadata.containsKey('splits')) {
      final splits = convertedMetadata['splits'] as Map<String, dynamic>?;
      if (splits != null) {
        final Map<String, dynamic> convertedSplits = {};
        splits.forEach((uid, splitMap) {
          if (splitMap is Map) {
            final Map<String, dynamic> m = Map<String, dynamic>.from(splitMap);
            if (m.containsKey('owedAmount')) {
              m['owedAmount'] = convertUsdToSelected((m['owedAmount'] as num).toDouble());
            }
            convertedSplits[uid] = m;
          }
        });
        convertedMetadata['splits'] = convertedSplits;
      }
    }
    return ActivityModel(
      activityId: act.activityId,
      groupId: act.groupId,
      friendId: act.friendId,
      activityType: act.activityType,
      userIds: act.userIds,
      actorId: act.actorId,
      targetId: act.targetId,
      metadata: convertedMetadata,
      createdAt: act.createdAt,
    );
  }

  Future<void> initCurrency(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedCurrency = prefs.getString('currency_selected_$userId') ?? 'INR';
      _usdToInrRate = prefs.getDouble('currency_usd_inr_$userId') ?? 95.0;
      _usdToEurRate = prefs.getDouble('currency_usd_eur_$userId') ?? 0.85;
      AppConstants.currencySymbol = currencySymbol;
      notifyListeners();
    } catch (e) {
      debugPrint("Error initializing currency: $e");
    }
  }

  Future<void> updateCurrencySettings({
    required String userId,
    required String currency,
    required double usdToInr,
    required double usdToEur,
  }) async {
    try {
      _selectedCurrency = currency;
      _usdToInrRate = usdToInr;
      _usdToEurRate = usdToEur;
      AppConstants.currencySymbol = currencySymbol;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency_selected_$userId', currency);
      await prefs.setDouble('currency_usd_inr_$userId', usdToInr);
      await prefs.setDouble('currency_usd_eur_$userId', usdToEur);

      await loadDashboardData(userId);
    } catch (e) {
      debugPrint("Error updating currency settings: $e");
    }
  }

  int getUnreadRemindersCount(String userId) {
    if (_lastViewedRemindersTime == null) {
      return _activities.where((act) => act.activityType == 'reminder' && act.targetId == userId).length;
    }
    return _activities.where((act) => act.activityType == 'reminder' && act.targetId == userId && act.createdAt.isAfter(_lastViewedRemindersTime!)).length;
  }

  Future<void> initLastViewedReminders(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString('last_viewed_reminders_$userId');
      if (timeStr != null) {
        _lastViewedRemindersTime = DateTime.tryParse(timeStr);
      } else {
        _lastViewedRemindersTime = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading last viewed reminders: $e");
    }
  }

  Future<void> markRemindersAsRead(String userId) async {
    try {
      _lastViewedRemindersTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_viewed_reminders_$userId', _lastViewedRemindersTime!.toIso8601String());
      notifyListeners();
    } catch (e) {
      debugPrint("Error marking reminders as read: $e");
    }
  }

  List<ExpenseModel> getGroupExpensesList(String groupId) => _groupExpenses[groupId] ?? [];
  List<ExpenseModel> getDirectExpensesList(String friendId) => _directExpenses[friendId] ?? [];

  Future<void> _loadCachedData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'dashboard_cache_$userId';
      final cacheStr = prefs.getString(cacheKey);
      if (cacheStr != null) {
        final Map<String, dynamic> cacheData = json.decode(cacheStr);
        
        final List<dynamic> cachedGroups = cacheData['groups'] ?? [];
        _groups = cachedGroups.map((g) => GroupModel.fromMap(Map<String, dynamic>.from(g), g['groupId'] ?? '')).toList();

        final List<dynamic> cachedFriends = cacheData['friends'] ?? [];
        _friends = cachedFriends.map((f) => UserModel.fromMap(Map<String, dynamic>.from(f))).toList();

        _groupExpenses.clear();
        final Map<String, dynamic> cachedGroupExps = cacheData['groupExpenses'] ?? {};
        cachedGroupExps.forEach((key, val) {
          if (val is List) {
            _groupExpenses[key] = val.map((e) => ExpenseModel.fromMap(Map<String, dynamic>.from(e), e['expenseId'] ?? '')).toList();
          }
        });

        _directExpenses.clear();
        final Map<String, dynamic> cachedDirectExps = cacheData['directExpenses'] ?? {};
        cachedDirectExps.forEach((key, val) {
          if (val is List) {
            _directExpenses[key] = val.map((e) => ExpenseModel.fromMap(Map<String, dynamic>.from(e), e['expenseId'] ?? '')).toList();
          }
        });

        final List<dynamic> cachedActivities = cacheData['activities'] ?? [];
        _activities = cachedActivities.map((a) => ActivityModel.fromMap(Map<String, dynamic>.from(a), a['activityId'] ?? '')).toList();

        _recalculateOverallBalances(userId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading cached dashboard data: $e");
    }
  }

  Future<void> _saveToCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'dashboard_cache_$userId';

      final Map<String, dynamic> cacheData = {
        'groups': _groups.map((g) {
          final m = g.toMap();
          m['groupId'] = g.groupId;
          return m;
        }).toList(),
        'friends': _friends.map((f) => f.toMap()).toList(),
        'groupExpenses': _groupExpenses.map((key, val) => MapEntry(
              key,
              val.map((e) {
                final m = e.toMap();
                m['expenseId'] = e.expenseId;
                return m;
              }).toList(),
            )),
        'directExpenses': _directExpenses.map((key, val) => MapEntry(
              key,
              val.map((e) {
                final m = e.toMap();
                m['expenseId'] = e.expenseId;
                return m;
              }).toList(),
            )),
        'activities': _activities.map((a) {
          final m = a.toMap();
          m['activityId'] = a.activityId;
          return m;
        }).toList(),
      };

      await prefs.setString(cacheKey, json.encode(cacheData));
    } catch (e) {
      debugPrint("Error saving dashboard data to cache: $e");
    }
  }

  /// Load all core dashboard data
  Future<void> loadDashboardData(String currentUserId) async {
    _isLoading = true;
    notifyListeners();

    await initCurrency(currentUserId);
    // Load cached data first to render UI instantly
    await _loadCachedData(currentUserId);
    await initLastViewedReminders(currentUserId);

    try {
      // Fetch user profile, groups, friends, and activities in parallel
      final userProfileFuture = _dbService.getUserProfile(currentUserId);
      final groupsFuture = _dbService.getGroupsForUser(currentUserId);
      final friendsFuture = _dbService.getFriends(currentUserId);
      final activitiesFuture = _dbService.getActivities(currentUserId);

      final coreResults = await Future.wait([
        userProfileFuture,
        groupsFuture,
        friendsFuture,
        activitiesFuture,
      ]);

      final currentUserProfile = coreResults[0] as UserModel?;
      _groups = coreResults[1] as List<GroupModel>;
      _friends = coreResults[2] as List<UserModel>;
      final rawActs = coreResults[3] as List<ActivityModel>;

      // Self-healing database check (non-blocking in background)
      if (currentUserProfile != null) {
        _dbService.findPlaceholderForEmailOrPhone(
          currentUserProfile.email,
          currentUserProfile.phone,
        ).then((placeholder) {
          if (placeholder != null && placeholder.uid != currentUserId) {
            _dbService.claimPlaceholderHistory(placeholder.uid, currentUserId).then((_) {
              // Reload dashboard data in background silently if healing occurred
              loadDashboardData(currentUserId);
            });
          }
        }).catchError((e) {
          debugPrint("Self-healing background check failed: $e");
        });
      }

      // Pre-load expenses to compute overall summary in parallel
      _groupExpenses.clear();
      _directExpenses.clear();

      final List<Future<void>> expenseFetchFutures = [];

      for (var group in _groups) {
        expenseFetchFutures.add(
          _dbService.getExpenses(groupId: group.groupId).then((exps) {
            _groupExpenses[group.groupId] = exps.map((e) => _convertExpenseToSelected(e)).toList();
          })
        );
      }

      for (var friend in _friends) {
        expenseFetchFutures.add(
          _dbService.getExpenses(
            currentUserId: currentUserId,
            friendId: friend.uid,
          ).then((exps) {
            _directExpenses[friend.uid] = exps.map((e) => _convertExpenseToSelected(e)).toList();
          })
        );
      }

      await Future.wait(expenseFetchFutures);

      _recalculateOverallBalances(currentUserId);
      _activities = rawActs.map((a) => _convertActivityToSelected(a)).toList();

      // Save fresh data to local cache
      await _saveToCache(currentUserId);
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recalculates net balances across all groups and friends for dashboard widgets
  void _recalculateOverallBalances(String currentUserId) {
    double owed = 0.0;
    double owe = 0.0;

    // Initialize offset balances map with the raw group balance for the current user
    _groupOffsetBalances.clear();
    for (var group in _groups) {
      final netBalances = getGroupBalances(group.groupId);
      _groupOffsetBalances[group.groupId] = netBalances[currentUserId] ?? 0.0;
    }

    final Set<String> allUserIds = {};
    for (var friend in _friends) {
      allUserIds.add(friend.uid);
    }
    for (var group in _groups) {
      for (var memberId in group.members) {
        if (memberId != currentUserId) {
          allUserIds.add(memberId);
        }
      }
    }

    for (var uid in allUserIds) {
      final double netPerPerson = getFriendTotalBalance(currentUserId, uid);
      if (netPerPerson > 0.01) {
        owed += netPerPerson;
      } else if (netPerPerson < -0.01) {
        owe += netPerPerson.abs();
      }

      // Calculate cross-group offsets for this specific user
      final List<Map<String, dynamic>> credits = [];
      final List<Map<String, dynamic>> debits = [];

      for (var group in _groups) {
        if (group.members.contains(currentUserId) && group.members.contains(uid)) {
          final simplifiedDebts = getGroupSimplifiedDebts(group.groupId);
          for (var tx in simplifiedDebts) {
            if (tx.from == uid && tx.to == currentUserId) {
              credits.add({'groupId': group.groupId, 'amount': tx.amount});
            } else if (tx.from == currentUserId && tx.to == uid) {
              debits.add({'groupId': group.groupId, 'amount': tx.amount});
            }
          }
        }
      }

      int cIdx = 0;
      int dIdx = 0;
      while (cIdx < credits.length && dIdx < debits.length) {
        final credit = credits[cIdx];
        final debit = debits[dIdx];

        final double cAmt = credit['amount'];
        final double dAmt = debit['amount'];

        final double offset = cAmt < dAmt ? cAmt : dAmt;

        if (offset > 0.01) {
          final String cGroupId = credit['groupId'];
          _groupOffsetBalances[cGroupId] = DebtService.round((_groupOffsetBalances[cGroupId] ?? 0.0) - offset);

          final String dGroupId = debit['groupId'];
          _groupOffsetBalances[dGroupId] = DebtService.round((_groupOffsetBalances[dGroupId] ?? 0.0) + offset);

          credit['amount'] = DebtService.round(cAmt - offset);
          debit['amount'] = DebtService.round(dAmt - offset);
        }

        if (credit['amount'] <= 0.01) cIdx++;
        if (debit['amount'] <= 0.01) dIdx++;
      }
    }

    _overallOwed = DebtService.round(owed);
    _overallOwe = DebtService.round(owe);
  }

  /// Calculate net balances for a specific group
  Map<String, double> getGroupBalances(String groupId) {
    final group = _groups.firstWhere((g) => g.groupId == groupId, orElse: () => throw Exception("Group not found"));
    final expenses = _groupExpenses[groupId] ?? [];
    return DebtService.calculateNetBalances(
      memberUids: group.members,
      transactions: expenses,
    );
  }

  /// Calculate simplified debts for a specific group
  List<SimplifiedTransaction> getGroupSimplifiedDebts(String groupId) {
    final balances = getGroupBalances(groupId);
    return DebtService.simplifyDebts(balances);
  }

  /// Calculate direct friend balance
  double getFriendBalance(String currentUserId, String friendId) {
    final expenses = _directExpenses[friendId] ?? [];
    final balances = DebtService.calculateNetBalances(
      memberUids: [currentUserId, friendId],
      transactions: expenses,
    );
    return balances[currentUserId] ?? 0.0;
  }

  /// Calculate friend balance combining direct and mutual group simplified debts
  double getFriendTotalBalance(String currentUserId, String friendId) {
    double total = getFriendBalance(currentUserId, friendId);

    for (var group in _groups) {
      if (group.members.contains(currentUserId) && group.members.contains(friendId)) {
        final simplifiedDebts = getGroupSimplifiedDebts(group.groupId);
        for (var tx in simplifiedDebts) {
          if (tx.from == currentUserId && tx.to == friendId) {
            total -= tx.amount;
          } else if (tx.from == friendId && tx.to == currentUserId) {
            total += tx.amount;
          }
        }
      }
    }
    return DebtService.round(total);
  }

  /// Create a new group
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required List<UserModel> members,
    required String currentUserId,
    String type = 'TRIP',
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      final newGroup = await _dbService.createGroup(
        name: name,
        description: description,
        createdBy: currentUserId,
        members: members,
        type: type,
      );

      // Log activity for group creation
      final creatorProfile = await _dbService.getUserProfile(currentUserId);
      final creatorName = creatorProfile?.displayName ?? 'You';

      await _dbService.logActivity(ActivityModel(
        activityId: '',
        groupId: newGroup.groupId,
        activityType: 'group_create',
        userIds: newGroup.members,
        actorId: currentUserId,
        metadata: {
          'groupName': newGroup.name,
          'creatorName': creatorName,
        },
        createdAt: DateTime.now(),
      ));

      for (var member in members) {
        if (member.uid == currentUserId) continue;
        await _dbService.logActivity(ActivityModel(
          activityId: '',
          groupId: newGroup.groupId,
          activityType: 'member_add',
          userIds: newGroup.members,
          actorId: currentUserId,
          targetId: member.uid,
          metadata: {
            'groupName': newGroup.name,
            'actorName': creatorName,
            'targetName': member.displayName,
          },
          createdAt: DateTime.now().add(const Duration(milliseconds: 1)),
        ));
      }
      
      // Reload dashboard to fetch updated groups/friends lists
      await loadDashboardData(currentUserId);
      return newGroup;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete Group
  Future<void> deleteGroup(String groupId, String currentUserId) async {
    _isSaving = true;
    notifyListeners();

    try {
      final group = _groups.firstWhere((g) => g.groupId == groupId, orElse: () => throw Exception("Group not found"));
      final groupName = group.name;

      await _dbService.deleteGroup(groupId);

      // Log group deletion activity
      final currentUserProfile = await _dbService.getUserProfile(currentUserId);
      final currentUserName = currentUserProfile?.displayName ?? 'You';

      await _dbService.logActivity(ActivityModel(
        activityId: '',
        groupId: groupId,
        activityType: 'group_delete',
        userIds: group.members,
        actorId: currentUserId,
        metadata: {
          'groupName': groupName,
          'actorName': currentUserName,
        },
        createdAt: DateTime.now(),
      ));

      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Add Members to an already existing group
  Future<void> addMembersToGroup({
    required String groupId,
    required List<UserModel> newMembers,
    required String currentUserId,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      final group = _groups.firstWhere((g) => g.groupId == groupId, orElse: () => throw Exception("Group not found"));
      final groupName = group.name;

      await _dbService.addMembersToGroup(groupId, newMembers);

      // Log activities for member additions
      final actorProfile = await _dbService.getUserProfile(currentUserId);
      final actorName = actorProfile?.displayName ?? 'You';

      final updatedMembers = [...group.members, ...newMembers.map((m) => m.uid)];

      for (var member in newMembers) {
        await _dbService.logActivity(ActivityModel(
          activityId: '',
          groupId: groupId,
          activityType: 'member_add',
          userIds: updatedMembers,
          actorId: currentUserId,
          targetId: member.uid,
          metadata: {
            'groupName': groupName,
            'actorName': actorName,
            'targetName': member.displayName,
          },
          createdAt: DateTime.now().add(const Duration(milliseconds: 1)),
        ));
      }

      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete activity
  Future<void> deleteActivity(String currentUserId, String activityId) async {
    try {
      await _dbService.deleteActivity(activityId);
      _activities.removeWhere((act) => act.activityId == activityId);
      await _saveToCache(currentUserId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting activity: $e");
    }
  }

  /// Send in-app reminder to a friend
  Future<void> sendInAppReminder({
    required String currentUserId,
    required String friendId,
    required double amount,
    required String message,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      final currentUserProfile = await _dbService.getUserProfile(currentUserId);
      final currentUserName = currentUserProfile?.displayName ?? 'You';

      final friendProfile = await _dbService.getUserProfile(friendId);
      final friendName = friendProfile?.displayName ?? 'Friend';

      await _dbService.logActivity(ActivityModel(
        activityId: '',
        friendId: friendId,
        activityType: 'reminder',
        userIds: [currentUserId, friendId],
        actorId: currentUserId,
        targetId: friendId,
        metadata: {
          'amount': convertSelectedToUsd(amount),
          'actorName': currentUserName,
          'friendName': friendName,
          'message': message,
        },
        createdAt: DateTime.now(),
      ));

      // Reload activities from DB to get the new activity
      _activities = await _dbService.getActivities(currentUserId);
      await _saveToCache(currentUserId);
    } catch (e) {
      debugPrint("Error sending reminder: $e");
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Add Friend
  Future<void> addFriend(String currentUserId, UserModel friend) async {
    // Prevent duplicates
    if (friends.any((f) => f.uid == friend.uid || f.email.toLowerCase() == friend.email.toLowerCase())) {
      return;
    }
    _isSaving = true;
    notifyListeners();
    try {
      await _dbService.addFriend(currentUserId, friend);

      // Log friend addition activity
      final currentUserProfile = await _dbService.getUserProfile(currentUserId);
      final currentUserName = currentUserProfile?.displayName ?? 'You';
      await _dbService.logActivity(ActivityModel(
        activityId: '',
        friendId: friend.uid,
        activityType: 'member_add',
        userIds: [currentUserId, friend.uid],
        actorId: currentUserId,
        targetId: friend.uid,
        metadata: {
          'actorName': currentUserName,
          'targetName': friend.displayName,
        },
        createdAt: DateTime.now(),
      ));

      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Search user by email
  Future<UserModel?> searchUserByEmail(String email) async {
    return await _dbService.searchUserByEmail(email);
  }

  /// Invite user by email (creates placeholder)
  Future<UserModel> inviteUser(String email, String displayName, String currentUserId) async {
    final sanitizedEmail = email.trim().toLowerCase();
    // Return existing if they are already in the friend list
    final existing = friends.firstWhere(
      (f) => f.email.toLowerCase() == sanitizedEmail,
      orElse: () => UserModel(uid: '', email: '', displayName: '', createdAt: DateTime.now()),
    );
    if (existing.uid.isNotEmpty) {
      return existing;
    }

    _isSaving = true;
    notifyListeners();
    try {
      // Check if user already exists globally in DB (users collection) first
      final dbUser = await _dbService.searchUserByEmail(sanitizedEmail);
      if (dbUser != null) {
        await _dbService.addFriend(currentUserId, dbUser);
        await loadDashboardData(currentUserId);
        return dbUser;
      }

      final placeholder = await _dbService.createPlaceholderUser(email, displayName);
      await _dbService.addFriend(currentUserId, placeholder);
      await loadDashboardData(currentUserId);
      return placeholder;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Remove a friend and reload dashboard
  Future<void> removeFriend(String currentUserId, String friendId) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _dbService.removeFriend(currentUserId, friendId);
      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update a friend's local display name (nickname stored in current user's friends subcollection)
  Future<void> updateFriendDisplayName(
      String currentUserId, String friendId, String newName) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _dbService.updateFriendDisplayName(currentUserId, friendId, newName);
      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update a friend's avatar (stored in current user's friends subcollection)
  Future<void> updateFriendAvatar(
      String currentUserId, String friendId, String avatarId) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _dbService.updateFriendAvatar(currentUserId, friendId, avatarId);
      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update the current user's own avatar
  Future<void> updateSelfAvatar(String userId, String avatarId) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _dbService.updateUserAvatar(userId, avatarId);
      await loadDashboardData(userId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Returns a merged, date-sorted list of all expenses involving both [currentUserId] and [friendId]:
  /// 1. Direct expenses between the two
  /// 2. Group expenses from shared groups that include both members
  List<ExpenseModel> getFriendAllExpenses(String currentUserId, String friendId) {
    final List<ExpenseModel> result = [];

    // Direct expenses
    result.addAll(_directExpenses[friendId] ?? []);

    // Shared group expenses
    for (final group in _groups) {
      if (group.members.contains(currentUserId) && group.members.contains(friendId)) {
        result.addAll(_groupExpenses[group.groupId] ?? []);
      }
    }

    // Sort newest first
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Add Expense
  Future<void> addExpense(ExpenseModel expense, String currentUserId) async {
    _isSaving = true;
    notifyListeners();

    try {
      final usdExpense = _convertExpenseToUsd(expense);
      await _dbService.addExpense(usdExpense);
      await _logExpenseActivity(usdExpense, currentUserId);
      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Soft Delete Expense
  Future<void> softDeleteExpense({
    required String expenseId,
    required String currentUserId,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      ExpenseModel? expense;
      for (var list in _groupExpenses.values) {
        final matches = list.where((e) => e.expenseId == expenseId);
        if (matches.isNotEmpty) {
          expense = matches.first;
          break;
        }
      }
      if (expense == null) {
        for (var list in _directExpenses.values) {
          final matches = list.where((e) => e.expenseId == expenseId);
          if (matches.isNotEmpty) {
            expense = matches.first;
            break;
          }
        }
      }

      await _dbService.softDeleteExpense(expenseId);

      final exp = expense;
      if (exp != null) {
        final currentUserProfile = await _dbService.getUserProfile(currentUserId);
        final actorName = currentUserProfile?.displayName ?? 'You';

        String? groupName;
        String? friendName;
        List<String> userIds = [];

        if (exp.groupId != null) {
          final matches = _groups.where((g) => g.groupId == exp.groupId);
          if (matches.isNotEmpty) {
            groupName = matches.first.name;
            userIds = matches.first.members;
          }
        } else {
          final friendId = exp.friendId ?? (exp.splits.keys.firstWhere((k) => k != currentUserId, orElse: () => ''));
          final matches = _friends.where((f) => f.uid == friendId);
          if (matches.isNotEmpty) {
            friendName = matches.first.displayName;
          }
          userIds = [currentUserId, friendId];
        }

        await _dbService.logActivity(ActivityModel(
          activityId: '',
          groupId: exp.groupId,
          friendId: exp.friendId,
          activityType: 'expense_delete',
          userIds: userIds,
          actorId: currentUserId,
          metadata: {
            'description': exp.description,
            'amount': convertSelectedToUsd(exp.amount),
            'actorName': actorName,
            'groupName': groupName,
            'friendName': friendName,
          },
          createdAt: DateTime.now(),
        ));
      }

      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Settle Up Payment (Virtually logged as cash/UPI)
  Future<void> settleUp({
    String? groupId,
    String? friendId,
    required String payerId,
    required String receiverId,
    required double amount,
    required String paymentMethod,
    required String currentUserId,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      if (groupId == null && friendId != null) {
        // Cross-group settlement: automatically offset mutual debts and distribute
        final List<Map<String, dynamic>> payerOwesReceiverGroups = [];
        final List<Map<String, dynamic>> receiverOwesPayerGroups = [];
        
        double totalPayerOwesReceiver = 0.0;
        double totalReceiverOwesPayer = 0.0;

        for (var group in _groups) {
          if (group.members.contains(payerId) && group.members.contains(receiverId)) {
            final simplifiedDebts = getGroupSimplifiedDebts(group.groupId);
            for (var tx in simplifiedDebts) {
              if (tx.from == payerId && tx.to == receiverId) {
                payerOwesReceiverGroups.add({
                  'groupId': group.groupId,
                  'amount': tx.amount,
                });
                totalPayerOwesReceiver += tx.amount;
              } else if (tx.from == receiverId && tx.to == payerId) {
                receiverOwesPayerGroups.add({
                  'groupId': group.groupId,
                  'amount': tx.amount,
                });
                totalReceiverOwesPayer += tx.amount;
              }
            }
          }
        }

        final double offsetAmount = totalPayerOwesReceiver < totalReceiverOwesPayer 
            ? totalPayerOwesReceiver 
            : totalReceiverOwesPayer;

        // Distribute the offset to clear receiver's debts to payer (receiverId pays payerId in those groups)
        double remainingReceiverToPayer = offsetAmount;
        for (var item in receiverOwesPayerGroups) {
          if (remainingReceiverToPayer <= 0.01) break;
          final String gId = item['groupId'];
          final double debtVal = item['amount'];
          final double settleVal = remainingReceiverToPayer < debtVal ? remainingReceiverToPayer : debtVal;
          
          if (settleVal > 0.01) {
            final groupSettlement = ExpenseModel(
              expenseId: '',
              groupId: gId,
              friendId: null,
              description: 'Cross-Group Settlement Offset [Distributed]',
              amount: settleVal,
              paidBy: receiverId,
              splitType: 'EXACT',
              splits: {
                payerId: SplitDetail(owedAmount: settleVal),
                receiverId: SplitDetail(owedAmount: 0.0),
              },
              isSettlement: true,
              createdAt: DateTime.now(),
              createdBy: currentUserId,
            );
            final usdSettlement = _convertExpenseToUsd(groupSettlement);
            await _dbService.addExpense(usdSettlement);
            await _logExpenseActivity(usdSettlement, currentUserId);
            remainingReceiverToPayer = DebtService.round(remainingReceiverToPayer - settleVal);
          }
        }

        // Distribute (amount + offsetAmount) to clear payer's debts to receiver (payerId pays receiverId in those groups)
        double remainingPayerToReceiver = DebtService.round(amount + offsetAmount);
        for (var item in payerOwesReceiverGroups) {
          if (remainingPayerToReceiver <= 0.01) break;
          final String gId = item['groupId'];
          final double debtVal = item['amount'];
          final double settleVal = remainingPayerToReceiver < debtVal ? remainingPayerToReceiver : debtVal;
          
          if (settleVal > 0.01) {
            final groupSettlement = ExpenseModel(
              expenseId: '',
              groupId: gId,
              friendId: null,
              description: 'Cross-Group Settlement [Distributed]',
              amount: settleVal,
              paidBy: payerId,
              splitType: 'EXACT',
              splits: {
                receiverId: SplitDetail(owedAmount: settleVal),
                payerId: SplitDetail(owedAmount: 0.0),
              },
              isSettlement: true,
              createdAt: DateTime.now(),
              createdBy: currentUserId,
            );
            final usdSettlement = _convertExpenseToUsd(groupSettlement);
            await _dbService.addExpense(usdSettlement);
            await _logExpenseActivity(usdSettlement, currentUserId);
            remainingPayerToReceiver = DebtService.round(remainingPayerToReceiver - settleVal);
          }
        }

        // Save remainder or direct cash flow if no group debts
        if (remainingPayerToReceiver > 0.01 || (amount == 0 && offsetAmount == 0)) {
          final directSettlement = ExpenseModel(
            expenseId: '',
            groupId: null,
            friendId: friendId,
            description: 'Settle Up Payment (${paymentMethod == "CASH" ? "Cash" : "Online"})',
            amount: remainingPayerToReceiver,
            paidBy: payerId,
            splitType: 'EXACT',
            splits: {
              receiverId: SplitDetail(owedAmount: remainingPayerToReceiver),
              payerId: SplitDetail(owedAmount: 0.0),
            },
            isSettlement: true,
            createdAt: DateTime.now(),
            createdBy: currentUserId,
          );
          final usdSettlement = _convertExpenseToUsd(directSettlement);
          await _dbService.addExpense(usdSettlement);
          await _logExpenseActivity(usdSettlement, currentUserId);
        }
      } else {
        // Normal group-specific settlement
        final expense = ExpenseModel(
          expenseId: '',
          groupId: groupId,
          friendId: friendId,
          description: 'Settle Up Payment (${paymentMethod == "CASH" ? "Cash" : "Online"})',
          amount: amount,
          paidBy: payerId,
          splitType: 'EXACT',
          splits: {
            receiverId: SplitDetail(owedAmount: amount),
            payerId: SplitDetail(owedAmount: 0.0),
          },
          isSettlement: true,
          createdAt: DateTime.now(),
          createdBy: currentUserId,
        );
        final usdSettlement = _convertExpenseToUsd(expense);
        await _dbService.addExpense(usdSettlement);
        await _logExpenseActivity(usdSettlement, currentUserId);
      }

      await loadDashboardData(currentUserId);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Helper to log expense additions/settlements to Activity collection
  Future<void> _logExpenseActivity(ExpenseModel expense, String currentUserId) async {
    try {
      final currentUserProfile = await _dbService.getUserProfile(currentUserId);
      final actorName = currentUserProfile?.displayName ?? 'You';

      String? groupName;
      String? friendName;
      List<String> userIds = [];

      if (expense.groupId != null) {
        final matches = _groups.where((g) => g.groupId == expense.groupId);
        if (matches.isNotEmpty) {
          final group = matches.first;
          groupName = group.name;
          userIds = group.members;
        }
      } else {
        final friendId = expense.friendId ?? (expense.splits.keys.firstWhere((k) => k != currentUserId, orElse: () => ''));
        final matches = _friends.where((f) => f.uid == friendId);
        if (matches.isNotEmpty) {
          friendName = matches.first.displayName;
        } else {
          final fProfile = await _dbService.getUserProfile(friendId);
          friendName = fProfile?.displayName ?? 'Someone';
        }
        userIds = [currentUserId, friendId];
      }

      final splitsMap = expense.splits.map((uid, detail) => MapEntry(uid, {'owedAmount': detail.owedAmount}));

      String paidByName = 'Someone';
      if (expense.paidBy == currentUserId) {
        paidByName = actorName;
      } else {
        if (expense.groupId != null) {
          final group = _groups.firstWhere((g) => g.groupId == expense.groupId);
          paidByName = group.memberDetails[expense.paidBy]?.displayName ?? 'Someone';
        } else {
          paidByName = friendName ?? 'Someone';
        }
      }

      String? receiverId;
      String? receiverName;
      if (expense.isSettlement) {
        receiverId = expense.splits.keys.firstWhere((k) => k != expense.paidBy, orElse: () => '');
        if (receiverId == currentUserId) {
          receiverName = actorName;
        } else {
          if (expense.groupId != null) {
            final group = _groups.firstWhere((g) => g.groupId == expense.groupId);
            receiverName = group.memberDetails[receiverId]?.displayName ?? 'Someone';
          } else {
            receiverName = friendName ?? 'Someone';
          }
        }
      }

      await _dbService.logActivity(ActivityModel(
        activityId: '',
        groupId: expense.groupId,
        friendId: expense.friendId,
        activityType: expense.isSettlement ? 'settlement' : 'expense_add',
        userIds: userIds,
        actorId: currentUserId,
        metadata: {
          'description': expense.description,
          'amount': expense.amount,
          'paidBy': expense.paidBy,
          'paidByName': paidByName,
          'groupName': groupName,
          'friendName': friendName,
          'splits': splitsMap,
          'payerId': expense.paidBy,
          'receiverId': receiverId,
          'receiverName': receiverName,
        },
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint("Error logging expense activity: $e");
    }
  }

  /// Claims placeholder records when user registers
  Future<void> claimPlaceholderHistory(String placeholderUid, String newRealUid, String currentUserId) async {
    await _dbService.claimPlaceholderHistory(placeholderUid, newRealUid);
    await loadDashboardData(currentUserId);
  }

  /// Load notes for a group
  Future<void> loadGroupNotes(String groupId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentGroupNotes = await _dbService.getGroupNotes(groupId);
    } catch (e) {
      debugPrint("Error loading group notes: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a note to a group
  Future<void> addGroupNote(String groupId, String content, String userId, String userName) async {
    _isSaving = true;
    notifyListeners();
    try {
      final note = GroupNoteModel(
        noteId: '',
        groupId: groupId,
        content: content.trim(),
        createdBy: userId,
        createdByName: userName,
        createdAt: DateTime.now(),
      );
      await _dbService.addGroupNote(note);
      await loadGroupNotes(groupId);
    } catch (e) {
      debugPrint("Error adding group note: $e");
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete a note from a group
  Future<void> deleteGroupNote(String groupId, String noteId) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _dbService.deleteGroupNote(groupId, noteId);
      await loadGroupNotes(groupId);
    } catch (e) {
      debugPrint("Error deleting group note: $e");
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
