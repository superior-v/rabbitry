import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/format_utils.dart';
import '../../services/settings_service.dart';
import '../../constants/app_colors.dart';

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
  List<String> _locations = [];
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadBarns();
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
        } catch (_) {}
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
        _selectedLocation = locations.contains(widget.rabbit.location) ? widget.rabbit.location : null;
      });
    }
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

  String _formatRabbitHeader() {
    final prefix = (widget.rabbit.breederPrefix ?? '').trim();
    final name = widget.rabbit.name.trim();
    final ear = (widget.rabbit.earNumber?.trim().isNotEmpty == true
            ? widget.rabbit.earNumber!.trim()
            : widget.rabbit.id.trim())
        .toUpperCase();

    final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
    if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
      return '$namePart $ear';
    }
    return namePart;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7B6BA0),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C2C2E),
            ),
          ),
          child: child!,
        );
      },
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

      await _db.addHealthRecord(
        widget.rabbit.id,
        _selectedType.toLowerCase(),
        _selectedDate,
        _treatmentController.text,
        cost,
        _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (_addToQuarantine) {
        await _db.addToQuarantine(
          widget.rabbit.id,
          _treatmentController.text.isNotEmpty ? _treatmentController.text : 'Health Record Quarantine',
          _quarantineDays,
          cost,
        );

        if (_selectedCage != null && _selectedCage!.isNotEmpty) {
          await _db.moveCage(widget.rabbit.id, _selectedLocation ?? '', _selectedCage!);
        }
      }

      widget.onComplete();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_addToQuarantine ? 'Health record added & moved to quarantine' : 'Health record added'),
          backgroundColor: const Color(0xFF7B6BA0),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding record: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          children: [
            // Top Lilac Header Banner (matches LogBirthModal)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFEADBEE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Health',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A3E6D),
                          letterSpacing: 0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _formatRabbitHeader(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A3E6D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FormatUtils.formatDate(_selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A3E6D),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Inner Lilac Wash Box (compact format)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kLilacWash,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kLilacLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Record Type & Date Picker
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE5DEEC)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedType,
                                    decoration: const InputDecoration(
                                      labelText: 'Type',
                                      labelStyle: TextStyle(color: Color(0xFF4A3E6D), fontWeight: FontWeight.w600, fontSize: 12),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                                    ),
                                    items: _healthTypes.map((type) {
                                      return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) setState(() => _selectedType = value);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: InkWell(
                                  onTap: _selectDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: const Color(0xFFE5DEEC)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF7B6BA0)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            FormatUtils.formatDate(_selectedDate),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2E)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Condition / Issue input (compact)
                          Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              final issues = SettingsService.instance.healthIssues.map((i) => i['name'] ?? '').where((n) => n.isNotEmpty).toList();
                              if (textEditingValue.text.isEmpty) return issues;
                              return issues.where((i) => i.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            fieldViewBuilder: (ctx2, textController, focusNode, onSubmitted) {
                              textController.addListener(() {
                                _treatmentController.text = textController.text;
                              });
                              if (_treatmentController.text.isNotEmpty && textController.text.isEmpty) {
                                textController.text = _treatmentController.text;
                              }
                              return TextFormField(
                                controller: textController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Condition / Treatment',
                                  labelStyle: const TextStyle(color: Color(0xFF4A3E6D), fontWeight: FontWeight.w600, fontSize: 12),
                                  hintText: 'e.g. Snuffles, Nail Trim...',
                                  hintStyle: const TextStyle(fontSize: 12),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a condition or treatment';
                                  }
                                  return null;
                                },
                              );
                            },
                            onSelected: (value) {
                              _treatmentController.text = value;
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(10),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: 180, maxWidth: MediaQuery.of(context).size.width - 60),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        final issues = SettingsService.instance.healthIssues;
                                        final match = issues.firstWhere((i) => i['name'] == option, orElse: () => {});
                                        final treatment = match['treatment'] ?? '';
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(option, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                                if (treatment.isNotEmpty) Text(treatment, style: const TextStyle(fontSize: 11, color: Color(0xFF787774))),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),

                          // Row 3: Cost and Notes in side-by-side or compact layout
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cost input
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _costController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Cost',
                                    labelStyle: const TextStyle(color: Color(0xFF4A3E6D), fontWeight: FontWeight.w600, fontSize: 12),
                                    hintText: '0.00',
                                    prefixText: FormatUtils.currencyPrefix,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Notes input
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: _notesController,
                                  maxLines: 1,
                                  decoration: InputDecoration(
                                    labelText: 'Notes (optional)',
                                    labelStyle: const TextStyle(color: Color(0xFF4A3E6D), fontWeight: FontWeight.w600, fontSize: 12),
                                    hintText: 'Optional details...',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Quarantine toggle card (compact)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _addToQuarantine ? const Color(0xFFFFB300) : const Color(0xFFE5DEEC)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _addToQuarantine,
                                        activeColor: const Color(0xFFFF9800),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: widget.rabbit.status != RabbitStatus.quarantine ? (value) => setState(() => _addToQuarantine = value ?? false) : null,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Move to Quarantine',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2C2C2E),
                                        ),
                                      ),
                                    ),
                                    if (_addToQuarantine)
                                      Text(
                                        '$_quarantineDays days',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF9800)),
                                      ),
                                  ],
                                ),
                                if (_addToQuarantine) ...[
                                  const SizedBox(height: 4),
                                  Slider(
                                    value: _quarantineDays.toDouble(),
                                    min: 1,
                                    max: 30,
                                    divisions: 29,
                                    activeColor: const Color(0xFFFF9800),
                                    onChanged: (value) => setState(() => _quarantineDays = value.toInt()),
                                  ),
                                  Row(
                                    children: [
                                      if (_locations.isNotEmpty)
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedLocation,
                                            decoration: InputDecoration(
                                              labelText: 'Location',
                                              isDense: true,
                                              filled: true,
                                              fillColor: kLilacWash,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DEEC))),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            ),
                                            items: _locations.map((location) {
                                              return DropdownMenuItem(value: location, child: Text(location, style: const TextStyle(fontSize: 12)));
                                            }).toList(),
                                            onChanged: (value) => setState(() => _selectedLocation = value),
                                          ),
                                        ),
                                      if (_locations.isNotEmpty) const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: _selectedCage,
                                          decoration: InputDecoration(
                                            labelText: 'Cage ID',
                                            hintText: 'Quarantine-1',
                                            isDense: true,
                                            filled: true,
                                            fillColor: kLilacWash,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DEEC))),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          ),
                                          onChanged: (value) => _selectedCage = value,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Full Width Purple Save Button (prominent & visible)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveRecord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B6BA0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Health Record',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
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
