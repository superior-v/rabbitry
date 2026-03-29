import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/transaction.dart' as finance_model;
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';

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

  // Theme Helpers
  Color get _primaryColor => widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;
  Color get _washColor => widget.rabbit.type == RabbitType.buck ? kBlueWash : kPinkWash;
  Color get _pastelColor => widget.rabbit.type == RabbitType.buck ? kBluePastel : kPinkPastel;
  Color get _lightColor => widget.rabbit.type == RabbitType.buck ? kBlueLight : kPinkLight;

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
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickStats(),
        const SizedBox(height: 24),
        _buildWeightTrendCard(),
        const SizedBox(height: 24),
        _buildKitOutcomesCard(),
        const SizedBox(height: 24),
        _buildLitterSizesCard(),
        const SizedBox(height: 24),
        _buildFinancialsCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuickStats() {
    String survival = '--';
    if (_litters.isNotEmpty) {
      final totalBorn = _litters.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
      final totalAlive = _litters.fold<int>(0, (sum, l) => sum + (l.aliveKits ?? 0));
      if (totalBorn > 0) survival = '${((totalAlive / totalBorn) * 100).round()}%';
    }

    String avgLitter = '--';
    if (_litters.isNotEmpty) {
      final littersWithKits = _litters.where((l) => (l.totalKits ?? 0) > 0).toList();
      if (littersWithKits.isNotEmpty) {
        final total = littersWithKits.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
        avgLitter = (total / littersWithKits.length).toStringAsFixed(1);
      }
    }

    String avgGest = '--';
    if (_litters.isNotEmpty) {
      final littersWithKindle = _litters.where((l) => l.kindleDate != null).toList();
      if (littersWithKindle.isNotEmpty) {
        final totalDays = littersWithKindle.fold<int>(0, (sum, l) => sum + l.kindleDate!.difference(l.breedDate).inDays);
        avgGest = '${(totalDays / littersWithKindle.length).round()}d';
      }
    }

    String avgWean = '--';
    if (_litters.isNotEmpty) {
      final littersWithWean = _litters.where((l) => l.weanDate != null && l.kindleDate != null).toList();
      if (littersWithWean.isNotEmpty) {
        final totalDays = littersWithWean.fold<int>(0, (sum, l) => sum + l.weanDate!.difference(l.kindleDate!).inDays);
        avgWean = '${((totalDays / littersWithWean.length) / 7).round()}w';
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatBox(survival, 'SURVIVAL', PhosphorIconsFill.heartbeat, _washColor, _primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatBox(avgLitter, 'AVG LITTER', PhosphorIconsFill.smiley, _washColor, _primaryColor)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatBox(avgGest, 'GESTATION', PhosphorIconsFill.calendarBlank, _washColor, _primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatBox(avgWean, 'WEAN AGE', PhosphorIconsFill.scales, _washColor, _primaryColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(String val, String label, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kNeutral400, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTrendCard() {
    final filtered = _getFilteredWeights();
    double current = 0, diff = 0;
    if (filtered.isNotEmpty) {
      current = (filtered.last['weight'] as num).toDouble();
      if (filtered.length > 1) diff = current - (filtered[filtered.length - 2]['weight'] as num).toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kNeutral200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardTitle('WEIGHT TREND', PhosphorIconsFill.trendUp),
              Row(children: ['W', 'M', 'Y'].map((t) => _buildToggle(t, _selectedWeightRange == t, (v) => setState(() => _selectedWeightRange = v))).toList()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$current', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              const SizedBox(width: 4),
              Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('lbs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kNeutral400))),
              const SizedBox(width: 12),
              if (diff != 0) _buildTrendBadge(diff),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 160, child: filtered.isEmpty ? const Center(child: Text('No data')) : LineChart(_getWeightLineData(filtered))),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSmallStat('${_getMinWeight(filtered)}', 'LOW (LBS)'),
              _buildSmallStat('${_getAvgWeight(filtered)}', 'AVERAGE'),
              _buildSmallStat('${_getMaxWeight(filtered)}', 'PEAK'),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsFill.target, size: 14, color: _primaryColor.withOpacity(0.6)),
                const SizedBox(width: 6),
                const Text('Target: 9.0 – 11.0 lbs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitOutcomesCard() {
    int sold = 0, breeder = 0, butchered = 0, died = 0, total = 0;
    for (var l in _litters) {
      total += l.totalKits ?? 0;
      for (var k in l.kits) {
        if (k.status == 'Sold') sold++;
        else if (k.status == 'Breeder') breeder++;
        else if (k.status == 'Butchered') butchered++;
        else if (['Dead', 'Cull'].contains(k.status)) died++;
      }
    }
    String survivalLabel = total > 0 ? '${((total - died) / total * 100).round()}% survival' : '0% survival';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kNeutral200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('KIT OUTCOMES', PhosphorIconsFill.target),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$total', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('total kits', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500))),
            const SizedBox(width: 8),
              _buildPillBadge(survivalLabel, _washColor, _primaryColor),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (sold > 0) Expanded(flex: sold, child: Container(color: _primaryColor)),
                  if (breeder > 0) Expanded(flex: breeder, child: Container(color: _primaryColor.withOpacity(0.7))),
                  if (butchered > 0) Expanded(flex: butchered, child: Container(color: _primaryColor.withOpacity(0.4))),
                  if (died > 0) Expanded(flex: died, child: Container(color: _primaryColor.withOpacity(0.1))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegend('Sold', _primaryColor),
              _buildLegend('Breeder', _primaryColor.withOpacity(0.7)),
              _buildLegend('Butchered', _primaryColor.withOpacity(0.4)),
              _buildLegend('Died', _primaryColor.withOpacity(0.1)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSmallStat('$sold', 'SOLD'),
              _buildSmallStat('$breeder', 'BREEDER'),
              _buildSmallStat('$butchered', 'BUTCHERED'),
              _buildSmallStat('$died', 'DIED'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLitterSizesCard() {
    final data = _litters.where((l) => (l.totalKits ?? 0) > 0).take(6).toList().reversed.toList();
    double avg = 0;
    if (data.isNotEmpty) avg = data.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0)) / data.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kNeutral200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardTitle('LITTER SIZES', PhosphorIconsFill.chartBar),
              Row(children: ['All', '6M'].map((t) => _buildToggle(t, _selectedLitterRange == t, (v) => setState(() => _selectedLitterRange = v))).toList()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('avg kits', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500))),
              const SizedBox(width: 12),
              _buildTrendBadge(0.2),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 140, child: data.isEmpty ? const Center(child: Text('No data')) : LineChart(_getLitterLineData(data))),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSmallStat('6', 'SMALLEST'),
              _buildSmallStat(avg.toStringAsFixed(1), 'AVERAGE'),
              _buildSmallStat('9', 'LARGEST'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialsCard() {
    double income = 0, expenses = 0;
    for (var t in _transactions) {
      if (t.type == finance_model.TransactionType.income) income += t.amount;
      else expenses += t.amount;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kNeutral200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardTitle('FINANCIALS', PhosphorIconsFill.currencyDollar),
              GestureDetector(
                onTap: widget.onAddTransaction,
                child: Row(
                  children: [
                    Icon(Icons.add, size: 14, color: _primaryColor.withOpacity(0.6)),
                    const SizedBox(width: 4),
                    const Text('ADD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildFinanceBox('+\$${income.toInt()}', 'INCOME', _washColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildFinanceBox('-\$${expenses.toInt()}', 'EXPENSES', kNeutral100)),
              const SizedBox(width: 8),
              Expanded(child: _buildFinanceBox('+\$${(income - expenses).toInt()}', 'NET', _washColor)),
            ],
          ),
          const SizedBox(height: 20),
          ..._transactions.take(2).map((t) => _buildTransactionItem(t)),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: widget.onViewAllTransactions,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View All Transactions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral400)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: kNeutral400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kNeutral500),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.6)),
      ],
    );
  }

  Widget _buildToggle(String label, bool isActive, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: isActive ? _washColor : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isActive ? _primaryColor : kNeutral400)),
      ),
    );
  }

  Widget _buildTrendBadge(double val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _washColor, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(val > 0 ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown, size: 12, color: _primaryColor),
          const SizedBox(width: 4),
          Text('${val > 0 ? '+' : ''}$val', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primaryColor)),
        ],
      ),
    );
  }

  Widget _buildPillBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: text)),
    );
  }

  Widget _buildFinanceBox(String val, String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kNeutral200)),
      child: Column(
        children: [
          Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kNeutral400, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(finance_model.Transaction t) {
    final isIncome = t.type == finance_model.TransactionType.income;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kNeutral200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('MMM d').format(t.date), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral400)),
              Text(t.description ?? t.categoryName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            ],
          ),
          Text('${isIncome ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isIncome ? const Color(0xFF22C55E) : (t.type == finance_model.TransactionType.expense ? Colors.redAccent.withOpacity(0.7) : _primaryColor))),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral500)),
      ],
    );
  }

  LineChartData _getWeightLineData(List<Map<String, dynamic>> data) {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i >= 0 && i < data.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(DateFormat('MMM').format(DateTime.parse(data[i]['date'])), style: TextStyle(fontSize: 10, color: kNeutral400, fontWeight: FontWeight.w600)),
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
          spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), (data[i]['weight'] as num).toDouble())),
          isCurved: true,
          color: _primaryColor,
          barWidth: 3,
          dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: _primaryColor)),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_primaryColor.withOpacity(0.15), _primaryColor.withOpacity(0)])),
        ),
      ],
    );
  }

  LineChartData _getLitterLineData(List<Litter> data) {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i >= 0 && i < data.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('L-${data[i].id.substring(data[i].id.length - 3)}', style: TextStyle(fontSize: 9, color: kNeutral400, fontWeight: FontWeight.w600)),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), (data[i].totalKits ?? 0).toDouble())),
          isCurved: true,
          color: _primaryColor,
          barWidth: 3,
          dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: _primaryColor)),
        ),
      ],
    );
  }

  Widget _buildSmallStat(String val, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kNeutral400, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // Helpers
  List<Map<String, dynamic>> _getFilteredWeights() { if (_weightHistory.isEmpty) return []; var f = List<Map<String, dynamic>>.from(_weightHistory); f.sort((a,b) => (a['date'] as String).compareTo(b['date'] as String)); return f; }
  double _getMinWeight(List<Map<String, dynamic>> data) => data.isEmpty ? 0 : data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a < b ? a : b);
  double _getMaxWeight(List<Map<String, dynamic>> data) => data.isEmpty ? 0 : data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
  double _getAvgWeight(List<Map<String, dynamic>> data) => data.isEmpty ? 0 : double.parse((data.map((e) => (e['weight'] as num).toDouble()).reduce((a, b) => a + b) / data.length).toStringAsFixed(1));
}
