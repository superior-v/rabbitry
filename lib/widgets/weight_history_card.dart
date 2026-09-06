import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../constants/app_colors.dart';
import 'modals/log_weight_modal.dart';

class WeightHistoryCard extends StatefulWidget {
  final Rabbit rabbit;
  const WeightHistoryCard({Key? key, required this.rabbit}) : super(key: key);

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
    return DateFormat('MMM d, yyyy').format(dt);
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
        onComplete: _loadWeightHistory,
      ),
    );
  }

  Future<void> _deleteWeightLog(String id) async {
    await _db.deleteWeightRecord(id);
    _loadWeightHistory();
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.monitor_weight_outlined, size: 18, color: kNeutral500),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'WEIGHT HISTORY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kNeutral500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showLogWeightModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kNeutral100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 14, color: kNeutral600),
                        const SizedBox(width: 4),
                        const Text(
                          'Log',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kNeutral600,
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
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep)),
            )
          else if (_weightLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.monitor_weight_outlined, size: 36, color: kNeutral300),
                  const SizedBox(height: 8),
                  Text('No weight logs yet', style: TextStyle(fontSize: 14, color: kNeutral400, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Tap "Log" to record a weight entry', style: TextStyle(fontSize: 12, color: kNeutral300)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _weightLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: kNeutral100),
              itemBuilder: (context, index) {
                final log = _weightLogs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E8F7),
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
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2E2E35)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(log['date']),
                              style: const TextStyle(fontSize: 12, color: kNeutral400, fontWeight: FontWeight.w500),
                            ),
                            if ((log['notes'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                log['notes'].toString(),
                                style: const TextStyle(fontSize: 12, color: kNeutral400),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showDeleteConfirm(log),
                        child: const Icon(Icons.more_vert, size: 18, color: kNeutral300),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
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
              leading: const Icon(Icons.delete, color: Color(0xFFC47070)),
              title: const Text('Delete Entry', style: TextStyle(color: Color(0xFFC47070), fontWeight: FontWeight.w500)),
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
