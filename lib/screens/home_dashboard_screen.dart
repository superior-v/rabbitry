import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'herd_screen.dart';
import 'litters_screen.dart';
import 'finance_screen.dart';
import 'settings_screen.dart';
import 'task_screen.dart';
import 'import_screen.dart';
import 'reports_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/transaction.dart' as finance;
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../widgets/modals/log_birth_modal.dart';

// === PASTEL PALETTE ===
const kLilac = Color(0xFFC3B1E1);
const kLilacLight = Color(0xFFE8DFFA);
const kLilacWash = Color(0xFFF5F1FC);
const kLilacDeep = Color(0xFF7B6BA0);
const kLilacText = Color(0xFF5A4880);

const kBlue = Color(0xFFA8D4F0);
const kBlueLight = Color(0xFFD9EEFB);
const kBlueWash = Color(0xFFF0F7FD);

const kPink = Color(0xFFF2B8C6);
const kPinkLight = Color(0xFFFADCE5);
const kPinkWash = Color(0xFFFDF2F5);

const kNeutral900 = Color(0xFF2C2C2E);
const kNeutral800 = Color(0xFF3A3A3C);
const kNeutral700 = Color(0xFF636366);
const kNeutral600 = Color(0xFF8E8E93);
const kNeutral500 = Color(0xFFAEAEB2);
const kNeutral400 = Color(0xFFC7C7CC);
const kNeutral300 = Color(0xFFE5E5EA);
const kNeutral200 = Color(0xFFF2F2F7);
const kNeutral100 = Color(0xFFF9F9FB);
const kNeutral50 = Color(0xFFFCFCFD);

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
        // Give it a tiny delay to ensure the tab is built/mounted
        Future.delayed(const Duration(milliseconds: 100), () {
          (state._financeTabKey.currentState as dynamic)?.setRabbitFilter(rabbitId);
        });
      }
    }
  }
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _selectedNavIndex = 0;

  final GlobalKey<TaskScreenState> _taskTabKey = GlobalKey<TaskScreenState>();
  final GlobalKey<State<FinanceScreen>> _financeTabKey = GlobalKey<State<FinanceScreen>>();
  late final List<Widget> _navScreens;

  @override
  void initState() {
    super.initState();
    _navScreens = [
      KindleHomeScreen(),
      HerdScreen(),
      LittersScreen(),
      TaskScreen(key: _taskTabKey),
      FinanceScreen(key: _financeTabKey),
    ];
  }

  void _onNavTap(int index) {
    setState(() => _selectedNavIndex = index);
    if (index == 3) _taskTabKey.currentState?.refresh();
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
      floatingActionButton: _selectedNavIndex == 0 ? _buildFAB(context) : null,
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kNeutral200, width: 1)),
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
            label: 'Litters',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.clipboardText(PhosphorIconsStyle.duotone))),
            label: 'Task',
          ),
          BottomNavigationBarItem(
            icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.currencyDollar(PhosphorIconsStyle.duotone))),
            label: 'Finance',
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showQuickActions(context),
      backgroundColor: kLilacDeep,
      elevation: 4,
      shape: const CircleBorder(),
      child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.duotone), color: Colors.white, size: 24),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 20), decoration: BoxDecoration(color: kNeutral300, borderRadius: BorderRadius.circular(100))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kNeutral900)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.duotone), color: kNeutral500)),
                ],
              ),
            ),
            _buildActionRow(context, 'Log Breeding', PhosphorIcons.heart(PhosphorIconsStyle.duotone), kLilacDeep, () => _onNavTap(1)),
            _buildActionRow(context, 'Log Birth', PhosphorIcons.baby(PhosphorIconsStyle.duotone), kPink, () => _onNavTap(2)),
            _buildActionRow(context, 'Add Bunny', PhosphorIcons.plusCircle(PhosphorIconsStyle.duotone), kLilac, () => _onNavTap(1)),
            _buildActionRow(context, 'Add Task', PhosphorIcons.clipboardText(PhosphorIconsStyle.duotone), kLilacDeep, () => _onNavTap(3)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, String label, IconData icon, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 38),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 15, color: kNeutral900, fontWeight: FontWeight.w500)),
          ],
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
  _KindleHomeScreenState createState() => _KindleHomeScreenState();
}

