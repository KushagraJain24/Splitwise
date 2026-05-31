import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise/models/group_note_model.dart';
import 'package:splitwise/services/db_service.dart';
import 'package:splitwise/services/auth_service.dart';

void main() {
  setUpAll(() {
    AuthService(); // Initialize structures
  });

  group('DbService - Group Notes', () {
    test('Successfully adds, fetches, and deletes group notes', () async {
      final dbService = DbService();
      final groupId = 'notes_test_group';

      // Verify notes list is initially empty
      var notes = await dbService.getGroupNotes(groupId);
      expect(notes.isEmpty, isTrue);

      // Create a new note
      final note = GroupNoteModel(
        noteId: 'note_1',
        groupId: groupId,
        content: 'Don\'t forget to pay the electric bill by Friday!',
        createdBy: 'alice_uid',
        createdByName: 'Alice Smith',
        createdAt: DateTime.now(),
      );

      // Add the note
      await dbService.addGroupNote(note);

      // Fetch notes and verify
      notes = await dbService.getGroupNotes(groupId);
      expect(notes.length, equals(1));
      expect(notes.first.noteId, equals('note_1'));
      expect(notes.first.content, equals('Don\'t forget to pay the electric bill by Friday!'));
      expect(notes.first.createdByName, equals('Alice Smith'));

      // Delete the note
      await dbService.deleteGroupNote(groupId, 'note_1');

      // Fetch and verify deletion
      notes = await dbService.getGroupNotes(groupId);
      expect(notes.isEmpty, isTrue);
    });
  });
}
