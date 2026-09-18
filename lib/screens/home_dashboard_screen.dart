import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'herd_screen.dart';
import 'litters_screen.dart';
import 'finance_screen.dart';
import 'settings_screen.dart';
import 'task_screen.dart';
import 'reports_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../models/transaction.dart' as finance;
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../widgets/modals/log_birth_modal.dart';
import '../widgets/modals/confirm_pregnancy_modal.dart';
import '../widgets/modals/log_breeding_modal.dart';
import '../services/app_event_service.dart';

// === EXACT HTML PALETTE ===
const kLilac = Color(0xFFC3B1E1);
const kLilacLight = Color(0xFFE8DFFA);
const kLilacWash = Color(0xFFF4F0FA);
const kLilacDeep = Color(0xFF5E4A8A);
const kLilacText = Color(0xFF463466);

const kPink = Color(0xFFF2B8C6);
const kPinkLight = Color(0xFFFFBCE7);
const kPinkWash = Color(0xFFFDF2F5);
const kPinkDeep = Color(0xFFC47A8B);

// RESTORED BLUE COLORS FOR HERD SCREEN
const kBlue = Color(0xFFA8D4F0);
const kBlueLight = Color(0xFFD9EEFB);
const kBlueWash = Color(0xFFF0F7FD);

const kNeutral900 = Color(0xFF2C2C2E);
const kNeutral800 = Color(0xFF3A3A3C);
const kNeutral700 = Color(0xFF4F4F56);
const kNeutral600 = Color(0xFF66666D);
const kNeutral500 = Color(0xFF787880);
const kNeutral400 = Color(0xFF67676F);
const kNeutral300 = Color(0xFFE5E5EA);
const kNeutral200 = Color(0xFFF2F2F7);
const kNeutral100 = Color(0xFFF9F9FB);
const kNeutral50 = Color(0xFFFCFCFD);

const kError = Color(0xFFE05263);
const kErrorBg = Color(0xFFFDF2F4);

// Custom colors based on the design provided
const kAppBgPurple = Color(0xFFE6BEFE);
const kFabPurple = Color(0xFFE2BFFB);
const kHeaderPink = Color(0xFFFFBCE7); // A lighter, soft pastel pink
const kLightLavender = Color(0xFFEEDAFE);

class HomeDashboardScreen extends StatefulWidget {
  static final GlobalKey<_HomeDashboardScreenState> dashboardKey = GlobalKey<_HomeDashboardScreenState>();

  HomeDashboardScreen({Key? key}) : super(key: key ?? dashboardKey);

  @override
  _HomeDashboardScreenState createState() => _HomeDashboardScreenState();

  static void switchToTab(int index, {String? rabbitId}) {
    final state = dashboardKey.currentState;
    if (state != null) {
      state._onNavTap(index);
      if (index == 4 && rabbitId != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          (state._financeTabKey.currentState as dynamic)?.setRabbitFilter(rabbitId);
        });
      }
    }
  }
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _selectedNavIndex = 0;

  final GlobalKey<KindleHomeScreenState> _homeTabKey = GlobalKey<KindleHomeScreenState>();
  final GlobalKey<HerdScreenState> _herdTabKey = GlobalKey<HerdScreenState>();
  final GlobalKey<LittersScreenState> _littersTabKey = GlobalKey<LittersScreenState>();
  final GlobalKey<TaskScreenState> _taskTabKey = GlobalKey<TaskScreenState>();
  final GlobalKey<FinanceScreenState> _financeTabKey = GlobalKey<FinanceScreenState>();
  late final List<Widget> _navScreens;

  @override
  void initState() {
    super.initState();
    _navScreens = [
      KindleHomeScreen(key: _homeTabKey),
      HerdScreen(key: _herdTabKey),
      LittersScreen(key: _littersTabKey),
      TaskScreen(key: _taskTabKey),
      FinanceScreen(key: _financeTabKey),
    ];
  }

  void _onNavTap(int index) {
    if (_selectedNavIndex == 4 && index != 4) {
      _financeTabKey.currentState?.resetView();
    }
    setState(() => _selectedNavIndex = index);
    if (index == 0) {
      _homeTabKey.currentState?._loadData(showLoading: false);
      _homeTabKey.currentState?.scrollToTop();
    } else if (index == 1) {
      _herdTabKey.currentState?.refresh();
      _herdTabKey.currentState?.scrollToTop();
    } else if (index == 2) {
      _littersTabKey.currentState?.refresh();
      _littersTabKey.currentState?.scrollToTop();
    } else if (index == 3) {
      _taskTabKey.currentState?.refresh();
      _taskTabKey.currentState?.scrollToTop();
    } else if (index == 4) {
      _financeTabKey.currentState?.resetView();
      _financeTabKey.currentState?.refresh();
      _financeTabKey.currentState?.scrollToTop();
    }
  }

  void switchTab(int index) {
    _onNavTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _selectedNavIndex, children: _navScreens),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: kNeutral200,
        border: Border(top: BorderSide(color: kNeutral300, width: 1)),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kLilacDeep,
        unselectedItemColor: kNeutral500,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        currentIndex: _selectedNavIndex,
        onTap: _onNavTap,
        elevation: 0,
        backgroundColor: Colors.transparent,
        items: [
          BottomNavigationBarItem(
            icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.house(PhosphorIconsStyle.duotone))),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.pawPrint(PhosphorIconsStyle.duotone))),
            label: 'Herd',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.baby(PhosphorIconsStyle.duotone))),
            label: 'Nursery',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.checkSquareOffset(PhosphorIconsStyle.duotone))),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.currencyDollar(PhosphorIconsStyle.duotone))),
            label: 'Finance',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// KINDLE HOME SCREEN
