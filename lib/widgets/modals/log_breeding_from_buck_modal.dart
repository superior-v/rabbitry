import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/format_utils.dart';
import '../../constants/app_colors.dart';

/// Log Breeding Modal when initiated from a Buck
/// Asks for the Doe, date, and shows palpation reminder timeline
class LogBreedingFromBuckModal extends StatefulWidget {
  final Rabbit buck;
  final VoidCallback onComplete;

  const LogBreedingFromBuckModal({
    Key? key,
    required this.buck,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LogBreedingFromBuckModal> createState() => _LogBreedingFromBuckModalState();
}

class _LogBreedingFromBuckModalState extends State<LogBreedingFromBuckModal> {
  final DatabaseService _db = DatabaseService();
  List<Rabbit> _does = [];
  Rabbit? _selectedDoe;
  DateTime _breedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCustomTimeline = false;

  // Timeline days (loaded from settings, editable by user)
  int _palpationDays = 14;
  int _nestBoxDays = 28;
  int _gestationDays = 31;
  final TextEditingController _breedingNotesController = TextEditingController();
  final TextEditingController _fallOffsController = TextEditingController();

  @override
  void dispose() {
    _breedingNotesController.dispose();
    _fallOffsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await SettingsService.instance.init();
    final settings = SettingsService.instance;
    final allRabbits = await _db.getAllRabbits();
    final does = allRabbits.where((r) => r.type == RabbitType.doe && (r.status == RabbitStatus.open || r.status == RabbitStatus.resting)).toList();

    setState(() {
      _palpationDays = settings.palpationDays;
      _nestBoxDays = settings.nestBoxDays;
      _gestationDays = settings.gestationDays;
      _does = does;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: kLilacLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilac, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record Breeding',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kLilacText,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buck: ${widget.buck.name} (${widget.buck.id})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kLilacText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: kLilacText),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doe Selection
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_does.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE58F)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Color(0xFF856404), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No does available for breeding. All does are either bred, nursing, or in quarantine.',
                              style: TextStyle(color: Color(0xFF856404), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildDropdownField<Rabbit>(
                      label: 'Select Doe',
                      value: _selectedDoe,
                      prefixIcon: Icons.female_rounded,
                      items: _does.map((doe) {
                        return DropdownMenuItem(
                          value: doe,
                          child: Row(
                            children: [
                              Text('${doe.name} (${doe.id})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7EDE3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  doe.statusText,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF7B6BA0)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (doe) {
                        setState(() => _selectedDoe = doe);
                      },
                    ),
                  const SizedBox(height: 10),

                  // Purple Container Card for Breed Date, Fall Offs, Breeding Notes
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kLilacWash,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kLilacLight),
                    ),
                    child: Column(
                      children: [
                        _buildDatePickerField(
                          label: 'Breed Date',
                          value: _breedDate,
                          onTap: () => _selectDate(context),
                        ),
                        const SizedBox(height: 10),
                        _buildOutlinedField(
                          label: 'Fall Offs',
                          controller: _fallOffsController,
                          prefixIcon: Icons.repeat_on_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        _buildOutlinedField(
                          label: 'Breeding Notes',
                          controller: _breedingNotesController,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Timeline Preview with Palpation Reminder
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kLilacWash.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kLilacLight.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Color(0xFF7B6BA0)),
                                SizedBox(width: 6),
                                Text(
                                  'TIMELINE & REMINDERS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7B6BA0),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _isCustomTimeline = !_isCustomTimeline);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isCustomTimeline ? const Color(0xFF7B6BA0).withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _isCustomTimeline ? const Color(0xFF7B6BA0) : const Color(0xFFE9E9E7),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isCustomTimeline ? Icons.check_circle : Icons.edit,
                                      size: 14,
                                      color: _isCustomTimeline ? const Color(0xFF7B6BA0) : const Color(0xFF787774),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isCustomTimeline ? 'Custom' : 'Edit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _isCustomTimeline ? const Color(0xFF7B6BA0) : const Color(0xFF787774),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_isCustomTimeline) ...[
                          _buildEditableTimelineRow(
                            'Palpation Check',
                            _palpationDays,
                            _breedDate.add(Duration(days: _palpationDays)),
                            (val) => setState(() => _palpationDays = val),
                          ),
                          _buildEditableTimelineRow(
                            'Nest Box',
                            _nestBoxDays,
                            _breedDate.add(Duration(days: _nestBoxDays)),
                            (val) => setState(() => _nestBoxDays = val),
                          ),
                          _buildEditableTimelineRow(
                            'Due Date',
                            _gestationDays,
                            _breedDate.add(Duration(days: _gestationDays)),
                            (val) => setState(() => _gestationDays = val),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              await SettingsService.instance.init();
                              setState(() {
                                _palpationDays = SettingsService.instance.palpationDays;
                                _nestBoxDays = SettingsService.instance.nestBoxDays;
                                _gestationDays = SettingsService.instance.gestationDays;
                              });
                            },
                            child: const Text(
                              'Reset to defaults',
                              style: TextStyle(fontSize: 12, color: Color(0xFF7B6BA0), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ] else ...[
                          _buildTimelineItem(
                            'Palpation Check',
                            _breedDate.add(Duration(days: _palpationDays)),
                            'Confirm bred status',
                            isHighlighted: true,
                          ),
                          _buildTimelineItem(
                            'Nest Box',
                            _breedDate.add(Duration(days: _nestBoxDays)),
                            'Prepare nest box',
                            isHighlighted: false,
                          ),
                          _buildTimelineItem(
                            'Due Date',
                            _breedDate.add(Duration(days: _gestationDays)),
                            'Expected kindle date',
                            isHighlighted: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // Submit Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedDoe == null || _isSaving ? null : _saveBreeding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLilacLight,
                  foregroundColor: kLilacText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kLilacText,
                        ),
                      )
                    : const Text(
                        'SAVE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kLilacText,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTimelineRow(
    String label,
    int days,
    DateTime date,
    ValueChanged<int> onChanged,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE9E9E7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          // Day stepper
          GestureDetector(
            onTap: () {
              if (days > 1) onChanged(days - 1);
            },
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Color(0xFFE9E9E7)),
              ),
              child: Icon(Icons.remove, size: 14, color: Color(0xFF787774)),
            ),
          ),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$days d',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7B6BA0)),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(days + 1),
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Color(0xFFE9E9E7)),
              ),
              child: Icon(Icons.add, size: 14, color: Color(0xFF787774)),
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(date),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54),
              ),
              Text(
                'in ${date.difference(DateTime.now()).inDays} days',
                style: TextStyle(fontSize: 10, color: Color(0xFF787774)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, DateTime date, String subtitle, {bool isHighlighted = false}) {
    final daysFromNow = date.difference(DateTime.now()).inDays;

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? Color(0xFFFFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted ? Border.all(color: Color(0xFF8B5CF6).withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(date),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'in $daysFromNow days',
                style: TextStyle(
                  fontSize: 11,
                  color: isHighlighted ? Color(0xFF8B5CF6) : Color(0xFF787774),
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MM-dd-yyyy').format(date);
  }

  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
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
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF7B6BA0), size: 18),
            const SizedBox(width: 8),
            Text(
              DateFormat('MM-dd-yyyy').format(value),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData prefixIcon,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF7B6BA0), size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7B6BA0)),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _breedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _breedDate = picked);
    }
  }

  Future<void> _saveBreeding() async {
    if (_selectedDoe == null) return;

    setState(() => _isSaving = true);

    try {
      // Log breeding with doe and buck
      await _db.logBreeding(
        _selectedDoe!.id,
        widget.buck.id,
        _breedDate,
        _gestationDays,
        customPalpationDays: _palpationDays,
        customNestBoxDays: _nestBoxDays,
        fallOffs: int.tryParse(_fallOffsController.text),
        breedingNotes: _breedingNotesController.text,
      );

      // Call callback FIRST to trigger parent refresh
      widget.onComplete();

      // Then close this modal
      if (mounted) {
        Navigator.pop(context);
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
        setState(() => _isSaving = false);
      }
    }
  }
}
