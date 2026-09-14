import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';

class GeneticsCard extends StatefulWidget {
  final Rabbit rabbit;
  final bool isEditing;

  const GeneticsCard({Key? key, required this.rabbit, this.isEditing = false}) : super(key: key);

  @override
  State<GeneticsCard> createState() => _GeneticsCardState();
}

class _GeneticsCardState extends State<GeneticsCard> {
  // Genetics map — populated only from rabbit data
  Map<String, String> genetics = {};

  // Map of known locus keys for matching
  static const List<String> _locusKeys = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'En',
    'V',
    'W'
  ];

  @override
  void initState() {
    super.initState();
    _parseRabbitGenetics();
  }

  @override
  void didUpdateWidget(covariant GeneticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rabbit.genetics != widget.rabbit.genetics) {
      _parseRabbitGenetics();
    }
  }

  /// Parse the rabbit's genetics string and populate the map
  void _parseRabbitGenetics() {
    final raw = widget.rabbit.genetics;
    if (raw == null || raw.trim().isEmpty) {
      setState(() => genetics = {});
      return;
    }

    // Split by spaces or commas
    final parts = raw.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty).toList();

    final newGenetics = <String, String>{};
    for (final part in parts) {
      final lower = part.toLowerCase();
      // Match by first letter to known locus keys
      if (lower.startsWith('en')) {
        newGenetics['En'] = part;
      } else {
        bool matched = false;
        for (final key in _locusKeys) {
          if (key == 'En') continue;
          if (lower.startsWith(key.toLowerCase()) && part.length <= 3) {
            newGenetics[key] = part;
            matched = true;
            break;
          }
        }
        if (!matched) {
          final key = part.isNotEmpty ? part[0].toUpperCase() : part;
          newGenetics[key] = part;
        }
      }
    }

    setState(() => genetics = newGenetics);
  }

  /// Save genetics back to rabbit in DB
  Future<void> _saveGeneticsToRabbit() async {
    final geneticsString = genetics.values.join(' ');
    final updated = widget.rabbit.copyWith(genetics: geneticsString);
    await DatabaseService().updateRabbit(updated);
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.rabbit.genetics?.trim() ?? '';
    if (raw.isEmpty && genetics.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayString = genetics.isNotEmpty
        ? genetics.values.join('  ').toUpperCase()
        : raw.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'GENETICS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kNeutral500,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kNeutral100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayString,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: kNeutral900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (genetics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: genetics.length,
                    itemBuilder: (context, index) {
                      String key = genetics.keys.elementAt(index);
                      String value = genetics[key]!;
                      return _buildLocusBox(key, value);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocusBox(String name, String value) {
    return GestureDetector(
      onTap: widget.isEditing ? () => _showEditLocusDialog(name, value) : null,
      child: Container(
        decoration: BoxDecoration(
          color: kNeutral100,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: kNeutral500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              width: double.infinity,
              alignment: Alignment.center,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kNeutral900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLocusDialog(String locus, String currentValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $locus Locus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select genotype for $locus',
              style: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            const SizedBox(height: 16),
            _buildGenotypeOption(locus, '${locus.toUpperCase()}${locus.toUpperCase()}', currentValue),
            _buildGenotypeOption(locus, '${locus.toUpperCase()}${locus.toLowerCase()}', currentValue),
            _buildGenotypeOption(locus, '${locus.toLowerCase()}${locus.toLowerCase()}', currentValue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
        ],
      ),
    );
  }

  Widget _buildGenotypeOption(String locus, String value, String currentValue) {
    bool isSelected = value == currentValue;
    return InkWell(
      onTap: () {
        setState(() {
          genetics[locus] = value;
        });
        _saveGeneticsToRabbit();
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7B6BA0).withOpacity(0.1) : const Color(0xFFF7F7F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFFE9E9E7),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
              color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFF9B9A97),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'monospace',
                color: const Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
