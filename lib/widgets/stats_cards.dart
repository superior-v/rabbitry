import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/transaction.dart' as finance_model;
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
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
  final DatabaseService _db = DatabaseService();
  String _selectedTimeRange = 'M'; // W, M, Y

  // Loaded data
  List<Litter> _litters = [];
  List<Map<String, dynamic>> _weightHistory = [];
  List<finance_model.Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      // Load litters (as doe or buck)
      final littersData = await _db.getLittersByDoe(widget.rabbit.id);
      final db = await _db.database;
      final sireLitters = await db.query(
        'litters',
        where: 'buckId = ?',
        whereArgs: [
          widget.rabbit.id
        ],
        orderBy: 'breedDate DESC',
      );
      final allLittersData = [
        ...littersData,
        ...sireLitters
      ];
      final seenIds = <String>{};
      final uniqueLitters = allLittersData.where((l) {
        final id = l['id'] as String?;
        if (id == null || seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();
      final litters = uniqueLitters.map((data) => Litter.fromMap(data)).toList();
      litters.sort((a, b) => (b.kindleDate ?? b.breedDate).compareTo(a.kindleDate ?? a.breedDate));

      // Load weight history
      final weightHistory = await _db.getWeightHistory(widget.rabbit.id);

      // Load transactions
      final transactions = await _db.getTransactionsByRabbit(widget.rabbit.id);

      if (mounted) {
        setState(() {
          _litters = litters;
          _weightHistory = weightHistory;
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stats data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
    // Survival rate
    String survival = '--';
    if (_litters.isNotEmpty) {
      final totalBorn = _litters.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
      final totalAlive = _litters.fold<int>(0, (sum, l) => sum + (l.aliveKits ?? 0));
      if (totalBorn > 0) {
        survival = '${((totalAlive / totalBorn) * 100).round()}%';
      }
    }

    // Avg litter size
    String avgLitter = '--';
    if (_litters.isNotEmpty) {
      final littersWithKits = _litters.where((l) => (l.totalKits ?? 0) > 0).toList();
      if (littersWithKits.isNotEmpty) {
        final total = littersWithKits.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
        avgLitter = (total / littersWithKits.length).toStringAsFixed(1);
      }
    }

    // Avg gestation
    String avgGest = '--';
    if (_litters.isNotEmpty) {
      final littersWithKindle = _litters.where((l) => l.kindleDate != null).toList();
      if (littersWithKindle.isNotEmpty) {
        final totalDays = littersWithKindle.fold<int>(
          0,
          (sum, l) => sum + l.kindleDate!.difference(l.breedDate).inDays,
        );
        avgGest = '${(totalDays / littersWithKindle.length).round()}d';
      }
    }

    // Avg wean age
    String avgWean = '--';
    if (_litters.isNotEmpty) {
      final littersWithWean = _litters.where((l) => l.weanDate != null && l.kindleDate != null).toList();
      if (littersWithWean.isNotEmpty) {
        final totalDays = littersWithWean.fold<int>(
          0,
          (sum, l) => sum + l.weanDate!.difference(l.kindleDate!).inDays,
        );
        avgWean = '${(totalDays / littersWithWean.length).round()}d';
      }
    }

    return Row(
      children: [
        Expanded(child: _buildPerformanceBox(survival, 'Survival', const Color(0xFF6B9E78))),
        const SizedBox(width: 12),
        Expanded(child: _buildPerformanceBox(avgLitter, 'Avg Litter', const Color(0xFF0F7B6C))),
        const SizedBox(width: 12),
        Expanded(child: _buildPerformanceBox(avgGest, 'Avg Gest.', const Color(0xFF5B8AD0))),
        const SizedBox(width: 12),
        Expanded(child: _buildPerformanceBox(avgWean, 'Avg Wean', const Color(0xFF9C6ADE))),
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
            child: _getFilteredWeights().isEmpty
                ? const Center(
                    child: Text(
                      'No weight data yet',
                      style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getFilteredWeights().isEmpty ? 12 : (_getFilteredWeights().map((w) => (w['weight'] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toStringAsFixed(1)} ${FormatUtils.weightUnit}',
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFF787774)),
                SizedBox(width: 8),
                Text(
                  'Target: 9.0 - 11.0 ${FormatUtils.weightUnit}',
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
    final filtered = _getFilteredWeights();
    if (filtered.isEmpty) return [];
    return filtered.map((w) {
      final date = DateTime.parse(w['date'] as String);
      return FormatUtils.formatDateChart(date, _selectedTimeRange);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredWeights() {
    if (_weightHistory.isEmpty) return [];
    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedTimeRange) {
      case 'W':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case 'M':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case 'Y':
        cutoff = now.subtract(const Duration(days: 365));
        break;
      default:
        cutoff = now.subtract(const Duration(days: 30));
    }
    final filtered = _weightHistory.where((w) {
      final date = DateTime.parse(w['date'] as String);
      return date.isAfter(cutoff);
    }).toList();
    // Sort oldest first for chart display
    filtered.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return filtered;
  }

  List<BarChartGroupData> _getBarData() {
    final filtered = _getFilteredWeights();
    return List.generate(filtered.length, (i) {
      final weight = (filtered[i]['weight'] as num).toDouble();
      return _buildBarGroup(i, weight);
    });
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
    // Count kit statuses across all litters
    int sold = 0;
    int breeder = 0;
    int butchered = 0;
    int died = 0;
    int totalKitsBorn = 0;

    for (final litter in _litters) {
      totalKitsBorn += litter.totalKits ?? 0;
      for (final kit in litter.kits) {
        switch (kit.status) {
          case 'Sold':
            sold++;
            break;
          case 'Breeder':
            breeder++;
            break;
          case 'Butchered':
            butchered++;
            break;
          case 'Dead':
          case 'Cull':
            died++;
            break;
        }
      }
    }

    final totalOutcomes = sold + breeder + butchered + died;

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
          _buildOutcomeRow('Sold', sold, const Color(0xFF0F7B6C), totalOutcomes > 0 ? sold / totalOutcomes : 0),
          const SizedBox(height: 12),
          _buildOutcomeRow('Breeder', breeder, const Color(0xFF5B8AD0), totalOutcomes > 0 ? breeder / totalOutcomes : 0),
          if (SettingsService.instance.meatProductionEnabled) ...[
            const SizedBox(height: 12),
            _buildOutcomeRow('Butchered', butchered, const Color(0xFF9C6ADE), totalOutcomes > 0 ? butchered / totalOutcomes : 0),
          ],
          const SizedBox(height: 12),
          _buildOutcomeRow('Died', died, const Color(0xFFCB8347), totalOutcomes > 0 ? died / totalOutcomes : 0),
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
                Text(
                  '$totalKitsBorn',
                  style: const TextStyle(
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
    // Find max litter size for progress bar scaling
    final maxSize = _litters.isEmpty ? 1 : _litters.map((l) => l.totalKits ?? 0).reduce((a, b) => a > b ? a : b);

    final statusColors = {
      'nursing': const Color(0xFF0F7B6C),
      'Nursing': const Color(0xFF0F7B6C),
      'weaned': const Color(0xFF5B8AD0),
      'Weaned': const Color(0xFF5B8AD0),
      'growing': const Color(0xFF6B9E78),
      'Growing': const Color(0xFF6B9E78),
      'archived': const Color(0xFF787774),
      'Archived': const Color(0xFF787774),
    };

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
          if (_litters.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No litter data available',
                  style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
                ),
              ),
            )
          else
            ...List.generate(_litters.length, (index) {
              final litter = _litters[index];
              final kitCount = litter.totalKits ?? 0;
              final progress = maxSize > 0 ? kitCount / maxSize : 0.0;
              final status = litter.status.isNotEmpty ? litter.status[0].toUpperCase() + litter.status.substring(1) : 'Unknown';
              final statusColor = statusColors[litter.status] ?? const Color(0xFF787774);

              // Use litter ID shortened
              final litterId = litter.id.length > 5 ? litter.id.substring(0, 5) : litter.id;

              return Padding(
                padding: EdgeInsets.only(bottom: index < _litters.length - 1 ? 16 : 0),
                child: _buildLitterBar('L-${index + 1}', kitCount, progress, status, statusColor),
              );
            }),
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
    // Compute income, expenses, net from transactions
    double income = 0;
    double expenses = 0;
    for (final t in _transactions) {
      if (t.type == finance_model.TransactionType.income) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }
    final net = income - expenses;

    // Get recent transactions (last 5)
    final recentTransactions = List<finance_model.Transaction>.from(_transactions);
    recentTransactions.sort((a, b) => b.date.compareTo(a.date));
    final recent = recentTransactions.take(5).toList();

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
                child: _buildFinancialBox(FormatUtils.formatCurrencyShort(income), 'INCOME', const Color(0xFF6B9E78)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialBox(FormatUtils.formatCurrencyShort(expenses), 'EXPENSES', const Color(0xFFCB8347)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialBox(
                  FormatUtils.formatCurrencySigned(net),
                  'NET',
                  net >= 0 ? const Color(0xFF0F7B6C) : const Color(0xFFCB8347),
                ),
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
          if (recent.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No transactions yet',
                  style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
                ),
              ),
            )
          else
            ...recent.map((t) {
              final isIncome = t.type == finance_model.TransactionType.income;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTransactionItem(
                  FormatUtils.formatDateShort(t.date),
                  t.categoryName,
                  t.description ?? '',
                  '${isIncome ? '+' : '-'}${FormatUtils.formatCurrencyShort(t.amount)}',
                  isIncome ? const Color(0xFF6B9E78) : const Color(0xFFCB8347),
                ),
              );
            }),
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
