import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise/models/group_model.dart';
import 'package:splitwise/services/db_service.dart';
import 'package:splitwise/services/auth_service.dart';

void main() {
  setUpAll(() {
    AuthService(); // Seeds mock users in DbService
  });

  group('DbService - Delete Group', () {
    test('Successfully soft-deletes a group and filters it out from getGroupsForUser queries', () async {
      final dbService = DbService();

      // Seed a temporary group to delete
      final tempGroup = GroupModel(
        groupId: 'delete_test_group',
        name: 'Group to Delete',
        description: 'Testing group deletion',
        createdBy: 'alice_uid',
        createdAt: DateTime.now(),
        members: ['alice_uid', 'bob_uid'],
        memberDetails: {
          'alice_uid': GroupMemberDetail(displayName: 'Alice Smith', email: 'alice@example.com', isPlaceholder: false),
          'bob_uid': GroupMemberDetail(displayName: 'Bob Jones', email: 'bob@example.com', isPlaceholder: false),
        },
      );
      DbService.mockGroups[tempGroup.groupId] = tempGroup;

      // Verify it initially appears in Alice's groups query
      var groups = await dbService.getGroupsForUser('alice_uid');
      expect(groups.any((g) => g.groupId == 'delete_test_group'), isTrue);

      // Perform soft-deletion
      await dbService.deleteGroup('delete_test_group');

      // Verify the group's deletedAt is set
      final deletedGroup = DbService.mockGroups['delete_test_group'];
      expect(deletedGroup, isNotNull);
      expect(deletedGroup!.deletedAt, isNotNull);

      // Verify it no longer appears in Alice's groups query
      groups = await dbService.getGroupsForUser('alice_uid');
      expect(groups.any((g) => g.groupId == 'delete_test_group'), isFalse);
    });
  });
}
