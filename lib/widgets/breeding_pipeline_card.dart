import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/rabbit.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';

class BreedingPipelineCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onRefresh;

  const BreedingPipelineCard({Key? key, required this.rabbit, this.onRefresh}) : super(key: key);

  @override
  State<BreedingPipelineCard> createState() => _BreedingPipelineCardState();
}

class _BreedingPipelineCardState extends State<BreedingPipelineCard> {
  final _settings = SettingsService.instance;
  final _db = DatabaseService();
  String? _buckName;

  @override
  void initState() {
    super.initState();
    _loadBuckName();
  }

  Future<void> _loadBuckName() async {
    if (widget.rabbit.lastBreedBuckId != null) {
      final buck = await _db.getRabbit(widget.rabbit.lastBreedBuckId!);
      if (mounted) {
        setState(() {
          _buckName = buck?.name ?? widget.rabbit.lastBreedBuckId;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  int get _daysSinceBred {
    if (widget.rabbit.lastBreedDate == null) return 0;
    return DateTime.now().difference(widget.rabbit.lastBreedDate!).inDays;
  }

  double get _progressFraction {
    if (widget.rabbit.lastBreedDate == null || widget.rabbit.dueDate == null) return 0;
    final totalDays = widget.rabbit.dueDate!.difference(widget.rabbit.lastBreedDate!).inDays;
    if (totalDays == 0) return 0;
    return (_daysSinceBred / totalDays).clamp(0.0, 1.0);
  }

  bool get _isPalpationDue {
    if (widget.rabbit.palpationDate == null) return false;
    final today = DateTime.now();
    return widget.rabbit.palpationDate!.isBefore(today.add(const Duration(days: 1))) && widget.rabbit.palpationDate!.isAfter(today.subtract(const Duration(days: 1)));
  }

  bool get _isPalpationComplete {
    return widget.rabbit.palpationResult != null && widget.rabbit.palpationResult == true;
  }

  bool get _hasActiveBreedingCycle {
    return widget.rabbit.lastBreedDate != null && (widget.rabbit.status == RabbitStatus.palpateDue || widget.rabbit.status == RabbitStatus.pregnant);
  }

  @override
  Widget build(BuildContext context) {
    // If no active breeding cycle, show empty state
    if (!_hasActiveBreedingCycle) {
      return _buildEmptyState(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CURRENT CYCLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showPipelineSettings(context),
                  child: Icon(Icons.settings, color: Color(0xFF787774), size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
                    children: [
                      TextSpan(text: 'with '),
                      TextSpan(
                        text: _buckName ?? widget.rabbit.lastBreedBuckId ?? 'Unknown',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF37352F)),
                      ),
                      if (widget.rabbit.lastBreedDate != null) ...[
                        TextSpan(text: ' • Bred '),
                        TextSpan(text: _formatDate(widget.rabbit.lastBreedDate!)),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(0xFFE9E9E7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _progressFraction,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Color(0xFF0F7B6C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Day $_daysSinceBred of ${_settings.gestationDays}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 2),
                if (widget.rabbit.dueDate != null)
                  Text(
                    'Kindle expected ${_formatDate(widget.rabbit.dueDate!)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF787774),
                    ),
                  ),
                SizedBox(height: 24),
                // Milestones
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMilestone(PhosphorIconsDuotone.checkCircle, 'Bred\n${widget.rabbit.lastBreedDate != null ? _formatDate(widget.rabbit.lastBreedDate!) : "-"}', true, Color(0xFF0F7B6C)),
                    if (_settings.palpationEnabled) _buildMilestone(PhosphorIconsDuotone.handPointing, 'Palpate\n${widget.rabbit.palpationDate != null ? (_isPalpationDue ? "Today" : _formatDate(widget.rabbit.palpationDate!)) : "-"}', _isPalpationComplete, _isPalpationComplete || _isPalpationDue ? Color(0xFF0F7B6C) : Color(0xFF9B9A97)),
                    if (_settings.nestBoxEnabled) _buildMilestone(PhosphorIconsDuotone.package, 'Nest Box\n${widget.rabbit.dueDate != null ? _formatDate(widget.rabbit.dueDate!.subtract(Duration(days: 3))) : "-"}', false, Color(0xFF9B9A97)),
                    _buildMilestone(PhosphorIconsDuotone.baby, 'Kindle\n${widget.rabbit.dueDate != null ? _formatDate(widget.rabbit.dueDate!) : "-"}', false, Color(0xFF9B9A97)),
                  ],
                ),
                SizedBox(height: 24),
                // Action Buttons based on status
                _buildActionButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (widget.rabbit.status == RabbitStatus.palpateDue) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showPalpationDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0F7B6C),
                padding: EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Log Palpation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showMarkOpenDialog(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Color(0xFFE9E9E7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Not Pregnant',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (widget.rabbit.status == RabbitStatus.pregnant) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showLogBirthDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0F7B6C),
                padding: EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Log Birth',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showMarkOpenDialog(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Color(0xFFE9E9E7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel Cycle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BREEDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showPipelineSettings(context),
                  child: Icon(Icons.settings, color: Color(0xFF787774), size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsDuotone.heartbeat,
                    size: 48,
                    color: Color(0xFFE9E9E7),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No Active Breeding Cycle',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF787774),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Status: ${_getStatusLabel(widget.rabbit.status)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9B9A97),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(RabbitStatus status) {
    switch (status) {
      case RabbitStatus.open:
        return 'Open - Ready to breed';
      case RabbitStatus.nursing:
        return 'Nursing';
      case RabbitStatus.resting:
        return 'Resting';
      default:
        return status.toString().split('.').last;
    }
  }

  void _showLogBirthDialog(BuildContext context) {
    // TODO: Implement log birth dialog or navigate to log birth modal
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Log birth functionality'),
        backgroundColor: Color(0xFF0F7B6C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildMilestone(IconData icon, String label, bool completed, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: completed ? color.withOpacity(0.1) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: completed ? color : Color(0xFFE9E9E7),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            height: 1.2,
            color: Color(0xFF787774),
          ),
        ),
      ],
    );
  }

  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF37352F),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF787774),
          ),
        ),
      ],
    );
  }

  void _showPipelineSettings(BuildContext context) {
    bool useDefault = widget.rabbit.customPalpationDay == null && widget.rabbit.customNestBoxDay == null && widget.rabbit.customGestationDay == null && widget.rabbit.customWeanWeek == null;
    int palpationDay = widget.rabbit.customPalpationDay ?? _settings.palpationDays;
    int nestBoxDay = widget.rabbit.customNestBoxDay ?? _settings.nestBoxDays;
    int expectedKindleDay = widget.rabbit.customGestationDay ?? _settings.gestationDays;
    int weaningWeek = widget.rabbit.customWeanWeek ?? _settings.weanAge;

    final palpationController = TextEditingController(text: '$palpationDay');
    final nestBoxController = TextEditingController(text: '$nestBoxDay');
    final kindleController = TextEditingController(text: '$expectedKindleDay');
    final weaningController = TextEditingController(text: '$weaningWeek');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pipeline Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      Text(
                        '${widget.rabbit.name} (${widget.rabbit.id})',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Color(0xFF787774)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Toggle Buttons
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() {
                          useDefault = true;
                          palpationController.text = '${_settings.palpationDays}';
                          nestBoxController.text = '${_settings.nestBoxDays}';
                          kindleController.text = '${_settings.gestationDays}';
                          weaningController.text = '${_settings.weanAge}';
                        }),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: useDefault ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: useDefault
                                ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3)
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Use Default',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: useDefault ? FontWeight.w600 : FontWeight.w400,
                              color: Color(0xFF37352F),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => useDefault = false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !useDefault ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: !useDefault
                                ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3)
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Custom',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: !useDefault ? FontWeight.w600 : FontWeight.w400,
                              color: Color(0xFF37352F),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'TIMING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 16),
              _buildEditableTimingItem('Palpation Check', 'Day', palpationController, 'after breeding', !useDefault),
              _buildEditableTimingItem('Nest Box', 'Day', nestBoxController, 'after breeding', !useDefault),
              _buildEditableTimingItem('Expected Kindle', 'Day', kindleController, 'after breeding', !useDefault),
              _buildEditableTimingItem('Weaning', 'Week', weaningController, 'after kindle', !useDefault),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          useDefault = true;
                          palpationController.text = '${_settings.palpationDays}';
                          nestBoxController.text = '${_settings.nestBoxDays}';
                          kindleController.text = '${_settings.gestationDays}';
                          weaningController.text = '${_settings.weanAge}';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Color(0xFFE9E9E7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Restore Defaults',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (useDefault) {
                          // Clear custom settings - use defaults
                          widget.rabbit.customPalpationDay = null;
                          widget.rabbit.customNestBoxDay = null;
                          widget.rabbit.customGestationDay = null;
                          widget.rabbit.customWeanWeek = null;
                        } else {
                          // Save custom settings
                          widget.rabbit.customPalpationDay = int.tryParse(palpationController.text) ?? _settings.palpationDays;
                          widget.rabbit.customNestBoxDay = int.tryParse(nestBoxController.text) ?? _settings.nestBoxDays;
                          widget.rabbit.customGestationDay = int.tryParse(kindleController.text) ?? _settings.gestationDays;
                          widget.rabbit.customWeanWeek = int.tryParse(weaningController.text) ?? _settings.weanAge;
                        }
                        await _db.updateRabbit(widget.rabbit);
                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(useDefault ? 'Using default pipeline settings' : 'Custom pipeline settings saved'),
                              backgroundColor: Color(0xFF0F7B6C),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          setState(() {});
                          widget.onRefresh?.call();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0F7B6C),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableTimingItem(String title, String unit, TextEditingController controller, String suffix, bool enabled) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF37352F),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 70,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: enabled ? Colors.white : Color(0xFFF7F7F5),
                  border: Border.all(color: Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF787774),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: enabled ? Colors.white : Color(0xFFF7F7F5),
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: InputBorder.none,
                      suffixText: suffix,
                      suffixStyle: TextStyle(fontSize: 13, color: Color(0xFF787774)),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? Color(0xFF37352F) : Color(0xFF787774),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFC47070) : Color(0xFF787774),
              size: 24,
            ),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? Color(0xFFC47070) : Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPalpationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Palpation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Did you feel kits during palpation?',
              style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handlePalpationResult(false);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Color(0xFFE9E9E7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'No',
                      style: TextStyle(color: Color(0xFF787774)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handlePalpationResult(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0F7B6C),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Yes', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePalpationResult(bool positive) async {
    try {
      final gestationDays = widget.rabbit.customGestationDay ?? _settings.gestationDays;
      await _db.confirmPregnancy(widget.rabbit.id, positive, gestationDays);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(positive ? '✅ Palpation positive - marked as pregnant' : '❌ Palpation negative - marked as open'),
            backgroundColor: positive ? Color(0xFF0F7B6C) : Color(0xFFF5A623),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMarkOpenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as Open'),
        content: Text(
          'This will end the current breeding cycle. Are you sure?',
          style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleMarkOpen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC47070),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Mark Open', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkOpen() async {
    try {
      await _db.cancelPregnancy(widget.rabbit.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Breeding cycle ended - marked as open'),
            backgroundColor: Color(0xFF0F7B6C),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