// ─────────────────────────────────────────────────────────────────
class KindleHomeScreen extends StatefulWidget {
  const KindleHomeScreen({Key? key}) : super(key: key);

  @override
  KindleHomeScreenState createState() => KindleHomeScreenState();
}

class KindleHomeScreenState extends State<KindleHomeScreen> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String _breedFilter = 'All';
  List<String> _availableBreeds = [];

  // Analytics metrics
  int _activeLitters = 0;
  int _breederCount = 0;
  int _nursingKits = 0;
  int _kitsWeanedCount = 0;
  double _monthlySales = 0.0;
  int _tasksDue = 0;

  Map<String, List<Map<String, dynamic>>> _kindleByBreed = {};

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    dataChangeNotifier.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) _loadData(showLoading: false);
  }

  @override
  void dispose() {
    dataChangeNotifier.removeListener(_onDataChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final rabbits = await _db.getAllRabbits();
      final litters = await _db.getLitters();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      // Litters: Current number of active nursing litters (same as All in Nursery Manager)
      _activeLitters = litters.where((litter) {
        final lStatus = litter.status.toLowerCase().trim();
        final aliveCount = litter.aliveKits ?? litter.kits.where((k) => !k.isArchived).length;
        if (aliveCount == 0 ||
            lStatus == 'died' ||
            lStatus == 'dead' ||
            lStatus == 'archived' ||
            lStatus == 'not taken') {
          return false;
        }
        return true;
      }).length;

      // Breeders: Current number of active does and bucks
      _breederCount = rabbits.where((r) => (r.type == RabbitType.doe || r.type == RabbitType.buck) && r.status != RabbitStatus.archived).length;

      // Kits calculation:
      // Nursing kits: non-archived kits with age < 49 days (7 weeks)
      // Weaned kits: non-archived kits with age >= 49 days (7 weeks)
      int nursingKits = 0;
      int kitsWeaned = 0;
      for (final litter in litters) {
        final lStatus = litter.status.toLowerCase().trim();
        if (lStatus == 'died' || lStatus == 'dead' || lStatus == 'archived' || lStatus == 'not taken') continue;

        final ageInDays = today.difference(litter.dob).inDays;

        for (final kit in litter.kits) {
          if (kit.isArchived) continue;
          final st = kit.status.toLowerCase().trim();
          if (st == 'sold' || st == 'dead' || st == 'died' || st == 'archived' || st == 'cull' || st == 'butchered') continue;

          if (ageInDays >= 49) {
            kitsWeaned++;
          } else {
            nursingKits++;
          }
        }
      }
      _nursingKits = nursingKits;
      _kitsWeanedCount = kitsWeaned;

      final transactions = await _db.getAllTransactions();
      _monthlySales = transactions.where((t) => t.type == finance.TransactionType.income && !t.date.isBefore(monthStart)).fold(0.0, (sum, t) => sum + t.amount);

      if (_monthlySales == 0) {
        double kitsTotal = 0.0;
        for (var l in litters) {
          for (var k in l.kits) {
            if (k.status == 'Sold' && k.price != null) {
              kitsTotal += k.price!;
            }
          }
        }
        double rabbitsTotal = 0.0;
        try {
          final archivedRabbits = await _db.getArchivedRabbits();
          rabbitsTotal = archivedRabbits.where((r) => r.archiveReason == ArchiveReason.sold && r.salePrice != null && r.archiveDate != null && !r.archiveDate!.isBefore(monthStart)).fold(0.0, (sum, r) => sum + (r.salePrice ?? 0.0));
        } catch (_) {}
        _monthlySales = kitsTotal + rabbitsTotal;
      }

      try {
        final todayTasks = await _db.getTasksDueToday();
        final pipelineTasks = await _db.getPipelineTasksDueToday();
        final uncompletedScheduled = todayTasks.where((t) => t['completedAt'] == null).length;
        final uncompletedPipeline = pipelineTasks.where((t) => t['completedAt'] == null).length;
        _tasksDue = uncompletedScheduled + uncompletedPipeline;
      } catch (_) {
        _tasksDue = 0;
      }

      final breedSet = <String>{};
      final kindleMap = <String, List<Map<String, dynamic>>>{};

      String normalizeBreedName(String raw) {
        final trimmed = raw.trim();
        final lower = trimmed.toLowerCase();
        if (lower == 'netherlands' || lower == 'netherland dwarfs' || lower == 'netherland dwarf') {
          return 'Netherland Dwarf';
        }
        if (lower == 'dwarf hotot' || lower == 'hotots' || lower == 'hotot') {
          return 'Dwarf Hotot';
        }
        return trimmed;
      }

      for (final r in rabbits) {
        final expectedKindleDate = r.kindleDate ?? r.dueDate;
        if (r.type == RabbitType.doe && expectedKindleDate != null && r.status != RabbitStatus.archived) {
          final breedName = normalizeBreedName(r.breed);
          breedSet.add(breedName);
          kindleMap.putIfAbsent(breedName, () => []);

          String buckName = 'Unknown';
          if (r.lastBreedBuckId != null) {
            try {
              final buck = await _db.getRabbit(r.lastBreedBuckId!);
              if (buck != null) buckName = buck.name;
            } catch (_) {}
          }

          final diff = expectedKindleDate.difference(today).inDays;
          kindleMap[breedName]!.add({
            'id': r.id,
            'doe': r,
            'doeName': r.name,
            'buckName': buckName,
            'kindleDate': expectedKindleDate,
            'daysUntil': diff,
          });
        }
      }

      for (final breed in kindleMap.keys) {
        kindleMap[breed]!.sort((a, b) => (a['kindleDate'] as DateTime).compareTo(b['kindleDate'] as DateTime));
      }

      final sortedBreedKeys = kindleMap.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final sortedKindleMap = <String, List<Map<String, dynamic>>>{};
      for (final bk in sortedBreedKeys) {
        sortedKindleMap[bk] = kindleMap[bk]!;
      }

      _availableBreeds = breedSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _kindleByBreed = sortedKindleMap;
    } catch (e) {
      print('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kLightLavender,
        body: Center(
          child: CircularProgressIndicator(color: kLilacDeep, strokeWidth: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kLightLavender,
      appBar: _buildSolidAppBar(),
      body: RefreshIndicator(
        onRefresh: () => _loadData(showLoading: false),
        color: kLilacDeep,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeroSection(),
              _buildKindleSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 46,
        height: 46,
        child: FloatingActionButton(
          heroTag: 'home_log_breeding_fab',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => LogBreedingModal(
                onComplete: _loadData,
              ),
            );
          },
          backgroundColor: const Color(0xFFE6BEFE),
          shape: const CircleBorder(),
          elevation: 4,
          child: Icon(
            PhosphorIcons.plus(PhosphorIconsStyle.bold),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSolidAppBar() {
    return AppBar(
      backgroundColor: kAppBgPurple,
      elevation: 0,
      centerTitle: true,
      title: Text(
        SettingsService.instance.farmName.isNotEmpty ? SettingsService.instance.farmName : 'Silly Billy Silkies',
        style: const TextStyle(
          color: Color(0xFF4F4F56),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
            _loadData();
          },
          icon: Icon(PhosphorIcons.chartBar(), color: kNeutral500, size: 24),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            _loadData();
          },
          icon: Icon(PhosphorIcons.gearSix(), color: kNeutral500, size: 24),
          padding: const EdgeInsets.only(right: 8),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      color: kAppBgPurple,
      padding: const EdgeInsets.only(
        top: 6,
        bottom: 12,
        left: 20,
        right: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.42,
            children: [
              _buildMetricCard('Task Due', '$_tasksDue'),
              _buildMetricCard('Breeders', '$_breederCount'),
              _buildMetricCard('Sales', _monthlySales > 0 ? FormatUtils.formatCurrency(_monthlySales, decimals: 0) : '\$0'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF86DAFF), Color(0xFFF0F9FF)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F4F56),
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6E6E73),
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindleSection() {
    final Map<String, List<Map<String, dynamic>>> displayData = _breedFilter == 'All'
        ? _kindleByBreed
        : {
            if (_kindleByBreed.containsKey(_breedFilter)) _breedFilter: _kindleByBreed[_breedFilter]!
          };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kindle Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kNeutral600)),
                  _buildFilterChip(),
                ],
              ),
            ),
            if (displayData.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Text(
                  'No expected litters for this filter.',
                  style: TextStyle(color: kNeutral500, fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < displayData.length; i++)
                        _buildBreedGroup(
                          displayData.keys.elementAt(i),
                          displayData.values.elementAt(i),
                          isFirst: i == 0,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip() {
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _breedFilter = val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'All', child: Text('All Breeds', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ..._availableBreeds.map((b) => PopupMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kNeutral200,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kNeutral300),
        ),
        child: Text(
          _breedFilter == 'All' ? 'All Breed' : _breedFilter,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kNeutral600),
        ),
      ),
    );
  }

  Widget _buildBreedGroup(String breed, List<Map<String, dynamic>> entries, {required bool isFirst}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: EdgeInsets.only(
            left: 0,
            right: 0,
            top: isFirst ? 0 : 8,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: kHeaderPink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            breed,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4F4F56),
            ),
          ),
        ),
        Column(
          children: entries.asMap().entries.map((e) {
            return _buildKindleCard(e.value, index: e.key, isLast: e.key == entries.length - 1);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKindleCard(Map<String, dynamic> entry, {required int index, required bool isLast}) {
    final int daysUntil = entry['daysUntil'];

    String daysText;
    Color daysColor;

    if (daysUntil < 0) {
      daysText = '-${daysUntil.abs()} Days';
      daysColor = kError;
    } else if (daysUntil == 0) {
      daysText = 'Today';
      daysColor = const Color(0xFF2E7D32);
    } else if (daysUntil == 1) {
      daysText = '1 Day';
      daysColor = const Color(0xFF2E7D32);
    } else {
      daysText = '$daysUntil Days';
      daysColor = kNeutral500;
    }

    final DateTime kDate = entry['kindleDate'];
    final List<String> monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final String formattedDate = '${monthNames[kDate.month - 1]} ${kDate.day.toString().padLeft(2, '0')}';

    final isOdd = index % 2 == 1;
    final backgroundColor = isOdd ? const Color(0xFFF9F5FE) : Colors.white;

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          if (entry['doe'] == null) return;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            enableDrag: false,
            backgroundColor: Colors.transparent,
            builder: (_) => LogBirthModal(
              doe: entry['doe'],
              onComplete: _loadData,
            ),
          );
        },
        onLongPress: () {
          if (entry['doe'] != null) {
            _showKindleLongPressMenu(entry['doe'] as Rabbit);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: isLast ? null : const Border(bottom: BorderSide(color: kNeutral200, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: Text(
                  '${entry['doeName']} × ${entry['buckName']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kNeutral800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral600, fontFeatures: [
                    ui.FontFeature.tabularFigures()
                  ]),
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  daysText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: daysColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showKindleLongPressMenu(Rabbit doe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: const Text(
                  'Edit Breeding',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => LogBreedingModal(
                      doe: doe,
                      onComplete: _loadData,
                    ),
                  );
                },
              ),
              if (SettingsService.instance.palpationEnabled)
                ListTile(
                  title: const Text(
                    'Log Palpation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C2C2E),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      enableDrag: false,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ConfirmPregnancyModal(
                        doe: doe,
                        onComplete: _loadData,
                      ),
                    );
                  },
                ),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              ListTile(
                title: const Text(
                  'Cancel Breeding',
                  style: TextStyle(
                    color: Color(0xFFD94452),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Cancel Breeding?', style: TextStyle(fontWeight: FontWeight.w600)),
                      content: const Text('This will clear the breeding schedule for this doe. This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep', style: TextStyle(color: kNeutral600))),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Cancel Breeding', style: TextStyle(color: Color(0xFFD94452), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _db.markOpenForBreeding(doe.id);
                    _loadData();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
