import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';

class QuarantineModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const QuarantineModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<QuarantineModal> createState() => _QuarantineModalState();
}

class _QuarantineModalState extends State<QuarantineModal> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _expenseController = TextEditingController();
  final _cageController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  int _quarantineDays = 14;
  bool _isLoading = false;
  String? _selectedLocation;
  List<String> _locations = []; // List of row names

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

  final List<Map<String, dynamic>> _presetReasons = [
    {
      'label': 'New rabbit',
      'days': 14
    },
    {
      'label': 'Illness/Treatment',
      'days': 7
    },
    {
      'label': 'Post-surgery recovery',
      'days': 14
    },
    {
      'label': 'Injury',
      'days': 10
    },
    {
      'label': 'Observation',
      'days': 7
    },
    {
      'label': 'Other',
      'days': 14
    },
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _expenseController.dispose();
    _cageController.dispose();
    super.dispose();
  }

  Future<void> _saveQuarantine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final expense = _expenseController.text.isNotEmpty ? double.tryParse(_expenseController.text) : null;

      // Fixed: Use correct number of arguments (4 not 5)
      await _db.addToQuarantine(
        widget.rabbit.id,
        _reasonController.text,
        _quarantineDays,
        expense,
      );

      // Move cage if specified
      if (_cageController.text.isNotEmpty || _selectedLocation != null) {
        await _db.moveCage(
          widget.rabbit.id,
          _selectedLocation ?? '',
          _cageController.text,
        );
      }

      widget.onComplete();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.rabbit.name} added to quarantine for $_quarantineDays days'),
          backgroundColor: Color(0xFF0F7B6C),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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
                        color: Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.shield,
                        color: Color(0xFFFF9800),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to Quarantine',
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

                // Warning banner
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF8E1),
                    border: Border.all(color: Color(0xFFFFB300)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Color(0xFFFF8F00), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Quarantine isolates the rabbit from the herd for health monitoring.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Preset reasons
                Text(
                  'Reason',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetReasons.map((preset) {
                    final isSelected = _reasonController.text == preset['label'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _reasonController.text = preset['label'];
                          _quarantineDays = preset['days'];
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Color(0xFFFF9800).withOpacity(0.1) : Colors.white,
                          border: Border.all(
                            color: isSelected ? Color(0xFFFF9800) : Color(0xFFE9E9E7),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          preset['label'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Color(0xFFFF9800) : Color(0xFF787774),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),

                // Reason input
                TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter reason or select above',
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
                      borderSide: BorderSide(color: Color(0xFFFF9800), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a reason';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Duration slider
                Text(
                  'Duration: $_quarantineDays days',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                Slider(
                  value: _quarantineDays.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: Color(0xFFFF9800),
                  inactiveColor: Color(0xFFE9E9E7),
                  label: '$_quarantineDays days',
                  onChanged: (value) {
                    setState(() => _quarantineDays = value.toInt());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 day', style: TextStyle(fontSize: 12, color: Color(0xFF9B9A97))),
                    Text('30 days', style: TextStyle(fontSize: 12, color: Color(0xFF9B9A97))),
                  ],
                ),
                SizedBox(height: 20),

                // Quarantine Cage Selection
                Text(
                  'Move to Quarantine Cage',
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
                    value: _selectedLocation,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      hintText: 'Select location',
                    ),
                    items: _locations.map((location) {
                      return DropdownMenuItem(
                        value: location,
                        child: Text(location),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedLocation = value),
                  ),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _cageController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Quarantine-1, Isolation Cage',
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
                      borderSide: BorderSide(color: Color(0xFFFF9800), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Expense input
                Text(
                  'Related Expense (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _expenseController,
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
                      borderSide: BorderSide(color: Color(0xFFFF9800), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveQuarantine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF9800),
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
                            'Add to Quarantine',
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
