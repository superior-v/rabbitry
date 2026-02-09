import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeneticsCard extends StatefulWidget {
  final Rabbit rabbit;

  const GeneticsCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<GeneticsCard> createState() => _GeneticsCardState();
}

class _GeneticsCardState extends State<GeneticsCard> {
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

  bool isBroken = false;
  bool isViennaMarked = false;
  bool isViennaCarrier = false;

  @override
  void initState() {
    super.initState();
    _loadCheckboxState();
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
              children: [
                Text(
                  'GENETICS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
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
                Text(
                  genetics.values.join(' '),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                    color: Color(0xFF37352F),
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
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
                Row(
                  children: [
                    _buildCheckbox('Broken', isBroken, (value) {
                      setState(() => isBroken = value ?? false);
                      _saveCheckboxState('broken', value ?? false);
                    }, color: Color(0xFF0F7B6C)),
                    SizedBox(width: 16),
                    _buildCheckbox('Vienna Marked', isViennaMarked, (value) {
                      setState(() => isViennaMarked = value ?? false);
                      _saveCheckboxState('vienna_marked', value ?? false);
                    }, color: Color(0xFF0F7B6C)),
                  ],
                ),
                SizedBox(height: 8),
                _buildCheckbox('Vienna Carrier', isViennaCarrier, (value) {
                  setState(() => isViennaCarrier = value ?? false);
                  _saveCheckboxState('vienna_carrier', value ?? false);
                }, color: Color(0xFF0F7B6C)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocusBox(String name, String value) {
    return GestureDetector(
      onTap: () => _showEditLocusDialog(name, value),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF7F7F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFE9E9E7)),
        ),
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF787774),
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged, {Color? color}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
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
        Navigator.pop(context);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF0F7B6C).withOpacity(0.1) : Color(0xFFF7F7F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFE9E9E7),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
              color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF9B9A97),
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
