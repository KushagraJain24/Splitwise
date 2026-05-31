import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/models/group_model.dart';
import 'package:splitwise/models/expense_model.dart';
import 'package:splitwise/services/debt_service.dart';
import 'package:splitwise/utils/constants.dart';
import 'package:splitwise/widgets/saving_overlay.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? groupId;
  final UserModel? directFriend; // Used when navigating directly from friend lists

  const AddExpenseScreen({super.key, this.groupId, this.directFriend});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  String? _selectedGroupId;
  UserModel? _selectedDirectFriend;
  String? _paidById;

  String _splitType = 'EQUAL'; // EQUAL, EXACT, PERCENT, SHARES

  DateTime _selectedDate = DateTime.now();
  IconData _selectedCategoryIcon = Icons.receipt_long;

  // Split details mapping: memberUid -> input value (exact amount, percent, or shares weight)
  final Map<String, TextEditingController> _splitControllers = {};
  // Boolean mapping to track who is involved in the expense
  final Map<String, bool> _involvedMembers = {};

  /// Dismisses the soft keyboard and removes focus from all fields.
  void _dismissKeyboard() {
    _descriptionFocusNode.unfocus();
    _amountFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _selectedDirectFriend = widget.directFriend;
    _paidById = context.read<AuthProvider>().user!.uid;

    _initializeMembers();

    _descriptionController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _descriptionFocusNode.dispose();
    _amountFocusNode.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _splitControllers.forEach((_, controller) => controller.dispose());
    _splitControllers.clear();
  }

  // Get active members list based on selected group or direct friend
  List<UserModel> _getActiveMembers() {
    final appProv = context.read<AppProvider>();
    final currentUser = context.read<AuthProvider>().user!;

    if (_selectedGroupId != null) {
      final group = appProv.groups.firstWhere((g) => g.groupId == _selectedGroupId);
      return group.members.map((uid) {
        final details = group.memberDetails[uid]!;
        return UserModel(
          uid: uid,
          email: details.email,
          displayName: details.displayName,
          isPlaceholder: details.isPlaceholder,
          createdAt: DateTime.now(),
        );
      }).toList();
    } else if (_selectedDirectFriend != null) {
      return [currentUser, _selectedDirectFriend!];
    }
    return [currentUser];
  }

  void _initializeMembers() {
    _disposeControllers();
    _involvedMembers.clear();

    final members = _getActiveMembers();
    for (var m in members) {
      _involvedMembers[m.uid] = true; // Selected by default
      _splitControllers[m.uid] = TextEditingController(
        text: _splitType == 'EQUAL'
            ? ''
            : (_splitType == 'PERCENT'
                ? '0'
                : (_splitType == 'EXACT' ? '0' : '1')),
      );
    }
  }

  void _submit() async {
    if (_selectedGroupId == null && _selectedDirectFriend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a group or friend to split with."),
          backgroundColor: AppConstants.debitOrange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid expense amount")),
      );
      return;
    }

    final activeInvolved = _involvedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
    if (activeInvolved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("At least one person must be involved in the split")),
      );
      return;
    }

    // 1. Gather raw inputs for splits
    final Map<String, double> splitValues = {};
    for (var uid in activeInvolved) {
      final rawVal = double.tryParse(_splitControllers[uid]?.text ?? '') ?? 0.0;
      splitValues[uid] = rawVal;
    }

    // 2. Validate strategies
    if (_splitType == 'EXACT') {
      final double sum = splitValues.values.fold(0.0, (s, v) => s + v);
      if ((sum - totalAmount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sum of exact shares (${AppConstants.currencySymbol}${sum.toStringAsFixed(2)}) must match total (${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)})")),
        );
        return;
      }
    } else if (_splitType == 'PERCENT') {
      final double sum = splitValues.values.fold(0.0, (s, v) => s + v);
      if ((sum - 100.0).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sum of percentages ($sum%) must equal 100%")),
        );
        return;
      }
    } else if (_splitType == 'SHARES') {
      final double sum = splitValues.values.fold(0.0, (s, v) => s + v);
      if (sum <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Total shares must be greater than 0")),
        );
        return;
      }
    }

    // 3. Compute final owed amounts per participant (absorbs rounding pennies on the last person)
    final Map<String, double> computedOwed = DebtService.calculateSplits(
      totalAmount: totalAmount,
      members: activeInvolved,
      splitType: _splitType,
      splitValues: splitValues,
    );

    // 4. Construct splits map
    final Map<String, SplitDetail> finalSplits = {};
    computedOwed.forEach((uid, owed) {
      finalSplits[uid] = SplitDetail(
        owedAmount: owed,
        exactValue: _splitType == 'EXACT' ? splitValues[uid] : null,
        percentage: _splitType == 'PERCENT' ? splitValues[uid] : null,
        shares: _splitType == 'SHARES' ? splitValues[uid] : null,
      );
    });

    // 5. Save expense
    final currentUserId = context.read<AuthProvider>().user!.uid;
    final now = DateTime.now();
    final expenseDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    final expense = ExpenseModel(
      expenseId: '',
      groupId: _selectedGroupId,
      friendId: _selectedGroupId == null ? _selectedDirectFriend?.uid : null,
      description: _descriptionController.text.trim(),
      amount: totalAmount,
      paidBy: _paidById!,
      splitType: _splitType,
      splits: finalSplits,
      createdAt: expenseDate,
      createdBy: currentUserId,
    );

    await context.read<AppProvider>().addExpense(expense, currentUserId);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final currentUser = context.read<AuthProvider>().user!;
    final members = _getActiveMembers();

    return SavingOverlay(
      isSaving: appProv.isSaving,
      message: 'Saving expense...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Expense', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
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
                // 1. Group / Direct connection selector (Custom list bottom sheet trigger)
                const Text(
                  'SPLIT CONTEXT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _showSplitContextBottomSheet(appProv),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedGroupId != null 
                                  ? Icons.group_outlined 
                                  : (_selectedDirectFriend != null ? Icons.person_outline : Icons.help_outline),
                              color: AppConstants.accentTeal,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _selectedGroupId != null
                                  ? 'Group: ${appProv.groups.firstWhere((g) => g.groupId == _selectedGroupId).name}'
                                  : (_selectedDirectFriend != null
                                      ? 'Direct with ${_selectedDirectFriend!.displayName}'
                                      : 'Choose Group or Friend'),
                              style: const TextStyle(
                                color: AppConstants.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppConstants.accentTeal),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Expense Description & Amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _showCategoryPickerBottomSheet,
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Icon(
                          _selectedCategoryIcon,
                          color: AppConstants.accentTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        style: const TextStyle(color: AppConstants.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Description',
                          hintStyle: const TextStyle(color: AppConstants.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppConstants.accentTeal),
                          ),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter description' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppConstants.accentTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AppConstants.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Amount (${AppConstants.currencySymbol})',
                          hintStyle: const TextStyle(color: AppConstants.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppConstants.accentTeal),
                          ),
                        ),
                        validator: (value) => (value == null || double.tryParse(value) == null) ? 'Enter amount' : null,
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Inline Paid By and Split Strategy row
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    const Text('Paid by ', style: TextStyle(color: AppConstants.textSecondary, fontSize: 15)),
                    GestureDetector(
                      onTap: () => _showPayerPickerBottomSheet(members, currentUser),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppConstants.accentTeal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.accentTeal),
                        ),
                        child: Text(
                          _paidById == currentUser.uid 
                              ? 'you' 
                              : (members.firstWhere((m) => m.uid == _paidById, orElse: () => currentUser).displayName.split(' ').first),
                          style: const TextStyle(color: AppConstants.accentTeal, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    const Text(' and split ', style: TextStyle(color: AppConstants.textSecondary, fontSize: 15)),
                    GestureDetector(
                      onTap: _showSplitStrategyBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppConstants.accentIndigo.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.accentIndigo),
                        ),
                        child: Text(
                          _splitType.toLowerCase(),
                          style: const TextStyle(color: AppConstants.accentIndigo, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 5. Splitting Details Input Pane
                const Text(
                  'PARTICIPANTS & VALUE DISTRIBUTION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppConstants.textSecondary),
                ),
                const SizedBox(height: 12),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (ctx, index) {
                    final member = members[index];
                    final isSelf = member.uid == currentUser.uid;
                    final isInvolved = _involvedMembers[member.uid] ?? false;

                    return Card(
                      color: Colors.white.withOpacity(0.02),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // Selection Checkbox
                            Checkbox(
                              value: isInvolved,
                              activeColor: AppConstants.accentTeal,
                              onChanged: (val) {
                                setState(() {
                                  _involvedMembers[member.uid] = val ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                isSelf ? 'You (${member.displayName})' : member.displayName,
                                style: TextStyle(
                                  color: isInvolved ? AppConstants.textPrimary : AppConstants.textSecondary.withOpacity(0.5),
                                  fontWeight: isInvolved ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),

                            // Dynamic input field based on strategy
                            if (isInvolved) ...[
                              if (_splitType == 'EQUAL') ...[
                                Text(
                                  '${AppConstants.currencySymbol}${_calculateEqualSplitEstimate(member.uid)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.accentTeal),
                                )
                              ] else ...[
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: _splitControllers[member.uid],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(color: AppConstants.textPrimary, fontSize: 13),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    ),
                                    onChanged: (_) {
                                      // Trigger validation totals recalculation
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ]
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 6. Validation message pane
                _buildValidationMessage(),

                const SizedBox(height: 40),

                // Submit
                appProv.isSaving
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
                          child: const Text('SAVE EXPENSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showCategoryPickerBottomSheet() {
    _dismissKeyboard();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  {'name': 'Food & Drinks', 'icon': Icons.fastfood_rounded},
                  {'name': 'Transportation', 'icon': Icons.directions_car_rounded},
                  {'name': 'Accommodation', 'icon': Icons.hotel_rounded},
                  {'name': 'Activities', 'icon': Icons.local_activity_rounded},
                  {'name': 'Shopping', 'icon': Icons.shopping_bag_rounded},
                  {'name': 'General/Other', 'icon': Icons.receipt_long},
                ].map((category) {
                  final name = category['name'] as String;
                  final icon = category['icon'] as IconData;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIcon = icon;
                        _descriptionController.text = name;
                        _descriptionController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _descriptionController.text.length),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: AppConstants.accentTeal, size: 20),
                          const SizedBox(width: 8),
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    ).then((_) => _dismissKeyboard());
  }

  void _showSplitContextBottomSheet(AppProvider appProv) {
    _dismissKeyboard();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose Split Context',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text(
                    'GROUPS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (appProv.groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No groups available', style: TextStyle(color: Colors.white30, fontSize: 13)),
                    )
                  else
                    ...appProv.groups.map((group) {
                      final isSelected = _selectedGroupId == group.groupId;
                      return ListTile(
                        onTap: () {
                          setState(() {
                            _selectedGroupId = group.groupId;
                            _selectedDirectFriend = null;
                            _initializeMembers();
                          });
                          Navigator.pop(ctx);
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppConstants.accentIndigo.withOpacity(0.2),
                          child: const Icon(Icons.group_outlined, color: AppConstants.accentIndigo),
                        ),
                        title: Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: AppConstants.accentTeal) : null,
                      );
                    }),
                  
                  const SizedBox(height: 24),

                  const Text(
                    'FRIENDS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppConstants.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (appProv.friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No friends available', style: TextStyle(color: Colors.white30, fontSize: 13)),
                    )
                  else
                    ...appProv.friends.map((friend) {
                      final isSelected = _selectedDirectFriend?.uid == friend.uid;
                      return ListTile(
                        onTap: () {
                          setState(() {
                            _selectedDirectFriend = friend;
                            _selectedGroupId = null;
                            _initializeMembers();
                          });
                          Navigator.pop(ctx);
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppConstants.accentTeal.withOpacity(0.2),
                          child: const Icon(Icons.person_outline, color: AppConstants.accentTeal),
                        ),
                        title: Text(friend.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: AppConstants.accentTeal) : null,
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => _dismissKeyboard());
  }

  void _showPayerPickerBottomSheet(List<UserModel> members, UserModel currentUser) {
    _dismissKeyboard();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Payer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),
              ...members.map((member) {
                final isSelf = member.uid == currentUser.uid;
                final isSelected = _paidById == member.uid;
                return ListTile(
                  onTap: () {
                    setState(() {
                      _paidById = member.uid;
                    });
                    Navigator.pop(ctx);
                  },
                  title: Text(
                    isSelf ? 'You (${member.displayName})' : member.displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppConstants.accentTeal) : null,
                );
              }),
            ],
          ),
        );
      },
    ).then((_) => _dismissKeyboard());
  }

  void _showSplitStrategyBottomSheet() {
    _dismissKeyboard();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Split Strategy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),
              ...[
                {'type': 'EQUAL', 'label': 'equally'},
                {'type': 'EXACT', 'label': 'exact (${AppConstants.currencySymbol})'},
                {'type': 'PERCENT', 'label': 'percent (%)'},
                {'type': 'SHARES', 'label': 'shares'},
              ].map((strategy) {
                final type = strategy['type'] as String;
                final label = strategy['label'] as String;
                final isSelected = _splitType == type;

                return ListTile(
                  onTap: () {
                    setState(() {
                      _splitType = type;
                      _initializeMembers();
                    });
                    Navigator.pop(ctx);
                  },
                  title: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppConstants.accentTeal) : null,
                );
              }),
            ],
          ),
        );
      },
    ).then((_) => _dismissKeyboard());
  }

  Widget _buildSplitTypeButton(String type, String label) {
    final isSelected = _splitType == type;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppConstants.accentIndigo : Colors.white.withOpacity(0.04),
        foregroundColor: isSelected ? Colors.white : AppConstants.textSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed: () {
        setState(() {
          _splitType = type;
          _initializeMembers();
        });
      },
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _calculateEqualSplitEstimate(String memberUid) {
    final double amount = double.tryParse(_amountController.text) ?? 0.0;
    final int count = _involvedMembers.values.where((v) => v).length;
    if (amount <= 0 || count == 0) return '0.00';

    final activeInvolved = _involvedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
    final splits = DebtService.calculateSplits(
      totalAmount: amount,
      members: activeInvolved,
      splitType: 'EQUAL',
      splitValues: {},
    );
    return (splits[memberUid] ?? 0.0).toStringAsFixed(2);
  }

  Widget _buildValidationMessage() {
    final double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final activeInvolved = _involvedMembers.entries.where((e) => e.value).map((e) => e.key).toList();

    if (totalAmount <= 0) return const SizedBox.shrink();

    double runningSum = 0.0;
    for (var uid in activeInvolved) {
      runningSum += double.tryParse(_splitControllers[uid]?.text ?? '') ?? 0.0;
    }

    if (_splitType == 'EXACT') {
      final diff = (totalAmount - runningSum).abs();
      final isCorrect = diff < 0.05;
      return Text(
        'Sum: ${AppConstants.currencySymbol}${runningSum.toStringAsFixed(2)} / ${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)} '
        '${isCorrect ? "✅" : "⚠️ Needs to match total"}',
        style: TextStyle(color: isCorrect ? AppConstants.creditGreen : AppConstants.debitOrange, fontSize: 13, fontWeight: FontWeight.bold),
      );
    } else if (_splitType == 'PERCENT') {
      final diff = (100.0 - runningSum).abs();
      final isCorrect = diff < 0.1;
      return Text(
        'Sum: ${runningSum.toStringAsFixed(1)}% / 100% '
        '${isCorrect ? "✅" : "⚠️ Needs to sum to 100%"}',
        style: TextStyle(color: isCorrect ? AppConstants.creditGreen : AppConstants.debitOrange, fontSize: 13, fontWeight: FontWeight.bold),
      );
    } else if (_splitType == 'SHARES') {
      return Text(
        'Total Shares: ${runningSum.toStringAsFixed(0)} ${runningSum > 0 ? "✅" : "⚠️ Must be > 0"}',
        style: TextStyle(color: runningSum > 0 ? AppConstants.creditGreen : AppConstants.debitOrange, fontSize: 13, fontWeight: FontWeight.bold),
      );
    }
    return const SizedBox.shrink();
  }
}