class _KindleHomeScreenState extends State<KindleHomeScreen> {
  final DatabaseService _db = DatabaseService();
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

  // Kindle date data: breed → list of {doeName, buckName, kindleDate, daysUntil}
  Map<String, List<Map<String, dynamic>>> _kindleByBreed = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final rabbits = await _db.getAllRabbits();
      final litters = await _db.getLitters();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      // Stats
      _activeLitters = litters.where((l) => l.status.toLowerCase() != 'archived').length;
      _breederCount = rabbits.where((r) => (r.type == RabbitType.doe || r.type == RabbitType.buck) && r.status != RabbitStatus.archived).length;
      
      // Nursing kits: total kits in litters marked as 'Nursing'
      _nursingKits = litters
          .where((l) => l.status.toLowerCase() == 'nursing')
          .fold(0, (sum, l) => sum + l.kits.where((k) => k.status.toLowerCase() != 'died').length);

      // Weaned kits this month
      int kitsWeaned = 0;
      for (final litter in litters) {
        if (litter.weanDate != null && !litter.weanDate!.isBefore(monthStart)) {
          kitsWeaned += litter.kits.where((k) => k.status.toLowerCase() == 'weaned' || k.status.toLowerCase() == 'growout').length;
        }
      }
      _kitsWeanedCount = kitsWeaned;

      // Monthly sales from transactions
      final transactions = await _db.getAllTransactions();
      _monthlySales = transactions
          .where((t) => t.type == finance.TransactionType.income && !t.date.isBefore(monthStart))
          .fold(0.0, (sum, t) => sum + t.amount);

