import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' show FontFeature;
import '../models/report_models.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/transaction.dart' as finance_model;
import '../services/database_service.dart';
import '../services/format_utils.dart';
import 'package:path_provider/path_provider.dart'; // ✅ Add this
import 'package:open_filex/open_filex.dart'; // ✅ Add this
import '../services/notification_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// === PASTEL PALETTE (Matching HTML) ===
const kLilac = Color(0xFFC3B1E1);
const kLilacLight = Color(0xFFE8DFFA);
const kLilacWash = Color(0xFFF5F1FC);
const kLilacDeep = Color(0xFF7B6BA0);
const kLilacText = Color(0xFF5A4880);
const kPurple = Color(0xFF8B5CF6);

const kBlue = Color(0xFFA8D4F0);
const kBlueLight = Color(0xFFD9EEFB);
const kBlueWash = Color(0xFFF0F7FD);
const kBlueDeep = Color(0xFF3A7BB8);

const kPink = Color(0xFFF2B8C6);
const kPinkLight = Color(0xFFFADCE5);
const kPinkWash = Color(0xFFFDF2F5);
const kPinkDeep = Color(0xFFD4809A);

const kNeutral900 = Color(0xFF2C2C2E);
const kNeutral800 = Color(0xFF3A3A3C);
const kNeutral700 = Color(0xFF636366);
const kNeutral600 = Color(0xFF8E8E93);
const kNeutral500 = Color(0xFFAEAEB2);
const kNeutral400 = Color(0xFFC7C7CC);
const kNeutral300 = Color(0xFFE5E5EA);
const kNeutral200 = Color(0xFFF2F2F7);
const kNeutral100 = Color(0xFFF9F9FB);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedPeriod = '30D';
  bool showBest = true;
  bool _isLoading = true;

  final DatabaseService _db = DatabaseService();

  final List<String> periods = [
    '7D',
    '30D',
    '90D',
    'YTD',
    'All'
  ];

  // Cached raw data
  List<Rabbit> _allRabbits = [];
  List<Rabbit> _archivedRabbits = [];
  List<Litter> _allLitters = [];
  List<finance_model.Transaction> _allTransactions = [];

  // Production
  int _activeLitters = 0;
  int _totalLiveKitsBorn = 0;
  double _avgLitterSize = 0;
  double _avgGestationDays = 0;
  int _doeConceptionRate = 0;
  int _buckConceptionRate = 0;
  String _littersTrend = '';
  String _kitsTrend = '';
  List<RankingItem> _doeRankings = [];
  List<ChartData> _gestationData = [];

  // Growth
  double _totalMeatYield = 0;
  double _avgHarvestWeight = 0;
  int _avgButcherAge = 0;
  int _dressOutPercent = 0;
  List<ChartData> _growthData = [];
  double _w4_avg = 0;
  double _w8_avg = 0;
  double _w12_avg = 0;
  int _lightPercent = 0;
  int _targetPercent = 0;
  int _heavyPercent = 0;

  // Health
  int _survivalRate = 0;
  int _totalLosses = 0;
  int _doeMortality = 0;
  int _quarantineCount = 0;
  List<ChartData> _lossData = [];
  int _bornTotal = 0;
  int _bornLive = 0;
  int _weanedCount = 0;
  int _matureCount = 0;

  // Finance
  double _netProfit = 0;
  double _totalRevenue = 0;
  double _totalExpense = 0;
  double _costPerKit = 0;
  double _costPerDoe = 0;
  double _costPerWeight = 0;
  List<ChartData> _expenseData = [];
  List<ChartData> _incomeData = [];
  List<RankingItem> _buyerRankings = [];
  List<ChartData> _buyerRevenueData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _getPeriodStart() {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case '7D':
        return now.subtract(Duration(days: 7));
      case '30D':
        return now.subtract(Duration(days: 30));
      case '90D':
        return now.subtract(Duration(days: 90));
      case 'YTD':
        return DateTime(now.year, 1, 1);
      case 'All':
      default:
        return DateTime(2000, 1, 1);
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final rabbits = await _db.getAllRabbits();
      final archived = await _db.getArchivedRabbits();
      final litters = await _db.getLitters();
      final transactions = await _db.getAllTransactions();

      _allRabbits = rabbits;
      _archivedRabbits = archived;
      _allLitters = litters;
      _allTransactions = transactions;

      _computeAnalytics();
    } catch (e) {
      print('Error loading analytics data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _computeAnalytics() {
    final periodStart = _getPeriodStart();
    final now = DateTime.now();

    // Filter by period
    final periodLitters = _allLitters.where((l) {
      final date = l.kindleDate ?? l.breedDate;
      return date.isAfter(periodStart);
    }).toList();

    final periodTransactions = _allTransactions.where((t) {
      return t.date.isAfter(periodStart);
    }).toList();

    final periodArchived = _archivedRabbits.where((r) {
      return r.archiveDate != null && r.archiveDate!.isAfter(periodStart);
    }).toList();

    final allRabbitsIncArchived = [
      ..._allRabbits,
      ..._archivedRabbits
    ];

    // ========================
    // PRODUCTION ANALYTICS
    // ========================
    _activeLitters = _allLitters.where((l) {
      final s = l.status.toLowerCase();
      return s == 'nursing' || s == 'weaned';
    }).length;

    _totalLiveKitsBorn = 0;
    double totalLitterSize = 0;
    int littersWithKits = 0;
    for (final l in periodLitters) {
      final alive = l.aliveKits ?? 0;
      _totalLiveKitsBorn += alive;
      if (alive > 0) {
        totalLitterSize += alive;
        littersWithKits++;
      }
    }
    _avgLitterSize = littersWithKits > 0 ? totalLitterSize / littersWithKits : 0;

    final prevPeriodEnd = periodStart;
    final periodDuration = now.difference(periodStart).inDays;
    final prevPeriodStart = prevPeriodEnd.subtract(Duration(days: periodDuration));

    final prevPeriodLitters = _allLitters.where((l) => l.breedDate.isAfter(prevPeriodStart) && l.breedDate.isBefore(prevPeriodEnd)).toList();
    
    int prevKits = 0;
    for (final l in prevPeriodLitters) {
      prevKits += l.aliveKits ?? 0;
    }

    final litterDiff = periodLitters.length - prevPeriodLitters.length;
    final kitDiff = _totalLiveKitsBorn - prevKits;
    
    _littersTrend = litterDiff >= 0 ? '+$litterDiff' : '$litterDiff';
    _kitsTrend = kitDiff >= 0 ? '+$kitDiff' : '$kitDiff';
    _avgLitterSize = littersWithKits > 0 ? totalLitterSize / littersWithKits : 0;

    // Gestation days
    List<double> gestations = [];
    for (final l in _allLitters) {
      if (l.kindleDate != null) {
        final days = l.kindleDate!.difference(l.breedDate).inDays;
        if (days >= 28 && days <= 35) {
          gestations.add(days.toDouble());
        }
      }
    }

    _avgGestationDays = gestations.isNotEmpty ? gestations.reduce((a, b) => a + b) / gestations.length : 0;

    // Gestation bar chart data
    Map<int, int> gestationCounts = {};
    for (final g in gestations) {
      final day = g.toInt();
      gestationCounts[day] = (gestationCounts[day] ?? 0) + 1;
    }
    _gestationData = gestationCounts.entries.map((e) => ChartData(label: '${e.key}d', value: e.value.toDouble())).toList()..sort((a, b) => a.label.compareTo(b.label));

    // Conception rate by doe
    final does = allRabbitsIncArchived.where((r) => r.type == RabbitType.doe).toList();

    int doesBred = 0;
    int doesConceived = 0;
    Map<String, List<Litter>> littersByDoe = {};
    for (final l in periodLitters) {
      littersByDoe.putIfAbsent(l.doeId, () => []);
      littersByDoe[l.doeId]!.add(l);
    }
    for (final doe in does) {
      if (doe.palpationResult != null || littersByDoe.containsKey(doe.id)) {
        doesBred++;
        if (doe.palpationResult == true || (littersByDoe[doe.id]?.isNotEmpty ?? false)) {
          doesConceived++;
        }
      }
    }
    _doeConceptionRate = doesBred > 0 ? ((doesConceived / doesBred) * 100).round() : 0;

    int bucksBred = 0;
    Map<String, int> buckBreedings = {};
    Map<String, int> buckConceptions = {};
    for (final l in periodLitters) {
      buckBreedings[l.buckId] = (buckBreedings[l.buckId] ?? 0) + 1;
      if ((l.aliveKits ?? 0) > 0) {
        buckConceptions[l.buckId] = (buckConceptions[l.buckId] ?? 0) + 1;
      }
    }
    bucksBred = buckBreedings.length;
    final bucksConceived = buckConceptions.length;
    _buckConceptionRate = bucksBred > 0 ? ((bucksConceived / bucksBred) * 100).round() : 0;

    // Doe performance ranking
    _doeRankings = [];
    for (final entry in littersByDoe.entries) {
      final doeLitters = entry.value;
      final doe = allRabbitsIncArchived.where((r) => r.id == entry.key).firstOrNull;
      if (doe == null) continue;

      int totalBorn = 0;
      int totalAlive = 0;
      for (final l in doeLitters) {
        totalBorn += l.totalKits ?? 0;
        totalAlive += l.aliveKits ?? 0;
      }
      double survivalPct = totalBorn > 0 ? (totalAlive / totalBorn) * 100 : 0;

      _doeRankings.add(RankingItem(
        rank: 0,
        name: doe.name.isNotEmpty ? doe.name : doe.id,
        id: doe.id,
        subtitle: '${doeLitters.length} litters, $totalAlive kits alive',
        percentage: survivalPct,
      ));
    }
    _doeRankings.sort((a, b) => b.percentage.compareTo(a.percentage));
    for (int i = 0; i < _doeRankings.length; i++) {
      _doeRankings[i] = RankingItem(
        rank: i + 1,
        name: _doeRankings[i].name,
        id: _doeRankings[i].id,
        subtitle: _doeRankings[i].subtitle,
        percentage: _doeRankings[i].percentage,
        isTop: i == 0,
      );
    }

    // ========================
    // GROWTH ANALYTICS
    // ========================
    final butchered = periodArchived.where((r) => r.archiveReason == ArchiveReason.butchered).toList();

    _totalMeatYield = 0;
    double totalHarvestWeight = 0;
    int harvestCount = 0;
    int totalButcherAgeDays = 0;
    int butcherAgeCount = 0;
    int lightCount = 0;
    int targetCount = 0;
    int heavyCount = 0;

    for (final r in butchered) {
      final yield_ = r.butcherYield ?? 0;
      _totalMeatYield += yield_;
      if (r.weight != null && r.weight! > 0) {
        totalHarvestWeight += r.weight!;
        harvestCount++;
        if (r.weight! < 4.5)
          lightCount++;
        else if (r.weight! <= 5.5)
          targetCount++;
        else
          heavyCount++;
      }
      if (r.dateOfBirth != null && r.archiveDate != null) {
        totalButcherAgeDays += r.archiveDate!.difference(r.dateOfBirth!).inDays;
        butcherAgeCount++;
      }
    }
    _avgHarvestWeight = harvestCount > 0 ? totalHarvestWeight / harvestCount : 0;
    _avgButcherAge = butcherAgeCount > 0 ? (totalButcherAgeDays / butcherAgeCount / 7).round() : 0;
    _dressOutPercent = (harvestCount > 0 && _totalMeatYield > 0 && totalHarvestWeight > 0) ? ((_totalMeatYield / totalHarvestWeight) * 100).round() : 0;

    final totalWeightCats = lightCount + targetCount + heavyCount;
    _lightPercent = totalWeightCats > 0 ? ((lightCount / totalWeightCats) * 100).round() : 0;
    _targetPercent = totalWeightCats > 0 ? ((targetCount / totalWeightCats) * 100).round() : 0;
    _heavyPercent = totalWeightCats > 0 ? ((heavyCount / totalWeightCats) * 100).round() : 0;

    // Growth milestones calculation
    List<double> w4_weights = [];
    List<double> w8_weights = [];
    List<double> w12_weights = [];
    
    // Growth curve data points
    Map<int, List<double>> ageWeights = {};

    final allRelevant = [..._allRabbits, ..._archivedRabbits];
    for (final r in allRelevant) {
      if (r.dateOfBirth != null && r.weight != null && r.weight! > 0) {
        // Use archiveDate for archived rabbits, otherwise use NOW
        final referenceDate = r.archiveDate ?? now;
        final ageDays = referenceDate.difference(r.dateOfBirth!).inDays;
        
        if (ageDays >= 21 && ageDays <= 35) w4_weights.add(r.weight!);
        if (ageDays >= 49 && ageDays <= 63) w8_weights.add(r.weight!);
        if (ageDays >= 77 && ageDays <= 95) w12_weights.add(r.weight!);

        // For the chart, group by weeks (rounded)
        final week = (ageDays / 7).round();
        if (week >= 4 && week <= 16) {
          ageWeights.putIfAbsent(week, () => []);
          ageWeights[week]!.add(r.weight!);
        }
      }
    }

    _w4_avg = w4_weights.isNotEmpty ? w4_weights.reduce((a, b) => a + b) / w4_weights.length : 0;
    _w8_avg = w8_weights.isNotEmpty ? w8_weights.reduce((a, b) => a + b) / w8_weights.length : 0;
    _w12_avg = w12_weights.isNotEmpty ? w12_weights.reduce((a, b) => a + b) / w12_weights.length : 0;

    // Create sorted chart data points
    final sortedWeeks = ageWeights.keys.toList()..sort();
    _growthData = sortedWeeks.map((w) {
      final avg = ageWeights[w]!.reduce((a, b) => a + b) / ageWeights[w]!.length;
      return ChartData(label: '${w}w', value: double.parse(avg.toStringAsFixed(1)));
    }).toList();
    
    // Ensure at least 2 points for the chart, even if empty
    if (_growthData.isEmpty) {
      _growthData = [
        ChartData(label: '4w', value: _w4_avg),
        ChartData(label: '8w', value: _w8_avg),
        ChartData(label: '12w', value: _w12_avg),
      ];
    }

    // ========================
    // HEALTH ANALYTICS
    // ========================
    _bornTotal = 0;
    _bornLive = 0;
    _weanedCount = 0;
    _matureCount = 0;
    int totalKitsDeadInLitters = 0;

    for (final l in periodLitters) {
      _bornTotal += l.totalKits ?? l.aliveKits ?? 0;
      _bornLive += l.aliveKits ?? 0;
      if (l.weanDate != null) {
        final weanedFromKits = l.kits.where((k) => !k.isArchived || k.status == 'Sold' || k.status == 'Butchered').length;
        _weanedCount += weanedFromKits > 0 ? weanedFromKits : (l.aliveKits ?? 0);
      }
    }

    _matureCount = allRabbitsIncArchived.where((r) => r.type == RabbitType.doe || r.type == RabbitType.buck).where((r) {
      if (r.dateOfBirth == null) return false;
      return r.dateOfBirth!.isAfter(periodStart);
    }).length;

    _survivalRate = _bornTotal > 0 ? ((_bornLive / _bornTotal) * 100).round() : 0;

    final deaths = periodArchived.where((r) => r.archiveReason == ArchiveReason.dead || r.archiveReason == ArchiveReason.cull).toList();
    _totalLosses = deaths.length;

    for (final l in periodLitters) {
      totalKitsDeadInLitters += l.deadKits ?? 0;
      totalKitsDeadInLitters += l.kits.where((k) => k.status == 'Dead' || k.status == 'Cull').length;
    }
    _totalLosses += totalKitsDeadInLitters;

    final totalDoes = does.length;
    final doeDeaths = deaths.where((r) => r.type == RabbitType.doe).length;
    _doeMortality = totalDoes > 0 ? ((doeDeaths / totalDoes) * 100).round() : 0;

    _quarantineCount = _allRabbits.where((r) => r.status == RabbitStatus.quarantine).length;

    Map<String, int> lossCauses = {};
    for (final r in deaths) {
      final cause = r.deathCause?.isNotEmpty == true ? r.deathCause! : (r.cullReason?.isNotEmpty == true ? r.cullReason! : 'Unknown');
      lossCauses[cause] = (lossCauses[cause] ?? 0) + 1;
    }
    if (totalKitsDeadInLitters > 0) {
      lossCauses['Stillborn / Kit Loss'] = (lossCauses['Stillborn / Kit Loss'] ?? 0) + totalKitsDeadInLitters;
    }
    final totalLossCauses = lossCauses.values.fold(0, (a, b) => a + b);
    _lossData = lossCauses.entries.map((e) {
      final pct = totalLossCauses > 0 ? (e.value / totalLossCauses) * 100 : 0;
      return ChartData(label: e.key, value: pct.toDouble());
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ========================
    // FINANCE ANALYTICS
    // ========================
    final income = periodTransactions.where((t) => t.type == finance_model.TransactionType.income).toList();
    final expenses = periodTransactions.where((t) => t.type == finance_model.TransactionType.expense).toList();

    _totalRevenue = income.fold(0.0, (sum, t) => sum + t.amount);
    _totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);
    _netProfit = _totalRevenue - _totalExpense;

    final totalKitsProduced = periodLitters.fold(0, (sum, l) => sum + (l.aliveKits ?? 0));
    _costPerKit = totalKitsProduced > 0 ? _totalExpense / totalKitsProduced : 0;

    final activeDoes = _allRabbits.where((r) => r.type == RabbitType.doe).length;
    final periodMonths = now.difference(periodStart).inDays / 30;
    _costPerDoe = (activeDoes > 0 && periodMonths > 0) ? _totalExpense / activeDoes / periodMonths : 0;

    _costPerWeight = _totalMeatYield > 0 ? _totalExpense / _totalMeatYield : 0;

    Map<String, double> expenseByCategory = {};
    for (final t in expenses) {
      expenseByCategory[t.categoryName] = (expenseByCategory[t.categoryName] ?? 0) + t.amount;
    }
    _expenseData = expenseByCategory.entries.map((e) {
      final pct = _totalExpense > 0 ? (e.value / _totalExpense) * 100 : 0;
      return ChartData(label: e.key, value: pct.toDouble());
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Map<String, double> incomeByCategory = {};
    for (final t in income) {
      incomeByCategory[t.categoryName] = (incomeByCategory[t.categoryName] ?? 0) + t.amount;
    }
    _incomeData = incomeByCategory.entries.map((e) {
      return ChartData(label: e.key, value: e.value);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Buyer Analytics
    Map<String, double> buyerRevenue = {};
    for (final t in income) {
      if (t.buyerInfo != null && t.buyerInfo!.isNotEmpty) {
        buyerRevenue[t.buyerInfo!] = (buyerRevenue[t.buyerInfo!] ?? 0) + t.amount;
      }
    }

    _buyerRankings = [];
    final sortedBuyers = buyerRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (int i = 0; i < sortedBuyers.length; i++) {
      final entry = sortedBuyers[i];
      _buyerRankings.add(RankingItem(
        rank: i + 1,
        name: entry.key,
        id: '',
        subtitle: 'Total Spend: ${FormatUtils.formatCurrency(entry.value)}',
        percentage: _totalRevenue > 0 ? (entry.value / _totalRevenue * 100).roundToDouble() : 0,
        isTop: i == 0,
      ));
    }

    _buyerRevenueData = sortedBuyers.take(5).map((e) {
      return ChartData(label: e.key, value: e.value);
    }).toList();

    // Prepare income stats for UI
    _incomeStats = [];
    if (_incomeData.isNotEmpty) {
      for (int i = 0; i < _incomeData.length.clamp(0, 3); i++) {
        _incomeStats.add(_MiniStatData(
          label: _incomeData[i].label,
          value: FormatUtils.formatCurrency(_incomeData[i].value),
        ));
      }
    }
  }

  List<_MiniStatData> _incomeStats = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: kLilacWash,
            border: Border(bottom: BorderSide(color: kLilacLight)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(PhosphorIconsBold.arrowLeft, color: kLilacDeep, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: const Row(
              children: [
                Icon(PhosphorIconsDuotone.chartPieSlice, color: kLilacDeep, size: 22),
                SizedBox(width: 8),
                Text(
                  'Analytics',
                  style: TextStyle(
                    color: kLilacText,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(PhosphorIconsBold.export, color: kLilacDeep, size: 20),
                onPressed: _exportAnalytics,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterIsland(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kLilacDeep, strokeWidth: 2))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProductionTab(),
                      _buildGrowthTab(),
                      _buildHealthTab(),
                      _buildFinanceTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterIsland() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kNeutral200)),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kNeutral200,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: periods.map((period) {
              bool isSelected = selectedPeriod == period;
              return GestureDetector(
                onTap: () {
                  setState(() => selectedPeriod = period);
                  _computeAnalytics();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? kLilacDeep : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : kNeutral600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kNeutral300)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: kLilacDeep,
        unselectedLabelColor: kNeutral500,
        indicatorColor: kLilacDeep,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelPadding: const EdgeInsets.symmetric(vertical: 12),
        tabs: const [
          Text('Production'),
          Text('Growth'),
          Text('Health'),
          Text('Finance'),
        ],
      ),
    );
  }

  String _fmtNum(double val, {int decimals = 1}) {
    if (val == 0) return '0';
    if (val == val.roundToDouble() && decimals <= 1) return val.toInt().toString();
    return val.toStringAsFixed(decimals);
  }

  Future<Directory?> _getExportDirectory() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        var manageStatus = await Permission.manageExternalStorage.request();
        if (!manageStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Storage permission required to export CSV'),
                backgroundColor: const Color(0xFFD44C47),
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return null;
        }
      }

      final List<String> paths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
      ];
      for (String p in paths) {
        final dir = Directory(p);
        try {
          if (await dir.exists()) return dir;
          await dir.create(recursive: true);
          return dir;
        } catch (_) {}
      }
      return await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _exportAnalytics() async {
    try {
      final buffer = StringBuffer();
      
      buffer.writeln('Analytics Report - $selectedPeriod');
      buffer.writeln('Generated on: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');
      
      buffer.writeln('--- PRODUCTION ---');
      buffer.writeln('Active Litters,$_activeLitters');
      buffer.writeln('Live Kits Born,$_totalLiveKitsBorn');
      buffer.writeln('Avg Litter Size,${_fmtNum(_avgLitterSize)}');
      buffer.writeln('Gestation Days (Avg),${_avgGestationDays > 0 ? _fmtNum(_avgGestationDays) : "-"}');
      buffer.writeln('Doe Conception Rate,$_doeConceptionRate%');
      buffer.writeln('Buck Conception Rate,$_buckConceptionRate%');
      buffer.writeln('');

      buffer.writeln('--- GROWTH ---');
      buffer.writeln('Total Meat Yield,${_fmtNum(_totalMeatYield)} ${FormatUtils.weightUnit}');
      buffer.writeln('Avg Harvest Weight,${_avgHarvestWeight > 0 ? _fmtNum(_avgHarvestWeight) : "0"} ${FormatUtils.weightUnit}');
      buffer.writeln('Dress-Out Percentage,${_dressOutPercent > 0 ? "$_dressOutPercent%" : "-"}');
      buffer.writeln('Avg Age To Butcher,${_avgButcherAge > 0 ? "${_avgButcherAge}w" : "-"}');
      buffer.writeln('');

      buffer.writeln('--- HEALTH ---');
      buffer.writeln('Survival Rate,${_bornTotal > 0 ? "$_survivalRate%" : "-"}');
      buffer.writeln('Total Losses,$_totalLosses');
      buffer.writeln('Doe Mortality,$_doeMortality%');
      buffer.writeln('Quarantine Count,$_quarantineCount');
      buffer.writeln('');

      buffer.writeln('--- FINANCE ---');
      buffer.writeln('Net Profit,${_netProfit != 0 ? _netProfit.toStringAsFixed(2) : "-"}');
      buffer.writeln('Total Revenue,${_totalRevenue > 0 ? _totalRevenue.toStringAsFixed(2) : "0"}');
      buffer.writeln('Total Expense,${_totalExpense > 0 ? _totalExpense.toStringAsFixed(2) : "0"}');
      buffer.writeln('Cost Per Kit,${_costPerKit > 0 ? _costPerKit.toStringAsFixed(2) : "-"}');

      final directory = await _getExportDirectory();
      if (directory == null) return;
      final file = File('${directory.path}/analytics_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analytics exported to ${file.path.split('/').last}'),
            backgroundColor: const Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );

        // ✅ Show system notification
        await NotificationService.instance.showFileNotification(
          title: 'Analytics Exported',
          body: 'Tap to open analytics_export.csv',
          filePath: file.path,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(0xFFD44C47)),
        );
      }
    }
  }

  Widget _buildProductionTab() {
    final kpis = [
      KPICard(label: 'Active Litters', value: '$_activeLitters', isTrending: true, isPositive: !_littersTrend.contains('-'), subtitle: _littersTrend),
      KPICard(label: 'Live Kits Born', value: '$_totalLiveKitsBorn', isTrending: true, isPositive: !_kitsTrend.contains('-'), subtitle: _kitsTrend),
      KPICard(
        label: 'Avg Litter',
        value: _fmtNum(_avgLitterSize),
        subtitle: 'Target: 8.0',
      ),
      KPICard(
        label: 'Gestation',
        value: _avgGestationDays > 0 ? _fmtNum(_avgGestationDays) : '--',
        subtitle: 'Range: 30-33',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        const SizedBox(height: 16),
        _buildConceptionRateCard(),
        const SizedBox(height: 16),
        _buildPerformanceCard(),
        const SizedBox(height: 16),
        _buildGestationChart(),
      ],
    );
  }

  Widget _buildGestationChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GESTATION DAYS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: LineChartPainter(data: _gestationData, color: kLilacDeep),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('29d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral400)),
              Text('30d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral400)),
              Text('31d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral400)),
              Text('32d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral400)),
              Text('33d+', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral400)),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(label: 'Earliest', value: '29d'),
              _MiniStat(label: 'Mode', value: '31d'),
              _MiniStat(label: 'Latest', value: '33d'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(8)),
            child: const Text('Mode: 31 days — within normal range (30–33d)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kNeutral500)),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthTab() {
    final kpis = [
      KPICard(
        label: 'Meat Yield',
        value: '${_fmtNum(_totalMeatYield)} ${FormatUtils.weightUnit}',
        subtitle: 'Last 30 Days',
      ),
      KPICard(
        label: 'Avg Live Wt',
        value: '${_fmtNum(_avgHarvestWeight)} ${FormatUtils.weightUnit}',
        subtitle: 'At Harvest',
      ),
      KPICard(
        label: 'Dress-Out',
        value: '$_dressOutPercent%',
        isTrending: true,
        isPositive: true,
        subtitle: 'Avg yield %',
      ),
      KPICard(
        label: 'Avg Age',
        value: '${_avgButcherAge}w',
        subtitle: 'To Butcher',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        const SizedBox(height: 16),
        _buildGrowthRateChart(),
        const SizedBox(height: 16),
        _buildHarvestWeightCard(),
      ],
    );
  }

  Widget _buildGrowthRateChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVG GROWTH RATE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: LineChartPainter(data: _growthData, color: kLilacDeep),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _growthData.map((d) => Text(
              d.label, 
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral400)
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(label: 'At 4w', value: '${_fmtNum(_w4_avg)} ${FormatUtils.weightUnit}'),
              _MiniStat(label: 'At 8w', value: '${_fmtNum(_w8_avg)} ${FormatUtils.weightUnit}'),
              _MiniStat(label: 'At 12w', value: '${_fmtNum(_w12_avg)} ${FormatUtils.weightUnit}'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(8)),
            child: Text(
              _w12_avg > 0 
                ? 'Growth peaking at ${_fmtNum(_w12_avg)} ${FormatUtils.weightUnit} — optimal butcher window'
                : 'Steady linear growth curve — track to determine peak',
              textAlign: TextAlign.center, 
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kNeutral500)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    final kpis = [
      KPICard(
        label: 'Survival Rate',
        value: '$_survivalRate%',
        subtitle: 'Target: 90%+',
      ),
      KPICard(
        label: 'Losses',
        value: '$_totalLosses',
        subtitle: 'Last 30 days',
      ),
      KPICard(
        label: 'Doe Mortality',
        value: '$_doeMortality%',
        subtitle: 'Active Herd',
      ),
      KPICard(
        label: 'Quarantine',
        value: '$_quarantineCount',
        subtitle: 'Current',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        const SizedBox(height: 16),
        _buildLossCausesCard(),
        const SizedBox(height: 16),
        _buildSurvivalFunnelCard(),
      ],
    );
  }

  Widget _buildLossCausesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CAUSES OF LOSS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 16),
          if (_lossData.isEmpty)
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 24),
               child: Center(child: Text('No loss data recorded', style: TextStyle(color: kNeutral400, fontSize: 13))),
             )
          else ...[
            ..._lossData.take(3).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRatioBar(d.label, d.value, kLilac),
            )),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(12)),
              child: Text(
                _lossData.isNotEmpty 
                  ? '${_lossData.first.label} is the leading cause — review conditions'
                  : 'Maintain healthy conditions to minimize losses',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceTab() {
    final kpis = [
      KPICard(
        label: 'Net Profit',
        value: FormatUtils.formatCurrency(_netProfit),
        isTrending: true,
        isPositive: _netProfit >= 0,
        subtitle: _netProfit >= 0 ? 'Profit' : 'Loss',
      ),
      KPICard(
        label: 'Revenue',
        value: FormatUtils.formatCurrency(_totalRevenue),
      ),
      KPICard(
        label: 'Expense',
        value: FormatUtils.formatCurrency(_totalExpense),
        isTrending: true,
        isPositive: false,
        subtitle: 'Expenses',
      ),
      KPICard(
        label: 'Cost / Kit',
        value: FormatUtils.formatCurrency(_costPerKit),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        const SizedBox(height: 16),
        _buildUnitEconomicsCard(),
        const SizedBox(height: 16),
        _buildExpenseBreakdownCard(),
        const SizedBox(height: 16),
        _buildIncomeSourcesCard(),
        const SizedBox(height: 16),
        _buildTopBuyersCard(),
        const SizedBox(height: 16),
        _buildBuyerRevenueChart(),
      ],
    );
  }

  Widget _buildTopBuyersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP BUYERS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 16),
          if (_buyerRankings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No buyer data for this period', style: TextStyle(color: kNeutral500, fontSize: 13)),
              ),
            )
          else
            ..._buyerRankings.take(5).map((item) => _buildBuyerRankingRow(item)),
        ],
      ),
    );
  }

  Widget _buildBuyerRankingRow(RankingItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: item.isTop ? kLilacWash : kNeutral100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: item.isTop ? kLilacDeep : kNeutral500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kNeutral800),
                ),
                Text(
                  item.subtitle,
                  style: const TextStyle(fontSize: 12, color: kNeutral500),
                ),
              ],
            ),
          ),
          Text(
            '${item.percentage.toInt()}%',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kLilacDeep),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerRevenueChart() {
    return _buildBarChart('REVENUE BY BUYER', _buyerRevenueData);
  }

  Widget _buildExpenseBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPENSE BREAKDOWN',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 16),
          if (_expenseData.isEmpty)
             const Padding(
               padding: EdgeInsets.symmetric(vertical: 24),
               child: Center(child: Text('No expenses recorded', style: TextStyle(color: kNeutral400, fontSize: 13))),
             )
          else ...[
            ..._expenseData.take(3).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRatioBar(d.label, d.value, kLilac),
            )),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(12)),
              child: Text(
                _expenseData.isNotEmpty 
                  ? '${_expenseData.first.label} accounts for ${(_expenseData.first.value).toInt()}% of total expenses'
                  : 'Track your expenses to see cost breakdown',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncomeSourcesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INCOME SOURCES',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 20),
          if (_incomeData.isEmpty)
            const SizedBox(
              height: 100,
              child: Center(child: Text('No income data yet', style: TextStyle(color: kNeutral400, fontSize: 13))),
            )
          else ...[
            SizedBox(
              height: 100,
              width: double.infinity,
              child: CustomPaint(
                painter: LineChartPainter(data: _incomeData, color: kLilacDeep),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _incomeData.take(4).map((d) => Text(
                d.label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral400),
              )).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _incomeStats.map((s) => _MiniStat(label: s.label, value: s.value)).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(8)),
              child: Text(
                _incomeData.isNotEmpty 
                  ? '${_incomeData.first.label} is the top revenue source this period'
                  : 'Track your sales to see revenue sources',
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kNeutral500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKPIGrid(List<KPICard> kpis) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kNeutral200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                kpi.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kNeutral500,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    kpi.value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kNeutral900,
                    ),
                  ),
                  if (kpi.subtitle != null && !kpi.isTrending)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        kpi.subtitle!,
                        style: const TextStyle(fontSize: 10, color: kNeutral400),
                      ),
                    ),
                ],
              ),
              if (kpi.subtitle != null && kpi.isTrending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kpi.isPositive ? kBlueWash : kPinkWash,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        kpi.isPositive ? PhosphorIconsBold.trendUp : PhosphorIconsBold.trendDown,
                        size: 9,
                        color: kpi.isPositive ? kBlueDeep : kPinkDeep,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        kpi.subtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kpi.isPositive ? kBlueDeep : kPinkDeep,
                        ),
                      ),
                    ],
                  ),
                )
              else if (kpi.label.toLowerCase().contains('avg') || kpi.label.toLowerCase().contains('gestation'))
                 Text(
                   kpi.subtitle ?? '',
                   style: const TextStyle(fontSize: 10, color: kNeutral500, fontWeight: FontWeight.w500),
                 ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConceptionRateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONCEPTION RATE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 16),
          _buildRatioBar('Does', _doeConceptionRate.toDouble(), kLilacDeep),
          const SizedBox(height: 12),
          _buildRatioBar('Bucks', _buckConceptionRate.toDouble(), kLilac),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Both above target — herd fertility is healthy',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral700)),
            Text('${percentage.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral500)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (percentage / 100).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard() {
    List<RankingItem> displayRankings;
    if (showBest) {
      displayRankings = _doeRankings.take(5).toList();
    } else {
      displayRankings = _doeRankings.reversed.take(5).toList();
      for (int i = 0; i < displayRankings.length; i++) {
        displayRankings[i] = RankingItem(
          rank: i + 1,
          name: displayRankings[i].name,
          id: displayRankings[i].id,
          subtitle: displayRankings[i].subtitle,
          percentage: displayRankings[i].percentage,
          isTop: i == 0,
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DOE PERFORMANCE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: kNeutral100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildToggleOption('Best', showBest, () {
                      setState(() {
                        showBest = true;
                      });
                    }),
                    _buildToggleOption('Worst', !showBest, () {
                      setState(() {
                        showBest = false;
                      });
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (displayRankings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No breeding data yet', style: TextStyle(color: kNeutral400, fontSize: 13)),
              ),
            )
          else
            ...displayRankings.map((item) => _buildRankingRow(item, showBest)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Kit survival rate per doe',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? kNeutral900 : kNeutral500,
          ),
        ),
      ),
    );
  }

  Widget _buildRankingRow(RankingItem item, bool isBest) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kNeutral800),
                    ),
                    Text(
                      '${item.percentage.toInt()}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNeutral700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: kNeutral100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (item.percentage / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kLilac.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [kLilac, kLilac.withOpacity(0.6)],
                        ),
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

  Widget _buildBarChart(String title, List<ChartData> data) {
    if (data.isEmpty) {
      return Container(
        height: 240,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kNeutral200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3)),
            const Expanded(child: Center(child: Text('No data yet', style: TextStyle(fontSize: 13, color: kNeutral400)))),
          ],
        ),
      );
    }
    double maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((entry) {
                ChartData item = entry.value;
                double heightPercent = (item.value / maxValue) * 100;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(item.value.toInt().toString(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kNeutral500)),
                        const SizedBox(height: 4),
                        Container(
                          height: (heightPercent / 100) * 140,
                          decoration: BoxDecoration(
                            color: kLilac.withOpacity(0.8),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [kLilac, kLilac.withOpacity(0.4)],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.label,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral600),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(String title, List<ChartData> data) {
    const colors = [kLilacDeep, kLilac, kLilacLight, kBlueDeep, kPinkDeep, kPurple];
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kNeutral200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3)),
            const SizedBox(height: 48),
            const Center(child: Text('No data yet', style: TextStyle(fontSize: 13, color: kNeutral400))),
            const SizedBox(height: 48),
          ],
        ),
      );
    }
    double total = data.fold(0.0, (sum, d) => sum + d.value);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3)),
          const SizedBox(height: 24),
          Row(
            children: [
               SizedBox(
                 width: 100,
                 height: 100,
                 child: Stack(
                   children: [
                     Center(child: Container(width: 70, height: 70, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                     // Placeholder for a real donut chart if needed, or just visual
                     Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kNeutral100, width: 20))),
                   ],
                 ),
               ),
               const SizedBox(width: 24),
               Expanded(
                 child: Column(
                   children: List.generate(data.length.clamp(0, 4), (i) {
                     double pct = total > 0 ? (data[i].value / total * 100) : 0;
                     return Padding(
                       padding: const EdgeInsets.symmetric(vertical: 4),
                       child: Row(
                         children: [
                           Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                           const SizedBox(width: 8),
                           Expanded(child: Text(data[i].label, style: const TextStyle(fontSize: 11, color: kNeutral600, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                           Text('${pct.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral800)),
                         ],
                       ),
                     );
                   }),
                 ),
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestWeightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HARVEST WEIGHT CONSISTENCY',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 20),
          _buildRatioBar('Light (< 4.5 ${FormatUtils.weightUnit})', _lightPercent.toDouble(), kNeutral400),
          const SizedBox(height: 16),
          _buildRatioBar('Target (4.5 - 5.5 ${FormatUtils.weightUnit})', _targetPercent.toDouble(), kLilac),
          const SizedBox(height: 16),
          _buildRatioBar('Heavy (> 5.5 ${FormatUtils.weightUnit})', _heavyPercent.toDouble(), kNeutral700),
        ],
      ),
    );
  }

  Widget _buildSurvivalFunnelCard() {
    final bornLivePct = _bornTotal > 0 ? ((_bornLive / _bornTotal) * 100).round().toDouble() : 0.0;
    final weanedPct = _bornTotal > 0 ? ((_weanedCount / _bornTotal) * 100).round().toDouble() : 0.0;
    final maturePct = _bornTotal > 0 ? ((_matureCount / _bornTotal) * 100).round().toDouble() : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SURVIVAL FUNNEL',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 20),
          _buildRatioBar('Born Total (100%)', 100.0, kNeutral400),
          const SizedBox(height: 12),
          _buildRatioBar('Born Live', bornLivePct, kNeutral700),
          const SizedBox(height: 12),
          _buildRatioBar('Weaned', weanedPct, kLilac),
          const SizedBox(height: 12),
          _buildRatioBar('Mature', maturePct, kLilacDeep),
        ],
      ),
    );
  }

  Widget _buildFunnelItem(String label, int count, int percentage, int change, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              change != 0 ? '$count ($change)' : '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                fontFeatures: [
                  FontFeature.tabularFigures()
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildUnitEconomicsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UNIT ECONOMICS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 16),
          _buildEconomicRow('Cost Per Doe', 'Feed + Meds ÷ Active Does', _costPerDoe > 0 ? FormatUtils.formatCurrency(_costPerDoe) : '--', '/month'),
          const Divider(height: 28, color: kNeutral200),
          _buildEconomicRow('Cost Per ${FormatUtils.weightUnit} Meat', 'Total Exp ÷ Total ${FormatUtils.weightUnit}', _costPerWeight > 0 ? FormatUtils.formatCurrency(_costPerWeight) : '--', '/${FormatUtils.weightUnit}'),
        ],
      ),
    );
  }

  Widget _buildEconomicRow(String title, String subtitle, String value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kNeutral800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: kNeutral500),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kNeutral900, fontFamily: 'JetBrains Mono'),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 10, color: kNeutral500),
            ),
          ],
        ),
      ],
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<ChartData> data;
  final Color color;

  LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.2),
          color.withOpacity(0.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final pathLine = Path();
    final pathFill = Path();

    double maxValue = 0;
    if (data.isNotEmpty) {
      maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    }
    if (maxValue == 0) maxValue = 1;

    final double stepX = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double y = size.height - (data[i].value / maxValue * size.height * 0.8) - (size.height * 0.1);
      
      if (i == 0) {
        pathLine.moveTo(x, y);
        pathFill.moveTo(x, size.height);
        pathFill.lineTo(x, y);
      } else {
        pathLine.lineTo(x, y);
        pathFill.lineTo(x, y);
      }
      
      if (i == data.length - 1) {
        pathFill.lineTo(x, size.height);
        pathFill.close();
      }
    }

    canvas.drawPath(pathFill, paintFill);
    canvas.drawPath(pathLine, paintLine);

    // Draw dots
    final paintDot = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final paintDotStroke = Paint()..color = color.withOpacity(0.5)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    for (int i = 0; i < data.length; i++) {
        double x = i * stepX;
        double y = size.height - (data[i].value / maxValue * size.height * 0.8) - (size.height * 0.1);
        
        canvas.drawCircle(Offset(x, y), 3, paintDot);
        canvas.drawCircle(Offset(x, y), 3, paintDotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNeutral900)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kNeutral400, letterSpacing: 0.4)),
      ],
    );
  }
}

class _MiniStatData {
  final String label;
  final String value;
  _MiniStatData({required this.label, required this.value});
}
