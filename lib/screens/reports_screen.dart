import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import '../models/report_models.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/transaction.dart' as finance_model;
import '../services/database_service.dart';
import '../services/format_utils.dart';

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
  List<RankingItem> _doeRankings = [];
  List<ChartData> _gestationData = [];

  // Growth
  double _totalMeatYield = 0;
  double _avgHarvestWeight = 0;
  int _avgButcherAge = 0;
  int _dressOutPercent = 0;
  List<ChartData> _growthData = [];
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

    // Gestation days
    List<double> gestations = [];
    for (final l in periodLitters) {
      if (l.kindleDate != null) {
        final days = l.kindleDate!.difference(l.breedDate).inDays;
        if (days > 25 && days < 40) {
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

    // Growth data by breed
    Map<String, List<double>> breedWeights = {};
    for (final r in butchered) {
      if (r.weight != null && r.weight! > 0 && r.breed.isNotEmpty) {
        breedWeights.putIfAbsent(r.breed, () => []);
        breedWeights[r.breed]!.add(r.weight!);
      }
    }
    _growthData = breedWeights.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return ChartData(label: e.key, value: double.parse(avg.toStringAsFixed(1)));
    }).toList();

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

    _matureCount = _allRabbits.where((r) => r.type == RabbitType.doe || r.type == RabbitType.buck).where((r) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Analytics',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download, color: Color(0xFF1E293B)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Export feature coming soon'),
                  backgroundColor: Color(0xFF8B5E3C),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF8B5E3C)))
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

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((period) {
            bool isSelected = selectedPeriod == period;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedPeriod = period;
                });
                _computeAnalytics();
                setState(() {});
              },
              child: Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Color(0xFF8B5E3C) : Color(0xFFE2E8F0),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Color(0xFF8B5E3C) : Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Color(0xFF8B5E3C),
        unselectedLabelColor: Color(0xFF64748B),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorColor: Color(0xFF8B5E3C),
        indicatorWeight: 2,
        tabs: [
          Tab(text: 'Production'),
          Tab(text: 'Growth'),
          Tab(text: 'Health'),
          Tab(text: 'Finance'),
        ],
      ),
    );
  }

  String _fmtNum(double val, {int decimals = 1}) {
    if (val == 0) return '0';
    if (val == val.roundToDouble() && decimals <= 1) return val.toInt().toString();
    return val.toStringAsFixed(decimals);
  }

  Widget _buildProductionTab() {
    final kpis = [
      KPICard(label: 'Active Litters', value: '$_activeLitters'),
      KPICard(label: 'Live Kits Born', value: '$_totalLiveKitsBorn'),
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
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildConceptionRateCard(),
        SizedBox(height: 24),
        _buildPerformanceCard(),
        SizedBox(height: 24),
        _buildBarChart('Gestation Days', _gestationData),
      ],
    );
  }

  Widget _buildGrowthTab() {
    final kpis = [
      KPICard(
        label: 'Meat Yield',
        value: _totalMeatYield > 0 ? '${_fmtNum(_totalMeatYield)} ${FormatUtils.weightUnit}' : '--',
        subtitle: 'Period Total',
      ),
      KPICard(
        label: 'Avg Live Wt',
        value: _avgHarvestWeight > 0 ? '${_fmtNum(_avgHarvestWeight)} ${FormatUtils.weightUnit}' : '--',
        subtitle: 'At Harvest',
      ),
      KPICard(
        label: 'Dress-Out',
        value: _dressOutPercent > 0 ? '$_dressOutPercent%' : '--',
      ),
      KPICard(
        label: 'Avg Age',
        value: _avgButcherAge > 0 ? '${_avgButcherAge}w' : '--',
        subtitle: 'To Butcher',
      ),
    ];

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildBarChart('Avg Harvest Wt by Breed (${FormatUtils.weightUnit})', _growthData),
        SizedBox(height: 24),
        _buildHarvestWeightCard(),
      ],
    );
  }

  Widget _buildHealthTab() {
    final kpis = [
      KPICard(
        label: 'Survival Rate',
        value: _bornTotal > 0 ? '$_survivalRate%' : '--',
        subtitle: 'Target: 90%+',
      ),
      KPICard(
        label: 'Losses',
        value: '$_totalLosses',
        subtitle: 'This period',
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
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildDonutChart('Causes of Loss', _lossData),
        SizedBox(height: 24),
        _buildSurvivalFunnelCard(),
      ],
    );
  }

  Widget _buildFinanceTab() {
    final kpis = [
      KPICard(
        label: 'Net Profit',
        value: _netProfit != 0 ? FormatUtils.formatCurrency(_netProfit) : '--',
        isTrending: _netProfit != 0,
        isPositive: _netProfit >= 0,
        subtitle: _netProfit != 0 ? (_netProfit >= 0 ? 'Profit' : 'Loss') : null,
      ),
      KPICard(
        label: 'Revenue',
        value: _totalRevenue > 0 ? FormatUtils.formatCurrency(_totalRevenue) : '--',
      ),
      KPICard(
        label: 'Expense',
        value: _totalExpense > 0 ? FormatUtils.formatCurrency(_totalExpense) : '--',
      ),
      KPICard(
        label: 'Cost / Kit',
        value: _costPerKit > 0 ? FormatUtils.formatCurrency(_costPerKit) : '--',
      ),
    ];

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildUnitEconomicsCard(),
        SizedBox(height: 24),
        _buildDonutChart('Expenses', _expenseData),
        SizedBox(height: 24),
        _buildBarChart('Income Sources', _incomeData),
      ],
    );
  }

  Widget _buildKPIGrid(List<KPICard> kpis) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                kpi.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                kpi.value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                  fontFeatures: [
                    FontFeature.tabularFigures()
                  ],
                ),
              ),
              if (kpi.subtitle != null)
                Row(
                  children: [
                    if (kpi.isTrending)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kpi.isPositive ? Color(0xFFECFDF5) : Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              kpi.isPositive ? Icons.trending_up : Icons.trending_down,
                              size: 12,
                              color: kpi.isPositive ? Color(0xFF10B981) : Color(0xFFEF4444),
                            ),
                            SizedBox(width: 2),
                            Text(
                              kpi.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kpi.isPositive ? Color(0xFF10B981) : Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        kpi.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConceptionRateCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conception Rate',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          _buildRatioBar('Does', _doeConceptionRate, Color(0xFF8B5E3C)),
          SizedBox(height: 16),
          _buildRatioBar('Bucks', _buckConceptionRate, Color(0xFF475569)),
        ],
      ),
    );
  }

  Widget _buildRatioBar(String label, int percentage, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 14,
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
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
          SizedBox(height: 20),
          if (displayRankings.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No breeding data yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
            )
          else
            ...displayRankings.map((item) => _buildRankingRow(item, showBest)),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Color(0xFF1E293B) : Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildRankingRow(RankingItem item, bool isBest) {
    Color percentColor;
    if (isBest) {
      percentColor = item.percentage >= 90 ? Color(0xFF10B981) : Color(0xFF1E293B);
    } else {
      percentColor = item.percentage <= 50 ? Color(0xFFEF4444) : Color(0xFFF59E0B);
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            margin: EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: item.isTop && isBest
                  ? Color(0xFFFEF3C7)
                  : !isBest && item.rank == 1
                      ? Color(0xFFFEF2F2)
                      : Color(0xFFF5F7FA),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: item.isTop && isBest
                      ? Color(0xFFD97706)
                      : !isBest && item.rank == 1
                          ? Color(0xFFEF4444)
                          : Color(0xFF64748B),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.name} (${item.id})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.percentage}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: percentColor,
                  fontFeatures: [
                    FontFeature.tabularFigures()
                  ],
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Survival',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(String title, List<ChartData> data) {
    if (data.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 24),
            Center(
              child: Text(
                'No data yet',
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      );
    }
    double maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) maxValue = 1;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 200, // Increased height
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((entry) {
                int index = entry.key;
                ChartData item = entry.value;
                double heightPercent = (item.value / maxValue) * 100;
                Color barColor = heightPercent >= 70
                    ? Color(0xFF8B5E3C)
                    : heightPercent >= 40
                        ? Color(0xFF475569)
                        : Color(0xFF94A3B8);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min, // Add this
                      children: [
                        // Value label on top of bar
                        if (heightPercent > 15)
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${item.value.toInt()}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        // Bar
                        Container(
                          height: (heightPercent / 100) * 150, // Reduced from 140
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(height: 6), // Reduced from 8
                        // Label below bar
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
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
    final colors = [
      Color(0xFF8B5E3C),
      Color(0xFF475569),
      Color(0xFF94A3B8),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
    ];

    if (data.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            SizedBox(height: 24),
            Center(child: Text('No data yet', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)))),
            SizedBox(height: 24),
          ],
        ),
      );
    }

    // Compute sweep gradient stops from data percentages
    List<double> stops = [];
    final total = data.fold(0.0, (sum, d) => sum + d.value);
    if (total > 0) {
      double cumulative = 0;
      for (int i = 0; i < data.length; i++) {
        stops.add(cumulative / total);
        cumulative += data[i].value;
      }
    } else {
      stops = List.generate(data.length, (i) => i / (data.length > 1 ? data.length - 1 : 1));
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFFE2E8F0), width: 20),
                  gradient: SweepGradient(
                    colors: data.length >= 2
                        ? List.generate(data.length, (i) => colors[i % colors.length])
                        : [
                            colors[0],
                            colors[0]
                          ],
                    stops: data.length >= 2
                        ? stops
                        : [
                            0.0,
                            1.0
                          ],
                  ),
                ),
                child: Container(
                  margin: EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: List.generate(data.length.clamp(0, 6), (index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colors[index % colors.length],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    data[index].label,
                                    style: TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${data[index].value.toInt()}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              fontFeatures: [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harvest Weight Consistency',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          _buildRatioBar('Light (< 4.5 ${FormatUtils.weightUnit})', _lightPercent, Color(0xFF94A3B8)),
          SizedBox(height: 16),
          _buildRatioBar('Target (4.5 - 5.5 ${FormatUtils.weightUnit})', _targetPercent, Color(0xFF8B5E3C)),
          SizedBox(height: 16),
          _buildRatioBar('Heavy (> 5.5 ${FormatUtils.weightUnit})', _heavyPercent, Color(0xFF475569)),
        ],
      ),
    );
  }

  Widget _buildSurvivalFunnelCard() {
    final bornLivePct = _bornTotal > 0 ? ((_bornLive / _bornTotal) * 100).round() : 0;
    final weanedPct = _bornTotal > 0 ? ((_weanedCount / _bornTotal) * 100).round() : 0;
    final maturePct = _bornTotal > 0 ? ((_matureCount / _bornTotal) * 100).round() : 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Survival Funnel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          _buildFunnelItem('Born Total', _bornTotal, 100, 0, Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: _buildFunnelItem('Born Live', _bornLive, bornLivePct, _bornTotal > 0 ? _bornLive - _bornTotal : 0, Color(0xFF475569)),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: _buildFunnelItem('Weaned', _weanedCount, weanedPct, 0, Color(0xFF5EEAD4)),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 24),
            child: _buildFunnelItem('Mature', _matureCount, maturePct, 0, Color(0xFF8B5E3C)),
          ),
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit Economics',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 16),
          _buildEconomicRow('Cost Per Doe', 'Feed + Meds / Active Does', _costPerDoe > 0 ? FormatUtils.formatCurrency(_costPerDoe) : '--', '/mo'),
          Divider(height: 28, color: Color(0xFFE2E8F0)),
          _buildEconomicRow('Cost Per ${FormatUtils.weightUnit} Meat', 'Total Exp / Total ${FormatUtils.weightUnit}', _costPerWeight > 0 ? FormatUtils.formatCurrency(_costPerWeight) : '--', '/${FormatUtils.weightUnit}'),
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontFeatures: [
                  FontFeature.tabularFigures()
                ],
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
