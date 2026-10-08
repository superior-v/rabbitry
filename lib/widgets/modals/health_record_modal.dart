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
    super.key,
    required this.rabbit,
    required this.onComplete,
  });

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
  String? _selectedTreatment;
  bool _isEnteringCustom = false;
  List<String> _healthOptions = [
    'Nail Trim',
    'Deworm',
    'Coccidiosis Med',
    'Teeth Check',
    'Weight Check',
    'Eye Medication',
    '+ Custom',
  ];
  bool _isLoading = false;
  bool _addToQuarantine = false;
  int _quarantineDays = 14;
  List<String> _locations = [];
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadBarns();
    _loadHealthOptions();
  }

  Future<void> _loadHealthOptions() async {
    try {
      final items = await _db.getAllTaskDirectoryItems();
      final healthItems = items
          .where((t) => (t['category'] as String?)?.toLowerCase() == 'health')
          .map((t) => (t['name'] as String?)?.trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final combined = <String>[];
      for (final def in [
        'Nail Trim',
        'Deworm',
        'Coccidiosis Med',
        'Teeth Check',
        'Weight Check',
        'Eye Medication',
      ]) {
        if (!combined.contains(def)) combined.add(def);
      }
      for (final item in healthItems) {
        if (!combined.contains(item)) combined.add(item);
      }
      for (final issue in SettingsService.instance.healthIssues) {
        final name = issue['name']?.trim() ?? '';
        if (name.isNotEmpty && !combined.contains(name)) {
          combined.add(name);
        }
      }
      combined.add('+ Custom');

      if (mounted) {
        setState(() {
          _healthOptions = combined;
          if (_selectedTreatment == null && combined.isNotEmpty && combined.first != '+ Custom') {
            _selectedTreatment = combined.first;
            _treatmentController.text = combined.first;
          }
        });
      }
    } catch (_) {}
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

    final treatmentName = _isEnteringCustom
        ? _treatmentController.text.trim()
        : (_selectedTreatment ?? _treatmentController.text.trim());

    if (treatmentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a treatment type'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEnteringCustom && treatmentName.isNotEmpty) {
        try {
          await _db.insertTaskDirectoryItem(treatmentName, 'Health');
        } catch (_) {}
      }

      final cost = _costController.text.isNotEmpty ? double.tryParse(_costController.text) : null;

      await _db.addHealthRecord(
        widget.rabbit.id,
        treatmentName,
        _selectedDate,
        treatmentName,
        cost,
        _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (_addToQuarantine) {
        await _db.addToQuarantine(
          widget.rabbit.id,
          treatmentName,
          _quarantineDays,
          cost,
        );

        if (_cageController.text.isNotEmpty || _selectedLocation != null) {
          await _db.moveCage(widget.rabbit.id, _selectedLocation ?? '', _cageController.text);
        }
      }

      widget.onComplete();
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_addToQuarantine ? 'Health record added & moved to quarantine' : 'Health record added'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding record: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            // Top Lilac Header Banner (matches consistency.jpg)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFEEDAFE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Health Record',
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _formatRabbitHeader(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A3E6D),
                          ),
                          overflow: TextOverflow.ellipsis,
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
                          // Treatment Type Dropdown / Custom field
                          if (!_isEnteringCustom) ...[
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Treatment Type',
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
                                  value: (_selectedTreatment == '+ Custom' || !_healthOptions.contains(_selectedTreatment)) ? null : _selectedTreatment,
                                  hint: const Text('Select treatment type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: kNeutral400)),
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
                                  selectedItemBuilder: (BuildContext context) {
                                    return _healthOptions.map((e) => Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        e,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: e == '+ Custom' ? FontStyle.italic : FontStyle.normal,
                                          color: e == '+ Custom' ? const Color(0xFF8B5CF6) : const Color(0xFF3A3A3C),
                                        ),
                                      ),
                                    )).toList();
                                  },
                                  items: _healthOptions.asMap().entries.map((entry) {
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
                                            color: e == '+ Custom' ? const Color(0xFF8B5CF6) : const Color(0xFF3A3A3C),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val == '+ Custom') {
                                      setState(() {
                                        _isEnteringCustom = true;
                                        _selectedTreatment = null;
                                        _treatmentController.clear();
                                      });
                                    } else {
                                      setState(() {
                                        _selectedTreatment = val;
                                        _treatmentController.text = val ?? '';
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
                                      _treatmentController.text = _healthOptions.firstWhere((e) => e != '+ Custom', orElse: () => '');
                                      _selectedTreatment = _treatmentController.text;
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
                            _buildOutlinedField(
                              label: 'Treatment Type',
                              controller: _treatmentController,
                              hint: 'Enter treatment type',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter treatment type';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Row 2: Date Picker & Cost
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildDatePickerField(
                                  label: 'Date',
                                  value: _selectedDate,
                                  onTap: _selectDate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: _buildOutlinedField(
                                  label: 'Cost',
                                  controller: _costController,
                                  hint: '0.00',
                                  prefixText: FormatUtils.currencyPrefix,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 3: Notes
                          _buildOutlinedField(
                            label: 'Notes',
                            controller: _notesController,
                            maxLines: 2,
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

                    // Full Width Light Purple Save Button (matches consistency.jpg)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveRecord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6BEFE),
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
                                  color: Color(0xFF2C2C2E),
                                ),
                              )
                            : const Text(
                                'Save Health Record',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C2C2E),
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
