import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/format_utils.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';
import 'modals/health_record_modal.dart';
import 'purple_dialog.dart';

class HealthRecordsCard extends StatefulWidget {
  final Rabbit rabbit;

  const HealthRecordsCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<HealthRecordsCard> createState() => _HealthRecordsCardState();
}

class _HealthRecordsCardState extends State<HealthRecordsCard> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void didUpdateWidget(covariant HealthRecordsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rabbit.id != widget.rabbit.id) {
      _loadRecords();
    }
  }

  Future<void> _loadRecords() async {
    try {
      final records = await _db.getHealthRecordsByRabbit(widget.rabbit.id);
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddRecordModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HealthRecordModal(
        rabbit: widget.rabbit,
        onComplete: () {
          _loadRecords();
        },
      ),
    );
  }

  Future<void> _deleteRecord(String id) async {
    final confirmed = await showBrightPurpleDialog<bool>(
      context: context,
      title: 'Delete Health Record',
      content: 'Are you sure you want to delete this health record?',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      await _db.deleteHealthRecord(id);
      await _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health record deleted'), backgroundColor: kPrimary),
        );
      }
    }
  }

  IconData _getRecordIcon(String type, String treatment) {
    final combined = '$type $treatment'.toLowerCase();
    if (combined.contains('nail') || combined.contains('trim') || combined.contains('groom')) {
      return PhosphorIcons.scissors(PhosphorIconsStyle.duotone);
    }
    if (combined.contains('deworm') || combined.contains('vaccin') || combined.contains('inject')) {
      return PhosphorIcons.syringe(PhosphorIconsStyle.duotone);
    }
    if (combined.contains('quarantine')) {
      return PhosphorIcons.shieldCheck(PhosphorIconsStyle.duotone);
    }
    if (combined.contains('weight')) {
      return PhosphorIcons.scales(PhosphorIconsStyle.duotone);
    }
    return PhosphorIcons.firstAid(PhosphorIconsStyle.duotone);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'HEALTH RECORDS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F4F56),
                    letterSpacing: 0.8,
                  ),
                ),
                GestureDetector(
                  onTap: _showAddRecordModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE5FA),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFFD4C8EB)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 15, color: Color(0xFF7B6BA0)),
                        SizedBox(width: 4),
                        Text(
                          'ADD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7B6BA0),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kNeutral100),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF7B6BA0), strokeWidth: 2)),
            )
          else if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No health records yet.\nTap ADD to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: _records.map((record) => _buildRecordItem(record)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> record) {
    final id = record['id']?.toString() ?? '';
    final type = record['type']?.toString() ?? 'Treatment';
    final treatment = record['treatment']?.toString() ?? type;
    final dateStr = record['date']?.toString();
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final cost = record['cost'] is num ? (record['cost'] as num).toDouble() : double.tryParse(record['cost']?.toString() ?? '');
    final notes = record['notes']?.toString();
    final icon = _getRecordIcon(type, treatment);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF7B6BA0).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF7B6BA0), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  treatment.isNotEmpty ? treatment : type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (date != null)
                      Text(
                        FormatUtils.formatDate(date),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    if (cost != null && cost > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•  ${FormatUtils.formatCurrency(cost)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
                if (notes != null && notes.trim().isNotEmpty && notes != 'Completed from Tasks') ...[
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (id.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Color(0xFF787774), size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (val) {
                if (val == 'delete') {
                  _deleteRecord(id);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
