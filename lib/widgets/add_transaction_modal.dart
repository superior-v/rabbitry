import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_transaction.dart';
import '../models/rabbit.dart';
import '../constants/finance_categories.dart';

class AddTransactionModal extends StatefulWidget {
  final Function(FinanceTransaction) onAdd;
  final List<Rabbit> rabbits;

  const AddTransactionModal({
    Key? key,
    required this.onAdd,
    required this.rabbits,
  }) : super(key: key);

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  TransactionType selectedType = TransactionType.expense;
  String? selectedCategory;
  TransactionContext selectedContext = TransactionContext.general;
  String? selectedRabbit;
  String? selectedLitter;
  DateTime selectedDate = DateTime.now();
  bool isVirtual = false;
  bool enableBatch = false;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController entityController = TextEditingController();

  List<TransactionCategory> get availableCategories {
    return FinanceCategories.getByType(selectedType);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Divider(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                _buildTypeSelector(),
                SizedBox(height: 20),
                _buildCategoryGrid(),
                SizedBox(height: 20),
                _buildAmountField(),
                SizedBox(height: 20),
                _buildDatePicker(),
                SizedBox(height: 20),
                _buildContextSelector(),
                if (selectedContext != TransactionContext.general) ...[
                  SizedBox(height: 20),
                  _buildEntitySelector(),
                ],
                SizedBox(height: 20),
                _buildNotesField(),
                SizedBox(height: 20),
                _buildVirtualToggle(),
                if (selectedType == TransactionType.income &&
                    selectedContext == TransactionContext.kit) ...[
                  SizedBox(height: 20),
                  _buildBatchToggle(),
                ],
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'New Transaction',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSACTION TYPE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                'Income',
                Icons.add_circle,
                TransactionType.income,
                Color(0xFF2F855A),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildTypeButton(
                'Expense',
                Icons.remove_circle,
                TransactionType.expense,
                Color(0xFFC53030),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton(String label, IconData icon, TransactionType type, Color color) {
    bool isSelected = selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedType = type;
          selectedCategory = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Color(0xFFE9E9E7),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Color(0xFF787774), size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: availableCategories.length,
          itemBuilder: (context, index) {
            final category = availableCategories[index];
            bool isSelected = selectedCategory == category.key;
            final color = selectedType == TransactionType.income
                ? Color(0xFF2F855A)
                : Color(0xFFC53030);

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategory = category.key;
                  if (category.isVirtual) {
                    isVirtual = true;
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Color(0xFFF7F7F5),
                  border: Border.all(
                    color: isSelected ? color : Color(0xFFE9E9E7),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getCategoryIcon(category.icon),
                      color: isSelected ? color : Color(0xFF787774),
                      size: 28,
                    ),
                    SizedBox(height: 6),
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? color : Color(0xFF37352F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AMOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.attach_money, color: Color(0xFF787774)),
            hintText: '0.00',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Color(0xFF0F7B6C),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                selectedDate = picked;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFE9E9E7)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF787774), size: 20),
                SizedBox(width: 12),
                Text(
                  DateFormat('MMMM d, yyyy').format(selectedDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF37352F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContextSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LINK TO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildContextChip('General', Icons.home, TransactionContext.general),
            _buildContextChip('Rabbit', Icons.pets, TransactionContext.rabbit),
            _buildContextChip('Litter', Icons.account_tree, TransactionContext.litter),
            _buildContextChip('Kit', Icons.sell, TransactionContext.kit),
          ],
        ),
      ],
    );
  }

  Widget _buildContextChip(String label, IconData icon, TransactionContext context) {
    bool isSelected = selectedContext == context;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedContext = context;
          selectedRabbit = null;
          selectedLitter = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFE8F5F3) : Color(0xFFF7F7F5),
          border: Border.all(
            color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFE9E9E7),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF787774),
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedContext == TransactionContext.rabbit ? 'SELECT RABBIT' :
          selectedContext == TransactionContext.litter ? 'SELECT LITTER' :
          'SELECT KIT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedRabbit,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          hint: Text('Select...'),
          items: widget.rabbits.map((rabbit) {
            return DropdownMenuItem(
              value: rabbit.id,
              child: Text('${rabbit.name} (${rabbit.id})'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedRabbit = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTES (OPTIONAL)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVirtualToggle() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Virtual Transaction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track value without affecting balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF787774),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isVirtual,
            onChanged: (value) {
              setState(() {
                isVirtual = value;
              });
            },
            activeColor: Color(0xFF0F7B6C),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchToggle() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFE8F5F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.layers, size: 16, color: Color(0xFF0F7B6C)),
                    SizedBox(width: 6),
                    Text(
                      'Batch Entry',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F7B6C),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Apply to all kits in litter',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF787774),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enableBatch,
            onChanged: (value) {
              setState(() {
                enableBatch = value;
              });
            },
            activeColor: Color(0xFF0F7B6C),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    bool canSave = selectedCategory != null && amountController.text.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE9E9E7))),
        color: Color(0xFFF7F7F5),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Color(0xFFE9E9E7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37352F),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: canSave ? _saveTransaction : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0F7B6C),
                disabledBackgroundColor: Color(0xFFE9E9E7),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add Transaction',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveTransaction() {
    if (selectedCategory == null || amountController.text.isEmpty) return;

    final transaction = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: selectedDate,
      type: selectedType,
      category: selectedCategory!,
      amount: double.parse(amountController.text),
      context: selectedContext,
      entity: selectedContext == TransactionContext.general
          ? 'General Herd'
          : 'Entity Name', // Get from selected rabbit/litter/kit
      entityId: selectedRabbit ?? 'GEN',
      litterId: selectedLitter,
      sub: notesController.text.isNotEmpty ? notesController.text : null,
      batchId: enableBatch ? 'B${DateTime.now().millisecondsSinceEpoch}' : null,
      isVirtual: isVirtual,
    );

    widget.onAdd(transaction);
    Navigator.pop(context);
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'sell': return Icons.sell;
      case 'restaurant': return Icons.restaurant;
      case 'male': return Icons.male;
      case 'person_remove': return Icons.person_remove;
      case 'grass': return Icons.grass;
      case 'paid': return Icons.paid;
      case 'grain': return Icons.grain;
      case 'medical_services': return Icons.medical_services;
      case 'build': return Icons.build;
      case 'emoji_events': return Icons.emoji_events;
      case 'forest': return Icons.forest;
      case 'local_hospital': return Icons.local_hospital;
      case 'inventory_2': return Icons.inventory_2;
      default: return Icons.receipt;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    entityController.dispose();
    super.dispose();
  }
}