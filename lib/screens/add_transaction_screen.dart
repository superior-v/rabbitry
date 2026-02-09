import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../services/database_service.dart';

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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Transaction' : 'New Transaction',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
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
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(12),
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
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _type == TransactionType.income ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: _type == TransactionType.income ? Border.all(color: Color(0xFF0F7B6C), width: 2) : null,
                ),
                child: Center(
                  child: Text(
                    'Income',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _type == TransactionType.income ? Color(0xFF0F7B6C) : Color(0xFF787774),
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
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _type == TransactionType.expense ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: _type == TransactionType.expense ? Border.all(color: Color(0xFFDC2626), width: 2) : null,
                ),
                child: Center(
                  child: Text(
                    'Expense',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _type == TransactionType.expense ? Color(0xFFDC2626) : Color(0xFF787774),
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
        Text(
          'ENTRY MODE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF7F7F5),
            borderRadius: BorderRadius.circular(12),
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
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: Color(0xFF0F7B6C)) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF787774),
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
        Text(
          'CATEGORY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFFE9E9E7)),
            borderRadius: BorderRadius.circular(12),
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
        Text(
          'LINK TO',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF7F7F5),
            borderRadius: BorderRadius.circular(12),
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
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: Color(0xFF0F7B6C)) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF787774),
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
        Text(
          'SELECT RABBIT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFFE9E9E7)),
            borderRadius: BorderRadius.circular(12),
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
        Text(
          'SELECT LITTER',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFFE9E9E7)),
            borderRadius: BorderRadius.circular(12),
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
        color: Color(0xFFE8F5F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF0F7B6C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT KITS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F7B6C),
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
        Text(
          'AMOUNT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        if (_entryMode == EntryMode.wholeLitter && _selectedKits.isNotEmpty) _buildAmountToggle(),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _type == TransactionType.income ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _type == TransactionType.income ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
                width: 2,
              ),
            ),
          ),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _type == TransactionType.income ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
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
                  border: _usePerItem ? Border.all(color: Color(0xFF0F7B6C)) : null,
                ),
                child: Center(
                  child: Text(
                    'Per Item',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _usePerItem ? FontWeight.w600 : FontWeight.w500,
                      color: _usePerItem ? Color(0xFF0F7B6C) : Color(0xFF787774),
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
                  border: !_usePerItem ? Border.all(color: Color(0xFF0F7B6C)) : null,
                ),
                child: Center(
                  child: Text(
                    'Total Split',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: !_usePerItem ? FontWeight.w600 : FontWeight.w500,
                      color: !_usePerItem ? Color(0xFF0F7B6C) : Color(0xFF787774),
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
        Text(
          'DATE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFE9E9E7)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF787774), size: 20),
                SizedBox(width: 12),
                Text(
                  DateFormat('MMMM d, yyyy').format(_date),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right, color: Color(0xFF787774)),
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
        Text(
          'DESCRIPTION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: 'e.g., Kit #1 - Black Otter, Buck',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTES (optional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9B9A97),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Additional notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveTransaction,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        _isEditing ? 'Update Transaction' : 'Save Transaction',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
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
