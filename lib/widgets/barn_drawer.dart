import 'package:flutter/material.dart';
import '../models/barn.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BarnDrawer extends StatelessWidget {
  final List<Barn> barns;
  final String? locationFilter;
  final Function(String?) onLocationSelected;

  const BarnDrawer({
    required this.barns,
    this.locationFilter,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone), color: Color(0xFF14B8A6)),
                SizedBox(width: 8),
                Text(
                  'BARN & CAGES',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.all(16),
              children: [
                _buildLocationItem('All Locations', null, context),
                _buildLocationItem('Unassigned', 'Unassigned', context),
                Divider(),
                ...barns.map((barn) => _buildBarnSection(barn, context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, String? value, BuildContext context) {
    final isActive = locationFilter == value;
    return GestureDetector(
      onTap: () => onLocationSelected(value),
      child: Container(
        margin: EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFE8F5F3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Color(0xFF0F7B6C) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value == null ? Icons.circle : Icons.warning_amber_rounded,
              size: 20,
              color: isActive ? Color(0xFF0F7B6C) : Color(0xFF787774),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Color(0xFF0F7B6C) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarnSection(Barn barn, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            barn.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF37352F),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...barn.rows.map((row) => _buildLocationItem(row.name, row.name, context)),
        SizedBox(height: 8),
      ],
    );
  }
}