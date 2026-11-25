import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'herd_screen.dart';
import 'litters_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../widgets/modals/rabbit_picker_modal.dart';
import '../services/app_event_service.dart';
import '../services/appearance_service.dart';
import 'package:google_fonts/google_fonts.dart';

// === EXACT HTML PALETTE (Light & Crafted Dark Mode) ===
Color get kLilac => appSurface(0xFFC3B1E1, 0xFF352C4C);
Color get kLilacLight => appSurface(0xFFE8DFFA, 0xFF2B263C);
Color get kLilacWash => appSurface(0xFFF4F0FA, 0xFF232030);
Color get kLilacDeep => appColor(0xFF5E4A8A, 0xFFA78BFA);
Color get kLilacText => appColor(0xFF463466, 0xFFCFC6E6);

Color get kPink => appSurface(0xFFF2B8C6, 0xFF36232F);
Color get kPinkLight => appSurface(0xFFFFBCE7, 0xFF332233);
Color get kPinkWash => appSurface(0xFFFDF2F5, 0xFF28202A);
Color get kPinkDeep => appColor(0xFFC47A8B, 0xFFF48FB1);

// RESTORED BLUE COLORS FOR HERD SCREEN
Color get kBlue => appSurface(0xFFA8D4F0, 0xFF243348);
Color get kBlueLight => appSurface(0xFFD9EEFB, 0xFF202A3A);
Color get kBlueWash => appSurface(0xFFF0F7FD, 0xFF1E2633);

Color get kNeutral900 => appColor(0xFF2C2C2E, 0xFFF1F3F9);
Color get kNeutral800 => appColor(0xFF3A3A3C, 0xFFECEDF4);
Color get kNeutral700 => appColor(0xFF4F4F56, 0xFFC2C6D4);
Color get kNeutral600 => appColor(0xFF66666D, 0xFFB0B5C4);
Color get kNeutral500 => appColor(0xFF787880, 0xFF9095A6);
Color get kNeutral400 => appColor(0xFFC7C7CC, 0xFF7E8494);
Color get kNeutral300 => appSurface(0xFFE5E5EA, 0xFF2D303E);
Color get kNeutral200 => appSurface(0xFFF2F2F7, 0xFF161820);
Color get kNeutral100 => appSurface(0xFFF9F9FB, 0xFF1A1C25);
Color get kNeutral50 => appSurface(0xFFFCFCFD, 0xFF1E2028);

Color get kError => appColor(0xFFE05263, 0xFFFB7185);
Color get kErrorBg => appSurface(0xFFFDF2F4, 0xFF2B2026);

// Custom colors based on the design provided
Color get kAppBgPurple => appSurface(0xFFE6BEFE, 0xFF221C30);
Color get kFabPurple => appSurface(0xFFE2BFFB, 0xFF7C52B8);
Color get kHeaderPink => appSurface(0xFFFFBCE7, 0xFF332233); // A lighter, soft pastel pink / dark berry-plum
Color get kLightLavender => appSurface(0xFFEEDAFE, 0xFF121318);

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

class _HomeDashboardScreenState extends State<HomeDashboardScreen> with WidgetsBindingObserver {
  int _selectedNavIndex = 0;
  bool _wasBackgrounded = false;