      // Fallback: If transactions table is missing records, check litters and archived rabbits directly
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
          rabbitsTotal = archivedRabbits
              .where((r) => r.archiveReason == ArchiveReason.sold && r.salePrice != null && r.archiveDate != null && !r.archiveDate!.isBefore(monthStart))
              .fold(0.0, (sum, r) => sum + (r.salePrice ?? 0.0));
        } catch (_) {}
            
        _monthlySales = kitsTotal + rabbitsTotal;
      }

      // Tasks due
      try {
        final todayTasks = await _db.getTasksDueToday();
        final pipelineTasks = await _db.getPipelineTasksDueToday();
        _tasksDue = todayTasks.length + pipelineTasks.length;
      } catch (_) { _tasksDue = 0; }

      // Kindle grouping
      final breedSet = <String>{};
      final kindleMap = <String, List<Map<String, dynamic>>>{};
      
      for (final r in rabbits) {
        if (r.type == RabbitType.doe && r.kindleDate != null && r.status != RabbitStatus.archived) {
          breedSet.add(r.breed);
          kindleMap.putIfAbsent(r.breed, () => []);
          
          String buckName = 'Unknown';
          if (r.lastBreedBuckId != null) {
            try {
              final buck = await _db.getRabbit(r.lastBreedBuckId!);
              if (buck != null) buckName = buck.name;
            } catch (_) {}
          }
          
          final diff = r.kindleDate!.difference(today).inDays;
          kindleMap[r.breed]!.add({
            'doe': r,
            'doeName': r.name,
            'buckName': buckName,
            'kindleDate': r.kindleDate!,
            'daysUntil': diff,
          });
        }
      }
      
      for (final breed in kindleMap.keys) {
        kindleMap[breed]!.sort((a, b) => (a['kindleDate'] as DateTime).compareTo(b['kindleDate'] as DateTime));
      }

      _availableBreeds = breedSet.toList()..sort();
      _kindleByBreed = kindleMap;
    } catch (e) { print('Error loading data: $e'); }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kLilacDeep, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: kLilacDeep,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  _buildMetricsGrid(),
                  const SizedBox(height: 24),
                  _buildKindleSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final logoPath = SettingsService.instance.farmLogo;
    final hasLogo = logoPath != null && File(logoPath).existsSync();

    return AppBar(
      backgroundColor: kLilacWash,
      elevation: 0,
      centerTitle: false,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: hasLogo
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: FileImage(File(logoPath)),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Icon(PhosphorIcons.rabbit(PhosphorIconsStyle.duotone), color: kLilacDeep, size: 32),
      ),
      titleSpacing: 0,
      title: Text(SettingsService.instance.farmName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 19, color: kLilacText, letterSpacing: -0.2)),
      actions: [
        IconButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
            _loadData(); // Refresh if needed
          },
          icon: Icon(PhosphorIcons.chartPieSlice(PhosphorIconsStyle.duotone), color: kLilacDeep, size: 24),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            _loadData();
          },
          icon: Icon(PhosphorIcons.gearSix(PhosphorIconsStyle.duotone), color: kLilacDeep, size: 24),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kLilacLight, height: 1),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.92,
        children: [
          _buildMetricCard('Task Due', '$_tasksDue', PhosphorIcons.clipboardText(PhosphorIconsStyle.duotone)),
          _buildMetricCard('Active Breeder', '$_breederCount', PhosphorIcons.pawPrint(PhosphorIconsStyle.duotone)),
          _buildMetricCard('Litters', '$_activeLitters', PhosphorIcons.baby(PhosphorIconsStyle.duotone)),
          _buildMetricCard('Nursing Kits', '$_nursingKits', PhosphorIcons.firstAid(PhosphorIconsStyle.duotone)),
          _buildMetricCard('Weaned Kits', '$_kitsWeanedCount', PhosphorIcons.plant(PhosphorIconsStyle.duotone)),
          _buildMetricCard('Sales', _monthlySales > 0 ? FormatUtils.formatCurrency(_monthlySales, decimals: 0) : '${FormatUtils.currencySymbol}0', PhosphorIcons.currencyDollar(PhosphorIconsStyle.duotone)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: kLilacDeep),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kNeutral900, height: 1.0)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kNeutral600, height: 1.2), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildKindleSection() {
    final Map<String, List<Map<String, dynamic>>> displayData = _breedFilter == 'All' 
        ? _kindleByBreed 
        : {if (_kindleByBreed.containsKey(_breedFilter)) _breedFilter: _kindleByBreed[_breedFilter]!};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('EXPECTED LITTERS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNeutral500, letterSpacing: 0.6)),
              _buildFilterChip(),
            ],
          ),
          const SizedBox(height: 12),
          if (displayData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 72),
                child: Column(
                  children: [
                    Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.duotone), size: 48, color: kLilacLight),
                    const SizedBox(height: 14),
                    const Text('No expected litters for this breed.', style: TextStyle(color: kNeutral500, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            ...displayData.entries.map((entry) => _buildBreedGroup(entry.key, entry.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildFilterChip() {
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _breedFilter = val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'All', child: Text('All Breeds')),
        ..._availableBreeds.map((b) => PopupMenuItem(value: b, child: Text(b))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: kLilacWash, borderRadius: BorderRadius.circular(100)),
        child: Row(
          children: [
            Icon(PhosphorIcons.funnel(PhosphorIconsStyle.duotone), size: 14, color: kLilac),
            const SizedBox(width: 4),
            Text(_breedFilter == 'All' ? 'All Breeds' : _breedFilter, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kLilacText)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 12, color: kLilacText),
          ],
        ),
      ),
    );
  }

  Widget _buildBreedGroup(String breed, List<Map<String, dynamic>> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          margin: const EdgeInsets.only(top: 20, bottom: 12),
          decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Icon(PhosphorIcons.dna(PhosphorIconsStyle.duotone), color: kLilac, size: 16),
                  const SizedBox(width: 6),
                  Text(breed, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kNeutral800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
                child: Text('${entries.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kLilacText)),
              ),
            ],
          ),
        ),
        ...entries.map((entry) => _buildKindleCard(entry)).toList(),
      ],
    );
  }

  Widget _buildKindleCard(Map<String, dynamic> entry) {
    final int daysUntil = entry['daysUntil'];
    String badgeText = '';
    Color badgeBg = kLilacWash;
    Color badgeTextCol = kLilacDeep;

    if (daysUntil < 0) {
      badgeText = '${daysUntil.abs()}d overdue';
      badgeBg = const Color(0xFFFDF2F4);
      badgeTextCol = const Color(0xFFD94452);
    } else if (daysUntil == 0) {
      badgeText = 'Today';
      badgeBg = const Color(0xFFFFF3E0);
      badgeTextCol = const Color(0xFFE65100);
    } else if (daysUntil <= 3) {
      badgeText = 'in $daysUntil days';
      badgeBg = const Color(0xFFFFF3E0);
      badgeTextCol = const Color(0xFFE65100);
    } else {
      badgeText = 'in $daysUntil days';
      badgeBg = kLilacWash;
      badgeTextCol = kLilacDeep;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: InkWell(
        onTap: () {
          if (entry['doe'] == null) return;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => LogBirthModal(
              doe: entry['doe'],
              onComplete: _loadData,
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.genderFemale(PhosphorIconsStyle.duotone), color: const Color(0xFFD4809A), size: 16),
                            const SizedBox(width: 6),
                            Text(entry['doeName'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kNeutral900)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('×', style: TextStyle(color: kNeutral400, fontWeight: FontWeight.w400, fontSize: 13)),
                            ),
                            Icon(PhosphorIcons.genderMale(PhosphorIconsStyle.duotone), color: const Color(0xFF5B9BD5), size: 16),
                            const SizedBox(width: 6),
                            Text(entry['buckName'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kNeutral900)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(100)),
                          child: Text(badgeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeTextCol)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.duotone), size: 14, color: kLilac),
                        const SizedBox(width: 6),
                        Text('Due ${FormatUtils.formatDateShort(entry['kindleDate'])}', style: const TextStyle(fontSize: 13, color: kNeutral600, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (entry['doe'] != null)
                _buildThreeDotMenu(entry['doe']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreeDotMenu(Rabbit doe) {
    return PopupMenuButton<String>(
      icon: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.duotone), color: kNeutral400, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.duotone), size: 20, color: kNeutral600), const SizedBox(width: 12), const Text('Edit Breeding')])),
        PopupMenuItem(value: 'delete', child: Row(children: [Icon(PhosphorIcons.trash(PhosphorIconsStyle.duotone), size: 20, color: const Color(0xFFE05263)), const SizedBox(width: 12), const Text('Delete Breeding', style: TextStyle(color: Color(0xFFE05263)))]))
      ],
      onSelected: (val) async {
        if (val == 'edit') {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: doe.kindleDate ?? DateTime.now().add(const Duration(days: 31)),
            firstDate: DateTime.now().subtract(const Duration(days: 31)),
            lastDate: DateTime.now().add(const Duration(days: 45)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: kPinkDeep,
                    onPrimary: Colors.white,
                    onSurface: kNeutral900,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedDate != null) {
            final updatedDoe = doe.copyWith(
              kindleDate: pickedDate,
              dueDate: pickedDate,
            );
            await _db.updateRabbit(updatedDoe);
            _loadData();
          }
        } else if (val == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Breeding?'),
              content: const Text('This will clear the breeding schedule for this doe. This action cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05263)),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await _db.markOpenForBreeding(doe.id);
            _loadData();
          }
        }
      },
    );
  }
}
