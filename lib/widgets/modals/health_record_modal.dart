import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';

class HealthRecordModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const HealthRecordModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<HealthRecordModal> createState() => _HealthRecordModalState();
}

class _HealthRecordModalState extends State<HealthRecordModal> {
  final _formKey = GlobalKey<FormState>();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();
  final _costController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'Treatment';
  bool _isLoading = false;
  bool _addToQuarantine = false;
  int _quarantineDays = 14;
  String? _selectedCage;
  List<String> _locations = []; // List of row names
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadBarns();
  }

  Future<void> _loadBarns() async {
    final barns = await _db.getAllBarns();
    // Extract all row names from barns as location options
    List<String> locations = [];
    for (var barn in barns) {
      final rowsRaw = barn['rows'];
      List<dynamic> rows = [];
      if (rowsRaw is String && rowsRaw.isNotEmpty) {
        try {
          rows = jsonDecode(rowsRaw) as List<dynamic>;
        } catch (e) {
          print('Error decoding barn rows: $e');
        }
      } else if (rowsRaw is List) {
        rows = rowsRaw;
      }
      for (var row in rows) {
        if (row is Map) {
          final rowName = row['name'] as String?;
          if (rowName != null && !locations.contains(rowName)) {
            locations.add(rowName);
          }
        }
      }
    }

    setState(() {
      _locations = locations;
      // Only set location if it exists in the list
      _selectedLocation = locations.contains(widget.rabbit.location) ? widget.rabbit.location : null;
    });
  }

  final List<String> _healthTypes = [
    'Treatment',
    'Vaccination',
    'Medication',
    'Injury',
    'Illness',
    'Check-up',
    'Other',
  ];

  @override
  void dispose() {
    _treatmentController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final cost = _costController.text.isNotEmpty ? double.tryParse(_costController.text) : null;

      // Use addHealthRecord instead of insertHealthRecord
      await _db.addHealthRecord(
        widget.rabbit.id,
        _selectedType.toLowerCase(),
        _selectedDate,
        _treatmentController.text,
        cost,
        _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Add to quarantine if checkbox is checked
      if (_addToQuarantine) {
        await _db.addToQuarantine(
          widget.rabbit.id,
          _treatmentController.text,
          _quarantineDays,
          cost,
        );

        // Move cage if selected
        if (_selectedCage != null && _selectedCage!.isNotEmpty) {
          await _db.moveCage(widget.rabbit.id, _selectedLocation ?? '', _selectedCage!);
        }
      }

      widget.onComplete();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_addToQuarantine ? 'Health record added & moved to quarantine' : 'Health record added'),
          backgroundColor: Color(0xFF0F7B6C),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding record: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(0xFFE91E63).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.medical_services,
                        color: Color(0xFFE91E63),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health Record',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.rabbit.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF787774),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Type selector
                Text(
                  'Record Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    items: _healthTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedType = value);
                    },
                  ),
                ),
                SizedBox(height: 16),

                // Date selector
                Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFE9E9E7)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20, color: Color(0xFF787774)),
                        SizedBox(width: 12),
                        Text(
                          '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                          style: TextStyle(fontSize: 16),
                        ),
                        Spacer(),
                        Icon(Icons.chevron_right, color: Color(0xFF787774)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Treatment/Description input
                Text(
                  'Treatment/Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _treatmentController,
                  decoration: InputDecoration(
                    hintText: 'Enter treatment or description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Cost input
                Text(
                  'Cost (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Notes input
                Text(
                  'Notes (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any additional notes...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Quarantine checkbox
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF8E1),
                    border: Border.all(color: Color(0xFFFFB300)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _addToQuarantine,
                            activeColor: Color(0xFFFF9800),
                            onChanged: widget.rabbit.status != RabbitStatus.quarantine ? (value) => setState(() => _addToQuarantine = value ?? false) : null,
                          ),
                          Expanded(
                            child: Text(
                              'Add to Quarantine',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF37352F),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_addToQuarantine) ...[
                        SizedBox(height: 12),
                        Text(
                          'Quarantine Duration: $_quarantineDays days',
                          style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
                        ),
                        Slider(
                          value: _quarantineDays.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          activeColor: Color(0xFFFF9800),
                          onChanged: (value) => setState(() => _quarantineDays = value.toInt()),
                        ),
                        SizedBox(height: 8),
                        // Cage selection for quarantine
                        DropdownButtonFormField<String>(
                          value: _selectedLocation,
                          decoration: InputDecoration(
                            labelText: 'Move to Location',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: _locations.map((location) {
                            return DropdownMenuItem(
                              value: location,
                              child: Text(location),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedLocation = value),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          initialValue: _selectedCage,
                          decoration: InputDecoration(
                            labelText: 'Cage / Hutch ID',
                            hintText: 'e.g., Quarantine-1',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (value) => _selectedCage = value,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveRecord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0F7B6C),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Save Record',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
