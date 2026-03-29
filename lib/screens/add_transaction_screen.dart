import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';

enum EntryMode {
  single,
  multiple,
  wholeLitter,
}

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({this.transaction});

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  // Form state
  TransactionType _type = TransactionType.income;
  EntryMode _entryMode = EntryMode.single;
  TransactionCategory? _category;
  LinkType _linkType = LinkType.general;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _date = DateTime.now();
  String? _selectedRabbitId;
  String? _selectedLitterId;

  // For kit sales
  List<Map<String, dynamic>> _selectedKits = [];
  bool _usePerItem = true;

  // Data lists
  List<Rabbit> _rabbits = [];
  List<Litter> _litters = [];
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.transaction != null;
    _loadData();

    if (_isEditing) {
      _populateForm();
    }
  }

  void _populateForm() {
    final t = widget.transaction!;
    _type = t.type;
    _category = t.category;
    _linkType = t.linkType;
    _amountController.text = t.amount.toStringAsFixed(2);
    _descriptionController.text = t.description ?? '';
    _notesController.text = t.notes ?? '';
    _date = t.date;
    _selectedRabbitId = t.rabbitId;
    _selectedLitterId = t.litterId;
  }

  Future<void> _loadData() async {
    try {
      final rabbits = await _db.getAllRabbits();
      final litters = await _db.getLitters();

      setState(() {
        _rabbits = rabbits.where((r) => r.status != RabbitStatus.archived).toList();
        _litters = litters;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<TransactionCategory> get _availableCategories {
    if (_type == TransactionType.income) {
      return Transaction.incomeCategories;
    } else {
      return Transaction.expenseCategories;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kLilacWash,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: kLilacText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Transaction' : 'New Transaction',
          style: const TextStyle(
            color: kLilacText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Income/Expense toggle
                  _buildTypeToggle(),
                  SizedBox(height: 24),

                  // Entry mode (for income only)
                  if (_type == TransactionType.income && _category == TransactionCategory.soldKit) ...[
                    _buildEntryModeSelector(),
                    SizedBox(height: 24),
                  ],

                  // Category dropdown
                  _buildCategoryDropdown(),
                  SizedBox(height: 16),

                  // Link type selector
                  _buildLinkTypeSelector(),
                  SizedBox(height: 16),

                  // Rabbit/Litter selector based on link type
                  if (_linkType == LinkType.rabbit) _buildRabbitSelector(),
                  if (_linkType == LinkType.litter) _buildLitterSelector(),

                  SizedBox(height: 16),

                  // Kit selector for whole litter mode
                  if (_entryMode == EntryMode.wholeLitter && _selectedLitterId != null) _buildKitSelector(),

                  // Amount field
                  _buildAmountField(),
                  SizedBox(height: 16),

                  // Date picker
                  _buildDatePicker(),
                  SizedBox(height: 16),

                  // Description
                  _buildDescriptionField(),
                  SizedBox(height: 16),

                  // Notes
                  _buildNotesField(),
                  SizedBox(height: 32),

                  // Save button
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kNeutral100,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: kNeutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _type = TransactionType.income;
                _category = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _type == TransactionType.income ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: _type == TransactionType.income 
                    ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
                ),
                child: Center(
                  child: Text(
                    'Income',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _type == TransactionType.income ? kBlueDeep : kNeutral500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _type = TransactionType.expense;
                _category = null;
                _entryMode = EntryMode.single;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _type == TransactionType.expense ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: _type == TransactionType.expense 
                    ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
                ),
                child: Center(
                  child: Text(
                    'Expense',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _type == TransactionType.expense ? kPinkDeep : kNeutral500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ENTRY MODE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kNeutral100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kNeutral200),
          ),
          child: Row(
            children: [
              _buildModeChip(EntryMode.single, 'Single'),
              _buildModeChip(EntryMode.multiple, 'Multiple'),
              _buildModeChip(EntryMode.wholeLitter, 'Whole Litter'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(EntryMode mode, String label) {
    final isSelected = _entryMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _entryMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected 
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
            border: Border.all(color: isSelected ? kLilacLight : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? kLilacDeep : kNeutral500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kNeutral300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonFormField<TransactionCategory>(
            value: _category,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: Text('Select category'),
            items: _availableCategories.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(
                  Transaction(
                    id: '',
                    type: _type,
                    category: cat,
                    amount: 0,
                    date: DateTime.now(),
                  ).categoryName,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _category = value;
                if (value == TransactionCategory.soldKit) {
                  _linkType = LinkType.rabbit;
                }
              });
            },
            validator: (value) => value == null ? 'Please select a category' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LINK TO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kNeutral100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kNeutral200),
          ),
          child: Row(
            children: [
              _buildLinkTypeChip(LinkType.general, 'General'),
              _buildLinkTypeChip(LinkType.rabbit, 'Rabbit'),
              _buildLinkTypeChip(LinkType.litter, 'Litter'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkTypeChip(LinkType type, String label) {
    final isSelected = _linkType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _linkType = type;
          _selectedRabbitId = null;
          _selectedLitterId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
            border: Border.all(color: isSelected ? kLilacLight : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? kLilacDeep : kNeutral500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRabbitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT RABBIT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kNeutral300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRabbitId,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: Text('Select rabbit'),
            items: _rabbits.map((rabbit) {
              return DropdownMenuItem(
                value: rabbit.id,
                child: Text('${rabbit.name} (${rabbit.id})'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedRabbitId = value),
          ),
        ),
      ],
    );
  }

  Widget _buildLitterSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT LITTER',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kNeutral300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedLitterId,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: Text('Select litter'),
            items: _litters.map((litter) {
              final dam = _rabbits.firstWhere(
                (r) => r.id == litter.doeId,
                orElse: () => Rabbit(id: '', name: 'Unknown', type: RabbitType.doe, status: RabbitStatus.open, breed: ''),
              );
              return DropdownMenuItem(
                value: litter.id,
                child: Text('${litter.id} - ${dam.name}'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedLitterId = value),
          ),
        ),
      ],
    );
  }

  Widget _buildKitSelector() {
    // Placeholder for kit selection from litter
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF6366F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT KITS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6366F1),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Kit selection for whole litter entry will be implemented.',
            style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AMOUNT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (_entryMode == EntryMode.wholeLitter && _selectedKits.isNotEmpty) _buildAmountToggle(),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '${FormatUtils.currencySymbol} ',
            prefixStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _type == TransactionType.income ? kBlueDeep : kPinkDeep,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kNeutral300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kNeutral300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _type == TransactionType.income ? kBlueDeep : kPinkDeep,
                width: 2,
              ),
            ),
          ),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _type == TransactionType.income ? kBlueDeep : kPinkDeep,
            letterSpacing: -0.5,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAmountToggle() {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _usePerItem = true),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _usePerItem ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _usePerItem ? Border.all(color: Color(0xFF6366F1)) : null,
                ),
                child: Center(
                  child: Text(
                    'Per Item',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _usePerItem ? FontWeight.w600 : FontWeight.w500,
                      color: _usePerItem ? Color(0xFF6366F1) : Color(0xFF787774),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _usePerItem = false),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_usePerItem ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: !_usePerItem ? Border.all(color: Color(0xFF6366F1)) : null,
                ),
                child: Center(
                  child: Text(
                    'Total Split',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: !_usePerItem ? FontWeight.w600 : FontWeight.w500,
                      color: !_usePerItem ? Color(0xFF6366F1) : Color(0xFF787774),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DATE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: kNeutral300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), color: kNeutral600, size: 20),
                const SizedBox(width: 12),
                Text(
                  FormatUtils.formatDateLong(_date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kNeutral900,
                  ),
                ),
                const Spacer(),
                Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), color: kNeutral400, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DESCRIPTION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: 'e.g., Kit #1 - Black Otter, Buck',
            hintStyle: const TextStyle(color: kNeutral400, fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kNeutral300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kNeutral300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kLilacLight, width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTES (optional)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: kNeutral500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Additional notes...',
            hintStyle: const TextStyle(color: kNeutral400, fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kNeutral300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kNeutral300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kLilacLight, width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kLilacDeep.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveTransaction,
        style: ElevatedButton.styleFrom(
          backgroundColor: kLilacDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _isEditing ? 'Update Transaction' : 'Save Transaction',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text);

      final transaction = Transaction(
        id: _isEditing ? widget.transaction!.id : 'txn_${DateTime.now().millisecondsSinceEpoch}',
        type: _type,
        category: _category!,
        amount: amount,
        date: _date,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        linkType: _linkType,
        rabbitId: _selectedRabbitId,
        litterId: _selectedLitterId,
      );

      if (_isEditing) {
        await _db.updateTransaction(transaction);
      } else {
        await _db.insertTransaction(transaction);
      }

      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving transaction: $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
