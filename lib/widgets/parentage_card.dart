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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildParentCard(
              label: 'SIRE',
              rabbit: _sireRabbit,
              fallbackId: widget.rabbit.sireId,
              isMale: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildParentCard(
              label: 'DAM',
              rabbit: _damRabbit,
              fallbackId: widget.rabbit.damId,
              isMale: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentCard({
    required String label,
    required Rabbit? rabbit,
    required String? fallbackId,
    required bool isMale,
  }) {
    // Pastel colors: #D8EEFB for Sire, #FFBCE7 for Dam
    final Color cardBg = isMale
        ? const Color(0xFFD8EEFB)
        : const Color(0xFFFFBCE7);

    final bool hasDetails = rabbit != null || (fallbackId != null && fallbackId.isNotEmpty);

    return GestureDetector(
      onTap: rabbit != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RabbitDetailScreen(rabbit: rabbit),
                ),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SIRE / DAM label
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF55555C),
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            // Prefix + Name or '-'
            if (!hasDetails)
              const Text(
                '-',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              )
            else
              RichText(
                text: TextSpan(
                  children: [
                    if ((rabbit?.breederPrefix ?? '').isNotEmpty) ...[
                      TextSpan(
                        text: '${rabbit!.breederPrefix} ',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                    ],
                    TextSpan(
                      text: rabbit?.name ?? fallbackId ?? '-',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C2C2E),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6A6171),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            const SizedBox(height: 14),
            // In Herd / External badge — corner radius matches rest of app (8)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMale ? const Color(0xFFBFE0F7) : const Color(0xFFF7B4DE),
                  width: 1,
                ),
              ),
              child: Text(
                !hasDetails
                    ? '-'
                    : (rabbit != null ? 'In Herd' : 'External'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F4F56),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
