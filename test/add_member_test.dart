import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/services/db_service.dart';
import 'package:splitwise/services/auth_service.dart';

void main() {
  setUpAll(() {
    AuthService(); // Seeds mock users in DbService
  });

  group('DbService - Add Members to Existing Group', () {
    test('Successfully adds new member to existing group and sets up reciprocal friendships', () async {
      final dbService = DbService();

      // Get initial गोवा trip group which has alice, bob, charlie
      final groupId = 'goa_trip_id';
      final existingGroup = DbService.mockGroups[groupId];
      expect(existingGroup, isNotNull);
      expect(existingGroup!.members.contains('david_uid'), isFalse);

      // Create new user David
      final david = UserModel(
        uid: 'david_uid',
        email: 'david@example.com',
        displayName: 'David Miller',
        isPlaceholder: false,
        createdAt: DateTime.now(),
      );
      DbService.addMockUser(david);

      // Add David to Goa Trip group
      await dbService.addMembersToGroup(groupId, [david]);

      // Verify David was added to group members and details
      final updatedGroup = DbService.mockGroups[groupId];
      expect(updatedGroup, isNotNull);
      expect(updatedGroup!.members.contains('david_uid'), isTrue);
      expect(updatedGroup.memberDetails.containsKey('david_uid'), isTrue);
      expect(updatedGroup.memberDetails['david_uid']!.displayName, 'David Miller');

      // Verify reciprocal friendships are created
      // David should be friends with Alice, Bob, Charlie
      final davidFriends = await dbService.getFriends('david_uid');
      final davidFriendUids = davidFriends.map((f) => f.uid).toList();
      expect(davidFriendUids.contains('alice_uid'), isTrue);
      expect(davidFriendUids.contains('bob_uid'), isTrue);
      expect(davidFriendUids.contains('charlie_uid'), isTrue);

      // Alice, Bob, and Charlie should also be friends with David
      final aliceFriends = await dbService.getFriends('alice_uid');
      expect(aliceFriends.any((f) => f.uid == 'david_uid'), isTrue);

      final bobFriends = await dbService.getFriends('bob_uid');
      expect(bobFriends.any((f) => f.uid == 'david_uid'), isTrue);

      final charlieFriends = await dbService.getFriends('charlie_uid');
      expect(charlieFriends.any((f) => f.uid == 'david_uid'), isTrue);
    });
  });
}
