import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../constants/app_colors.dart';

class RegistrationCard extends StatefulWidget {
  final Rabbit rabbit;
  const RegistrationCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<RegistrationCard> createState() => _RegistrationCardState();
}

class _RegistrationCardState extends State<RegistrationCard> {
  late List<bool> gcLegs;

  @override
  void initState() {
    super.initState();
    final legs = widget.rabbit.grandChampionLegs ?? 0;
    gcLegs = List.generate(3, (i) => i < legs);
  }

  // Theme Helpers
  Color get _primaryColor => widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;

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
                    'REGISTRATION',
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

          _buildRegRow('Registration #', widget.rabbit.registrationNumber ?? 'Not set', PhosphorIconsFill.hash),
          _buildRegRow('Grand Champion #', widget.rabbit.grandChampionNumber ?? 'Not set', PhosphorIconsFill.star),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsFill.medal, size: 18, color: kNeutral400),
                    const SizedBox(width: 12),
                    const Text(
                      'GC Legs',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ...List.generate(3, (index) => _buildLegBadge(gcLegs[index])),
                    const SizedBox(width: 10),
                    Text(
                      '${gcLegs.where((l) => l).length}/3',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
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

  Widget _buildRegRow(String label, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: kNeutral400),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          Text(
            val,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegBadge(bool earned) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? _primaryColor : kNeutral100,
        border: Border.all(
          color: earned ? _primaryColor : kNeutral200,
          width: 1.5,
        ),
      ),
    );
  }
}
