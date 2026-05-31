import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitwise/providers/auth_provider.dart';
import 'package:splitwise/providers/app_provider.dart';
import 'package:splitwise/models/user_model.dart';
import 'package:splitwise/models/expense_model.dart';
import 'package:splitwise/services/debt_service.dart';
import 'package:splitwise/utils/constants.dart';
import 'package:splitwise/widgets/saving_overlay.dart';

class SettleUpScreen extends StatefulWidget {
  final String? groupId;
  final String? preFilledPayerId;
  final String? preFilledReceiverId;
  final double? preFilledAmount;

  const SettleUpScreen({
    super.key,
    this.groupId,
    this.preFilledPayerId,
    this.preFilledReceiverId,
    this.preFilledAmount,
  });

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedGroupId;
  String? _payerId;
  String? _receiverId;
  String _paymentMethod = 'CASH'; // CASH, ONLINE

  bool _isProcessingOnline = false;
  double _processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _payerId = widget.preFilledPayerId;
    _receiverId = widget.preFilledReceiverId;

    if (widget.preFilledAmount != null) {
      _amountController.text = widget.preFilledAmount!.toStringAsFixed(2);
    }

    // Default payer is current user if not prefilled
    final currentUser = context.read<AuthProvider>().user!;
    _payerId ??= currentUser.uid;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
    }
    // If no group selected, fall back to current user + all friends
    return [currentUser, ...appProv.friends];
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid settlement amount")),
      );
      return;
    }

    if (_payerId == _receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payer and recipient must be different members.")),
      );
      return;
    }

    final currentUserId = context.read<AuthProvider>().user!.uid;

    if (_paymentMethod == 'ONLINE') {
      // Trigger mock online UPI simulation
      _startOnlinePaymentSimulation(amount, currentUserId);
    } else {
      // CASH Settlement direct save
      await _saveSettlement(amount, currentUserId);
    }
  }

  Future<void> _saveSettlement(double amount, String currentUserId) async {
    final String? friendId = _selectedGroupId == null
        ? (_payerId == currentUserId ? _receiverId : _payerId)
        : null;

    await context.read<AppProvider>().settleUp(
          groupId: _selectedGroupId,
          friendId: friendId,
          payerId: _payerId!,
          receiverId: _receiverId!,
          amount: amount,
          paymentMethod: _paymentMethod,
          currentUserId: currentUserId,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recorded Settlement: Paid ${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}"),
          backgroundColor: AppConstants.creditGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _startOnlinePaymentSimulation(double amount, String currentUserId) async {
    setState(() {
      _isProcessingOnline = true;
      _processingProgress = 0.0;
    });

    // Animate progress bar over 2 seconds
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _processingProgress = i / 10.0;
      });
    }

    // Success Screen briefly
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isProcessingOnline = false;
      });
      // Save transaction
      await _saveSettlement(amount, currentUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final members = _getActiveMembers();

    // Default recipient is first member who isn't the payer
    if (_receiverId == null || _receiverId == _payerId) {
      final potential = members.firstWhere((m) => m.uid != _payerId, orElse: () => members.first);
      _receiverId = potential.uid;
    }

    if (_isProcessingOnline) {
      return _buildUPISimulatorView();
    }

    return SavingOverlay(
      isSaving: appProv.isSaving,
      message: 'Processing settlement...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settle Up', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
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
                // 1. Group Selector
                DropdownButtonFormField<String>(
                  value: _selectedGroupId,
                  dropdownColor: AppConstants.cardDark,
                  style: const TextStyle(color: AppConstants.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Select Group',
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
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Settle Net Balance (Cross-Group)'),
                    ),
                    ...appProv.groups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group.groupId,
                        child: Text(group.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupId = value;
                      _payerId = null;
                      _receiverId = null;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // 2. Visual Transaction Flow card
                Card(
                  color: Colors.white.withOpacity(0.02),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Payer Column
                        Expanded(
                          child: _buildUserSelectorColumn('Who paid / settles?', _payerId, members, (val) {
                            setState(() {
                              _payerId = val;
                              if (_payerId == _receiverId) {
                                _receiverId = members.firstWhere((m) => m.uid != _payerId).uid;
                              }
                            });
                          }),
                        ),

                        // Arrow
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(Icons.arrow_forward, color: AppConstants.accentTeal, size: 24),
                        ),

                        // Recipient Column
                        Expanded(
                          child: _buildUserSelectorColumn('Who received?', _receiverId, members, (val) {
                            setState(() {
                              _receiverId = val;
                              if (_receiverId == _payerId) {
                                _payerId = members.firstWhere((m) => m.uid != _receiverId).uid;
                              }
                            });
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Dues Status Info Banner
                _buildDuesInfo(appProv, context.read<AuthProvider>().user!.uid),
                const SizedBox(height: 24),

                // 3. Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppConstants.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Settlement Amount (${AppConstants.currencySymbol})',
                    labelStyle: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
                    prefixIcon: Container(
                      width: 48,
                      alignment: Alignment.center,
                      child: Text(
                        AppConstants.currencySymbol,
                        style: const TextStyle(color: AppConstants.accentTeal, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppConstants.accentTeal),
                    ),
                  ),
                  validator: (value) => (value == null || double.tryParse(value) == null) ? 'Enter a valid amount' : null,
                ),
                const SizedBox(height: 32),

                // 4. Payment Method Picker
                const Text(
                  'SETTLEMENT MODE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppConstants.textSecondary),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _paymentMethod = 'CASH'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'CASH' ? AppConstants.accentIndigo.withOpacity(0.2) : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _paymentMethod == 'CASH' ? AppConstants.accentIndigo : Colors.white10),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.monetization_on_outlined, color: Colors.white),
                              SizedBox(height: 8),
                              Text('Record Cash', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
                              Text('Manual virtual ledger entry', style: TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _paymentMethod = 'ONLINE'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'ONLINE' ? AppConstants.accentTeal.withOpacity(0.2) : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _paymentMethod == 'ONLINE' ? AppConstants.accentTeal : Colors.white10),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.qr_code_scanner, color: Colors.white),
                              SizedBox(height: 8),
                              Text('Online UPI Scan', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
                              Text('Simulate QR scan & payment', style: TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Save button
                appProv.isSaving
                    ? const Center(child: CircularProgressIndicator(color: AppConstants.accentTeal))
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _paymentMethod == 'ONLINE' ? AppConstants.accentTeal : AppConstants.accentIndigo,
                            foregroundColor: _paymentMethod == 'ONLINE' ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _paymentMethod == 'ONLINE' ? 'PROCEED TO MOCK UPI' : 'RECORD CASH SETTLEMENT',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
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

  Widget _buildUserSelectorColumn(String label, String? value, List<UserModel> members, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppConstants.textSecondary, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            alignment: Alignment.center,
            dropdownColor: AppConstants.cardDark,
            style: const TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold),
            icon: const Icon(Icons.arrow_drop_down, color: AppConstants.accentTeal),
            items: members.map((m) {
              return DropdownMenuItem<String>(
                value: m.uid,
                alignment: Alignment.center,
                child: Text(
                  m.displayName.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildUPISimulatorView() {
    final activeMembers = _getActiveMembers();
    final payer = activeMembers.firstWhere((m) => m.uid == _payerId);
    final receiver = activeMembers.firstWhere((m) => m.uid == _receiverId);
    final amountText = double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? '0.00';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Phone Mock frame
              Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppConstants.cardDark,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white10, width: 2),
                  boxShadow: [
                    BoxShadow(color: AppConstants.accentTeal.withOpacity(0.1), blurRadius: 40, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  children: [
                    // Mock QR graphic
                    Container(
                      width: 140,
                      height: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CustomPaint(
                        painter: MockQRPainter(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'UPI BHIM SIMULATOR',
                      style: TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppConstants.accentTeal),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${AppConstants.currencySymbol}$amountText',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Transferring from ${payer.displayName}\nto ${receiver.displayName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // Progress Loader
                    if (_processingProgress < 1.0) ...[
                      LinearProgressIndicator(
                        value: _processingProgress,
                        color: AppConstants.accentTeal,
                        backgroundColor: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Securing connection with bank...',
                        style: TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ] else ...[
                      // Big Green Success Circle
                      const Icon(Icons.check_circle, color: AppConstants.creditGreen, size: 54),
                      const SizedBox(height: 12),
                      const Text(
                        'Payment Successful!',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.creditGreen),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double getPairwiseNetBalance(String payerId, String receiverId, List<ExpenseModel> transactions) {
    double payerPaidForReceiver = 0.0;
    double receiverPaidForPayer = 0.0;

    for (var tx in transactions) {
      if (tx.deletedAt != null) continue;

      if (!tx.isSettlement) {
        // Normal expense
        if (tx.paidBy == payerId && tx.splits.containsKey(receiverId)) {
          payerPaidForReceiver += tx.splits[receiverId]!.owedAmount;
        }
        if (tx.paidBy == receiverId && tx.splits.containsKey(payerId)) {
          receiverPaidForPayer += tx.splits[payerId]!.owedAmount;
        }
      } else {
        // Settlement
        final String sPayer = tx.paidBy;
        final String sReceiver = tx.splits.keys.firstWhere(
          (key) => key != sPayer,
          orElse: () => '',
        );
        if (sPayer == payerId && sReceiver == receiverId) {
          payerPaidForReceiver += tx.amount;
        }
        if (sPayer == receiverId && sReceiver == payerId) {
          receiverPaidForPayer += tx.amount;
        }
      }
    }
    return DebtService.round(payerPaidForReceiver - receiverPaidForPayer);
  }

  Widget _buildDuesInfo(AppProvider appProv, String currentUserId) {
    if (_payerId == null || _receiverId == null || _payerId == _receiverId) {
      return const SizedBox.shrink();
    }

    final members = _getActiveMembers();
    final payerUser = members.firstWhere((m) => m.uid == _payerId, orElse: () => UserModel(uid: _payerId!, email: '', displayName: 'Payer', createdAt: DateTime.now()));
    final receiverUser = members.firstWhere((m) => m.uid == _receiverId, orElse: () => UserModel(uid: _receiverId!, email: '', displayName: 'Receiver', createdAt: DateTime.now()));

    final payerName = payerUser.displayName.split(' ').first;
    final receiverName = receiverUser.displayName.split(' ').first;

    double netBalance = 0.0;
    if (_selectedGroupId != null) {
      final transactions = appProv.getGroupExpensesList(_selectedGroupId!);
      netBalance = getPairwiseNetBalance(_payerId!, _receiverId!, transactions);
    } else {
      final friendId = (_payerId == currentUserId) ? _receiverId : _payerId;
      if (friendId != null) {
        final totalBalance = appProv.getFriendTotalBalance(currentUserId, friendId);
        if (_payerId == currentUserId) {
          netBalance = totalBalance;
        } else {
          netBalance = -totalBalance;
        }
      }
    }

    // Check simplified debt in group
    SimplifiedTransaction? groupSimplifiedTx;
    if (_selectedGroupId != null) {
      final simplifiedDebts = appProv.getGroupSimplifiedDebts(_selectedGroupId!);
      for (var tx in simplifiedDebts) {
        if ((tx.from == _payerId && tx.to == _receiverId) || (tx.from == _receiverId && tx.to == _payerId)) {
          groupSimplifiedTx = tx;
          break;
        }
      }
    }

    final bool showSimplified = groupSimplifiedTx != null;
    
    String balanceText = '';
    Color textColor = AppConstants.textPrimary;
    double suggestAmount = 0.0;

    if (netBalance < -0.01) {
      suggestAmount = netBalance.abs();
      balanceText = '$payerName owes $receiverName ${AppConstants.currencySymbol}${suggestAmount.toStringAsFixed(2)}';
      textColor = AppConstants.debitOrange;
    } else if (netBalance > 0.01) {
      suggestAmount = netBalance;
      balanceText = '$receiverName owes $payerName ${AppConstants.currencySymbol}${suggestAmount.toStringAsFixed(2)}';
      textColor = AppConstants.creditGreen;
    } else {
      balanceText = 'No direct outstanding balance';
      textColor = AppConstants.textSecondary;
    }

    String simplifiedText = '';
    double simplifiedSuggestAmount = 0.0;
    if (showSimplified) {
      simplifiedSuggestAmount = groupSimplifiedTx.amount;
      if (groupSimplifiedTx.from == _payerId) {
        simplifiedText = 'Simplified: $payerName owes $receiverName ${AppConstants.currencySymbol}${simplifiedSuggestAmount.toStringAsFixed(2)}';
      } else {
        simplifiedText = 'Simplified: $receiverName owes $payerName ${AppConstants.currencySymbol}${simplifiedSuggestAmount.toStringAsFixed(2)}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppConstants.accentTeal),
              const SizedBox(width: 8),
              Text(
                'OUTSTANDING DUES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Direct Balance Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  balanceText,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (suggestAmount > 0.01)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _amountController.text = suggestAmount.toStringAsFixed(2);
                    });
                  },
                  child: const Text(
                    'Use this',
                    style: TextStyle(color: AppConstants.accentTeal, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (showSimplified) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    simplifiedText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _amountController.text = simplifiedSuggestAmount.toStringAsFixed(2);
                    });
                  },
                  child: const Text(
                    'Use this',
                    style: TextStyle(color: AppConstants.accentTeal, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MockQRPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Draw standard 3 corner anchors
    const anchorSize = 30.0;
    // Top-Left
    canvas.drawRect(const Rect.fromLTWH(0, 0, anchorSize, anchorSize), paint);
    canvas.drawRect(const Rect.fromLTWH(4, 4, anchorSize - 8, anchorSize - 8), Paint()..color = Colors.white);
    canvas.drawRect(const Rect.fromLTWH(8, 8, anchorSize - 16, anchorSize - 16), paint);

    // Top-Right
    canvas.drawRect(Rect.fromLTWH(size.width - anchorSize, 0, anchorSize, anchorSize), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - anchorSize + 4, 4, anchorSize - 8, anchorSize - 8), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(size.width - anchorSize + 8, 8, anchorSize - 16, anchorSize - 16), paint);

    // Bottom-Left
    canvas.drawRect(Rect.fromLTWH(0, size.height - anchorSize, anchorSize, anchorSize), paint);
    canvas.drawRect(Rect.fromLTWH(4, size.height - anchorSize + 4, anchorSize - 8, anchorSize - 8), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(8, size.height - anchorSize + 8, anchorSize - 16, anchorSize - 16), paint);

    // Draw some random barcode pixels
    final rand = math.Random(42); // Seeded so it looks consistent
    for (double x = 35; x < size.width - 35; x += 8) {
      for (double y = 0; y < size.height; y += 8) {
        if (rand.nextBool()) {
          canvas.drawRect(Rect.fromLTWH(x, y, 6, 6), paint);
        }
      }
    }
    // Fill remaining sections
    for (double x = 0; x < size.width; x += 8) {
      for (double y = 35; y < size.height - 35; y += 8) {
        if (rand.nextBool()) {
          canvas.drawRect(Rect.fromLTWH(x, y, 6, 6), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
