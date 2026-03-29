import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.treeStructure, size: 18, color: kNeutral500),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'PARENTAGE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kNeutral500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kNeutral100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kNeutral600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep))
                : Row(
                    children: [
                      Expanded(child: _buildParentItem('Sire', _sireRabbit?.name ?? widget.rabbit.sireId ?? 'Unknown', _sireRabbit?.id ?? widget.rabbit.sireId ?? '-', true, _sireRabbit)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildParentItem('Dam', _damRabbit?.name ?? widget.rabbit.damId ?? 'Unknown', _damRabbit?.id ?? widget.rabbit.damId ?? '-', false, _damRabbit)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentItem(String label, String name, String id, bool isMale, Rabbit? parent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNeutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: isMale ? kBlueDeep : kPinkDeep, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2937), overflow: TextOverflow.ellipsis),
          ),
          Text(id, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral400)),
          const SizedBox(height: 12),
          if (parent != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RabbitDetailScreen(rabbit: parent))),
              child: Row(
                children: [
                  Text('Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isMale ? kBlueDeep : kPinkDeep)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 10, color: isMale ? kBlueDeep : kPinkDeep),
                ],
              ),
            )
          else
            const Text('Not in herd', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral300, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
