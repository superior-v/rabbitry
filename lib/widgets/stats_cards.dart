import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsCards extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onViewAllTransactions;

  const StatsCards({
    Key? key,
    required this.rabbit,
    this.onAddTransaction,
    this.onViewAllTransactions,
  }) : super(key: key);

  @override
  State<StatsCards> createState() => _StatsCardsState();
}

class _StatsCardsState extends State<StatsCards> {
  String _selectedTimeRange = 'M'; // W, M, Y

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PERFORMANCE Section
        const Text(
          'PERFORMANCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _buildPerformanceGrid(),
        const SizedBox(height: 24),

        // WEIGHT TREND Section
        _buildWeightTrendCard(),
        const SizedBox(height: 24),

        // KIT OUTCOMES Section
        _buildKitOutcomesCard(),
        const SizedBox(height: 24),

        // LITTER SIZES Section
        _buildLitterSizesCard(),
        const SizedBox(height: 24),

        // FINANCIALS Section
        _buildFinancialsCard(),
      ],
    );
  }

  Widget _buildPerformanceGrid() {
    return Row(
      children: [
        Expanded(child: _buildPerformanceBox('90.5%', 'Survival', const Color(0xFF6B9E78))),
        const SizedBox(width: 12),
        Expanded(child: _buildPerformanceBox('8.4', 'Avg Litter', const Color(0xFF0F7B6C))),
        const SizedBox(width: 12),
        Expanded(child: _buildPerformanceBox('31d', 'Avg Gest.', const Color(0xFF5B8AD0))),
        const SizedBox(width: 12),
        Expanded(child: _buildPerformanceBox('8w', 'Avg Wean', const Color(0xFF9C6ADE))),
      ],
    );
  }

  Widget _buildPerformanceBox(String value, String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF787774),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTrendCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weight Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37352F),
                ),
              ),
              Row(
                children: [
                  _buildTimeTab('W', _selectedTimeRange == 'W'),
                  const SizedBox(width: 8),
                  _buildTimeTab('M', _selectedTimeRange == 'M'),
                  const SizedBox(width: 8),
                  _buildTimeTab('Y', _selectedTimeRange == 'Y'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 12,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)} lbs',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = _getTimeLabels();
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[value.toInt()],
                              style: const TextStyle(fontSize: 10, color: Color(0xFF9B9A97)),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _getBarData(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFF787774)),
                SizedBox(width: 8),
                Text(
                  'Target: 9.0 - 11.0 lbs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF787774),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getTimeLabels() {
    switch (_selectedTimeRange) {
      case 'W':
        return [
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun'
        ];
      case 'M':
        return [
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
          'Jan',
          'Feb'
        ];
      case 'Y':
        return [
          '2020',
          '2021',
          '2022',
          '2023',
          '2024',
          '2025',
          '2026'
        ];
      default:
        return [];
    }
  }

  List<BarChartGroupData> _getBarData() {
    switch (_selectedTimeRange) {
      case 'W':
        return [
          _buildBarGroup(0, 9.4),
          _buildBarGroup(1, 9.5),
          _buildBarGroup(2, 9.4),
          _buildBarGroup(3, 9.6),
          _buildBarGroup(4, 9.5),
          _buildBarGroup(5, 9.7),
          _buildBarGroup(6, 9.5),
        ];
      case 'M':
        return [
          _buildBarGroup(0, 8.0),
          _buildBarGroup(1, 8.3),
          _buildBarGroup(2, 8.5),
          _buildBarGroup(3, 8.6),
          _buildBarGroup(4, 9.0),
          _buildBarGroup(5, 9.3),
          _buildBarGroup(6, 9.5),
          _buildBarGroup(7, 10.0),
          _buildBarGroup(8, 10.5),
        ];
      case 'Y':
        return [
          _buildBarGroup(0, 5.0),
          _buildBarGroup(1, 6.5),
          _buildBarGroup(2, 7.8),
          _buildBarGroup(3, 8.5),
          _buildBarGroup(4, 9.2),
          _buildBarGroup(5, 9.8),
          _buildBarGroup(6, 10.5),
        ];
      default:
        return [];
    }
  }

  BarChartGroupData _buildBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFF0F7B6C),
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildTimeTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeRange = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F7B6C).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF0F7B6C) : const Color(0xFFE9E9E7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF0F7B6C) : const Color(0xFF787774),
          ),
        ),
      ),
    );
  }

  Widget _buildKitOutcomesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kit Outcomes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37352F),
            ),
          ),
          const SizedBox(height: 16),
          _buildOutcomeRow('Sold', 28, const Color(0xFF0F7B6C), 0.65),
          const SizedBox(height: 12),
          _buildOutcomeRow('Breeder', 8, const Color(0xFF5B8AD0), 0.19),
          const SizedBox(height: 12),
          _buildOutcomeRow('Butchered', 4, const Color(0xFF9C6ADE), 0.09),
          const SizedBox(height: 12),
          _buildOutcomeRow('Died', 2, const Color(0xFFCB8347), 0.05),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Kits Born',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                  ),
                ),
                const Text(
                  '42',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF37352F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeRow(String label, int count, Color color, double percentage) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF37352F),
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37352F),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(percentage * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF787774),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: const Color(0xFFF7F7F5),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildLitterSizesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Litter Sizes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37352F),
            ),
          ),
          const SizedBox(height: 16),
          _buildLitterBar('L-105', 8, 0.88, 'Nursing', const Color(0xFF5B8AD0)),
          const SizedBox(height: 12),
          _buildLitterBar('L-098', 7, 0.77, 'Weaned', const Color(0xFF6B9E78)),
          const SizedBox(height: 12),
          _buildLitterBar('L-091', 6, 0.66, 'Grow-out', const Color(0xFF9C6ADE)),
          const SizedBox(height: 12),
          _buildLitterBar('L-085', 9, 1.0, 'Mature', const Color(0xFF0F7B6C)),
        ],
      ),
    );
  }

  Widget _buildLitterBar(String litterId, int count, double progress, String status, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                litterId,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37352F),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFF7F7F5),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
                      minHeight: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 20,
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF37352F),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 62),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FINANCIALS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: widget.onAddTransaction,
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF0F7B6C)),
                    SizedBox(width: 4),
                    Text(
                      'ADD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F7B6C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFinancialBox('+\$450', 'INCOME', const Color(0xFF6B9E78)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialBox('-\$125', 'EXPENSES', const Color(0xFFCB8347)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialBox('+\$325', 'NET', const Color(0xFF0F7B6C)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'RECENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF787774),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildTransactionItem('Jan 15', 'Feed Allocation', 'Monthly pellet cost', '-\$12.50', const Color(0xFFCB8347)),
          const Divider(height: 24, color: Color(0xFFF7F7F5)),
          _buildTransactionItem('Jan 10', 'Medication', 'Pen G for sniffles', '-\$8.00', const Color(0xFFCB8347)),
          const Divider(height: 24, color: Color(0xFFF7F7F5)),
          _buildTransactionItem('Dec 20', 'Sale (3x)', 'Sold to Happy Homestead', '+\$135.00', const Color(0xFF6B9E78)),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: widget.onViewAllTransactions,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All Transactions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F7B6C),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16, color: Color(0xFF0F7B6C)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF787774),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String date, String title, String subtitle, String amount, Color amountColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9B9A97),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37352F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9B9A97),
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
