import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/rabbit.dart';
import '../../models/transaction.dart' as finance;
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

class ArchiveModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const ArchiveModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<ArchiveModal> createState() => _ArchiveModalState();
}

class _ArchiveModalState extends State<ArchiveModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _buyerController = TextEditingController();
  final TextEditingController _yieldController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _deathCauseController = TextEditingController();
  final TextEditingController _cullReasonController = TextEditingController();

  ArchiveReason? _selectedReason;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _salePriceController.dispose();
    _buyerController.dispose();
    _yieldController.dispose();
    _costController.dispose();
    _deathCauseController.dispose();
    _cullReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Archive Rabbit',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.rabbit.name} (${widget.rabbit.id})',
                style: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
              ),
              const SizedBox(height: 24),

              // Reason Selection
              const Text(
                'Select Reason',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Sold Option
              _buildReasonOption(
                reason: ArchiveReason.sold,
                title: 'Sold',
                subtitle: 'Rabbit was sold to another breeder',
                icon: Icons.monetization_on,
                color: const Color(0xFF0F7B6C),
              ),
              const SizedBox(height: 12),

              // Butchered Option - only show if meat production enabled
              if (SettingsService.instance.meatProductionEnabled) ...[
                _buildReasonOption(
                  reason: ArchiveReason.butchered,
                  title: 'Butchered',
                  subtitle: 'Processed for meat',
                  icon: Icons.restaurant,
                  color: const Color(0xFFCB8347),
                ),
                const SizedBox(height: 12),
              ],

              // Culled Option
              _buildReasonOption(
                reason: ArchiveReason.cull,
                title: 'Culled',
                subtitle: 'Removed from breeding program',
                icon: Icons.block,
                color: const Color(0xFFD44C47),
              ),
              const SizedBox(height: 12),

              // Dead Option - FIXED
              _buildReasonOption(
                reason: ArchiveReason.dead, // ✅ CHANGED FROM died
                title: 'Died',
                subtitle: 'Natural death or illness',
                icon: Icons.sentiment_very_dissatisfied,
                color: const Color(0xFF787774),
              ),
              const SizedBox(height: 20),

              // Dynamic fields based on selected reason
              if (_selectedReason != null) ..._buildReasonSpecificFields(),

              // General Notes
              const Text(
                'Additional Notes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any additional notes...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),

              // Warning Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD44C47).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD44C47).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFFD44C47), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: const Text(
                        'This will move the rabbit to the archive. You can still view archived rabbits in the Archive tab.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFD44C47)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedReason == null || _isSaving ? null : _saveArchive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD44C47),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Archive Rabbit',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonOption({
    required ArchiveReason reason,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedReason == reason;

    return InkWell(
      onTap: () => setState(() => _selectedReason = reason),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE9E9E7),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF787774)),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReasonSpecificFields() {
    switch (_selectedReason!) {
      case ArchiveReason.sold:
        return [
          const Text(
            'Sale Information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _salePriceController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            decoration: InputDecoration(
              labelText: 'Sale Price *',
              prefixText: '\$',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyerController,
            decoration: InputDecoration(
              labelText: 'Buyer Information',
              hintText: 'Name, phone, email...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
        ];

      case ArchiveReason.butchered: // ✅ FIXED
        return [
          const Text(
            'Butcher Information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _yieldController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            decoration: InputDecoration(
              labelText: 'Yield Weight (lbs) *',
              hintText: 'Dressed weight',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _costController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            decoration: InputDecoration(
              labelText: 'Processing Cost',
              prefixText: '\$',
              hintText: 'Optional',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
        ];

      case ArchiveReason.cull:
        return [
          const Text(
            'Cull Reason',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cullReasonController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Reason for Culling *',
              hintText: 'Poor temperament, health issues, etc...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
        ];

      case ArchiveReason.dead: // ✅ FIXED
        return [
          const Text(
            'Cause of Death',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deathCauseController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Cause of Death *',
              hintText: 'Natural causes, illness, injury...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
        ];
    }
  }

  Future<void> _saveArchive() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason'),
          backgroundColor: Color(0xFFD44C47),
        ),
      );
      return;
    }

    // Validation based on reason
    if (_selectedReason == ArchiveReason.sold) {
      if (_salePriceController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter sale price'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    if (_selectedReason == ArchiveReason.butchered) {
      // ✅ FIXED
      if (_yieldController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter yield weight'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    if (_selectedReason == ArchiveReason.dead) {
      // ✅ FIXED
      if (_deathCauseController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter cause of death'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    if (_selectedReason == ArchiveReason.cull) {
      if (_cullReasonController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter cull reason'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      await _db.archiveRabbit(
        widget.rabbit.id,
        _selectedReason!,
        _notesController.text.isEmpty ? null : _notesController.text,
        // Sold fields
        _selectedReason == ArchiveReason.sold && _salePriceController.text.isNotEmpty ? double.tryParse(_salePriceController.text) : null,
        _selectedReason == ArchiveReason.sold && _buyerController.text.isNotEmpty ? _buyerController.text : null,
        // Butcher fields - ✅ FIXED
        _selectedReason == ArchiveReason.butchered && _yieldController.text.isNotEmpty ? double.tryParse(_yieldController.text) : null,
        _selectedReason == ArchiveReason.butchered && _costController.text.isNotEmpty ? double.tryParse(_costController.text) : null,
        // Death cause - ✅ FIXED
        _selectedReason == ArchiveReason.dead && _deathCauseController.text.isNotEmpty ? _deathCauseController.text : null,
        // Cull reason
        _selectedReason == ArchiveReason.cull && _cullReasonController.text.isNotEmpty ? _cullReasonController.text : null,
      );

      // Add finance transaction for sold or butchered rabbits
      if (_selectedReason == ArchiveReason.sold && _salePriceController.text.isNotEmpty) {
        final salePrice = double.tryParse(_salePriceController.text) ?? 0;
        if (salePrice > 0) {
          // Create income transaction linked to the rabbit (and its parents)
          final transaction = finance.Transaction(
            id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
            type: finance.TransactionType.income,
            category: finance.TransactionCategory.soldKit,
            amount: salePrice,
            date: DateTime.now(),
            description: 'Sold ${widget.rabbit.name} (${widget.rabbit.id})',
            notes: _buyerController.text.isNotEmpty ? 'Buyer: ${_buyerController.text}' : null,
            linkType: finance.LinkType.rabbit,
            rabbitId: widget.rabbit.id,
            buyerInfo: _buyerController.text.isNotEmpty ? _buyerController.text : null,
          );
          await _db.insertTransaction(transaction);
        }
      }

      if (_selectedReason == ArchiveReason.butchered) {
        final butcherCost = double.tryParse(_costController.text) ?? 0;
        final butcherYield = double.tryParse(_yieldController.text) ?? 0;

        // Create meat harvest income transaction
        if (butcherYield > 0) {
          final transaction = finance.Transaction(
            id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
            type: finance.TransactionType.income,
            category: finance.TransactionCategory.meatHarvest,
            amount: butcherYield, // Yield value (could be multiplied by price per lb)
            date: DateTime.now(),
            description: 'Butchered ${widget.rabbit.name} (${widget.rabbit.id}) - ${butcherYield} lbs',
            linkType: finance.LinkType.rabbit,
            rabbitId: widget.rabbit.id,
          );
          await _db.insertTransaction(transaction);
        }

        // Create processing cost expense if any
        if (butcherCost > 0) {
          final expenseTransaction = finance.Transaction(
            id: 'txn_exp_${DateTime.now().millisecondsSinceEpoch}',
            type: finance.TransactionType.expense,
            category: finance.TransactionCategory.otherExpense,
            amount: butcherCost,
            date: DateTime.now(),
            description: 'Processing cost for ${widget.rabbit.name}',
            linkType: finance.LinkType.rabbit,
            rabbitId: widget.rabbit.id,
          );
          await _db.insertTransaction(expenseTransaction);
        }
      }

      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.rabbit.name} archived successfully'),
          backgroundColor: const Color(0xFF0F7B6C),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error archiving rabbit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
