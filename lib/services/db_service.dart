import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/models/group_model.dart';
import 'package:splitwise/models/expense_model.dart';
import 'package:splitwise/models/activity_model.dart';
import 'package:splitwise/models/group_note_model.dart';
import 'package:splitwise/services/auth_service.dart';

class DbService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // In-Memory Database for Mock Mode
  static final Map<String, UserModel> mockUsers = {};
  static final Map<String, List<UserModel>> mockFriends = {}; // uid -> friends
  static final Map<String, GroupModel> mockGroups = {};
  static final Map<String, ExpenseModel> mockExpenses = {};
  static final Map<String, ActivityModel> mockActivities = {};
  static final Map<String, List<GroupNoteModel>> mockGroupNotes = {};

  static bool _mockDataSeeded = false;

  DbService() {
    if (!AuthService.isFirebaseEnabled() && !_mockDataSeeded) {
      _seedMockData();
    }
  }

  /// Seeds mock database with beautiful sample data
  void _seedMockData() {
    _mockDataSeeded = true;

    // Seed Friends
    mockFriends['alice_uid'] = [
      mockUsers['bob_uid']!,
      mockUsers['charlie_uid']!,
    ];
    mockFriends['bob_uid'] = [
      mockUsers['alice_uid']!,
      mockUsers['charlie_uid']!,
    ];
    mockFriends['charlie_uid'] = [
      mockUsers['alice_uid']!,
      mockUsers['bob_uid']!,
    ];

    // Seed Groups
    final group1 = GroupModel(
      groupId: 'goa_trip_id',
      name: 'Goa Trip 2026 🌴',
      description: 'Expenses for the beach holiday',
      createdBy: 'alice_uid',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      members: ['alice_uid', 'bob_uid', 'charlie_uid'],
      memberDetails: {
        'alice_uid': GroupMemberDetail(displayName: 'Alice Smith', email: 'alice@example.com', isPlaceholder: false),
        'bob_uid': GroupMemberDetail(displayName: 'Bob Jones', email: 'bob@example.com', isPlaceholder: false),
        'charlie_uid': GroupMemberDetail(displayName: 'Charlie Brown', email: 'charlie@example.com', isPlaceholder: false),
      },
    );
    mockGroups[group1.groupId] = group1;

    final group2 = GroupModel(
      groupId: 'flat_302_id',
      name: 'Flat 302 Utilities 🏠',
      description: 'Rent, electricity, and internet bills',
      createdBy: 'bob_uid',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      members: ['alice_uid', 'bob_uid'],
      memberDetails: {
        'alice_uid': GroupMemberDetail(displayName: 'Alice Smith', email: 'alice@example.com', isPlaceholder: false),
        'bob_uid': GroupMemberDetail(displayName: 'Bob Jones', email: 'bob@example.com', isPlaceholder: false),
      },
    );
    mockGroups[group2.groupId] = group2;

    // Seed Expenses for Goa Trip
    // 1. Villa Booking: Alice paid 9000, split equal (3000 each)
    final exp1 = ExpenseModel(
      expenseId: 'exp_villa',
      groupId: 'goa_trip_id',
      description: 'Villa Booking',
      amount: 9000.0,
      paidBy: 'alice_uid',
      splitType: 'EQUAL',
      splits: {
        'alice_uid': SplitDetail(owedAmount: 3000.0),
        'bob_uid': SplitDetail(owedAmount: 3000.0),
        'charlie_uid': SplitDetail(owedAmount: 3000.0),
      },
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      createdBy: 'alice_uid',
    );
    mockExpenses[exp1.expenseId] = exp1;

    // 2. Dinner: Bob paid 1500, split equal (500 each)
    final exp2 = ExpenseModel(
      expenseId: 'exp_dinner',
      groupId: 'goa_trip_id',
      description: 'Dinner at Beach Cafe',
      amount: 1500.0,
      paidBy: 'bob_uid',
      splitType: 'EQUAL',
      splits: {
        'alice_uid': SplitDetail(owedAmount: 500.0),
        'bob_uid': SplitDetail(owedAmount: 500.0),
        'charlie_uid': SplitDetail(owedAmount: 500.0),
      },
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      createdBy: 'bob_uid',
    );
    mockExpenses[exp2.expenseId] = exp2;

    // 3. Scuba Diving: Charlie paid 4000, split unequal (Alice 2000, Charlie 2000, Bob doesn't participate)
    final exp3 = ExpenseModel(
      expenseId: 'exp_scuba',
      groupId: 'goa_trip_id',
      description: 'Scuba Diving',
      amount: 4000.0,
      paidBy: 'charlie_uid',
      splitType: 'EXACT',
      splits: {
        'alice_uid': SplitDetail(owedAmount: 2000.0, exactValue: 2000.0),
        'charlie_uid': SplitDetail(owedAmount: 2000.0, exactValue: 2000.0),
      },
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      createdBy: 'charlie_uid',
    );
    mockExpenses[exp3.expenseId] = exp3;

    // Seed Expenses for Flat 302
    // 4. Rent: Bob paid 12000, split equal (6000 each)
    final exp4 = ExpenseModel(
      expenseId: 'exp_rent',
      groupId: 'flat_302_id',
      description: 'May Rent',
      amount: 12000.0,
      paidBy: 'bob_uid',
      splitType: 'EQUAL',
      splits: {
        'alice_uid': SplitDetail(owedAmount: 600.0), // wait, split equal should be 6000
        'bob_uid': SplitDetail(owedAmount: 6000.0), // typo corrected below
      },
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      createdBy: 'bob_uid',
    );
    // Let's make it correct
    final exp4Correct = ExpenseModel(
      expenseId: 'exp_rent',
      groupId: 'flat_302_id',
      description: 'Monthly Rent',
      amount: 12000.0,
      paidBy: 'bob_uid',
      splitType: 'EQUAL',
      splits: {
        'alice_uid': SplitDetail(owedAmount: 6000.0),
        'bob_uid': SplitDetail(owedAmount: 6000.0),
      },
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      createdBy: 'bob_uid',
    );
    mockExpenses[exp4Correct.expenseId] = exp4Correct;

    // Seed a Direct Friend-to-friend expense
    // 5. Alice lent Bob 1000 directly
    final exp5 = ExpenseModel(
      expenseId: 'exp_direct_cab',
      groupId: null,
      friendId: 'bob_uid',
      description: 'Shared Cab Ride',
      amount: 1000.0,
      paidBy: 'alice_uid',
      splitType: 'EQUAL',
      splits: {
        'alice_uid': SplitDetail(owedAmount: 500.0),
        'bob_uid': SplitDetail(owedAmount: 500.0),
      },
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      createdBy: 'alice_uid',
    );
    mockExpenses[exp5.expenseId] = exp5;

    // Seed mock activities
    final act1 = ActivityModel(
      activityId: 'act_seed_1',
      groupId: 'goa_trip_id',
      activityType: 'group_create',
      userIds: ['alice_uid', 'bob_uid', 'charlie_uid'],
      actorId: 'alice_uid',
      metadata: {
        'groupName': 'Goa Trip 2026 🌴',
        'creatorName': 'Alice Smith',
      },
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    );
    mockActivities[act1.activityId] = act1;

    final act2 = ActivityModel(
      activityId: 'act_seed_2',
      groupId: 'goa_trip_id',
      activityType: 'member_add',
      userIds: ['alice_uid', 'bob_uid', 'charlie_uid'],
      actorId: 'alice_uid',
      targetId: 'bob_uid',
      metadata: {
        'groupName': 'Goa Trip 2026 🌴',
        'actorName': 'Alice Smith',
        'targetName': 'Bob Jones',
      },
      createdAt: DateTime.now().subtract(const Duration(days: 5, minutes: 2)),
    );
    mockActivities[act2.activityId] = act2;

    final act3 = ActivityModel(
      activityId: 'act_seed_3',
      groupId: 'goa_trip_id',
      activityType: 'member_add',
      userIds: ['alice_uid', 'bob_uid', 'charlie_uid'],
      actorId: 'alice_uid',
      targetId: 'charlie_uid',
      metadata: {
        'groupName': 'Goa Trip 2026 🌴',
        'actorName': 'Alice Smith',
        'targetName': 'Charlie Brown',
      },
      createdAt: DateTime.now().subtract(const Duration(days: 5, minutes: 1)),
    );
    mockActivities[act3.activityId] = act3;

    final act4 = ActivityModel(
      activityId: 'act_seed_4',
      groupId: 'goa_trip_id',
      activityType: 'expense_add',
      userIds: ['alice_uid', 'bob_uid', 'charlie_uid'],
      actorId: 'alice_uid',
      metadata: {
        'description': 'Villa Booking',
        'amount': 9000.0,
        'paidBy': 'alice_uid',
        'paidByName': 'Alice Smith',
        'groupName': 'Goa Trip 2026 🌴',
        'splits': {
          'alice_uid': {'owedAmount': 3000.0},
          'bob_uid': {'owedAmount': 3000.0},
          'charlie_uid': {'owedAmount': 3000.0},
        },
      },
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    );
    mockActivities[act4.activityId] = act4;

    final act5 = ActivityModel(
      activityId: 'act_seed_5',
      groupId: 'goa_trip_id',
      activityType: 'expense_add',
      userIds: ['alice_uid', 'bob_uid', 'charlie_uid'],
      actorId: 'bob_uid',
      metadata: {
        'description': 'Dinner at Beach Cafe',
        'amount': 1500.0,
        'paidBy': 'bob_uid',
        'paidByName': 'Bob Jones',
        'groupName': 'Goa Trip 2026 🌴',
        'splits': {
          'alice_uid': {'owedAmount': 500.0},
          'bob_uid': {'owedAmount': 500.0},
          'charlie_uid': {'owedAmount': 500.0},
        },
      },
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );
    mockActivities[act5.activityId] = act5;

    final act6 = ActivityModel(
      activityId: 'act_seed_6',
      groupId: null,
      friendId: 'bob_uid',
      activityType: 'expense_add',
      userIds: ['alice_uid', 'bob_uid'],
      actorId: 'alice_uid',
      metadata: {
        'description': 'Shared Cab Ride',
        'amount': 1000.0,
        'paidBy': 'alice_uid',
        'paidByName': 'Alice Smith',
        'friendName': 'Bob Jones',
        'splits': {
          'alice_uid': {'owedAmount': 500.0},
          'bob_uid': {'owedAmount': 500.0},
        },
      },
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    mockActivities[act6.activityId] = act6;

    // Divide all seeded mock amounts/splits by 95.0 to store them in USD base currency
    mockExpenses.forEach((id, exp) {
      final Map<String, SplitDetail> convertedSplits = {};
      exp.splits.forEach((uid, split) {
        convertedSplits[uid] = SplitDetail(
          owedAmount: split.owedAmount / 95.0,
          exactValue: split.exactValue != null ? split.exactValue! / 95.0 : null,
        );
      });
      mockExpenses[id] = ExpenseModel(
        expenseId: exp.expenseId,
        groupId: exp.groupId,
        friendId: exp.friendId,
        description: exp.description,
        amount: exp.amount / 95.0,
        paidBy: exp.paidBy,
        splitType: exp.splitType,
        splits: convertedSplits,
        isSettlement: exp.isSettlement,
        createdAt: exp.createdAt,
        createdBy: exp.createdBy,
        deletedAt: exp.deletedAt,
      );
    });

    mockActivities.forEach((id, act) {
      final Map<String, dynamic> convertedMetadata = Map<String, dynamic>.from(act.metadata);
      if (convertedMetadata.containsKey('amount')) {
        convertedMetadata['amount'] = (convertedMetadata['amount'] as num).toDouble() / 95.0;
      }
      if (convertedMetadata.containsKey('splits')) {
        final splits = convertedMetadata['splits'] as Map<String, dynamic>?;
        if (splits != null) {
          final Map<String, dynamic> convertedSplits = {};
          splits.forEach((uid, splitMap) {
            if (splitMap is Map) {
              final Map<String, dynamic> m = Map<String, dynamic>.from(splitMap);
              if (m.containsKey('owedAmount')) {
                m['owedAmount'] = (m['owedAmount'] as num).toDouble() / 95.0;
              }
              convertedSplits[uid] = m;
            }
          });
          convertedMetadata['splits'] = convertedSplits;
        }
      }
      mockActivities[id] = ActivityModel(
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
    });
  }

  // --- Static helpers to seed mock users from AuthService ---
  static void addMockUser(UserModel user) {
    mockUsers[user.uid] = user;
  }

  static UserModel? getMockUserByEmail(String email) {
    for (var u in mockUsers.values) {
      if (u.email.toLowerCase() == email.toLowerCase()) return u;
    }
    return null;
  }

  // ==========================================
  // DB Operations (Dual-Mode Interface)
  // ==========================================

  /// Log activity in dual-mode
  Future<void> logActivity(ActivityModel activity) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('activities')
          .doc(activity.activityId.isEmpty ? null : activity.activityId)
          .set(activity.toFirestore());
    } else {
      final id = activity.activityId.isEmpty
          ? 'act_${DateTime.now().microsecondsSinceEpoch}'
          : activity.activityId;
      mockActivities[id] = ActivityModel(
        activityId: id,
        groupId: activity.groupId,
        friendId: activity.friendId,
        activityType: activity.activityType,
        userIds: activity.userIds,
        actorId: activity.actorId,
        targetId: activity.targetId,
        metadata: activity.metadata,
        createdAt: activity.createdAt,
      );
    }
  }

  /// Delete activity
  Future<void> deleteActivity(String activityId) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore.collection('activities').doc(activityId).delete();
    } else {
      mockActivities.remove(activityId);
    }
  }

  /// Get activities involving a user
  Future<List<ActivityModel>> getActivities(String userId) async {
    if (AuthService.isFirebaseEnabled()) {
      final snapshot = await _firestore
          .collection('activities')
          .where('userIds', arrayContains: userId)
          .get();

      final List<ActivityModel> list = snapshot.docs
          .map((doc) => ActivityModel.fromMap(doc.data(), doc.id))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } else {
      final list = mockActivities.values
          .where((act) => act.userIds.contains(userId))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
  }

  /// Create user profile in Database
  Future<void> createUserProfile(UserModel user) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore.collection('users').doc(user.uid).set(user.toFirestore());
    } else {
      mockUsers[user.uid] = user;
    }
  }

  /// Fetch user profile by UID
  Future<UserModel?> getUserProfile(String uid) async {
    if (AuthService.isFirebaseEnabled()) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    } else {
      return mockUsers[uid];
    }
  }

  /// Create placeholder contact for invite flow
  Future<UserModel> createPlaceholderUser(String email, String displayName) async {
    final sanitizedEmail = email.trim().toLowerCase();
    final uid = 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
    final isPhone = !sanitizedEmail.contains('@');
    final cleanPhone = isPhone ? sanitizedEmail.replaceAll(RegExp(r'\D'), '') : null;
    final placeholder = UserModel(
      uid: uid,
      email: sanitizedEmail,
      displayName: displayName.trim(),
      phone: cleanPhone,
      isPlaceholder: true,
      createdAt: DateTime.now(),
    );

    if (AuthService.isFirebaseEnabled()) {
      await _firestore.collection('users').doc(uid).set(placeholder.toFirestore());
    } else {
      mockUsers[uid] = placeholder;
    }

    return placeholder;
  }

  bool _isSamePhone(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    final c1 = p1.trim().replaceAll(RegExp(r'\D'), '');
    final c2 = p2.trim().replaceAll(RegExp(r'\D'), '');
    if (c1.isEmpty || c2.isEmpty) return false;
    if (c1.length >= 10 && c2.length >= 10) {
      return c1.substring(c1.length - 10) == c2.substring(c2.length - 10);
    }
    return c1 == c2;
  }

  List<String> getPhoneVariations(String phone) {
    final clean = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return [];
    final Set<String> variations = {clean};
    variations.add('+$clean');
    if (clean.length >= 10) {
      final last10 = clean.substring(clean.length - 10);
      variations.add(last10);
      variations.add('91$last10');
      variations.add('+91$last10');
      variations.add('0$last10');
    }
    return variations.where((v) => v.isNotEmpty).toList();
  }

  /// Find user by email (used for adding friends or group members)
  Future<UserModel?> searchUserByEmail(String email) async {
    final sanitizedEmail = email.trim().toLowerCase();

    if (AuthService.isFirebaseEnabled()) {
      var snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: sanitizedEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(snapshot.docs.first.data());
      }

      final originalEmail = email.trim();
      if (originalEmail != sanitizedEmail) {
        snapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: originalEmail)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return UserModel.fromMap(snapshot.docs.first.data());
        }
      }
      return null;
    } else {
      for (var u in mockUsers.values) {
        if (u.email.toLowerCase() == sanitizedEmail) return u;
      }
      return null;
    }
  }

  /// Find user by phone number
  Future<UserModel?> searchUserByPhone(String phone) async {
    final sanitizedPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (sanitizedPhone.isEmpty) return null;

    final variations = getPhoneVariations(phone);
    if (variations.isEmpty) return null;

    if (AuthService.isFirebaseEnabled()) {
      // 1. Search by phone field
      var snapshot = await _firestore
          .collection('users')
          .where('phone', whereIn: variations)
          .get();

      for (var doc in snapshot.docs) {
        final u = UserModel.fromMap(doc.data());
        if (_isSamePhone(u.phone, phone)) {
          return u;
        }
      }

      // 2. Search by email field (for placeholders that put phone in the email field)
      snapshot = await _firestore
          .collection('users')
          .where('email', whereIn: variations)
          .get();

      for (var doc in snapshot.docs) {
        final u = UserModel.fromMap(doc.data());
        if (_isSamePhone(u.email, phone)) {
          return u;
        }
      }
      return null;
    } else {
      for (var u in mockUsers.values) {
        if (_isSamePhone(u.phone, phone) || _isSamePhone(u.email, phone)) {
          return u;
        }
      }
      return null;
    }
  }

  /// Add Friend
  Future<void> addFriend(String currentUserId, UserModel friend) async {
    if (AuthService.isFirebaseEnabled()) {
      // Add Friend to current user's friends list
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friend.uid)
          .set(friend.toMap());

      // Reciprocal friendship logic - add current user to friend's list
      final currentUserProfile = await getUserProfile(currentUserId);
      if (currentUserProfile != null) {
        await _firestore
            .collection('users')
            .doc(friend.uid)
            .collection('friends')
            .doc(currentUserId)
            .set(currentUserProfile.toMap());
      }
    } else {
      mockFriends.putIfAbsent(currentUserId, () => []);
      if (!mockFriends[currentUserId]!.any((f) => f.uid == friend.uid)) {
        mockFriends[currentUserId]!.add(friend);
      }

      // Reciprocal mock friendship
      mockFriends.putIfAbsent(friend.uid, () => []);
      final currentUser = mockUsers[currentUserId];
      if (currentUser != null && !mockFriends[friend.uid]!.any((f) => f.uid == currentUserId)) {
        mockFriends[friend.uid]!.add(currentUser);
      }
    }
  }

  /// Fetch Friends List
  Future<List<UserModel>> getFriends(String currentUserId) async {
    if (AuthService.isFirebaseEnabled()) {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();

      final list = snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
      final updatedList = await Future.wait(list.map((f) async {
        final latestProfile = await getUserProfile(f.uid);
        if (latestProfile != null) {
          return f.copyWith(
            photoUrl: latestProfile.photoUrl,
            displayName: latestProfile.displayName,
          );
        }
        return f;
      }));
      return updatedList;
    } else {
      final list = mockFriends[currentUserId] ?? [];
      return list.map((f) => mockUsers[f.uid] ?? f).toList();
    }
  }

  /// Remove Friend (both directions)
  Future<void> removeFriend(String currentUserId, String friendId) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId)
          .delete();

      await _firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(currentUserId)
          .delete();
    } else {
      mockFriends[currentUserId]?.removeWhere((f) => f.uid == friendId);
      mockFriends[friendId]?.removeWhere((f) => f.uid == currentUserId);
    }
  }

  /// Update display name for a friend in current user's friends subcollection (local nickname)
  Future<void> updateFriendDisplayName(
      String currentUserId, String friendId, String newName) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId)
          .update({'displayName': newName});
    } else {
      final friends = mockFriends[currentUserId];
      if (friends != null) {
        final idx = friends.indexWhere((f) => f.uid == friendId);
        if (idx != -1) {
          friends[idx] = friends[idx].copyWith(displayName: newName);
        }
      }
    }
  }

  /// Update user's avatar (photoUrl stored as "avatar:<id>")
  Future<void> updateUserAvatar(String userId, String avatarId) async {
    final photoUrl = 'avatar:$avatarId';
    if (AuthService.isFirebaseEnabled()) {
      await _firestore.collection('users').doc(userId).update({'photoUrl': photoUrl});
    } else {
      final existing = mockUsers[userId];
      if (existing != null) {
        mockUsers[userId] = existing.copyWith(photoUrl: photoUrl);
      }
    }
  }

  /// Update friend's avatar in current user's friends subcollection
  Future<void> updateFriendAvatar(
      String currentUserId, String friendId, String avatarId) async {
    final photoUrl = 'avatar:$avatarId';
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId)
          .update({'photoUrl': photoUrl});
    } else {
      final friends = mockFriends[currentUserId];
      if (friends != null) {
        final idx = friends.indexWhere((f) => f.uid == friendId);
        if (idx != -1) {
          friends[idx] = friends[idx].copyWith(photoUrl: photoUrl);
        }
      }
    }
  }

  /// Create Group
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required List<UserModel> members,
    String type = 'TRIP',
  }) async {
    final groupId = AuthService.isFirebaseEnabled()
        ? _firestore.collection('groups').doc().id
        : 'group_${DateTime.now().millisecondsSinceEpoch}';

    final memberUids = members.map((m) => m.uid).toList();
    final Map<String, GroupMemberDetail> memberDetails = {
      for (var m in members)
        m.uid: GroupMemberDetail(
          displayName: m.displayName,
          email: m.email,
          isPlaceholder: m.isPlaceholder,
        )
    };

    final group = GroupModel(
      groupId: groupId,
      name: name.trim(),
      description: description.trim(),
      createdBy: createdBy,
      createdAt: DateTime.now(),
      members: memberUids,
      memberDetails: memberDetails,
      type: type,
    );

    if (AuthService.isFirebaseEnabled()) {
      await _firestore.collection('groups').doc(groupId).set(group.toFirestore());

      // Auto-friendship logic: Add all members as friends of each other
      for (var u1 in members) {
        for (var u2 in members) {
          if (u1.uid != u2.uid) {
            await addFriend(u1.uid, u2);
          }
        }
      }
    } else {
      mockGroups[groupId] = group;

      // Auto-friendship mock
      for (var u1 in members) {
        for (var u2 in members) {
          if (u1.uid != u2.uid) {
            await addFriend(u1.uid, u2);
          }
        }
      }
    }

    return group;
  }

  /// Add Members to an already existing group
  Future<void> addMembersToGroup(String groupId, List<UserModel> newMembers) async {
    if (AuthService.isFirebaseEnabled()) {
      final docRef = _firestore.collection('groups').doc(groupId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final List<String> members = List<String>.from(data['members'] ?? []);
      final Map<String, dynamic> rawDetails = data['memberDetails'] ?? {};
      final Map<String, GroupMemberDetail> memberDetails = {};
      rawDetails.forEach((key, value) {
        if (value is Map) {
          memberDetails[key] = GroupMemberDetail.fromMap(Map<String, dynamic>.from(value));
        }
      });

      // Reconstruct existing members as UserModels to establish reciprocal friendships
      final List<UserModel> existingMembers = [];
      memberDetails.forEach((uid, detail) {
        existingMembers.add(UserModel(
          uid: uid,
          email: detail.email,
          displayName: detail.displayName,
          isPlaceholder: detail.isPlaceholder,
          createdAt: DateTime.now(),
        ));
      });

      // Update members list and details
      for (var newMember in newMembers) {
        if (!members.contains(newMember.uid)) {
          members.add(newMember.uid);
          memberDetails[newMember.uid] = GroupMemberDetail(
            displayName: newMember.displayName,
            email: newMember.email,
            isPlaceholder: newMember.isPlaceholder,
          );
        }
      }

      await docRef.update({
        'members': members,
        'memberDetails': memberDetails.map((key, value) => MapEntry(key, value.toMap())),
      });

      // Establish reciprocal friendships
      final allMembers = [...existingMembers, ...newMembers];
      for (var newMember in newMembers) {
        for (var other in allMembers) {
          if (newMember.uid != other.uid) {
            await addFriend(newMember.uid, other);
          }
        }
      }
    } else {
      final group = mockGroups[groupId];
      if (group == null) return;

      final List<String> members = List<String>.from(group.members);
      final Map<String, GroupMemberDetail> memberDetails = Map<String, GroupMemberDetail>.from(group.memberDetails);

      final List<UserModel> existingMembers = [];
      memberDetails.forEach((uid, detail) {
        existingMembers.add(UserModel(
          uid: uid,
          email: detail.email,
          displayName: detail.displayName,
          isPlaceholder: detail.isPlaceholder,
          createdAt: DateTime.now(),
        ));
      });

      for (var newMember in newMembers) {
        if (!members.contains(newMember.uid)) {
          members.add(newMember.uid);
          memberDetails[newMember.uid] = GroupMemberDetail(
            displayName: newMember.displayName,
            email: newMember.email,
            isPlaceholder: newMember.isPlaceholder,
          );
        }
      }

      mockGroups[groupId] = GroupModel(
        groupId: group.groupId,
        name: group.name,
        description: group.description,
        createdBy: group.createdBy,
        createdAt: group.createdAt,
        members: members,
        memberDetails: memberDetails,
      );

      final allMembers = [...existingMembers, ...newMembers];
      for (var newMember in newMembers) {
        for (var other in allMembers) {
          if (newMember.uid != other.uid) {
            await addFriend(newMember.uid, other);
          }
        }
      }
    }
  }

  /// Delete Group (soft delete)
  Future<void> deleteGroup(String groupId) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .update({'deletedAt': FieldValue.serverTimestamp()});
    } else {
      final group = mockGroups[groupId];
      if (group != null) {
        mockGroups[groupId] = GroupModel(
          groupId: group.groupId,
          name: group.name,
          description: group.description,
          createdBy: group.createdBy,
          createdAt: group.createdAt,
          members: group.members,
          memberDetails: group.memberDetails,
          deletedAt: DateTime.now(),
        );
      }
    }
  }

  /// Fetch Groups for User
  Future<List<GroupModel>> getGroupsForUser(String userId) async {
    if (AuthService.isFirebaseEnabled()) {
      final snapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .get();

      return snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
          .where((g) => g.deletedAt == null)
          .toList();
    } else {
      return mockGroups.values
          .where((g) => g.members.contains(userId) && g.deletedAt == null)
          .toList();
    }
  }

  /// Add Expense (or Settlement Transaction)
  Future<void> addExpense(ExpenseModel expense) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('expenses')
          .doc(expense.expenseId.isEmpty ? null : expense.expenseId)
          .set(expense.toFirestore());
    } else {
      final id = expense.expenseId.isEmpty
          ? 'exp_${DateTime.now().millisecondsSinceEpoch}'
          : expense.expenseId;
      final savedExpense = ExpenseModel(
        expenseId: id,
        groupId: expense.groupId,
        friendId: expense.friendId,
        description: expense.description,
        amount: expense.amount,
        paidBy: expense.paidBy,
        splitType: expense.splitType,
        splits: expense.splits,
        isSettlement: expense.isSettlement,
        createdAt: expense.createdAt,
        createdBy: expense.createdBy,
        deletedAt: expense.deletedAt,
      );
      mockExpenses[id] = savedExpense;
    }
  }

  /// Fetch active Expenses for a specific Group or Direct Friend Connection
  Future<List<ExpenseModel>> getExpenses({
    String? groupId,
    String? currentUserId,
    String? friendId,
  }) async {
    if (AuthService.isFirebaseEnabled()) {
      Query query = _firestore.collection('expenses');

      if (groupId != null) {
        query = query.where('groupId', isEqualTo: groupId);
      } else if (currentUserId != null && friendId != null) {
        // Direct friend expenses has groupId = null
        query = query.where('groupId', isEqualTo: null);
      } else {
        return [];
      }

      final snapshot = await query.get();
      final List<ExpenseModel> allExpenses = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // For direct expenses, filter those that belong to both currentUserId and friendId
      if (groupId == null && currentUserId != null && friendId != null) {
        return allExpenses.where((exp) {
          if (exp.groupId != null && exp.groupId!.isNotEmpty) return false;
          final isPayerCurrent = exp.paidBy == currentUserId;
          final isPayerFriend = exp.paidBy == friendId;
          final isInvolvedCurrent = exp.splits.containsKey(currentUserId);
          final isInvolvedFriend = exp.splits.containsKey(friendId);

          return (isPayerCurrent && isInvolvedFriend) || (isPayerFriend && isInvolvedCurrent);
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      // Sort group expenses by date descending
      allExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allExpenses;
    } else {
      List<ExpenseModel> list = [];
      if (groupId != null) {
        list = mockExpenses.values.where((exp) => exp.groupId == groupId).toList();
      } else if (currentUserId != null && friendId != null) {
        list = mockExpenses.values.where((exp) {
          if (exp.groupId != null && exp.groupId!.isNotEmpty) return false;
          final isPayerCurrent = exp.paidBy == currentUserId;
          final isPayerFriend = exp.paidBy == friendId;
          final isInvolvedCurrent = exp.splits.containsKey(currentUserId);
          final isInvolvedFriend = exp.splits.containsKey(friendId);

          return (isPayerCurrent && isInvolvedFriend) || (isPayerFriend && isInvolvedCurrent);
        }).toList();
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
  }

  /// Soft delete an expense
  Future<void> softDeleteExpense(String expenseId) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('expenses')
          .doc(expenseId)
          .update({'deletedAt': FieldValue.serverTimestamp()});
    } else {
      if (mockExpenses.containsKey(expenseId)) {
        final exp = mockExpenses[expenseId]!;
        mockExpenses[expenseId] = ExpenseModel(
          expenseId: exp.expenseId,
          groupId: exp.groupId,
          friendId: exp.friendId,
          description: exp.description,
          amount: exp.amount,
          paidBy: exp.paidBy,
          splitType: exp.splitType,
          splits: exp.splits,
          isSettlement: exp.isSettlement,
          createdAt: exp.createdAt,
          createdBy: exp.createdBy,
          deletedAt: DateTime.now(),
        );
      }
    }
  }

  /// Claim a placeholder user history upon registration
  Future<void> claimPlaceholderHistory(String placeholderUid, String newRealUid) async {
    // If Firebase is enabled, we update Firestore documents where memberDetails or members array contains placeholderUid
    // For 3-day MVP simplicity in mock mode:
    if (!AuthService.isFirebaseEnabled()) {
      // 1. Move friends
      if (mockFriends.containsKey(placeholderUid)) {
        mockFriends[newRealUid] = mockFriends[placeholderUid]!;
        mockFriends.remove(placeholderUid);
      }
      // Remove placeholder from mockUsers
      mockUsers.remove(placeholderUid);
      // Update instances of friends lists
      mockFriends.forEach((uid, friendsList) {
        for (int i = 0; i < friendsList.length; i++) {
          if (friendsList[i].uid == placeholderUid) {
            friendsList[i] = mockUsers[newRealUid]!;
          }
        }
      });

      // 2. Update Group memberships
      mockGroups.forEach((groupId, group) {
        if (group.members.contains(placeholderUid)) {
          final members = List<String>.from(group.members);
          members.remove(placeholderUid);
          members.add(newRealUid);

          final details = Map<String, GroupMemberDetail>.from(group.memberDetails);
          final oldDetail = details.remove(placeholderUid);
          if (oldDetail != null) {
            details[newRealUid] = GroupMemberDetail(
              displayName: oldDetail.displayName,
              email: oldDetail.email,
              isPlaceholder: false,
            );
          }

          mockGroups[groupId] = GroupModel(
            groupId: group.groupId,
            name: group.name,
            description: group.description,
            createdBy: group.createdBy == placeholderUid ? newRealUid : group.createdBy,
            createdAt: group.createdAt,
            members: members,
            memberDetails: details,
          );
        }
      });

      // 3. Update expenses
      mockExpenses.forEach((expId, exp) {
        final Map<String, SplitDetail> splits = Map<String, SplitDetail>.from(exp.splits);
        if (splits.containsKey(placeholderUid)) {
          final split = splits.remove(placeholderUid);
          if (split != null) {
            splits[newRealUid] = split;
          }
        }

        mockExpenses[expId] = ExpenseModel(
          expenseId: exp.expenseId,
          groupId: exp.groupId,
          friendId: exp.friendId == placeholderUid ? newRealUid : exp.friendId,
          description: exp.description,
          amount: exp.amount,
          paidBy: exp.paidBy == placeholderUid ? newRealUid : exp.paidBy,
          splitType: exp.splitType,
          splits: splits,
          isSettlement: exp.isSettlement,
          createdAt: exp.createdAt,
          createdBy: exp.createdBy == placeholderUid ? newRealUid : exp.createdBy,
          deletedAt: exp.deletedAt,
        );
      });
    } else {
      // In production Firebase, we would run a batch update / cloud function
      // For the scope of this assignment, we implement the equivalent client batch logic:
      final firestoreBatch = _firestore.batch();

      // Find groups that contain this placeholder
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: placeholderUid)
          .get();

      for (var doc in groupsSnapshot.docs) {
        final data = doc.data();
        final List<String> members = List<String>.from(data['members'] ?? []);
        members.remove(placeholderUid);
        members.add(newRealUid);

        final Map<String, dynamic> memberDetails = Map<String, dynamic>.from(data['memberDetails'] ?? {});
        final oldDetail = memberDetails.remove(placeholderUid);
        if (oldDetail != null) {
          memberDetails[newRealUid] = {
            'displayName': oldDetail['displayName'],
            'email': oldDetail['email'],
            'isPlaceholder': false,
          };
        }

        firestoreBatch.update(doc.reference, {
          'members': members,
          'memberDetails': memberDetails,
        });
      }

      // Migrate friends list in Firestore
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(placeholderUid)
          .collection('friends')
          .get();

      final newRealProfile = await getUserProfile(newRealUid);

      for (var doc in friendsSnapshot.docs) {
        final friendData = doc.data();
        final friendUid = doc.id;

        // Add friend to new real user's friends list
        firestoreBatch.set(
          _firestore
              .collection('users')
              .doc(newRealUid)
              .collection('friends')
              .doc(friendUid),
          friendData,
        );

        // Remove from placeholder's friends list
        firestoreBatch.delete(doc.reference);

        // Update friend's own friends list: replace placeholderUid with newRealUid
        firestoreBatch.delete(
          _firestore
              .collection('users')
              .doc(friendUid)
              .collection('friends')
              .doc(placeholderUid),
        );

        if (newRealProfile != null) {
          firestoreBatch.set(
            _firestore
                .collection('users')
                .doc(friendUid)
                .collection('friends')
                .doc(newRealUid),
            newRealProfile.toMap(),
          );
        }
      }

      // Migrate expenses (group and direct) in Firestore
      // 1. Group expenses
      for (var groupDoc in groupsSnapshot.docs) {
        final groupId = groupDoc.id;
        final expensesSnapshot = await _firestore
            .collection('expenses')
            .where('groupId', isEqualTo: groupId)
            .get();

        for (var expDoc in expensesSnapshot.docs) {
          final expData = expDoc.data();
          bool changed = false;

          String paidBy = expData['paidBy'] ?? '';
          if (paidBy == placeholderUid) {
            paidBy = newRealUid;
            changed = true;
          }

          String friendId = expData['friendId'] ?? '';
          if (friendId == placeholderUid) {
            friendId = newRealUid;
            changed = true;
          }

          String createdBy = expData['createdBy'] ?? '';
          if (createdBy == placeholderUid) {
            createdBy = newRealUid;
            changed = true;
          }

          final Map<String, dynamic> splits = Map<String, dynamic>.from(expData['splits'] ?? {});
          if (splits.containsKey(placeholderUid)) {
            final split = splits.remove(placeholderUid);
            splits[newRealUid] = split;
            changed = true;
          }

          if (changed) {
            firestoreBatch.update(expDoc.reference, {
              'paidBy': paidBy,
              'friendId': friendId.isEmpty ? null : friendId,
              'createdBy': createdBy,
              'splits': splits,
            });
          }
        }
      }

      // 2. Direct expenses (where groupId is null)
      final directPaidSnapshot = await _firestore
          .collection('expenses')
          .where('groupId', isNull: true)
          .where('paidBy', isEqualTo: placeholderUid)
          .get();
      for (var expDoc in directPaidSnapshot.docs) {
        final expData = expDoc.data();
        final Map<String, dynamic> splits = Map<String, dynamic>.from(expData['splits'] ?? {});
        if (splits.containsKey(placeholderUid)) {
          final split = splits.remove(placeholderUid);
          splits[newRealUid] = split;
        }
        firestoreBatch.update(expDoc.reference, {
          'paidBy': newRealUid,
          'splits': splits,
          'createdBy': expData['createdBy'] == placeholderUid ? newRealUid : expData['createdBy'],
        });
      }

      final directFriendSnapshot = await _firestore
          .collection('expenses')
          .where('groupId', isNull: true)
          .where('friendId', isEqualTo: placeholderUid)
          .get();
      for (var expDoc in directFriendSnapshot.docs) {
        final expData = expDoc.data();
        final Map<String, dynamic> splits = Map<String, dynamic>.from(expData['splits'] ?? {});
        if (splits.containsKey(placeholderUid)) {
          final split = splits.remove(placeholderUid);
          splits[newRealUid] = split;
        }
        firestoreBatch.update(expDoc.reference, {
          'friendId': newRealUid,
          'splits': splits,
          'createdBy': expData['createdBy'] == placeholderUid ? newRealUid : expData['createdBy'],
        });
      }

      // Delete placeholder user document from users collection
      firestoreBatch.delete(_firestore.collection('users').doc(placeholderUid));

      await firestoreBatch.commit();
    }
  }

  /// Update user's phone number
  Future<void> updateUserPhone(String uid, String phone) async {
    final sanitizedPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (AuthService.isFirebaseEnabled()) {
      await _firestore.collection('users').doc(uid).update({
        'phone': sanitizedPhone,
      });
    } else {
      if (mockUsers.containsKey(uid)) {
        mockUsers[uid] = mockUsers[uid]!.copyWith(phone: sanitizedPhone);
      }
    }
  }

  /// Find a placeholder profile by email or phone
  Future<UserModel?> findPlaceholderForEmailOrPhone(String email, String? phone) async {
    final sanitizedEmail = email.trim().toLowerCase();
    if (AuthService.isFirebaseEnabled()) {
      // 1. Query by email (including fallback checks for potential casing mismatches)
      var snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: sanitizedEmail)
          .get();
      for (var doc in snapshot.docs) {
        final u = UserModel.fromMap(doc.data());
        if (u.isPlaceholder && u.email.toLowerCase() == sanitizedEmail) return u;
      }

      final originalEmail = email.trim();
      if (originalEmail != sanitizedEmail) {
        snapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: originalEmail)
            .get();
        for (var doc in snapshot.docs) {
          final u = UserModel.fromMap(doc.data());
          if (u.isPlaceholder && u.email.toLowerCase() == sanitizedEmail) return u;
        }
      }
      
      // 2. Query by phone variations
      if (phone != null && phone.isNotEmpty) {
        final variations = getPhoneVariations(phone);
        if (variations.isNotEmpty) {
          snapshot = await _firestore
              .collection('users')
              .where('phone', whereIn: variations)
              .get();
          for (var doc in snapshot.docs) {
            final u = UserModel.fromMap(doc.data());
            if (u.isPlaceholder && _isSamePhone(u.phone, phone)) return u;
          }

          // Also check email field for phone variations
          snapshot = await _firestore
              .collection('users')
              .where('email', whereIn: variations)
              .get();
          for (var doc in snapshot.docs) {
            final u = UserModel.fromMap(doc.data());
            if (u.isPlaceholder && _isSamePhone(u.email, phone)) return u;
          }
        }
      }
      return null;
    } else {
      for (var u in mockUsers.values) {
        if (u.isPlaceholder) {
          if (u.email.toLowerCase() == sanitizedEmail) return u;
          if (phone != null && phone.isNotEmpty && (_isSamePhone(u.phone, phone) || _isSamePhone(u.email, phone))) {
            return u;
          }
        }
      }
      return null;
    }
  }

  /// Add a note to a group
  Future<void> addGroupNote(GroupNoteModel note) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('groups')
          .doc(note.groupId)
          .collection('notes')
          .doc(note.noteId.isEmpty ? null : note.noteId)
          .set(note.toFirestore());
    } else {
      final noteId = note.noteId.isEmpty
          ? 'note_${DateTime.now().microsecondsSinceEpoch}'
          : note.noteId;
      final newNote = GroupNoteModel(
        noteId: noteId,
        groupId: note.groupId,
        content: note.content,
        createdBy: note.createdBy,
        createdByName: note.createdByName,
        createdAt: note.createdAt,
      );
      mockGroupNotes.putIfAbsent(note.groupId, () => []);
      mockGroupNotes[note.groupId]!.add(newNote);
    }
  }

  /// Get notes for a group
  Future<List<GroupNoteModel>> getGroupNotes(String groupId) async {
    if (AuthService.isFirebaseEnabled()) {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('notes')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => GroupNoteModel.fromMap(doc.data(), doc.id))
          .toList();
    } else {
      final list = mockGroupNotes[groupId] ?? [];
      final sortedList = List<GroupNoteModel>.from(list);
      sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sortedList;
    }
  }

  /// Delete a note from a group
  Future<void> deleteGroupNote(String groupId, String noteId) async {
    if (AuthService.isFirebaseEnabled()) {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('notes')
          .doc(noteId)
          .delete();
    } else {
      mockGroupNotes[groupId]?.removeWhere((n) => n.noteId == noteId);
    }
  }
}
