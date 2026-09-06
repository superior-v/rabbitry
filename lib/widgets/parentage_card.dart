import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../screens/rabbit_detail_screen.dart';
import '../constants/app_colors.dart';

class ParentageCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onUpdated;
  const ParentageCard({Key? key, required this.rabbit, this.onUpdated}) : super(key: key);

  @override
  State<ParentageCard> createState() => _ParentageCardState();
}

class _ParentageCardState extends State<ParentageCard> {
  Rabbit? _sireRabbit;
  Rabbit? _damRabbit;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    final db = DatabaseService();
    Rabbit? sire;
    Rabbit? dam;
    if (widget.rabbit.sireId != null) sire = await db.getRabbit(widget.rabbit.sireId!);
    if (widget.rabbit.damId != null) dam = await db.getRabbit(widget.rabbit.damId!);
    if (mounted) setState(() { _sireRabbit = sire; _damRabbit = dam; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep));
    }

    return Row(
      children: [
        Expanded(child: _buildParentCard(
          label: 'SIRE',
          rabbit: _sireRabbit,
          fallbackId: widget.rabbit.sireId,
          isMale: true,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildParentCard(
          label: 'DAM',
          rabbit: _damRabbit,
          fallbackId: widget.rabbit.damId,
          isMale: false,
        )),
      ],
    );
  }

  Widget _buildParentCard({
    required String label,
    required Rabbit? rabbit,
    required String? fallbackId,
    required bool isMale,
  }) {
    // Vivid Figma colors — bright cyan for Sire, hot pink for Dam
    final Color cardBg = isMale
        ? const Color(0xFF38CDF3) // slightly lighter cyan for Sire
        : const Color(0xFFF44CB0); // slightly lighter pink for Dam

    return GestureDetector(
      onTap: rabbit != null
          ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => RabbitDetailScreen(rabbit: rabbit)))
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SIRE / DAM label
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            // Prefix (bold) + Name
            RichText(
              text: TextSpan(
                children: [
                  if ((rabbit?.breederPrefix ?? '').isNotEmpty) ...[
                    TextSpan(
                      text: '${rabbit!.breederPrefix} ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  TextSpan(
                    text: rabbit?.name ?? fallbackId ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if ((rabbit?.color ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                rabbit!.color!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),
            // In Herd / External badge — white pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
              child: Text(
                rabbit != null ? 'In Herd' : 'External',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
