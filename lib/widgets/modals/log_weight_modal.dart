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

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _initWeightInputs();
    _loadHistory();
  }

  void _initWeightInputs() {
    if (widget.rabbit.weight != null && widget.rabbit.weight! > 0) {
      final totalWeight = widget.rabbit.weight!;
      final lbs = totalWeight.floor();
      final oz = (totalWeight - lbs) * 16.0;
      _lbsController.text = lbs.toString();
      _ozController.text = oz > 0.01 ? oz.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : '0';
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
    if (weightVal == null) return '0 lbs 0 oz';
    final double val = (weightVal is num) ? weightVal.toDouble() : double.tryParse(weightVal.toString()) ?? 0.0;
    final int lbs = val.floor();
    final double oz = (val - lbs) * 16.0;
    final ozStr = oz > 0.01 ? oz.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : '0';
    return '$lbs lbs $ozStr oz';
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
      Navigator.pop(context);

      final formattedDisplay = _formatLbsOz(totalWeightInLbs);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weight logged: $formattedDisplay (${totalWeightInLbs.toStringAsFixed(2)} lbs)'),
          backgroundColor: const Color(0xFF7B6BA0),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging weight: $e'),
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

  Future<void> _deleteRecord(String id) async {
    await _db.deleteWeightRecord(id);
    await _loadHistory();
    widget.onComplete();
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
                        'Log Weight',
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Text(
                        FormatUtils.formatDate(_selectedDate),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A3E6D),
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kLilacWash,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kLilacLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.rabbit.weight != null && widget.rabbit.weight! > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5DEEC)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monitor_weight_outlined, size: 18, color: Color(0xFF7B6BA0)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Current Weight: ${_formatLbsOz(widget.rabbit.weight)} (${widget.rabbit.weight!.toStringAsFixed(2)} lbs)',
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
                                child: TextFormField(
                                  controller: _lbsController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Pounds (lbs)',
                                    labelStyle: const TextStyle(color: Color(0xFF4A3E6D), fontWeight: FontWeight.w600, fontSize: 13),
                                    hintText: '0',
                                    suffixText: 'lbs',
                                    suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7B6BA0)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Box 2: oz (Ounces)
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _ozController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Ounces (oz)',
                                    labelStyle: const TextStyle(color: Color(0xFF4A3E6D), fontWeight: FontWeight.w600, fontSize: 13),
                                    hintText: '0',
                                    suffixText: 'oz',
                                    suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7B6BA0)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Date picker row
                          InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE5DEEC)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF7B6BA0)),
                                  const SizedBox(width: 10),
                                  Text(
                                    FormatUtils.formatDate(_selectedDate),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2E)),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right, color: Color(0xFF787774)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Notes Input field
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Notes (optional)',
                              labelStyle: const TextStyle(color: Color(0xFF4A3E6D), fontWeight: FontWeight.w600),
                              hintText: 'Add any notes...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5DEEC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Weight History Section
                    Container(
                      padding: const EdgeInsets.all(14),
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
                              const Icon(Icons.history_rounded, size: 18, color: Color(0xFF7B6BA0)),
                              const SizedBox(width: 8),
                              const Text(
                                'Weight History',
                                style: TextStyle(
                                  fontSize: 14,
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
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE5DEEC)),
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
                                                const SizedBox(width: 6),
                                                Text(
                                                  '(${((recordWeight is num) ? recordWeight.toDouble() : double.tryParse(recordWeight.toString()) ?? 0.0).toStringAsFixed(2)} lbs)',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF8E8E93),
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
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8E8E93)),
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

                    // Full Width Purple Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveWeight,
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
                                'Save Weight',
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
