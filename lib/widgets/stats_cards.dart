import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/transaction.dart' as finance_model;
import '../services/database_service.dart';

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
  String _selectedWeightRange = 'M';
  String _selectedLitterRange = 'All';

  List<Litter> _litters = [];
  List<Map<String, dynamic>> _weightHistory = [];
  List<finance_model.Transaction> _transactions = [];
  bool _isLoading = true;

  // Consistent Figma colors
  static const Color _kTextDark = Color(0xFF1E293B);
  static const Color _kTextMuted = Color(0xFF64748B);
  static const Color _kTextLight = Color(0xFF94A3B8);
  static const Color _kCardBorder = Color(0xFFE2E8F0);
  static const Color _kGreyTileBg = Color(0xFFF8FAFC);
  static const Color _kBlueAccent = Color(0xFF0284C7);
  static const Color _kBlueBadgeBg = Color(0xFFE1F3FE);
  static const Color _kHeaderBannerBg = Color(0xFFD8EEFB);

  // Segment colors for Kit Outcomes
  static const Color _kColorSold = Color(0xFF0284C7);
  static const Color _kColorBreeder = Color(0xFF38BDF8);
  static const Color _kColorCull = Color(0xFF7DD3FC);
  static const Color _kColorDied = Color(0xFFBAE6FD);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final littersData = await _db.getLittersByDoe(widget.rabbit.id);
      final db = await _db.database;
      final sireLitters = await db.query(
        'litters',
        where: 'buckId = ?',
        whereArgs: [widget.rabbit.id],
        orderBy: 'breedDate DESC',
      );
      final allLittersData = [...littersData, ...sireLitters];
      final seenIds = <String>{};
      final uniqueLitters = allLittersData.where((l) {
        final id = l['id'] as String?;
        if (id == null || seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();
      final litters = uniqueLitters.map((data) => Litter.fromMap(data)).toList();
      litters.sort((a, b) => (b.kindleDate ?? b.breedDate).compareTo(a.kindleDate ?? a.breedDate));

      final weightHistory = await _db.getWeightHistory(widget.rabbit.id);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kBlueAccent));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKitOutcomesCard(),
        const SizedBox(height: 16),
        _buildQuickStatsGrid6(),
        const SizedBox(height: 16),
        _buildLitterSizesCard(),
        const SizedBox(height: 16),
        _buildWeightTrendCard(),
        const SizedBox(height: 16),
        _buildFinancialsCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==========================================
  // CARD 1: KIT OUTCOMES
  // ==========================================
  Widget _buildKitOutcomesCard() {
    int sold = 0, breeder = 0, cull = 0, died = 0, total = 0;
    for (var l in _litters) {
      total += l.totalKits ?? 0;
      for (var k in l.kits) {
        if (k.status == 'Sold') {
          sold++;
        } else if (k.status == 'Breeder') {
          breeder++;
        } else if (k.status == 'Cull' || k.status == 'Butchered') {
          cull++;
        } else if (k.status == 'Dead' || k.status == 'Died') {
          died++;
        }
      }
      if (l.kits.isEmpty && l.deadKits != null) {
        died += l.deadKits!;
      }
    }

    final int alive = (total - died).clamp(0, total);
    final int survivalRate = total > 0 ? ((alive / total) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('KIT OUTCOMES'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'total kits',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kTextMuted,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBlueBadgeBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$survivalRate% survival',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kBlueAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Horizontal multi-colored progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (sold > 0) Expanded(flex: sold, child: Container(color: _kColorSold)),
                  if (breeder > 0) Expanded(flex: breeder, child: Container(color: _kColorBreeder)),
                  if (cull > 0) Expanded(flex: cull, child: Container(color: _kColorCull)),
                  if (died > 0) Expanded(flex: died, child: Container(color: _kColorDied)),
                  if (total == 0) Expanded(child: Container(color: const Color(0xFFE2E8F0))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _LegendDot(label: 'Sold', color: _kColorSold),
              _LegendDot(label: 'Breeder', color: _kColorBreeder),
              _LegendDot(label: 'Culled', color: _kColorCull),
              _LegendDot(label: 'Died', color: _kColorDied),
            ],
          ),
          const SizedBox(height: 16),
          // 4 Metric Tiles
          Row(
            children: [
              Expanded(child: _buildMetricTile('$sold', 'SOLD')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('$breeder', 'BREEDER')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('$cull', 'CULL')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('$died', 'DIED')),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD 2: 6 GRADIENT METRIC CARDS
  // ==========================================
  Widget _buildQuickStatsGrid6() {
    int soldKitsCount = 0;
    for (var l in _litters) {
      for (var k in l.kits) {
        if (k.status == 'Sold') soldKitsCount++;
      }
    }

    String avgGest = '-';
    final littersWithKindle = _litters.where((l) => l.kindleDate != null).toList();
    if (littersWithKindle.isNotEmpty) {
      final totalDays = littersWithKindle.fold<int>(0, (sum, l) => sum + l.kindleDate!.difference(l.breedDate).inDays);
      avgGest = '${(totalDays / littersWithKindle.length).round()}d';
    } else if (_litters.isNotEmpty) {
      avgGest = '31d';
    }

    double totalSales = 0;
    for (var t in _transactions) {
      if (t.type == finance_model.TransactionType.income) {
        totalSales += t.amount;
      }
    }

    String avgLitter = '0.0';
    if (_litters.isNotEmpty) {
      final littersWithKits = _litters.where((l) => (l.totalKits ?? 0) > 0).toList();
      if (littersWithKits.isNotEmpty) {
        final total = littersWithKits.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
        avgLitter = (total / littersWithKits.length).toStringAsFixed(1);
      }
    }

    final int littersCount = _litters.length;
    final int soldKits = soldKitsCount;
    final int missedLitters = _litters.where((l) => l.status == 'Not Taken' || (l.notes != null && l.notes!.toLowerCase().contains('missed'))).length;
    final String salesDisplay = '\$${totalSales.toInt()}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildGradientCard('$littersCount', 'LITTERS')),
              const SizedBox(width: 8),
              Expanded(child: _buildGradientCard('$soldKits', 'SOLD KITS')),
              const SizedBox(width: 8),
              Expanded(child: _buildGradientCard(avgGest, 'GESTATION')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildGradientCard('$missedLitters', 'MISSED LITTERS')),
              const SizedBox(width: 8),
              Expanded(child: _buildGradientCard(salesDisplay, 'SALES')),
              const SizedBox(width: 8),
              Expanded(child: _buildGradientCard(avgLitter, 'AVG LITTER SZ')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF86DAFF),
            Color(0xFFF0F9FF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD 3: LITTER SIZES
  // ==========================================
  Widget _buildLitterSizesCard() {
    final validLitters = _litters.where((l) => (l.totalKits ?? 0) > 0).toList();
    List<double> litterData = validLitters.map((l) => (l.totalKits ?? 0).toDouble()).toList();
    if (litterData.isEmpty) {
      litterData = [0];
    }

    final double avg = validLitters.isNotEmpty ? litterData.reduce((a, b) => a + b) / litterData.length : 0.0;
    final double smallest = validLitters.isNotEmpty ? litterData.reduce((a, b) => a < b ? a : b) : 0.0;
    final double largest = validLitters.isNotEmpty ? litterData.reduce((a, b) => a > b ? a : b) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardHeader('LITTER SIZES'),
              Row(
                children: ['All', '6M'].map((t) => _buildToggle(
                  t,
                  _selectedLitterRange == t,
                  (v) => setState(() => _selectedLitterRange = v),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'avg kits',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kTextMuted,
                ),
              ),
              const SizedBox(width: 10),
              _buildTrendBadge(2.0),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: LineChart(_getLitterSizesLineChartData(litterData, avg)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricTile('${smallest.toInt()}', 'SMALLEST')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile(avg.toStringAsFixed(1), 'AVERAGE')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('${largest.toInt()}', 'LARGEST')),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _getLitterSizesLineChartData(List<double> data, double avg) {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i >= 0 && i < data.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'L-0${i + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _kTextLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: avg,
            color: _kBlueAccent.withOpacity(0.4),
            strokeWidth: 1.5,
            dashArray: [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _kBlueAccent.withOpacity(0.8),
              ),
              labelResolver: (line) => 'avg ${avg.toStringAsFixed(1)}',
            ),
          ),
        ],
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
          isCurved: true,
          curveSmoothness: 0.35,
          color: _kBlueAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) => FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2.5,
              strokeColor: _kBlueAccent,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _kBlueAccent.withOpacity(0.2),
                _kBlueAccent.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CARD 4: WEIGHT TREND
  // ==========================================
  Widget _buildWeightTrendCard() {
    final filtered = _getFilteredWeights();
    double current = 0.0, diff = 0.0;
    if (filtered.isNotEmpty) {
      current = (filtered.last['weight'] as num).toDouble();
      if (filtered.length > 1) {
        diff = current - (filtered[filtered.length - 2]['weight'] as num).toDouble();
      }
    } else if (widget.rabbit.weight != null) {
      current = widget.rabbit.weight!;
    }

    final double minW = filtered.isNotEmpty ? _getMinWeight(filtered) : current;
    final double avgW = filtered.isNotEmpty ? _getAvgWeight(filtered) : current;
    final double maxW = filtered.isNotEmpty ? _getMaxWeight(filtered) : current;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardHeader('WEIGHT TREND'),
              Row(
                children: ['W', 'M', 'Y'].map((t) => _buildToggle(
                  t,
                  _selectedWeightRange == t,
                  (v) => setState(() => _selectedWeightRange = v),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                current.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'lbs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kTextMuted,
                ),
              ),
              const SizedBox(width: 10),
              _buildTrendBadge(diff),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: LineChart(_getWeightLineChartData(filtered)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricTile(minW.toStringAsFixed(1), 'LOW (LBS)')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile(avgW.toStringAsFixed(1), 'AVERAGE')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile(maxW.toStringAsFixed(1), 'PEAK')),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(PhosphorIconsFill.target, size: 14, color: _kBlueAccent),
                SizedBox(width: 6),
                Text(
                  'Target: 9.0 – 11.0 lbs',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _getWeightLineChartData(List<Map<String, dynamic>> data) {
    List<FlSpot> spots;
    List<String> labels;

    if (data.isNotEmpty) {
      spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), (data[i]['weight'] as num).toDouble()));
      labels = data.map((d) => DateFormat('MMM').format(DateTime.parse(d['date']))).toList();
    } else {
      spots = const [
        FlSpot(0, 0),
      ];
      labels = const ['-'];
    }

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i >= 0 && i < labels.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      color: _kTextLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: _kBlueAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) => FlDotCirclePainter(
              radius: 4,
              color: Colors.white,
              strokeWidth: 2.5,
              strokeColor: _kBlueAccent,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _kBlueAccent.withOpacity(0.2),
                _kBlueAccent.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CARD 5: FINANCIALS
  // ==========================================
  Widget _buildFinancialsCard() {
    double income = 0, expenses = 0;
    for (var t in _transactions) {
      if (t.type == finance_model.TransactionType.income) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }

    final double net = income - expenses;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF6EEFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FINANCIALS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F4F56),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onAddTransaction,
                  child: Row(
                    children: const [
                      Text(
                        'ADD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kBlueAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.add, size: 14, color: _kBlueAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 3 Financial Summary Boxes
                Row(
                  children: [
                    Expanded(
                      child: _buildFinanceBox(
                        '+\$${income.toInt()}',
                        'INCOME',
                        const Color(0xFFF0FDF4),
                        const Color(0xFFDCFCE7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFinanceBox(
                        '-\$${expenses.toInt()}',
                        'EXPENSES',
                        const Color(0xFFFEF2F2),
                        const Color(0xFFFEE2E2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFinanceBox(
                        '${net >= 0 ? '+' : '-'}\$${net.abs().toInt()}',
                        'NET',
                        const Color(0xFFF0F9FF),
                        const Color(0xFFE0F2FE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Recent transactions
                if (_transactions.isNotEmpty)
                  ..._transactions.take(2).map((t) => _buildTransactionItem(t))
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        'No transactions recorded',
                        style: TextStyle(fontSize: 13, color: _kTextMuted),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: widget.onViewAllTransactions,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'View All Transactions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kBlueAccent,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: _kBlueAccent),
                      ],
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

  Widget _buildFinanceBox(String val, String label, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _kTextMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(finance_model.Transaction t) {
    final isIncome = t.type == finance_model.TransactionType.income;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreyTileBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.description ?? t.categoryName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d').format(t.date),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kTextLight,
                ),
              ),
            ],
          ),
          Text(
            '${isIncome ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleTransactionItem(String title, String date, double amount) {
    final isIncome = amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreyTileBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kTextLight,
                ),
              ),
            ],
          ),
          Text(
            '${isIncome ? '+' : '-'}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED WIDGET HELPERS
  // ==========================================
  Widget _buildCardHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4F4F56),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMetricTile(String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _kGreyTileBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _kTextMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool isActive, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? _kBlueBadgeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isActive ? _kBlueAccent : _kTextLight,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendBadge(double val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kBlueBadgeBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            val >= 0 ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown,
            size: 12,
            color: _kBlueAccent,
          ),
          const SizedBox(width: 4),
          Text(
            '${val >= 0 ? '+' : ''}$val',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _kBlueAccent,
            ),
          ),
        ],
      ),
    );
  }

  // Helpers
  List<Map<String, dynamic>> _getFilteredWeights() {
    if (_weightHistory.isEmpty) return [];
    var f = List<Map<String, dynamic>>.from(_weightHistory);
    f.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return f;
  }

  double _getMinWeight(List<Map<String, dynamic>> data) =>
      data.isEmpty ? 0 : data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a < b ? a : b);

  double _getMaxWeight(List<Map<String, dynamic>> data) =>
      data.isEmpty ? 0 : data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

  double _getAvgWeight(List<Map<String, dynamic>> data) =>
      data.isEmpty ? 0 : double.parse((data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a + b) / data.length).toStringAsFixed(1));
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
