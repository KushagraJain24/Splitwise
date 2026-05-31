import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/utils/constants.dart';
import 'package:splitwise/utils/contacts_helper.dart';
import 'package:splitwise/utils/invite_helper.dart';

import 'package:splitwise/widgets/saving_overlay.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  final List<UserModel> _selectedMembers = [];
  final List<Map<String, String>> _customWebContacts = [];
  bool _isSearching = false;
  String? _searchError;
  String _selectedType = 'TRIP';


  @override
  void initState() {
    super.initState();
    // Add the creator of the group by default
    final currentUser = context.read<AuthProvider>().user!;
    _selectedMembers.add(currentUser);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _searchAndAddMember() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _searchError = "Enter a valid email");
      return;
    }

    if (_selectedMembers.any((m) => m.email.toLowerCase() == email)) {
      setState(() => _searchError = "User is already added");
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final appProvider = context.read<AppProvider>();
    final user = await appProvider.searchUserByEmail(email);

    if (user != null) {
      setState(() {
        _selectedMembers.add(user);
        _emailController.clear();
        _isSearching = false;
      });
    } else {
      // User not found, show invite placeholder prompt
      if (mounted) {
        _showInviteDialog(email);
      }
    }
  }

  void _showInviteDialog(String email) {
    final nameController = TextEditingController();
    bool isSavingLocal = false;
    showDialog(
      context: context,
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
                          setState(() => _isSearching = false);
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

                          setState(() {
                            _selectedMembers.add(placeholder);
                            _emailController.clear();
                            _isSearching = false;
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            final gName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null;
                            InviteHelper.showInviteChannelsDialog(context, email, groupName: gName);
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

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final requiresMembers = _selectedType == 'TRIP' || _selectedType == 'FAMILY';
      if (requiresMembers && _selectedMembers.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("A group must have at least 2 members."),
            backgroundColor: AppConstants.debitOrange,
          ),
        );
        return;
      }

      final currentUser = context.read<AuthProvider>().user!;
      final finalMembers = requiresMembers ? _selectedMembers : [currentUser];

      await context.read<AppProvider>().createGroup(
            name: _nameController.text,
            description: _descriptionController.text,
            members: finalMembers,
            currentUserId: currentUser.uid,
            type: _selectedType,
          );

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final currentUser = context.read<AuthProvider>().user!;

    return SavingOverlay(
      isSaving: appProvider.isSaving,
      message: 'Creating group...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Group', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.premiumGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Name
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppConstants.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    labelStyle: const TextStyle(color: AppConstants.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppConstants.accentTeal),
                    ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a group name' : null,
                ),
                const SizedBox(height: 16),

                // Group Description
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: AppConstants.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Description (e.g. flat expenses, Goa trip)',
                    labelStyle: const TextStyle(color: AppConstants.textSecondary),
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
                const SizedBox(height: 32),

                // Type Section
                const Text(
                  'TYPE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                  children: [
                    _buildTypeCard('TRIP', 'Trip', Icons.airplanemode_active),
                    _buildTypeCard('FAMILY', 'Family', Icons.home),
                    _buildTypeCard('SELF', 'Self', Icons.person),
                    _buildTypeCard('NO_EXPENSE', 'No Expense', Icons.money_off),
                  ],
                ),
                const SizedBox(height: 32),

                if (_selectedType == 'TRIP' || _selectedType == 'FAMILY') ...[
                  // Members Title
                  const Text(
                    'GROUP MEMBERS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Add Member TextField
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppConstants.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Add member by email',
                                labelStyle: const TextStyle(color: AppConstants.textSecondary),
                                errorText: _searchError,
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
                          onPressed: _isSearching ? null : _searchAndAddMember,
                          child: _isSearching
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selector Buttons for Friends and Contacts
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
                          onPressed: () => _showFriendsSelectorBottomSheet(appProvider),
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
                          onPressed: () => _showContactsSelectorBottomSheet(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Members List chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedMembers.map((member) {
                      final isSelf = member.uid == currentUser.uid;
                      return Chip(
                        backgroundColor: isSelf ? AppConstants.accentIndigo.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        label: Text(
                          isSelf ? 'You (${member.displayName})' : member.displayName,
                          style: const TextStyle(color: AppConstants.textPrimary),
                        ),
                        onDeleted: isSelf
                            ? null
                            : () {
                                setState(() {
                                  _selectedMembers.removeWhere((m) => m.uid == member.uid);
                                });
                              },
                        deleteIconColor: AppConstants.debitOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 48),
                ],


                // Submit Button
                appProvider.isSaving
                    ? const Center(child: CircularProgressIndicator(color: AppConstants.accentTeal))
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.accentTeal,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('CREATE GROUP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTypeCard(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.accentTeal.withOpacity(0.15) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppConstants.accentTeal : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppConstants.accentTeal : AppConstants.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppConstants.textPrimary : AppConstants.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendsSelectorBottomSheet(AppProvider appProv) {
    final searchController = TextEditingController();
    String query = "";

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Exclude friends whose emails are already selected in group members list
            final filteredFriends = appProv.friends.where((f) {
              final isEmailAlreadySelectedByAnother = _selectedMembers.any((m) => m.email.toLowerCase() == f.email.toLowerCase() && m.uid != f.uid);
              if (isEmailAlreadySelectedByAnother) return false;

              final matchQuery = f.displayName.toLowerCase().contains(query.toLowerCase()) ||
                  f.email.toLowerCase().contains(query.toLowerCase());
              return matchQuery;
            }).toList();

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
                        'Select from Friends',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                      if (_selectedMembers.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.check, color: AppConstants.accentTeal),
                          onPressed: () => Navigator.pop(ctx),
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
                      setSheetState(() => query = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  filteredFriends.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No friends found', style: TextStyle(color: AppConstants.textSecondary)),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredFriends.length,
                            itemBuilder: (context, index) {
                              final friend = filteredFriends[index];
                              final isSelected = _selectedMembers.any((m) => m.uid == friend.uid);

                              return CheckboxListTile(
                                activeColor: AppConstants.accentTeal,
                                checkColor: Colors.black,
                                title: Text(friend.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(friend.email, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                value: isSelected,
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      _selectedMembers.add(friend);
                                    } else {
                                      _selectedMembers.removeWhere((m) => m.uid == friend.uid);
                                    }
                                  });
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
      },
    );
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

  void _showContactsSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return _ContactsSelectorSheet(
          fetchContacts: _fetchDeviceContacts,
          customWebContacts: _customWebContacts,
          selectedMembers: _selectedMembers,
          onContactTapped: (email, name) {
            _addContact(email, name);
          },
          onCustomContactAdded: (email, name) {
            _addContact(email, name);
          },
        );
      },
    );
  }

  void _addContact(String email, String name) async {
    if (_selectedMembers.any((m) => m.email.toLowerCase() == email.toLowerCase())) {
      return;
    }

    final appProv = context.read<AppProvider>();
    final matchFriends = appProv.friends.where((f) => f.email.toLowerCase() == email.toLowerCase());

    if (matchFriends.isNotEmpty) {
      setState(() {
        _selectedMembers.add(matchFriends.first);
      });
    } else {
      final tempUser = UserModel(
        uid: 'temp_${DateTime.now().millisecondsSinceEpoch}_$email',
        email: email,
        displayName: name,
        isPlaceholder: true,
        createdAt: DateTime.now(),
      );
      setState(() {
        _selectedMembers.add(tempUser);
      });

      final currentUserId = context.read<AuthProvider>().user!.uid;
      final placeholder = await appProv.inviteUser(email, name, currentUserId);
      
      setState(() {
        final idx = _selectedMembers.indexWhere((m) => m.uid == tempUser.uid);
        if (idx != -1) {
          _selectedMembers[idx] = placeholder;
        }
      });

      if (mounted) {
        final gName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null;
        InviteHelper.showInviteChannelsDialog(context, email, groupName: gName);
      }
    }
  }
}

class _ContactsSelectorSheet extends StatefulWidget {
  final Future<List<Map<String, String>>> Function() fetchContacts;
  final List<Map<String, String>> customWebContacts;
  final List<UserModel> selectedMembers;
  final void Function(String email, String name) onContactTapped;
  final void Function(String email, String name) onCustomContactAdded;

  const _ContactsSelectorSheet({
    required this.fetchContacts,
    required this.customWebContacts,
    required this.selectedMembers,
    required this.onContactTapped,
    required this.onCustomContactAdded,
  });

  @override
  State<_ContactsSelectorSheet> createState() => _ContactsSelectorSheetState();
}

class _ContactsSelectorSheetState extends State<_ContactsSelectorSheet> {
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
                          widget.selectedMembers.isNotEmpty ? Icons.check : Icons.close,
                          color: widget.selectedMembers.isNotEmpty ? AppConstants.accentTeal : AppConstants.textSecondary,
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
                          final isSelected = widget.selectedMembers.any((m) => m.email.toLowerCase() == email.toLowerCase());

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppConstants.accentTeal.withOpacity(0.1),
                              child: Text(name.isNotEmpty ? name[0] : 'C', style: const TextStyle(color: AppConstants.accentTeal, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(email, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppConstants.accentTeal)
                                : const Icon(Icons.add_circle_outline, color: AppConstants.textSecondary),
                            onTap: () {
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