  final GlobalKey<KindleHomeScreenState> _homeTabKey = GlobalKey<KindleHomeScreenState>();
  final GlobalKey<HerdScreenState> _herdTabKey = GlobalKey<HerdScreenState>();
  final GlobalKey<LittersScreenState> _littersTabKey = GlobalKey<LittersScreenState>();
  final GlobalKey<TaskScreenState> _taskTabKey = GlobalKey<TaskScreenState>();
  final GlobalKey<FinanceScreenState> _financeTabKey = GlobalKey<FinanceScreenState>();
  late final List<Widget> _navScreens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navScreens = [
      KindleHomeScreen(key: _homeTabKey),
      HerdScreen(key: _herdTabKey),
      LittersScreen(key: _littersTabKey),
      TaskScreen(key: _taskTabKey),
      FinanceScreen(key: _financeTabKey),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      if (isExternalActivityActive || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        _onNavTap(0);
      });
    }
  }

  void _onNavTap(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
    if (_selectedNavIndex == 4 && index != 4) {
      _financeTabKey.currentState?.resetView();
    }
    if (_selectedNavIndex == 2 && index != 2) {
      _littersTabKey.currentState?.collapseAllLitters();
    }
    setState(() => _selectedNavIndex = index);
    if (index == 0) {
      _homeTabKey.currentState?._loadData(showLoading: false);
      _homeTabKey.currentState?.scrollToTop();
    } else if (index == 1) {
      _herdTabKey.currentState?.openDefaultPage();
      _herdTabKey.currentState?.refresh();
      _herdTabKey.currentState?.scrollToTop();
    } else if (index == 2) {
      _littersTabKey.currentState?.openDefaultPage();
      _littersTabKey.currentState?.collapseAllLitters();
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppearanceService.instance.mode,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: kLightLavender,
          resizeToAvoidBottomInset: false,
          body: IndexedStack(index: _selectedNavIndex, children: _navScreens),
          bottomNavigationBar: _buildBottomNavBar(),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    final dark = isAppDark;
    final navItems = <({IconData icon, String label})>[
      (icon: PhosphorIcons.house(PhosphorIconsStyle.duotone), label: 'Home'),
      (icon: PhosphorIcons.pawPrint(PhosphorIconsStyle.duotone), label: 'Herd'),
      (icon: PhosphorIcons.baby(PhosphorIconsStyle.duotone), label: 'Nursery'),
      (icon: PhosphorIcons.checkSquareOffset(PhosphorIconsStyle.duotone), label: 'Tasks'),
      (icon: PhosphorIcons.money(PhosphorIconsStyle.duotone), label: 'Finance'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF161820) : const Color(0xFFF2F2F7),
        border: Border(
          top: BorderSide(
            color: dark ? const Color(0xFF2D303E) : const Color(0xFFE5E5EA),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _selectedNavIndex == index;
              final fgColor = isSelected
                  ? (dark ? const Color(0xFFF1F3F9) : const Color(0xFF2C2C2E))
                  : (dark ? const Color(0xFF8C92A4) : const Color(0xFF4F4F56));

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onNavTap(index),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 60,
                      height: 52,
                      decoration: isSelected
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.78,
                                colors: dark
                                    ? const [
                                        Color(0xFF393C4E),
                                        Color(0xFF2A2D3B),
                                        Color(0xFF1A1C26),
                                      ]
                                    : const [
                                        Color(0xFFC2C2CA), // slightly darker grey in the middle
                                        Color(0xFFD8D8E0), // mid grey transition
                                        Color(0xFFEEEEF4), // fades to lighter grey on the outside
                                      ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            )
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (item.label == 'Finance')
                            SvgPicture.asset(
                              'assets/images/finance_icon.svg',
                              width: 24,
                              height: 24,
                              colorFilter: ColorFilter.mode(fgColor, BlendMode.srcIn),
                            )
                          else
                            Icon(item.icon, size: 24, color: fgColor),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: fgColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
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
      final nextMonthStart = DateTime(now.year, now.month + 1, 1);
      _monthlySales = transactions
          .where((t) => t.type == finance.TransactionType.income && !t.date.isBefore(monthStart) && t.date.isBefore(nextMonthStart))
          .fold(0.0, (sum, t) => sum + t.amount);

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
        if (r.type != RabbitType.doe || r.status == RabbitStatus.archived) continue;

        // A doe should only appear in Kindle Date if she has an active pregnancy/breeding
        // (dueDate is the upcoming expected kindle date for the current breeding)
        DateTime? expectedKindleDate = r.dueDate;

        // If dueDate is not set, check if kindleDate is an upcoming date (not in the past)
        if (expectedKindleDate == null && r.kindleDate != null && !today.isAfter(r.kindleDate!)) {
          expectedKindleDate = r.kindleDate;
        }

        if (expectedKindleDate == null) continue;

        final diff = expectedKindleDate.difference(today).inDays;

        // Only show active breeding: do not show past dates from previous litters (e.g. diff < -5 days)
        // or non-pregnant open/resting does
        if (diff < -5) continue;
        if ((r.status == RabbitStatus.open || r.status == RabbitStatus.resting) && r.lastBreedDate == null) continue;
        if (r.lastBreedDate != null && today.difference(r.lastBreedDate!).inDays > 38) continue;

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

        kindleMap[breedName]!.add({
          'id': r.id,
          'doe': r,
          'doeName': r.name,
          'buckName': buckName,
          'kindleDate': expectedKindleDate,
          'daysUntil': diff,
        });
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
      return Scaffold(
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
          onPressed: _openLogBreedingFlow,
          backgroundColor: appSurface(0xFFE6BEFE, 0xFF7C52B8),
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

  void _openLogBreedingFlow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogBreedingModal(
        onComplete: _loadData,
        autoOpenDoePicker: true,
      ),
    );
  }

  PreferredSizeWidget _buildSolidAppBar() {
    return AppBar(
      backgroundColor: kAppBgPurple,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 48,
      title: Text(
        SettingsService.instance.farmName.isNotEmpty ? SettingsService.instance.farmName : 'Silly Billy Silkies',
        style: TextStyle(
          color: appColor(0xFF2C2C2E),
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
          icon: Icon(PhosphorIconsRegular.chartBar, color: appColor(0xFF3A3A3C), size: 24),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            _loadData();
          },
          icon: Icon(PhosphorIconsRegular.gearSix, color: appColor(0xFF3A3A3C), size: 24),
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
        top: 0,
        bottom: 8,
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
    final dark = isAppDark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            appSurface(0xFF86DAFF, 0xFF263248),
            appSurface(0xFFF0F9FF, 0xFF1D2333),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: dark ? Border.all(color: const Color(0xFF34415C), width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withOpacity(0.28)
                : const Color(0xFF0284C7).withOpacity(0.08),
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: appColor(0xFF4F4F56, 0xFFF1F3F9),
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appColor(0xFF6E6E73, 0xFFB0B8C8),
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
                  Text('Kindle Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kNeutral600)),
                  _buildFilterChip(),
                ],
              ),
            ),
            if (displayData.isEmpty)
              Padding(
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
                    color: kAppCardWhite,
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kNeutral600),
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  breed,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: appColor(0xFF4F4F56, 0xFFF1EFF7),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: appColor(0xFF787880, 0xFFB8B0C8),
                  ),
                ),
              ),
            ],
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

    final String daysText = daysUntil == 0 ? 'Today' : '${daysUntil}d';
    Color daysColor;

    if (daysUntil < 0) {
      daysColor = kError;
    } else if (daysUntil <= 1) {
      daysColor = const Color(0xFF10B981);
    } else {
      daysColor = appColor(0xFF4F4F56);
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
    final backgroundColor = isOdd ? appSurface(0xFFF9F5FE, 0xFF252333) : kAppCardWhite;

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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: kNeutral200, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 6,
                child: Text(
                  '${entry['doeName']}\u00A0× ${entry['buckName']}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: appColor(0xFF1E293B),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: appColor(0xFF334155),
                      fontFeatures: [
                        ui.FontFeature.tabularFigures()
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  daysText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: daysUntil == 0 ? FontWeight.w700 : FontWeight.w500,
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
        decoration: BoxDecoration(
          color: kAppCardWhite,
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
                  color: appSurface(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  'Edit Breeding',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: appColor(0xFF2C2C2E),
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
                      isEditing: true,
                      onComplete: _loadData,
                    ),
                  );
                },
              ),
              if (SettingsService.instance.palpationEnabled)
                ListTile(
                  title: Text(
                    'Log Palpation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: appColor(0xFF2C2C2E),
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
              Divider(height: 1, color: appSurface(0xFFE5E5EA)),
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
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep', style: TextStyle(color: kNeutral600))),
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