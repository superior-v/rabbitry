import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';
import 'modals/log_weight_modal.dart';

class WeightHistoryCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onUpdate;
  const WeightHistoryCard({super.key, required this.rabbit, this.onUpdate});

  @override
  State<WeightHistoryCard> createState() => _WeightHistoryCardState();
}

class _WeightHistoryCardState extends State<WeightHistoryCard> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _weightLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeightHistory();
  }

  @override
  void didUpdateWidget(covariant WeightHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rabbit.id != oldWidget.rabbit.id || widget.rabbit.weight != oldWidget.rabbit.weight) {
      _loadWeightHistory();
    }
  }

  Future<void> _loadWeightHistory() async {
    try {
      final logs = await _db.getWeightHistory(widget.rabbit.id);
      if (mounted) {
        setState(() {
          _weightLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _weightUnit => SettingsService.instance.weightUnit;

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return FormatUtils.formatDate(dt);
  }

  String _formatWeight(dynamic w) {
    if (w == null) return '';
    final d = (w is num) ? w.toDouble() : double.tryParse(w.toString()) ?? 0;
    return '${d.toStringAsFixed(1)} $_weightUnit';
  }

  void _showLogWeightModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogWeightModal(
        rabbit: widget.rabbit,
        onComplete: () {
          _loadWeightHistory();
          widget.onUpdate?.call();
        },
      ),
    );
  }

  Future<void> _deleteWeightLog(String id) async {
    await _db.deleteWeightRecord(id);
    _loadWeightHistory();
    widget.onUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LOG WEIGHT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F4F56),
                    letterSpacing: 0.8,
                  ),
                ),
                GestureDetector(
                  onTap: _showLogWeightModal,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6BEFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 18,
                      color: Colors.white,
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
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep)),
            )
          else if (_weightLogs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No records yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF787774),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: _weightLogs.map((log) => _buildWeightItem(log)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeightItem(Map<String, dynamic> log) {
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
              color: const Color(0xFF7B6BA0).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.monitor_weight_outlined, size: 18, color: Color(0xFF7B6BA0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatWeight(log['weight']),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(log['date']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                if ((log['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    log['notes'].toString(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showDeleteConfirm(log),
            child: const Icon(Icons.more_horiz, size: 20, color: Color(0xFF787774)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFEF4444)),
              title: const Text('Delete Entry', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
              subtitle: Text('${_formatWeight(log['weight'])} on ${_formatDate(log['date'])}'),
              onTap: () {
                Navigator.pop(ctx);
                final id = log['id']?.toString() ?? '';
                if (id.isNotEmpty) _deleteWeightLog(id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
