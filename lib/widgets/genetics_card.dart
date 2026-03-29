import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

class GeneticsCard extends StatefulWidget {
  final Rabbit rabbit;
  final bool isEditing;

  const GeneticsCard({Key? key, required this.rabbit, this.isEditing = false}) : super(key: key);

  @override
  State<GeneticsCard> createState() => _GeneticsCardState();
}

class _GeneticsCardState extends State<GeneticsCard> {
  // Default genetics map — will be overwritten from rabbit data
  Map<String, String> genetics = {
    'A': 'Aa',
    'B': 'Bb',
    'C': 'CC',
    'D': 'Dd',
    'E': 'Ee',
    'En': 'enen',
    'V': 'Vv',
    'W': 'ww',
  };

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

  bool isBroken = false;
  bool isViennaMarked = false;
  bool isViennaCarrier = false;

  @override
  void initState() {
    super.initState();
    _parseRabbitGenetics();
    _loadCheckboxState();
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
    if (raw == null || raw.trim().isEmpty) return;

    // Split by spaces or commas
    final parts = raw.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty).toList();

    // Try to match each part to a locus
    final newGenetics = Map<String, String>.from(genetics);
    for (final part in parts) {
      final lower = part.toLowerCase();
      // Match by first letter to known locus keys
      if (lower.startsWith('en')) {
        newGenetics['En'] = part;
      } else {
        for (final key in _locusKeys) {
          if (key == 'En') continue;
          if (lower.startsWith(key.toLowerCase()) && part.length <= 3) {
            newGenetics[key] = part;
            break;
          }
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

  // Load checkbox states from SharedPreferences
  Future<void> _loadCheckboxState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isBroken = prefs.getBool('genetics_broken_${widget.rabbit.id}') ?? false;
      isViennaMarked = prefs.getBool('genetics_vienna_marked_${widget.rabbit.id}') ?? false;
      isViennaCarrier = prefs.getBool('genetics_vienna_carrier_${widget.rabbit.id}') ?? false;
    });
  }

  // Save checkbox state to SharedPreferences
  Future<void> _saveCheckboxState(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('genetics_${key}_${widget.rabbit.id}', value);
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GENETICS',
                  style: const TextStyle(
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
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kNeutral100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    genetics.values.join('  ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: kNeutral900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                SizedBox(height: 16),
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
                SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: kNeutral100),
                ),
                const Text(
                  'MARKERS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kNeutral400,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMarkerChip(
                      'Broken',
                      isBroken,
                      widget.isEditing
                          ? (value) {
                              setState(() => isBroken = value);
                              _saveCheckboxState('broken', value);
                            }
                          : null,
                    ),
                    _buildMarkerChip(
                      'Vienna Marked',
                      isViennaMarked,
                      widget.isEditing
                          ? (value) {
                              setState(() => isViennaMarked = value);
                              _saveCheckboxState('vienna_marked', value);
                            }
                          : null,
                    ),
                    _buildMarkerChip(
                      'Vienna Carrier',
                      isViennaCarrier,
                      widget.isEditing
                          ? (value) {
                              setState(() => isViennaCarrier = value);
                              _saveCheckboxState('vienna_carrier', value);
                            }
                          : null,
                    ),
                  ],
                ),
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

  Widget _buildMarkerChip(String label, bool value, Function(bool)? onToggle) {
    return GestureDetector(
      onTap: onToggle != null ? () => onToggle(!value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: kNeutral200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? kPinkDeep : Colors.transparent,
                border: Border.all(color: value ? kPinkDeep : kNeutral300, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: value
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: value ? kNeutral900 : kNeutral500,
                fontWeight: value ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?>? onChanged, {Color? color}) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(
                color: value ? (color ?? Color(0xFF787774)) : Color(0xFFD1D5DB),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(3),
              color: value ? (color ?? Color(0xFF787774)) : Colors.transparent,
            ),
            child: value
                ? Icon(
                    PhosphorIcons.check(PhosphorIconsStyle.bold),
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF787774),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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
              style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            SizedBox(height: 16),
            _buildGenotypeOption(locus, '${locus.toUpperCase()}${locus.toUpperCase()}', currentValue),
            _buildGenotypeOption(locus, '${locus.toUpperCase()}${locus.toLowerCase()}', currentValue),
            _buildGenotypeOption(locus, '${locus.toLowerCase()}${locus.toLowerCase()}', currentValue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
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
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF6366F1).withOpacity(0.1) : Color(0xFFF7F7F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Color(0xFF6366F1) : Color(0xFFE9E9E7),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
              color: isSelected ? Color(0xFF6366F1) : Color(0xFF9B9A97),
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'monospace',
                color: Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
