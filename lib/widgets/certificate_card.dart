import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';

class CertificateCard extends StatefulWidget {
  final Rabbit rabbit;
  const CertificateCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<CertificateCard> {
  final DatabaseService _db = DatabaseService();
  String _sireName = 'Not set';
  String _damName = 'Not set';

  // Theme Helpers
  Color get _primaryColor => widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;
  Color get _washColor => widget.rabbit.type == RabbitType.buck ? kBlueWash : kPinkWash;

  @override
  void initState() {
    super.initState();
    _loadParentNames();
  }

  Future<void> _loadParentNames() async {
    try {
      if (widget.rabbit.sireId?.isNotEmpty ?? false) {
        final sire = await _db.getRabbit(widget.rabbit.sireId!);
        if (sire != null && mounted) setState(() => _sireName = sire.name);
      }
      if (widget.rabbit.damId?.isNotEmpty ?? false) {
        final dam = await _db.getRabbit(widget.rabbit.damId!);
        if (dam != null && mounted) setState(() => _damName = dam.name);
      }
    } catch (e) {}
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
                Icon(PhosphorIconsFill.certificate, size: 18, color: kNeutral500),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CERTIFICATE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.6),
                  ),
                ),
                Text(
                  'ARBA OFFICIAL',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _primaryColor.withOpacity(0.6), letterSpacing: 0.5),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kNeutral100),
              ),
              child: Column(
                children: [
                  Text(
                    widget.rabbit.breed.toUpperCase(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _primaryColor, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 16),
                  _buildCertRow('Name', widget.rabbit.name),
                  _buildCertRow('ID', widget.rabbit.id),
                  _buildCertRow('Registration #', widget.rabbit.registrationNumber ?? 'Not set'),
                  _buildCertRow('Color', widget.rabbit.color ?? 'Not set'),
                  const Divider(height: 24, color: kNeutral100),
                  _buildCertRow('Sire', _sireName),
                  _buildCertRow('Dam', _damName),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(100)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsBold.printer, size: 14, color: kNeutral600),
                          const SizedBox(width: 4),
                          const Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNeutral600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(100)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsBold.shareNetwork, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          const Text('Share', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral400)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }
}
