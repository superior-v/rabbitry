import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../models/barn.dart';
import '../models/litter.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../widgets/rabbit_card.dart';
import 'dart:io';
import 'rabbit_detail_screen.dart';
import 'add_rabbit_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/action_sheets/rabbit_action_sheet.dart';
import 'home_dashboard_screen.dart'
    show
        kLilac,
        kLilacLight,
        kLilacWash,
        kLilacDeep,
        kLilacText,
        kBlue,
        kBlueLight,
        kBlueWash,
        kPink,
        kPinkLight,
        kPinkWash,
        kNeutral900,
        kNeutral800,
        kNeutral700,
        kNeutral600,
        kNeutral500,
        kNeutral400,
        kNeutral300,
        kNeutral200,
        kNeutral100,
        kNeutral50;

// Re-defining for local scope consistency or using imported ones
const kPrimary = kLilacDeep;
const kDoeTheme = Color(0xFFB5567A);
const kDoeIcon = Color(0xFFD4809A);
const kBuckTheme = Color(0xFF3A7BB8);
const kBuckIcon = Color(0xFF5B9BD5);
const kArchiveTheme = kLilacText;
const kArchiveIcon = kLilacDeep;
const kSuccess = Color(0xFF4CAF50);
const kError = Color(0xFFD94452);
const kWarning = Color(0xFFF59E0B);

class HerdScreen extends StatefulWidget {
  const HerdScreen({Key? key}) : super(key: key);

  @override
  _HerdScreenState createState() => _HerdScreenState();
}

