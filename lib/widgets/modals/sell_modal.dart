import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';

class SellModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const SellModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SellModal> createState() => _SellModalState();
}

class _SellModalState extends State<SellModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _buyerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _saleDate = DateTime.now();
  bool _addToLedger = true;
  bool _generatePedigree = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sell Rabbit',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '${widget.rabbit.name} (${widget.rabbit.id})',
                style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
              ),
              SizedBox(height: 24),

              // Sale Date
              Text(
                'Sale Date',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Color(0xFF787774)),
                      SizedBox(width: 12),
                      Text('${_saleDate.day}/${_saleDate.month}/${_saleDate.year}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Sale Price
              Text(
                'Sale Price',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 20),

              // Buyer Info
              Text(
                'Buyer Information (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _buyerController,
                decoration: InputDecoration(
                  hintText: 'Buyer name, contact, etc.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 20),

              // Notes
              Text(
                'Notes (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Additional notes...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 20),

              // Options
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Add to Ledger
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add to Sales Ledger',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        Switch(
                          value: _addToLedger,
                          onChanged: (value) => setState(() => _addToLedger = value),
                          activeColor: Color(0xFF0F7B6C),
                        ),
                      ],
                    ),
                    Divider(),
                    // Generate Pedigree
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Generate Pedigree for Buyer',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        Switch(
                          value: _generatePedigree,
                          onChanged: (value) => setState(() => _generatePedigree = value),
                          activeColor: Color(0xFF0F7B6C),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0F7B6C),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Complete Sale',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _saleDate = picked);
    }
  }

  Future<void> _saveSale() async {
    final price = double.tryParse(_priceController.text);

    setState(() => _isSaving = true);

    try {
      await _db.archiveRabbit(
        widget.rabbit.id,
        ArchiveReason.sold,
        _notesController.text.isEmpty ? null : _notesController.text,
        price,
        _buyerController.text.isEmpty ? null : _buyerController.text,
      );

      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.rabbit.name} sold${price != null ? " for \$${price.toStringAsFixed(2)}" : ""}'),
          backgroundColor: Color(0xFF0F7B6C),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
