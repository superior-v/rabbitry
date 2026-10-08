import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/format_utils.dart';
import '../../constants/app_colors.dart';

class LogWeightModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const LogWeightModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LogWeightModal> createState() => _LogWeightModalState();
}

class _LogWeightModalState extends State<LogWeightModal> {
  final _formKey = GlobalKey<FormState>();
  final _lbsController = TextEditingController();
  final _ozController = TextEditingController();
  final _notesController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  late Rabbit _currentRabbit;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _currentRabbit = widget.rabbit;
    if (_currentRabbit.weight != null && _currentRabbit.weight! > 0) {
      final totalWeight = _currentRabbit.weight!;
      final lbs = totalWeight.floor();
      final oz = ((totalWeight - lbs) * 16.0).round();
      _lbsController.text = lbs.toString();
      _ozController.text = oz.toString();
    }
    _initWeightInputs();
    _loadHistory();
  }

  Future<void> _initWeightInputs() async {
    final fresh = await _db.getRabbit(widget.rabbit.id);
    if (fresh != null && mounted) {
      setState(() {
        _currentRabbit = fresh;
      });
      if (fresh.weight != null && fresh.weight! > 0) {
        final totalWeight = fresh.weight!;
        final lbs = totalWeight.floor();
        final oz = ((totalWeight - lbs) * 16.0).round();
        _lbsController.text = lbs.toString();
        _ozController.text = oz.toString();
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _db.getWeightHistory(widget.rabbit.id);
      if (mounted) {
        setState(() {
          _weightHistory = history;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  @override
  void dispose() {
    _lbsController.dispose();
    _ozController.dispose();
    _notesController.dispose();
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

  String _formatLbsOz(dynamic weightVal) {
    if (weightVal == null) return '0 lbs';
    final double val = (weightVal is num) ? weightVal.toDouble() : double.tryParse(weightVal.toString()) ?? 0.0;
    return FormatUtils.formatWeight(val);
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

  Future<void> _saveWeight() async {
    if (!_formKey.currentState!.validate()) return;

    final lbs = double.tryParse(_lbsController.text.trim()) ?? 0.0;
    final oz = double.tryParse(_ozController.text.trim()) ?? 0.0;

    if (lbs <= 0 && oz <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid weight in lbs or oz'),
          backgroundColor: Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final totalWeightInLbs = lbs + (oz / 16.0);
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      await _db.logWeight(
        widget.rabbit.id,
        totalWeightInLbs,
        _selectedDate,
        notes,
      );

      widget.onComplete();
      if (mounted) {
        Navigator.pop(context);
        final formattedDisplay = _formatLbsOz(totalWeightInLbs);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weight logged: $formattedDisplay'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging weight: $e'),
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

  Future<void> _deleteRecord(String id) async {
    await _db.deleteWeightRecord(id);
    await _loadHistory();
    widget.onComplete();
  }

  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    String? suffixText,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    Color textColor = const Color(0xFF3A3A3C),
    Color? labelColor,
  }) {
    final effectiveLabelColor = labelColor ?? const Color(0xFF4F4F56);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: effectiveLabelColor, fontWeight: FontWeight.w600, fontSize: 17),
        floatingLabelStyle: TextStyle(color: effectiveLabelColor, fontWeight: FontWeight.w600, fontSize: 17),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: effectiveLabelColor, size: 18) : null,
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7B6BA0)),
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
                        'Log Weight',
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
                            color: Colors.white.withOpacity(0.6),
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
                          if (_currentRabbit.weight != null && _currentRabbit.weight! > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kLilacLight),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monitor_weight_outlined, size: 18, color: Color(0xFF7B6BA0)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Current Weight: ${FormatUtils.formatWeight(_currentRabbit.weight!)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A3E6D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Two Weight Boxes: lbs and oz
                          Row(
                            children: [
                              // Box 1: lbs (Pounds)
                              Expanded(
                                flex: 1,
                                child: _buildOutlinedField(
                                  label: 'Pounds',
                                  controller: _lbsController,
                                  hint: '0',
                                  suffixText: 'lbs',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Box 2: oz (Ounces)
                              Expanded(
                                flex: 1,
                                child: _buildOutlinedField(
                                  label: 'Ounces',
                                  controller: _ozController,
                                  hint: '0',
                                  suffixText: 'oz',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Date picker row
                          _buildDatePickerField(
                            label: 'Date',
                            value: _selectedDate,
                            onTap: _selectDate,
                          ),
                          const SizedBox(height: 12),

                          // Notes Input field
                          _buildOutlinedField(
                            label: 'Notes',
                            controller: _notesController,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Weight History Section
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
                          Row(
                            children: [
                              const Icon(Icons.history_rounded, size: 18, color: Color(0xFF4A3E6D)),
                              const SizedBox(width: 8),
                              const Text(
                                'Log Weight',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A3E6D),
                                ),
                              ),
                              const Spacer(),
                              if (_weightHistory.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7B6BA0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_weightHistory.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_loadingHistory)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B6BA0)),
                                ),
                              ),
                            )
                          else if (_weightHistory.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: const Text(
                                'No previous weight entries recorded yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _weightHistory.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final record = _weightHistory[index];
                                final recordWeight = record['weight'];
                                final recordDate = record['date'];
                                final recordNotes = record['notes'] as String?;
                                final recordId = record['id'] as String?;

                                DateTime? parsedDate;
                                if (recordDate != null) {
                                  parsedDate = DateTime.tryParse(recordDate.toString());
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: kLilacLight),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  _formatLbsOz(recordWeight),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF2C2C2E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (parsedDate != null || (recordNotes != null && recordNotes.isNotEmpty)) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  if (parsedDate != null)
                                                    Text(
                                                      FormatUtils.formatDate(parsedDate),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF787774),
                                                      ),
                                                    ),
                                                  if (recordNotes != null && recordNotes.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '• $recordNotes',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF787774),
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (recordId != null)
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Color(0xFF8E8E93)),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _deleteRecord(recordId),
                                        ),
                                    ],
                                  ),
                                );
                              },
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
                        onPressed: _isLoading ? null : _saveWeight,
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
                                'Save Weight',
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