class _HerdScreenState extends State<HerdScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentFilter = 'All'; // This is for status
  String _breedFilter = 'All';   // This is for breed
  String _searchQuery = '';
  String? _locationFilter;
  String _grouping = 'none';
  bool _isBarnEditMode = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final DatabaseService _db = DatabaseService();
  final SettingsService _settings = SettingsService.instance;

  List<Rabbit> _allRabbits = [];
  List<Rabbit> _archivedList = [];
  List<Barn> _barns = [];
  List<Map<String, dynamic>> _growOutKits = []; // Kits in grow-out phase
  bool _isLoading = true;
  int _dataVersion = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentFilter = 'All';
          _breedFilter = 'All';
        });
      }
    });
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    try {
      print('🔄 Loading herd data...');
      final rabbits = await _db.getAllRabbits();
      final archivedRabbits = await _db.getArchivedRabbits();
      final barnsData = await _db.getAllBarns();
      final litters = await _db.getLitters();

      // Extract grow-out kits from litters
      final growOutKits = <Map<String, dynamic>>[];
      for (final litter in litters) {
        for (final kit in litter.kits) {
          if (kit.status == 'GrowOut' || kit.status == 'Weaned') {
            growOutKits.add({
              'kit': kit,
              'litter': litter,
              'age': DateTime.now().difference(litter.dob).inDays,
            });
          }
        }
      }

      print('📊 Loaded ${rabbits.length} rabbits, ${archivedRabbits.length} archived, ${growOutKits.length} grow-out kits');

      for (var rabbit in rabbits) {
        final hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty;
        final photoPath = hasPhoto ? rabbit.photos!.first : null;
        final exists = photoPath != null ? File(photoPath).existsSync() : false;
        print('  📸 ${rabbit.name}: hasPhoto=$hasPhoto, path=$photoPath, exists=$exists');
      }

      if (mounted) {
        setState(() {
          _allRabbits = rabbits;
          _archivedList = archivedRabbits;
          _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
          _growOutKits = growOutKits;
          _isLoading = false;
        });
      }

      print('✅ Herd data loaded and UI updated');
    } catch (e, stackTrace) {
      print('❌ Error loading herd data: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _allRabbits = [];
          _archivedList = [];
          _barns = [];
          _growOutKits = [];
        });
      }
    }
  }

  List<String> _getUniqueBreeds() {
    final breeds = _allRabbits
        .where((r) => r.breed.isNotEmpty)
        .map((r) {
          final b = r.breed;
          if (b == 'Hotot' || b == 'Dwarf Hotot' || b == 'Netherlands') return 'Netherlands';
          return b;
        })
        .toSet()
        .toList();
    breeds.sort();
    return ['All', ...breeds];
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    try {
      print('🔄 Refreshing herd data...');
      final rabbits = await _db.getAllRabbits();
      final archivedRabbits = await _db.getArchivedRabbits();
      final barnsData = await _db.getAllBarns();

      if (mounted) {
        setState(() {
          _allRabbits = rabbits;
          _archivedList = archivedRabbits;
          _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
          _dataVersion++;
        });
      }

      print('✅ Herd data refreshed: ${rabbits.length} rabbits');
    } catch (e) {
      print('❌ Error refreshing herd data: $e');
    }
  }

  Future<void> _deleteRabbit(String id) async {
    await _db.deleteRabbit(id);
    await _refreshData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rabbit deleted')),
      );
    }
  }

  Future<void> _navigateToDetail(Rabbit rabbit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RabbitDetailScreen(rabbit: rabbit),
      ),
    );

    // Force full data reload when returning from detail screen
    if (!mounted) return;
    final rabbits = await _db.getAllRabbits();
    final archivedRabbits = await _db.getArchivedRabbits();
    final barnsData = await _db.getAllBarns();
    if (mounted) {
      setState(() {
        _allRabbits = rabbits;
        _archivedList = archivedRabbits;
        _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
        _dataVersion++;
      });
    }

    // Evict photo caches in background (non-blocking)
    _evictPhotoCaches(rabbit);
  }

  Future<void> _evictPhotoCaches(Rabbit rabbit) async {
    if (rabbit.photos != null && rabbit.photos!.isNotEmpty) {
      for (var path in rabbit.photos!) {
        try {
          await FileImage(File(path)).evict();
        } catch (_) {}
      }
    }
    for (var r in _allRabbits) {
      if (r.photos != null && r.photos!.isNotEmpty) {
        for (var path in r.photos!) {
          try {
            await FileImage(File(path)).evict();
          } catch (_) {}
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _showRabbitActions(Rabbit rabbit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RabbitActionSheet(
        rabbit: rabbit,
        onActionComplete: () async {
          // Don't call Navigator.pop - the modal already handles its own closing
          // Just refresh the data immediately
          print('🔄 Action complete callback triggered - refreshing data...');

          await _refreshData();

          // Force immediate UI rebuild after data refresh
          if (mounted) {
            setState(() {});
          }
        },
      ),
    ).then((_) {
      // Additional refresh when bottom sheet closes
      _refreshData();
    });
  }

  int _countRabbitsInLocation(String location, [String? cage]) {
    return _allRabbits.where((r) {
      if (r.status == RabbitStatus.archived) return false;
      if (cage != null) {
        return r.location == location && r.cage == cage;
      }
      return r.location == location;
    }).length;
  }

  int _countRabbitsInBarn(Barn barn) {
    int total = 0;
    for (var row in barn.rows) {
      total += _countRabbitsInLocation(row.name);
    }
    return total;
  }

  int _getTotalRabbits() {
    return _allRabbits.where((r) => r.status != RabbitStatus.archived).length;
  }

  int _getUnassignedCount() {
    return _allRabbits.where((r) {
      return r.status != RabbitStatus.archived && (r.location == null || r.location!.isEmpty || r.location == 'Unassigned');
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kPrimary)),
        ),
      );
    }

    final activeThemeColor = _tabController.index == 0 ? kPinkWash : (_tabController.index == 1 ? kBlueWash : kLilacWash);
    final activeBorderColor = _tabController.index == 0 ? kPinkLight : (_tabController.index == 1 ? kBlueLight : kLilacLight);
    final activeTextColor = _tabController.index == 0 ? kDoeTheme : (_tabController.index == 1 ? kBuckTheme : kLilacText);
    final activeIconColor = _tabController.index == 0 ? kDoeIcon : (_tabController.index == 1 ? kBuckIcon : kLilacDeep);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: activeThemeColor,
            border: Border(bottom: BorderSide(color: activeBorderColor)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(PhosphorIcons.pawPrint(PhosphorIconsStyle.duotone), color: activeIconColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Breeders Directory',
                    style: TextStyle(
                      color: activeTextColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showBarnDrawer,
                    icon: Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone), color: activeIconColor, size: 24),
                  ),
                  IconButton(
                    onPressed: () => _searchFocusNode.requestFocus(),
                    icon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone), color: activeIconColor, size: 24),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCleanTabs(),
          _buildSearchAndGroup(),
          if (_locationFilter != null) _buildFilterBanner(),
          _buildFilterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: kPrimary,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  KeyedSubtree(key: ValueKey('does_$_dataVersion'), child: _buildRabbitList(RabbitType.doe)),
                  KeyedSubtree(key: ValueKey('bucks_$_dataVersion'), child: _buildRabbitList(RabbitType.buck)),
                  KeyedSubtree(key: ValueKey('archive_$_dataVersion'), child: _buildArchivedList()),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index < 2
          ? FloatingActionButton(
              heroTag: 'herd_fab',
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddRabbitScreen()));
                if (result == true) {
                  await _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🐰 Rabbit added successfully'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating, backgroundColor: kPrimary),
                    );
                  }
                }
              },
              backgroundColor: activeIconColor,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, size: 28, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCleanTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          _buildPillTab('Does', PhosphorIcons.genderFemale(PhosphorIconsStyle.duotone), 0, kDoeIcon),
          const SizedBox(width: 8),
          _buildPillTab('Bucks', PhosphorIcons.genderMale(PhosphorIconsStyle.duotone), 1, kBuckIcon),
          const SizedBox(width: 8),
          _buildPillTab('Archive', PhosphorIcons.archive(PhosphorIconsStyle.duotone), 2, kLilacDeep),
        ],
      ),
    );
  }

  Widget _buildPillTab(String label, IconData icon, int index, Color activeColor) {
    final isActive = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {
            _currentFilter = 'All';
            _breedFilter = 'All';
            _locationFilter = null;
          });
        },
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? activeColor : kNeutral300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : activeColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? Colors.white : kNeutral700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndGroup() {
    // Determine active colors based on tab
    final activeWash = _tabController.index == 0 ? kPinkWash : (_tabController.index == 1 ? kBlueWash : kLilacWash);
    final activeBorder = _tabController.index == 0 ? kPinkLight : (_tabController.index == 1 ? kBlueLight : kLilacLight);
    final activeText = _tabController.index == 0 ? kDoeTheme : (_tabController.index == 1 ? kBuckTheme : kLilacText);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: kNeutral50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeutral200),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search ID or Name...',
                hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400, fontSize: 16),
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone), color: kNeutral500, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildControlItem(
                label: _breedFilter == 'All' ? 'Filter' : _breedFilter,
                icon: PhosphorIcons.funnel(PhosphorIconsStyle.duotone),
                isActive: _breedFilter != 'All',
                activeWash: activeWash,
                activeBorder: activeBorder,
                activeText: activeText,
                onTap: _showBreedFilterModal,
              ),
              const SizedBox(width: 8),
              _buildControlItem(
                label: _sortQuery == 'name' ? 'Sort' : 'Sort: ${_settingsCase(_sortQuery)}',
                icon: PhosphorIcons.sortAscending(PhosphorIconsStyle.duotone),
                isActive: _sortQuery != 'name',
                activeWash: activeWash,
                activeBorder: activeBorder,
                activeText: activeText,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMenuOption('Breed', 'breed', _sortQuery == 'breed', (v) => setState(() => _sortQuery = v)),
                        _buildMenuOption('Name', 'name', _sortQuery == 'name', (v) => setState(() => _sortQuery = v)),
                        _buildMenuOption('Cage', 'cage', _sortQuery == 'cage', (v) => setState(() => _sortQuery = v)),
                        _buildMenuOption('Age: Youngest First', 'age_asc', _sortQuery == 'age_asc', (v) => setState(() => _sortQuery = v)),
                        _buildMenuOption('Age: Oldest First', 'age_desc', _sortQuery == 'age_desc', (v) => setState(() => _sortQuery = v)),
                        _buildMenuOption('ID / Ear #', 'id', _sortQuery == 'id', (v) => setState(() => _sortQuery = v)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildControlItem(
                label: _grouping == 'none' ? 'Group' : 'Group: ${_settingsCase(_grouping)}',
                icon: PhosphorIcons.rows(PhosphorIconsStyle.duotone),
                isActive: _grouping != 'none',
                activeWash: activeWash,
                activeBorder: activeBorder,
                activeText: activeText,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMenuOption('None', 'none', _grouping == 'none', (v) => setState(() => _grouping = v)),
                        _buildMenuOption('Location', 'location', _grouping == 'location', (v) => setState(() => _grouping = v)),
                        _buildMenuOption('Breed', 'breed', _grouping == 'breed', (v) => setState(() => _grouping = v)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _sortQuery = 'name';
  String _settingsCase(String s) {
    if (s.isEmpty) return '';
    if (s == 'age_asc') return 'Age Asc';
    if (s == 'age_desc') return 'Age Desc';
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildMenuOption(String label, String value, bool isSelected, Function(String) onSelect) {
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check, color: kLilacDeep) : null,
      onTap: () { onSelect(value); Navigator.pop(context); },
    );
  }

  Widget _buildControlItem({required String label, required IconData icon, required bool isActive, required Color activeWash, required Color activeBorder, required Color activeText, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? activeWash : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? activeBorder : kNeutral300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? activeText : kNeutral700),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isActive ? activeText : kNeutral700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBreedFilterModal() {
    final List<String> filters = _getUniqueBreeds();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: filters.map((f) {
              return _buildMenuOption(f, f, _breedFilter == f, (v) => setState(() => _breedFilter = v));
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kLilacWash,
        border: Border.all(color: kLilacLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: kLilacDeep),
          const SizedBox(width: 8),
          const Text(
            'Filtering: ',
            style: TextStyle(color: kLilacDeep, fontSize: 14),
          ),
          if (_locationFilter != null) ...[
            Text(
              'Location: $_locationFilter',
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_breedFilter != 'All') const Text(' • ', style: TextStyle(color: Color(0xFF6366F1))),
          ],
          if (_breedFilter != 'All')
            Text(
              'Breed: $_breedFilter',
              style: const TextStyle(
                color: kLilacDeep,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _locationFilter = null;
              _breedFilter = 'All';
            }),
            child: const Icon(Icons.close, size: 18, color: kLilacDeep),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    List<String> filters = [];
    if (_tabController.index == 0) {
      filters = ['All', 'Open', 'Bred', 'Nursing', 'Resting', 'GrowOut', 'Quarantine'];
    } else if (_tabController.index == 1) {
      filters = ['All', 'Active', 'Inactive', 'GrowOut', 'Quarantine'];
    } else {
      filters = ['All', 'Sold', 'Butchered', 'Dead', 'Cull'];
    }

    final activeColor = _tabController.index == 0 ? kDoeIcon : (_tabController.index == 1 ? kBuckIcon : kLilacDeep);

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isActive = _currentFilter == filter;
          final label = filter == 'GrowOut' ? 'Grow-outs' : filter;

          return GestureDetector(
            onTap: () => setState(() => _currentFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? activeColor : Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: isActive ? activeColor : kNeutral300),
                boxShadow: isActive
                    ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : kNeutral700,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrowOutList() {
    List<Map<String, dynamic>> filtered = _growOutKits.where((data) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final kit = data['kit'] as Kit;
        if (!kit.id.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.plant(PhosphorIconsStyle.duotone), size: 64, color: const Color(0xFFE9E9E7)),
            const SizedBox(height: 16),
            const Text(
              'No kits in grow-out phase',
              style: TextStyle(
                color: Color(0xFF787774),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kits will appear here after weaning',
              style: TextStyle(
                color: Color(0xFF787774),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildGrowOutCard(filtered[index]),
    );
  }

  Widget _buildGrowOutCard(Map<String, dynamic> data) {
    final kit = data['kit'] as Kit;
    final litter = data['litter'] as Litter;
    final age = data['age'] as int;
    final sexualMaturityAge = _settings.sexualMaturityAge;
    final daysToMaturity = sexualMaturityAge - age;
    final progressToMaturity = (age / sexualMaturityAge).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    kit.sex == 'male' ? PhosphorIconsRegular.genderMale : PhosphorIconsRegular.genderFemale,
                    color: kit.sex == 'male' ? const Color(0xFF2E7BB5) : const Color(0xFF9C6ADE),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kit #${kit.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'From: ${litter.doeName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: daysToMaturity <= 0 ? const Color(0xFF6366F1).withOpacity(0.1) : const Color(0xFFF5A623).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysToMaturity <= 0 ? 'Ready' : '$daysToMaturity days',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: daysToMaturity <= 0 ? const Color(0xFF6366F1) : const Color(0xFFF5A623),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Age: $age days',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF787774)),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressToMaturity,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE9E9E7),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            daysToMaturity <= 0 ? const Color(0xFF6366F1) : const Color(0xFFF5A623),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (daysToMaturity <= 0)
                  TextButton(
                    onPressed: () => _promoteToBreeder(kit, litter),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Promote',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promoteToBreeder(Kit kit, Litter litter) async {
    final nameController = TextEditingController(text: 'Kit #${kit.id}');
    final idController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote to Breeder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Promote Kit #${kit.id} to an active breeder?'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'ID/Ear Tag (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('Promote', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.promoteKitToBreeder(
          litter,
          kit,
          customName: nameController.text.isNotEmpty ? nameController.text : null,
          customId: idController.text.isNotEmpty ? idController.text : null,
        );
        await _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${nameController.text} promoted to breeder!'),
              backgroundColor: const Color(0xFF6366F1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error promoting kit: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildArchivedList() {
    List<Rabbit> filtered = _archivedList.where((r) {
      if (_breedFilter != 'All') {
        if (r.breed != _breedFilter) return false;
      }

      if (_currentFilter != 'All') {
        if (_currentFilter == 'Sold' && r.archiveReason != ArchiveReason.sold) return false;
        if (_currentFilter == 'Butchered' && r.archiveReason != ArchiveReason.butchered) return false;
        if (_currentFilter == 'Dead' && r.archiveReason != ArchiveReason.dead) return false;
        if (_currentFilter == 'Cull' && r.archiveReason != ArchiveReason.cull) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!r.name.toLowerCase().contains(query) && !r.id.toLowerCase().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.archive(PhosphorIconsStyle.duotone), size: 64, color: kNeutral200),
            const SizedBox(height: 16),
            const Text(
              'No archived rabbits',
              style: TextStyle(
                color: kNeutral600,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildRedesignedRabbitCard(filtered[index]),
    );
  }

  Widget _buildArchiveCard(Rabbit rabbit) {
    final bool hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty && rabbit.photos!.first.isNotEmpty;
    final String? photoPath = hasPhoto ? rabbit.photos!.first : null;
    final bool isPhotoValid = photoPath != null && File(photoPath).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(rabbit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    width: 2,
                  ),
                  image: isPhotoValid
                      ? DecorationImage(
                          image: FileImage(File(photoPath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !isPhotoValid
                    ? Icon(
                        rabbit.type == RabbitType.doe ? Icons.female : Icons.male,
                        color: const Color(0xFF6366F1),
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rabbit.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          rabbit.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Archive',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Color(0xFF9B9A97))),
                        Text(
                          rabbit.breed,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (rabbit.archiveReason != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: rabbit.archiveReason!.backgroundColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getArchiveIcon(rabbit.archiveReason!),
                              size: 14,
                              color: rabbit.archiveReason!.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rabbit.archiveReason!.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: rabbit.archiveReason!.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    _buildArchiveDetails(rabbit),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Color(0xFF9B9A97)),
                iconSize: 20,
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(
                  minWidth: 56,
                  minHeight: 56,
                ),
                onPressed: () => _showArchiveMenu(rabbit),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getArchiveIcon(ArchiveReason reason) {
    switch (reason) {
      case ArchiveReason.sold:
        return Icons.monetization_on_outlined;
      case ArchiveReason.butchered:
        return Icons.restaurant_outlined;
      case ArchiveReason.dead:
        return Icons.close;
      case ArchiveReason.cull:
        return Icons.block;
    }
  }

  Widget _buildArchiveDetails(Rabbit rabbit) {
    switch (rabbit.archiveReason) {
      case ArchiveReason.sold:
        return Row(
          children: [
            Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Price: ${FormatUtils.formatCurrency(rabbit.salePrice ?? 0)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(width: 16),
            Icon(Icons.pets, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                rabbit.breed,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case ArchiveReason.butchered:
        return Row(
          children: [
            Icon(Icons.scale, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Yield: ${rabbit.butcherYield?.toStringAsFixed(1) ?? '0.0'} ${FormatUtils.weightUnit}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(width: 16),
            Icon(Icons.pets, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                rabbit.breed,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case ArchiveReason.dead:
        return Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Cause: ${rabbit.deathCause ?? 'Unknown'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.pets, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              rabbit.breed,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        );

      case ArchiveReason.cull:
        return Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Reason: ${rabbit.cullReason ?? 'Not specified'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.pets, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              rabbit.breed,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _showArchiveMenu(Rabbit rabbit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined, color: Color(0xFF6366F1)),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                _navigateToDetail(rabbit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: Color(0xFF2E7BB5)),
              title: const Text('Restore to Active'),
              subtitle: const Text('Move back to active breeders'),
              onTap: () async {
                Navigator.pop(context);
                await _restoreRabbit(rabbit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFE63946)),
              title: const Text('Remove Permanently'),
              subtitle: const Text('Cannot be undone'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(rabbit);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreRabbit(Rabbit rabbit) async {
    try {
      await _db.markOpenForBreeding(rabbit.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rabbit.name} restored to active breeders'),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );
      }

      await _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring rabbit: $e'),
            backgroundColor: const Color(0xFFE63946),
          ),
        );
      }
    }
  }

  void _confirmDelete(Rabbit rabbit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Permanently?'),
        content: Text(
          'Are you sure you want to permanently delete ${rabbit.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _db.deleteRabbit(rabbit.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${rabbit.name} permanently removed'),
                    backgroundColor: const Color(0xFFE63946),
                  ),
                );
              }
              await _refreshData();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE63946)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRabbitList(RabbitType type) {
    List<Rabbit> filtered = _allRabbits.where((r) {
      if (r.type != type) return false;
      if (r.status == RabbitStatus.archived) return false;

      if (_breedFilter != 'All') {
        final rb = r.breed;
        final normalizedBreed = (rb == 'Hotot' || rb == 'Dwarf Hotot') ? 'Netherlands' : rb;
        if (normalizedBreed != _breedFilter) return false;
      }

      if (_currentFilter != 'All') {
        final statusName = r.status.toString().split('.').last.toLowerCase();
        final filterName = _currentFilter.toLowerCase();
        if (filterName == 'growout') {
          if (statusName != 'growout' && statusName != 'weaned') return false;
        } else if (filterName == 'bred') {
          if (statusName != 'palpatedue' && statusName != 'pregnant') return false;
        } else if (statusName != filterName) {
          return false;
        }
      }

      if (_locationFilter != null) {
        if (_locationFilter == 'Unassigned') {
          if (r.location != null && r.location!.isNotEmpty && r.location != 'Unassigned') return false;
        } else if (r.location != _locationFilter) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!r.name.toLowerCase().contains(query) && !r.id.toLowerCase().contains(query)) return false;
      }
      return true;
    }).toList();

    // Apply Sorting
    filtered.sort((a, b) {
      if (_sortQuery == 'breed') return a.breed.compareTo(b.breed);
      if (_sortQuery == 'cage') return (a.cage ?? '').compareTo(b.cage ?? '');
      if (_sortQuery == 'id') return a.id.compareTo(b.id);
      if (_sortQuery == 'age_asc') {
        // Youngest to Oldest (Latest DOB first)
        final dobA = a.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dobB = b.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dobB.compareTo(dobA); 
      }
      if (_sortQuery == 'age_desc') {
        // Oldest to Youngest (Earliest DOB first)
        final dobA = a.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dobB = b.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dobA.compareTo(dobB);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets_outlined, size: 64, color: Color(0xFFE9E9E7)),
            const SizedBox(height: 16),
            const Text(
              'No rabbits found',
              style: TextStyle(
                color: Color(0xFF787774),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_currentFilter != 'All' || _breedFilter != 'All' || _searchQuery.isNotEmpty || _locationFilter != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _currentFilter = 'All';
                      _breedFilter = 'All';
                      _searchQuery = '';
                      _locationFilter = null;
                    });
                  },
                  child: const Text('Clear Filters'),
                ),
              ),
          ],
        ),
      );
    }

    Widget _buildCountHeader(int count) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$count ${count == 1 ? "bunny" : "bunnies"}',
              style: const TextStyle(
                fontSize: 12,
                color: kNeutral500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_grouping == 'none') {
      return Column(
        children: [
          _buildCountHeader(filtered.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final rabbit = filtered[index];
                return _buildRedesignedRabbitCard(rabbit);
              },
            ),
          ),
        ],
      );
    }

    Map<String, List<Rabbit>> groups = {};
    for (var rabbit in filtered) {
      String key = _grouping == 'location' ? (rabbit.location ?? 'Unassigned') : rabbit.breed;
      groups.putIfAbsent(key, () => []).add(rabbit);
    }

    List<String> sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Unassigned') return -1;
        if (b == 'Unassigned') return 1;
        return a.compareTo(b);
      });

    return Column(
      children: [
        _buildCountHeader(filtered.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: sortedKeys.map((key) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          _grouping == 'location' ? PhosphorIcons.warehouse(PhosphorIconsStyle.duotone) : PhosphorIcons.pawPrint(PhosphorIconsStyle.duotone),
                          size: 16,
                          color: kNeutral500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          key.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kNeutral500,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kNeutral100,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: kNeutral200),
                          ),
                          child: Text(
                            '${groups[key]!.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...groups[key]!.map((rabbit) => _buildRedesignedRabbitCard(rabbit)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRedesignedRabbitCard(Rabbit rabbit) {
    final themeColor = rabbit.type == RabbitType.doe ? kPinkWash : (rabbit.type == RabbitType.buck ? kBlueWash : kLilacWash);
    final borderColor = rabbit.type == RabbitType.doe ? kPinkLight : (rabbit.type == RabbitType.buck ? kBlueLight : kLilacLight);
    final iconColor = rabbit.type == RabbitType.doe ? kDoeIcon : (rabbit.type == RabbitType.buck ? kBuckIcon : kLilacDeep);
    final textColor = rabbit.type == RabbitType.doe ? kDoeTheme : (rabbit.type == RabbitType.buck ? kBuckTheme : kLilacText);

    final hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty;
    final photoPath = hasPhoto ? rabbit.photos!.first : null;
    final isPhotoValid = photoPath != null && File(photoPath).existsSync();

    return GestureDetector(
      onTap: () => _navigateToDetail(rabbit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: isPhotoValid
                          ? Image.file(
                              File(photoPath),
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Icon(
                                rabbit.type == RabbitType.doe ? PhosphorIcons.genderFemale(PhosphorIconsStyle.duotone) : PhosphorIcons.genderMale(PhosphorIconsStyle.duotone),
                                color: iconColor,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    if (rabbit.breederPrefix != null && rabbit.breederPrefix!.isNotEmpty)
                                      TextSpan(
                                        text: '${rabbit.breederPrefix} ',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'Product Sans'),
                                      ),
                                      TextSpan(
                                        text: rabbit.name,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kNeutral800, fontFamily: 'Product Sans'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              rabbit.type == RabbitType.doe ? PhosphorIcons.genderFemale(PhosphorIconsStyle.duotone) : PhosphorIcons.genderMale(PhosphorIconsStyle.duotone),
                              size: 16,
                              color: iconColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rabbit.breed} • ${rabbit.age}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Action Menu
                  GestureDetector(
                    onTap: () => _showRabbitActions(rabbit),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold), color: textColor, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Status & Badges
              Row(
                children: [
                  if (!(rabbit.type == RabbitType.buck && rabbit.status == RabbitStatus.open))
                    _buildStatusBadge(rabbit),
                  const Spacer(),
                  if (rabbit.weight != null)
                    _buildStatTag(
                      PhosphorIcons.scales(PhosphorIconsStyle.duotone),
                      FormatUtils.formatWeight(rabbit.weight!),
                      textColor,
                    ),
                  const SizedBox(width: 6),
                  _buildStatTag(
                    PhosphorIcons.hash(PhosphorIconsStyle.duotone),
                    rabbit.earNumber ?? (rabbit.id.length >= 6 ? rabbit.id.substring(0, 6) : rabbit.id).toUpperCase(),
                    textColor,
                  ),
                ],
              ),
              if (rabbit.statusDetails != null || (rabbit.notes != null && rabbit.notes!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.note(PhosphorIconsStyle.duotone), size: 14, color: textColor.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rabbit.statusDetails ?? rabbit.notes ?? '',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.8), height: 1.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Rabbit rabbit) {
    final statusColor = Color(rabbit.statusColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        rabbit.statusText.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildStatTag(IconData icon, String value, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }

  void _showBarnDrawer() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Barn Drawer',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                        decoration: BoxDecoration(
                          color: kLilacWash,
                          border: Border(bottom: BorderSide(color: kLilacLight)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone), color: kLilacDeep, size: 22),
                                        const SizedBox(width: 8),
                                        Text(
                                          'BARN & CAGES',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: kLilacText,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Manage your layout',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: kLilacText.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _isBarnEditMode = !_isBarnEditMode;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isBarnEditMode ? kLilacDeep : Colors.white,
                                      border: Border.all(
                                        color: _isBarnEditMode ? kLilacDeep : kLilacLight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _isBarnEditMode ? 'Done' : 'Manage',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _isBarnEditMode ? Colors.white : kLilacDeep,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (!_isBarnEditMode) ...[
                              _buildBarnTreeItem(
                                icon: PhosphorIcons.gridFour(PhosphorIconsStyle.duotone),
                                label: 'All Locations',
                                count: _getTotalRabbits(),
                                isActive: _locationFilter == null,
                                onTap: () {
                                  setState(() => _locationFilter = null);
                                  Navigator.pop(context);
                                },
                              ),
                              _buildBarnTreeItem(
                                icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.duotone),
                                label: 'Unassigned',
                                count: _getUnassignedCount(),
                                isActive: _locationFilter == 'Unassigned',
                                onTap: () {
                                  setState(() => _locationFilter = 'Unassigned');
                                  Navigator.pop(context);
                                },
                                isWarning: true,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Divider(color: kNeutral200, height: 1),
                              ),
                            ],
                            ..._barns.map((barn) => _buildBarnSection(
                                  barn,
                                  setModalState,
                                  context,
                                )),
                          ],
                        ),
                      ),
                      if (_isBarnEditMode)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: kNeutral200)),
                          ),
                          child: ElevatedButton(
                            onPressed: () => _addBarn(setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kLilacWash,
                              foregroundColor: kLilacDeep,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: kLilacDeep, width: 1.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIcons.plusCircle(PhosphorIconsStyle.duotone), size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Add New Barn / Building',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  Widget _buildBarnTreeItem({
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isActive ? kLilacWash : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? kLilacLight : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? kLilacDeep : (isWarning ? kError : kNeutral600)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? kLilacDeep : (isWarning ? kError : kNeutral700),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.5) : kNeutral100,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? kLilacDeep : kNeutral600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarnSection(Barn barn, StateSetter setModalState, BuildContext dialogContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(top: 16, bottom: 6),
          decoration: BoxDecoration(
            color: kLilacWash,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kLilacLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  barn.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kLilacDeep,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_isBarnEditMode && _countRabbitsInBarn(barn) == 0)
                IconButton(
                  icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), size: 16, color: kError),
                  onPressed: () => _deleteBarn(barn, setModalState),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        ...barn.rows.map((row) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isBarnEditMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.square(PhosphorIconsStyle.duotone), size: 14, color: kNeutral500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kNeutral800),
                        ),
                      ),
                      if (_countRabbitsInLocation(row.name) == 0)
                        IconButton(
                          icon: Icon(PhosphorIcons.trash(PhosphorIconsStyle.bold), size: 14, color: kError),
                          onPressed: () => _deleteRow(barn, row, setModalState),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                )
              else
                _buildBarnTreeItem(
                  icon: PhosphorIcons.list(PhosphorIconsStyle.duotone),
                  label: row.name,
                  count: _countRabbitsInLocation(row.name),
                  isActive: _locationFilter == row.name,
                  onTap: () {
                    setState(() => _locationFilter = row.name);
                    Navigator.pop(dialogContext);
                  },
                ),
              if (_isBarnEditMode) ...[
                ...row.cages.map((cage) {
                  final cageCount = _countRabbitsInLocation(row.name, cage);
                  return Container(
                    margin: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kNeutral50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kNeutral200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cage,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral700),
                        ),
                        if (cageCount == 0)
                          IconButton(
                            icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 12, color: kNeutral400),
                            onPressed: () => _deleteCage(barn, row, cage, setModalState),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          Text(
                            'Occupied',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kNeutral400),
                          ),
                      ],
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
                  child: GestureDetector(
                    onTap: () => _addCage(barn, row, setModalState),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: kLilacLight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 12, color: kLilacDeep),
                          const SizedBox(width: 4),
                          Text(
                            'Add Cage',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kLilacDeep),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
        if (_isBarnEditMode)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 16),
            child: TextButton.icon(
              onPressed: () => _addRowToBarn(barn, setModalState),
              icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 14),
              label: const Text('Add Row / Unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: kLilacDeep,
                backgroundColor: kLilacWash,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: kLilacLight)),
              ),
            ),
          ),
      ],
    );
  }

  void _addBarn(StateSetter setModalState) async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Barn'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter Barn Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final barnId = 'barn_${DateTime.now().millisecondsSinceEpoch}';
      final newBarn = Barn(id: barnId, name: controller.text, rows: []);
      await _db.insertBarn(newBarn.toMap());
      await _refreshData();
      setModalState(() {});
    }
  }

  void _addRowToBarn(Barn barn, StateSetter setModalState) async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Row'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter Row Name (e.g. Row C)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setModalState(() {
        barn.rows.add(BarnRow(name: controller.text, cages: []));
      });
      await _db.updateBarn(barn.toMap());
      await _refreshData();
    }
  }

  void _addCage(Barn barn, BarnRow row, StateSetter setModalState) async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Cage'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter Cage ID'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setModalState(() {
        row.cages.add(controller.text);
      });
      await _db.updateBarn(barn.toMap());
      await _refreshData();
    }
  }

  void _deleteBarn(Barn barn, StateSetter setModalState) async {
    if (_countRabbitsInBarn(barn) > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete occupied barn')),
        );
      }
      return;
    }

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Barn'),
        content: Text('Are you sure you want to delete ${barn.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _db.deleteBarn(barn.id);
      await _refreshData();
      setModalState(() {});
    }
  }

  void _deleteRow(Barn barn, BarnRow row, StateSetter setModalState) async {
    if (_countRabbitsInLocation(row.name) > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete occupied row')),
        );
      }
      return;
    }

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Row'),
        content: Text('Are you sure you want to delete ${row.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      setModalState(() {
        barn.rows.remove(row);
      });
      await _db.updateBarn(barn.toMap());
      await _refreshData();
    }
  }

  void _deleteCage(Barn barn, BarnRow row, String cage, StateSetter setModalState) async {
    if (_countRabbitsInLocation(row.name, cage) > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cage is occupied')),
        );
      }
      return;
    }

    setModalState(() {
      row.cages.remove(cage);
    });
    await _db.updateBarn(barn.toMap());
    await _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
