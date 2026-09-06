import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../constants/app_colors.dart';

class RegistrationCard extends StatelessWidget {
  final Rabbit rabbit;
  const RegistrationCard({Key? key, required this.rabbit}) : super(key: key);

  Color get _primaryColor => rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;

  @override
  Widget build(BuildContext context) {
    final int legs = rabbit.grandChampionLegs ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildInfoRow(
            label: 'Legs',
            value: legs > 0 ? '$legs / 3' : '-',
            isLast: false,
            rowIndex: 0,
          ),
          _buildInfoRow(
            label: 'Regn. No.',
            value: rabbit.registrationNumber?.isNotEmpty == true
                ? rabbit.registrationNumber!
                : '-',
            isLast: false,
            rowIndex: 1,
          ),
          _buildInfoRow(
            label: 'GC No.',
            value: rabbit.grandChampionNumber?.isNotEmpty == true
                ? rabbit.grandChampionNumber!
                : '-',
            isLast: true,
            rowIndex: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required bool isLast,
    int rowIndex = 0,
  }) {
    final bool isEven = rowIndex.isEven;
    final Color rowBg = isEven ? Colors.white : const Color(0xFFF5F3F8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: rowBg,
        border: isLast ? null : const Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: kNeutral600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: kNeutral900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
