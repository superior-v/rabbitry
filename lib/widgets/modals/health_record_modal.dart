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
  final _cageController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'Treatment';
  bool _isLoading = false;
  bool _addToQuarantine = false;
  int _quarantineDays = 14;
  List<String> _locations = [];
  String? _selectedLocation;
  Rabbit? _buck;
  String? _buckName;

  @override
  void initState() {
    super.initState();
    _loadBarns();
    _loadBuck();
  }

  void _loadBuck() {
    if (widget.rabbit.lastBreedBuckId != null && widget.rabbit.lastBreedBuckId!.isNotEmpty) {
      _db.getRabbit(widget.rabbit.lastBreedBuckId!).then((buck) {
        if (buck != null && mounted) {
          setState(() {
            _buck = buck;
            _buckName = buck.fullName.isNotEmpty ? buck.fullName : buck.name;
          });
        }
      });
    }
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
    _cageController.dispose();
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

  String _formatBuckHeader() {
    if (_buck != null) {
      final prefix = (_buck!.breederPrefix ?? '').trim();
      final name = _buck!.name.trim();
      final ear = (_buck!.earNumber?.trim().isNotEmpty == true
              ? _buck!.earNumber!.trim()
              : _buck!.id.trim())
          .toUpperCase();
      final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
      if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
        return '$namePart $ear';
      }
      return namePart;
    }

    final fallbackName = (_buckName ?? widget.rabbit.lastBreedBuckId ?? '').trim();
    final buckId = (widget.rabbit.lastBreedBuckId ?? '').trim();
    if (buckId.isNotEmpty && !fallbackName.toUpperCase().contains(buckId.toUpperCase())) {
      return '$fallbackName ${buckId.toUpperCase()}';
    }
    return fallbackName;
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

        if (_cageController.text.isNotEmpty || _selectedLocation != null) {
          await _db.moveCage(widget.rabbit.id, _selectedLocation ?? '', _cageController.text);
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

  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    String? prefixText,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    Color textColor = const Color(0xFF3A3A3C),
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF4F4F56), size: 18) : null,
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7B6BA0)),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    Color textColor = const Color(0xFF3A3A3C),
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F4F56), size: 18),
            const SizedBox(width: 8),
            Text(
              FormatUtils.formatDate(value),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBreedingBuck = widget.rabbit.lastBreedBuckId != null && widget.rabbit.lastBreedBuckId!.isNotEmpty;

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A3E6D),
                          letterSpacing: 0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatRabbitHeader(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A3E6D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasBreedingBuck) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formatBuckHeader(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A3E6D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 42),
                          child: Text(
                            FormatUtils.formatDate(_selectedDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A3E6D),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Inner Lilac Wash Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: kLilacWash,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kLilacLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Record Type Dropdown & Date Picker
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedType,
                                  decoration: InputDecoration(
                                    labelText: 'Type',
                                    labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                                    floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
                                  items: _healthTypes.map((type) {
                                    return DropdownMenuItem(value: type, child: Text(type));
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) setState(() => _selectedType = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: _buildDatePickerField(
                                  label: 'Date',
                                  value: _selectedDate,
                                  onTap: _selectDate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Condition / Issue input with autocomplete
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
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
                                decoration: InputDecoration(
                                  labelText: 'Condition / Treatment',
                                  labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                                  floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
                                  hintText: 'e.g. Snuffles, Nail Trim...',
                                  hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kLilacLight),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                                  borderRadius: BorderRadius.circular(12),
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
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(option, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2E))),
                                                if (treatment.isNotEmpty) Text(treatment, style: const TextStyle(fontSize: 12, color: Color(0xFF787774))),
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
                          const SizedBox(height: 12),

                          // Row 3: Cost and Notes
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildOutlinedField(
                                  label: 'Cost',
                                  controller: _costController,
                                  hint: '0.00',
                                  prefixText: FormatUtils.currencyPrefix,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: _buildOutlinedField(
                                  label: 'Notes (optional)',
                                  controller: _notesController,
                                  hint: 'Details...',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quarantine toggle card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _addToQuarantine ? const Color(0xFF7B6BA0) : kLilacLight),
                              borderRadius: BorderRadius.circular(12),
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
                                        activeColor: const Color(0xFF7B6BA0),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: widget.rabbit.status != RabbitStatus.quarantine
                                            ? (value) => setState(() => _addToQuarantine = value ?? false)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Move to Quarantine',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2C2C2E),
                                        ),
                                      ),
                                    ),
                                    if (_addToQuarantine)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7B6BA0),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$_quarantineDays days',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_addToQuarantine) ...[
                                  const SizedBox(height: 6),
                                  Slider(
                                    value: _quarantineDays.toDouble(),
                                    min: 1,
                                    max: 30,
                                    divisions: 29,
                                    activeColor: const Color(0xFF7B6BA0),
                                    inactiveColor: kLilacLight,
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
                                              labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
                                              floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
                                              floatingLabelBehavior: FloatingLabelBehavior.always,
                                              filled: true,
                                              fillColor: kLilacWash,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLilacLight)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLilacLight)),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                            items: _locations.map((location) {
                                              return DropdownMenuItem(value: location, child: Text(location, style: const TextStyle(fontSize: 13)));
                                            }).toList(),
                                            onChanged: (value) => setState(() => _selectedLocation = value),
                                          ),
                                        ),
                                      if (_locations.isNotEmpty) const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _cageController,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
                                          decoration: InputDecoration(
                                            labelText: 'Cage ID',
                                            labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
                                            floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
                                            floatingLabelBehavior: FloatingLabelBehavior.always,
                                            hintText: 'Quarantine-1',
                                            filled: true,
                                            fillColor: kLilacWash,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLilacLight)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kLilacLight)),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
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
                    const SizedBox(height: 20),

                    // Full Width Purple Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
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
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Health Record',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
