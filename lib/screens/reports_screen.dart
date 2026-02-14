import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import '../models/report_models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedPeriod = '30D';
  bool showBest = true;

  final List<String> periods = [
    '7D',
    '30D',
    '90D',
    'YTD',
    'All'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                  backgroundColor: Color(0xFF0F7B6C),
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
            child: TabBarView(
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
              },
              child: Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFE2E8F0),
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
                    color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF64748B),
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
        labelColor: Color(0xFF0F7B6C),
        unselectedLabelColor: Color(0xFF64748B),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorColor: Color(0xFF0F7B6C),
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

  Widget _buildProductionTab() {
    final kpis = [
      KPICard(label: 'Active Litters', value: '--', subtitle: ''),
      KPICard(label: 'Live Kits Born', value: '--', subtitle: ''),
      KPICard(label: 'Avg Litter', value: '--', subtitle: 'Target: 8.0'),
      KPICard(label: 'Gestation', value: '--', subtitle: 'Range: 30-33'),
    ];

    final gestationData = <ChartData>[];

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildConceptionRateCard(),
        SizedBox(height: 24),
        _buildPerformanceCard(),
        SizedBox(height: 24),
        _buildBarChart('Gestation Days', gestationData),
      ],
    );
  }

  Widget _buildGrowthTab() {
    final kpis = [
      KPICard(label: 'Meat Yield', value: '--', subtitle: 'Last 30 Days'),
      KPICard(label: 'Avg Live Wt', value: '--', subtitle: 'At Harvest'),
      KPICard(label: 'Dress-Out', value: '--', subtitle: ''),
      KPICard(label: 'Avg Age', value: '--', subtitle: 'To Butcher'),
    ];

    final growthData = <ChartData>[];

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildBarChart('Avg Growth Rate (lbs)', growthData),
        SizedBox(height: 24),
        _buildHarvestWeightCard(),
      ],
    );
  }

  Widget _buildHealthTab() {
    final kpis = [
      KPICard(label: 'Survival Rate', value: '--', subtitle: 'Target: 90%+'),
      KPICard(label: 'Losses', value: '--', subtitle: 'Last 30 days'),
      KPICard(label: 'Doe Mortality', value: '--', subtitle: 'Active Herd'),
      KPICard(label: 'Quarantine', value: '--', subtitle: 'Current'),
    ];

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildDonutChart(
          'Causes of Loss',
          <ChartData>[],
        ),
        SizedBox(height: 24),
        _buildSurvivalFunnelCard(),
      ],
    );
  }

  Widget _buildFinanceTab() {
    final kpis = [
      KPICard(label: 'Net Profit', value: '--'),
      KPICard(label: 'Revenue', value: '--'),
      KPICard(label: 'Expense', value: '--'),
      KPICard(label: 'Cost / Kit', value: '--'),
    ];

    final incomeData = <ChartData>[];

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildKPIGrid(kpis),
        SizedBox(height: 24),
        _buildUnitEconomicsCard(),
        SizedBox(height: 24),
        _buildDonutChart(
          'Expenses',
          [
            ChartData(label: 'Feed', value: 75),
            ChartData(label: 'Equipment', value: 15),
            ChartData(label: 'Meds', value: 10),
          ],
        ),
        SizedBox(height: 24),
        _buildBarChart('Income Sources', incomeData),
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
          _buildRatioBar('Does', 0, Color(0xFF0F7B6C)),
          SizedBox(height: 16),
          _buildRatioBar('Bucks', 0, Color(0xFF475569)),
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
    // TODO: Load performance data from database
    final List<RankingItem> rankings = [];

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
          ...rankings.map((item) => _buildRankingRow(item, showBest)),
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
                    ? Color(0xFF0F7B6C)
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
      Color(0xFF0F7B6C),
      Color(0xFF475569),
      Color(0xFF94A3B8)
    ];

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
                    colors: colors,
                    stops: [
                      0.0,
                      0.4,
                      0.7
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
                  children: List.generate(data.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[index],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                data[index].label,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
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
          _buildRatioBar('Light (< 4.5 lbs)', 0, Color(0xFF94A3B8)),
          SizedBox(height: 16),
          _buildRatioBar('Target (4.5 - 5.5 lbs)', 0, Color(0xFF0F7B6C)),
          SizedBox(height: 16),
          _buildRatioBar('Heavy (> 5.5 lbs)', 0, Color(0xFF475569)),
        ],
      ),
    );
  }

  Widget _buildSurvivalFunnelCard() {
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
          _buildFunnelItem('Born Total', 0, 0, 0, Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: _buildFunnelItem('Born Live', 0, 0, 0, Color(0xFF475569)),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: _buildFunnelItem('Weaned', 0, 0, 0, Color(0xFF5EEAD4)),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 24),
            child: _buildFunnelItem('Mature', 0, 0, 0, Color(0xFF0F7B6C)),
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
          _buildEconomicRow('Cost Per Doe', 'Feed + Meds / Active Does', '--', '/mo'),
          Divider(height: 28, color: Color(0xFFE2E8F0)),
          _buildEconomicRow('Cost Per lb Meat', 'Total Exp / Total lbs', '--', '/lb'),
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
