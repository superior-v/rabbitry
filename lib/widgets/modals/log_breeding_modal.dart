import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

class LogBreedingModal extends StatefulWidget {
  final Rabbit doe;
  final VoidCallback onComplete;

  const LogBreedingModal({
    Key? key,
    required this.doe,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LogBreedingModal> createState() => _LogBreedingModalState();
}

class _LogBreedingModalState extends State<LogBreedingModal> {
  final DatabaseService _db = DatabaseService();
  List<Rabbit> _bucks = [];
  Rabbit? _selectedBuck;
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
    final bucks = await _db.getAvailableBucks();
    setState(() {
      _palpationDays = settings.palpationDays;
      _nestBoxDays = settings.nestBoxDays;
      _gestationDays = settings.gestationDays;
      _bucks = bucks;
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Log Breeding',
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
              Text(
                'Breeding ${widget.doe.name} (${widget.doe.id})',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF787774),
                ),
              ),
              SizedBox(height: 24),

              // Buck Selection
              Text(
                'Select Buck',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else if (_bucks.isEmpty)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No bucks available. Please add a buck first.',
                    style: TextStyle(color: Color(0xFF856404)),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<Rabbit>(
                    value: _selectedBuck,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    hint: Text('Select a buck'),
                    items: _bucks.map((buck) {
                      return DropdownMenuItem(
                        value: buck,
                        child: Text('${buck.name} (${buck.id})'),
                      );
                    }).toList(),
                    onChanged: (buck) {
                      setState(() => _selectedBuck = buck);
                    },
                  ),
                ),
              SizedBox(height: 20),

              // Breed Date
              Text(
                'Breed Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
                        '${_breedDate.day}/${_breedDate.month}/${_breedDate.year}',
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Timeline Preview
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Timeline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF787774),
                          ),
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
                    SizedBox(height: 12),
                    if (_isCustomTimeline) ...[
                      _buildEditableTimelineRow(
                        'Palpation',
                        Icons.touch_app,
                        _palpationDays,
                        _breedDate.add(Duration(days: _palpationDays)),
                        (val) => setState(() => _palpationDays = val),
                      ),
                      _buildEditableTimelineRow(
                        'Nest Box',
                        Icons.home,
                        _nestBoxDays,
                        _breedDate.add(Duration(days: _nestBoxDays)),
                        (val) => setState(() => _nestBoxDays = val),
                      ),
                      _buildEditableTimelineRow(
                        'Due Date',
                        Icons.child_friendly,
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
                        'Palpation',
                        _breedDate.add(Duration(days: _palpationDays)),
                        Icons.touch_app,
                      ),
                      _buildTimelineItem(
                        'Nest Box',
                        _breedDate.add(Duration(days: _nestBoxDays)),
                        Icons.home,
                      ),
                      _buildTimelineItem(
                        'Due Date',
                        _breedDate.add(Duration(days: _gestationDays)),
                        Icons.child_friendly,
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
                  onPressed: _selectedBuck == null || _isSaving ? null : _saveBreeding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0F7B6C),
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
                          'Log Breeding',
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
    IconData icon,
    int days,
    DateTime date,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Color(0xFF0F7B6C)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
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
                color: Colors.white,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Color(0xFFE9E9E7)),
              ),
              child: Icon(Icons.add, size: 14, color: Color(0xFF787774)),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, DateTime date, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Color(0xFF0F7B6C)),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
          ),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
    if (_selectedBuck == null) return;

    setState(() => _isSaving = true);

    try {
      await _db.logBreeding(
        widget.doe.id,
        _selectedBuck!.id,
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
