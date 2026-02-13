import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

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
              SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Record Breeding',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFEBF8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.male, color: Color(0xFF2E7BB5), size: 20),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Buck: ${widget.buck.name} (${widget.buck.id})',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF787774),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Doe Selection
              Text(
                'SELECT DOE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else if (_does.isEmpty)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Color(0xFF856404), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No does available for breeding. All does are either pregnant, nursing, or in quarantine.',
                          style: TextStyle(color: Color(0xFF856404), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<Rabbit>(
                    value: _selectedDoe,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    hint: Text('Select a doe'),
                    items: _does.map((doe) {
                      return DropdownMenuItem(
                        value: doe,
                        child: Row(
                          children: [
                            Icon(Icons.female, color: Color(0xFF9C6ADE), size: 18),
                            SizedBox(width: 8),
                            Text('${doe.name} (${doe.id})'),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFF0F7F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                doe.statusText,
                                style: TextStyle(fontSize: 11, color: Color(0xFF0F7B6C)),
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
                ),
              SizedBox(height: 20),

              // Breed Date
              Text(
                'BREED DATE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                  letterSpacing: 0.5,
                ),
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
                      Text(
                        _formatDate(_breedDate),
                        style: TextStyle(fontSize: 15),
                      ),
                      Spacer(),
                      Text(
                        _breedDate.difference(DateTime.now()).inDays == 0 ? 'Today' : '${_breedDate.difference(DateTime.now()).inDays.abs()} days ago',
                        style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Timeline Preview with Palpation Reminder
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF0F7F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF0F7B6C).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Color(0xFF0F7B6C)),
                            SizedBox(width: 6),
                            Text(
                              'TIMELINE & REMINDERS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F7B6C),
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
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isCustomTimeline ? Color(0xFF0F7B6C).withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isCustomTimeline ? Color(0xFF0F7B6C) : Color(0xFFE9E9E7),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isCustomTimeline ? Icons.check_circle : Icons.edit,
                                  size: 14,
                                  color: _isCustomTimeline ? Color(0xFF0F7B6C) : Color(0xFF787774),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _isCustomTimeline ? 'Custom' : 'Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isCustomTimeline ? Color(0xFF0F7B6C) : Color(0xFF787774),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    if (_isCustomTimeline) ...[
                      _buildEditableTimelineRow(
                        '📅 Palpation Check',
                        _palpationDays,
                        _breedDate.add(Duration(days: _palpationDays)),
                        (val) => setState(() => _palpationDays = val),
                      ),
                      _buildEditableTimelineRow(
                        '🏠 Nest Box',
                        _nestBoxDays,
                        _breedDate.add(Duration(days: _nestBoxDays)),
                        (val) => setState(() => _nestBoxDays = val),
                      ),
                      _buildEditableTimelineRow(
                        '🐰 Due Date',
                        _gestationDays,
                        _breedDate.add(Duration(days: _gestationDays)),
                        (val) => setState(() => _gestationDays = val),
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          await SettingsService.instance.init();
                          setState(() {
                            _palpationDays = SettingsService.instance.palpationDays;
                            _nestBoxDays = SettingsService.instance.nestBoxDays;
                            _gestationDays = SettingsService.instance.gestationDays;
                          });
                        },
                        child: Text(
                          'Reset to defaults',
                          style: TextStyle(fontSize: 12, color: Color(0xFF0F7B6C), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ] else ...[
                      _buildTimelineItem(
                        '📅 Palpation Check',
                        _breedDate.add(Duration(days: _palpationDays)),
                        'Confirm pregnancy',
                        isHighlighted: true,
                      ),
                      _buildTimelineItem(
                        '🏠 Nest Box',
                        _breedDate.add(Duration(days: _nestBoxDays)),
                        'Prepare nest box',
                        isHighlighted: false,
                      ),
                      _buildTimelineItem(
                        '🐰 Due Date',
                        _breedDate.add(Duration(days: _gestationDays)),
                        'Expected kindle date',
                        isHighlighted: false,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedDoe == null || _isSaving ? null : _saveBreeding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0F7B6C),
                    disabledBackgroundColor: Color(0xFFE9E9E7),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Record Breeding',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
        borderRadius: BorderRadius.circular(8),
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
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F7B6C)),
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
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted ? Border.all(color: Color(0xFFCB8347).withOpacity(0.3)) : null,
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
                  color: isHighlighted ? Color(0xFFCB8347) : Color(0xFF787774),
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _breedDate,
      firstDate: DateTime.now().subtract(Duration(days: 30)),
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
