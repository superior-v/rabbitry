import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../constants/app_colors.dart';

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
  final _cageController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  int _quarantineDays = 14;
  bool _isLoading = false;
  String? _selectedLocation;
  List<String> _locations = [];

  String? _selectedReason = 'New rabbit';
  bool _isEnteringCustom = false;

  final List<String> _reasonOptions = [
    'New rabbit',
    'Illness/Treatment',
    'Post-surgery recovery',
    'Injury',
    'Observation',
    'Other',
    '+ Custom',
  ];

  final Map<String, int> _reasonDaysMap = {
    'New rabbit': 14,
    'Illness/Treatment': 7,
    'Post-surgery recovery': 14,
    'Injury': 10,
    'Observation': 7,
    'Other': 14,
  };

  @override
  void initState() {
    super.initState();
    _loadBarns();
    _selectedReason = 'New rabbit';
    _reasonController.text = 'New rabbit';
    _quarantineDays = 14;
  }

  Future<void> _loadBarns() async {
    final barns = await _db.getAllBarns();
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

    if (mounted) {
      setState(() {
        _locations = locations;
        _selectedLocation = null;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _cageController.dispose();
    super.dispose();
  }

  Future<void> _saveQuarantine() async {
    if (!_formKey.currentState!.validate()) return;

    final reason = _isEnteringCustom ? _reasonController.text.trim() : (_selectedReason ?? _reasonController.text.trim());
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a reason'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _db.addToQuarantine(
        widget.rabbit.id,
        reason,
        _quarantineDays,
        null, // Related expenses option removed per specification
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
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.rabbit.name} added to quarantine for $_quarantineDays days'),
            backgroundColor: const Color(0xFF7B6BA0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRabbitHeaderWidget() {
    final isDoe = widget.rabbit.type == RabbitType.doe;
    final isArchived = widget.rabbit.status == RabbitStatus.archived;
    final nameColor = isDoe
        ? (isArchived ? const Color(0xFFF48FB1) : const Color(0xFFE04F9F))
        : (isArchived ? const Color(0xFF80BFFF) : const Color(0xFF2196F3));
    final prefix = (widget.rabbit.breederPrefix ?? '').trim();
    final name = widget.rabbit.name.trim();
    final ear = (widget.rabbit.earNumber?.trim().isNotEmpty == true
            ? widget.rabbit.earNumber!.trim()
            : (widget.rabbit.id.length >= 6 ? widget.rabbit.id.substring(0, 6) : widget.rabbit.id).trim())
        .toUpperCase();

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: '$prefix ',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF787774),
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: nameColor,
            ),
          ),
          if (ear.isNotEmpty && !name.toUpperCase().endsWith(ear))
            TextSpan(
              text: ' $ear',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF787774),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Lilac Header Banner (matches Consistency.jpg)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFEEDAFE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A3E6D).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add to Quarantine',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C2C2E),
                          letterSpacing: 0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Color(0xFF2C2C2E), size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildRabbitHeaderWidget(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reason Dropdown / Custom field matching Consistency.jpg pattern
                    if (!_isEnteringCustom) ...[
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Reason',
                          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: (_selectedReason == '+ Custom' || !_reasonOptions.contains(_selectedReason)) ? null : _selectedReason,
                            hint: const Text('Select quarantine reason', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF787774))),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
                            selectedItemBuilder: (BuildContext context) {
                              return _reasonOptions.map((e) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  e,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: e == '+ Custom' ? FontStyle.italic : FontStyle.normal,
                                    color: e == '+ Custom' ? const Color(0xFF8B5CF6) : const Color(0xFF4F4F56),
                                  ),
                                ),
                              )).toList();
                            },
                            items: _reasonOptions.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final e = entry.value;
                              final isAlt = idx % 2 == 1;
                              return DropdownMenuItem(
                                value: e,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isAlt ? const Color(0xFFF6F0FD) : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    e,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: e == '+ Custom' ? FontStyle.italic : FontStyle.normal,
                                      color: e == '+ Custom' ? const Color(0xFF8B5CF6) : const Color(0xFF4F4F56),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == '+ Custom') {
                                setState(() {
                                  _isEnteringCustom = true;
                                  _selectedReason = null;
                                  _reasonController.clear();
                                });
                              } else {
                                setState(() {
                                  _selectedReason = val;
                                  _reasonController.text = val ?? '';
                                  if (val != null && _reasonDaysMap.containsKey(val)) {
                                    _quarantineDays = _reasonDaysMap[val]!;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEnteringCustom = false;
                                _selectedReason = _reasonOptions.firstWhere((e) => e != '+ Custom', orElse: () => 'New rabbit');
                                _reasonController.text = _selectedReason!;
                                _quarantineDays = _reasonDaysMap[_selectedReason] ?? 14;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Choose from list',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _reasonController,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                        decoration: InputDecoration(
                          labelText: 'Reason',
                          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a reason';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Duration Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF37352F),
                          ),
                        ),
                        Text(
                          '$_quarantineDays days',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7B6BA0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      value: _quarantineDays.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: const Color(0xFF7B6BA0),
                      inactiveColor: const Color(0xFFEADBEE),
                      label: '$_quarantineDays days',
                      onChanged: (value) {
                        setState(() => _quarantineDays = value.toInt());
                      },
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 day', style: TextStyle(fontSize: 12, color: Color(0xFF9B9A97))),
                        Text('30 days', style: TextStyle(fontSize: 12, color: Color(0xFF9B9A97))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quarantine Cage Selection
                    const Text(
                      'Move to Quarantine Cage',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF37352F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _locations.map((location) {
                        return DropdownMenuItem(
                          value: location,
                          child: Text(location, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56))),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedLocation = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cageController,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                      decoration: InputDecoration(
                        labelText: 'Cage / Pen',
                        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveQuarantine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6BEFE),
                          foregroundColor: const Color(0xFF4A3E6D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A3E6D)),
                                ),
                              )
                            : const Text(
                                'Add to Quarantine',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A3E6D),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
