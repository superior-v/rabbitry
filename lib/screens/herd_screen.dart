import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../models/barn.dart';
import '../models/litter.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import 'dart:io';
import 'rabbit_detail_screen.dart';
import 'add_rabbit_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/action_sheets/rabbit_action_sheet.dart';
import '../services/app_event_service.dart';
import '../constants/app_colors.dart';
import '../widgets/sale_ribbon_painter.dart';
import '../utils/toast_utils.dart';

// Re-defining for local scope consistency or using imported ones
const kDoeTheme = Color(0xFFB5567A);
const kDoeIcon = Color(0xFFD4809A);
const kBuckTheme = Color(0xFF3A7BB8);
const kBuckIcon = Color(0xFF5B9BD5);
const kArchiveTheme = Color(0xFF8E8E93);
const kArchiveIcon = Color(0xFF636366);
const kSuccess = Color(0xFF4CAF50);
const kError = Color(0xFFD94452);
const kWarning = Color(0xFFF59E0B);

// Specific constants to match the provided image
const Color iHeaderBg = Color(0xFFE6BEFE);
const Color iAppBg = Color(0xFFEEDAFE);
const Color iTextDark = Color(0xFF3F3B46);
const Color iTextLight = Color(0xFFA5A1AE);

class HerdScreen extends StatefulWidget {
  const HerdScreen({Key? key}) : super(key: key);

  @override
  HerdScreenState createState() => HerdScreenState();
}

class HerdScreenState extends State<HerdScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _doeScrollController = ScrollController();
  final ScrollController _buckScrollController = ScrollController();
  final ScrollController _archiveScrollController = ScrollController();

  void scrollToTop() {
    if (_doeScrollController.hasClients) _doeScrollController.jumpTo(0.0);
    if (_buckScrollController.hasClients) _buckScrollController.jumpTo(0.0);
    if (_archiveScrollController.hasClients) _archiveScrollController.jumpTo(0.0);
  }
  String _currentFilter = 'All'; // This is for status
  String _breedFilter = 'All'; // This is for breed
  String _searchQuery = '';
  String? _locationFilter;
  String _grouping = 'none';
  bool _isBarnEditMode = false;
  bool _isSearchEnabled = false; // New flag for the ultimate focus block
  bool _keyboardWasOpen = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(canRequestFocus: false, skipTraversal: true);

  final DatabaseService _db = DatabaseService();
  final SettingsService _settings = SettingsService.instance;

  List<Rabbit> _allRabbits = [];
  List<Rabbit> _archivedList = [];
  List<Barn> _barns = [];
  List<Map<String, dynamic>> _growOutKits = []; // Kits in grow-out phase
  List<Litter> _litters = [];
  final Map<String, Rabbit> _rabbitCache = {};
  final Map<String, String> _rabbitNameMap = {};
  final Set<String> _fetchingIds = {};
  bool _isLoading = true;
  int _dataVersion = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentFilter = _settings.defaultHerdFilter;
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentFilter = _tabController.index == 0 ? _settings.defaultHerdFilter : 'All';
          _breedFilter = 'All';
        });
      }
    });
    // Start with focus disabled to prevent auto-popup
    _searchFocusNode.canRequestFocus = false;
    _searchFocusNode.addListener(_handleSearchFocusChange);
    _loadData();
    dataChangeNotifier.addListener(_onDataChanged);
  }

  void openDefaultPage() {
    _searchFocusNode.unfocus();
    _searchFocusNode.canRequestFocus = false;
    final defaultFilter = _settings.defaultHerdFilter;
    if (_tabController.index != 0 && (defaultFilter == 'Pregnant' || defaultFilter == 'Nursing')) {
      _tabController.index = 0;
    }
    setState(() {
      _currentFilter = _tabController.index == 0 ? defaultFilter : 'All';
      _breedFilter = 'All';
      _searchQuery = '';
      _locationFilter = null;
    });
  }

  void _onDataChanged() {
    if (mounted) _refreshData();
  }

  Future<void> refresh() async {
    await _refreshData();
  }

  void _handleSearchFocusChange() {
    if (!_searchFocusNode.hasFocus) {
      if (_searchFocusNode.canRequestFocus) {
        _searchFocusNode.canRequestFocus = false;
      }
      if (mounted && _isSearchEnabled) {
        setState(() {
          _isSearchEnabled = false;
        });
      }
    }
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
      await _db.syncAllNursingDoes();
      final rabbits = await _db.getAllRabbits();
      final archivedRabbits = await _db.getArchivedRabbits();
      final pedigreeRabbits = await _db.getRabbitsByType(RabbitType.pedigree);
      final barnsData = await _db.getAllBarns();
      final litters = await _db.getLitters();
      final allNames = await _db.getAllRabbitDisplayNames();

      _rabbitNameMap.clear();
      _rabbitNameMap.addAll(allNames);

      for (final r in rabbits) _rabbitCache[r.id] = r;
      for (final r in archivedRabbits) _rabbitCache[r.id] = r;
      for (final r in pedigreeRabbits) _rabbitCache[r.id] = r;

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

      for (int i = 0; i < rabbits.length; i++) {
        final r = rabbits[i];
        if (r.status == RabbitStatus.growout && r.dateOfBirth != null) {
          final fiveMonthsDate = DateTime(r.dateOfBirth!.year, r.dateOfBirth!.month + 5, r.dateOfBirth!.day);
          if (!DateTime.now().isBefore(fiveMonthsDate)) {
            final newStatus = r.type == RabbitType.buck ? RabbitStatus.active : RabbitStatus.open;
            final updatedRabbit = r.copyWith(status: newStatus, activeInRabbitry: true);
            rabbits[i] = updatedRabbit;
            _rabbitCache[r.id] = updatedRabbit;
            await _db.updateRabbit(updatedRabbit);
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
          _litters = litters;
          _isLoading = false;
        });
      }

      print('âœ… Herd data loaded and UI updated');
    } catch (e, stackTrace) {
      print('âŒ Error loading herd data: $e');
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

  String _normalizeBreed(String rawBreed) {
    final b = rawBreed.trim();
    final bLower = b.toLowerCase();
    if (bLower == 'netherlands' || bLower == 'netherland dwarfs' || bLower == 'netherland dwarf') {
      return 'Netherland Dwarf';
    }
    if (bLower == 'dwarf hotot' || bLower == 'hotots' || bLower == 'hotot') {
      return 'Dwarf Hotot';
    }
    return b;
  }

  List<String> _getUniqueBreeds() {
    final breeds = _allRabbits
        .where((r) => r.breed.isNotEmpty)
        .map((r) => _normalizeBreed(r.breed))
        .toSet()
        .toList();

    breeds.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      'All',
      ...breeds
    ];
  }



  Future<void> _refreshData() async {
    if (!mounted) return;

    try {
      print('🔄 Refreshing herd data...');
      final rabbits = await _db.getAllRabbits();
      final archivedRabbits = await _db.getArchivedRabbits();
      final pedigreeRabbits = await _db.getRabbitsByType(RabbitType.pedigree);
      final barnsData = await _db.getAllBarns();
      final litters = await _db.getLitters();
      final allNames = await _db.getAllRabbitDisplayNames();

      _rabbitNameMap.clear();
      _rabbitNameMap.addAll(allNames);

      for (final r in rabbits) _rabbitCache[r.id] = r;
      for (final r in archivedRabbits) _rabbitCache[r.id] = r;
      for (final r in pedigreeRabbits) _rabbitCache[r.id] = r;

      if (mounted) {
        setState(() {
          _allRabbits = rabbits;
          _archivedList = archivedRabbits;
          _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
          _litters = litters;
          _dataVersion++;
        });
      }

      print('âœ… Herd data refreshed: ${rabbits.length} rabbits');
    } catch (e) {
      print('âŒ Error refreshing herd data: $e');
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

  Future<void> _navigateToDetail(Rabbit rabbit, {int tabIndex = 1}) async {
    _searchFocusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RabbitDetailScreen(rabbit: rabbit, initialTabIndex: tabIndex),
      ),
    );

    // Explicitly unfocus and LOCK focus again when returning
    if (mounted) {
      setState(() {
        _isSearchEnabled = false;
        _searchFocusNode.canRequestFocus = false;
      });
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }

    // Force full data reload when returning from detail screen
    if (!mounted) return;
    final rabbits = await _db.getAllRabbits();
    final archivedRabbits = await _db.getArchivedRabbits();
    final pedigreeRabbits = await _db.getRabbitsByType(RabbitType.pedigree);
    final barnsData = await _db.getAllBarns();
    final litters = await _db.getLitters();

    for (final r in rabbits) _rabbitCache[r.id] = r;
    for (final r in archivedRabbits) _rabbitCache[r.id] = r;
    for (final r in pedigreeRabbits) _rabbitCache[r.id] = r;

    if (mounted) {
      setState(() {
        _allRabbits = rabbits;
        _archivedList = archivedRabbits;
        _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
        _litters = litters;
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

  Future<void> _showRabbitActions(Rabbit rabbit) async {
    _searchFocusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RabbitActionSheet(
        rabbit: rabbit,
        onActionComplete: () async {
          // Don't call Navigator.pop - the modal already handles its own closing
          // Just refresh the data immediately
          print('ðŸ”„ Action complete callback triggered - refreshing data...');

          await _refreshData();

          // Force immediate UI rebuild after data refresh
          if (mounted) {
            setState(() {});
          }
        },
      ),
    ).then((_) {
      // Explicitly unfocus and LOCK focus again
      if (mounted) {
        setState(() {
          _isSearchEnabled = false;
          _searchFocusNode.canRequestFocus = false;
        });
        FocusScope.of(context).unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _refreshData();
      }
    });
  }

  int _countRabbitsInLocation(String location, [String? cage]) {
    return _allRabbits.where((r) {
      if (r.type == RabbitType.pedigree || r.id.startsWith('PED-') || r.id.startsWith('ped_')) return false;
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
    return _allRabbits.where((r) => r.status != RabbitStatus.archived && r.type != RabbitType.pedigree && !r.id.startsWith('PED-') && !r.id.startsWith('ped_')).length;
  }

  int _getUnassignedCount() {
    return _allRabbits.where((r) {
      return r.status != RabbitStatus.archived && r.type != RabbitType.pedigree && !r.id.startsWith('PED-') && !r.id.startsWith('ped_') && (r.location == null || r.location!.isEmpty || r.location == 'Unassigned');
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: iAppBg,
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep)),
        ),
      );
    }

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardVisible) {
      _keyboardWasOpen = true;
    } else if (_keyboardWasOpen && _searchFocusNode.hasFocus) {
      _keyboardWasOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      });
    }

    final activeIconColor = const Color(0xFFB388C7);

    return Scaffold(
      backgroundColor: iAppBg,
      body: Column(
        children: [
          Container(
            color: iHeaderBg,
            child: Column(
              children: [
                _buildHeader(),
                _buildSegmentedControl(),
                _buildActionRow(),
              ],
            ),
          ),
          if (_locationFilter != null) _buildFilterBanner(),
          _buildPipelineMenu(),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (DragEndDetails details) {
                final velocity = details.primaryVelocity ?? 0.0;
                if (velocity < -150) {
                  _onSwipeGreyBar(true); // Swipe left -> Next tab
                } else if (velocity > 150) {
                  _onSwipeGreyBar(false); // Swipe right -> Previous tab
                }
              },
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: kLilacDeep,
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
          ),
        ],
      ),
      floatingActionButton: _tabController.index < 2
          ? SizedBox(
              width: 46,
              height: 46,
              child: FloatingActionButton(
                heroTag: 'herd_fab',
                onPressed: () async {
                  _searchFocusNode.unfocus();
                  _searchFocusNode.canRequestFocus = false;
                  FocusScope.of(context).unfocus();
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddRabbitScreen()));
                  if (mounted) {
                    _searchFocusNode.unfocus();
                    _searchFocusNode.canRequestFocus = false;
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isSearchEnabled = false;
                    });
                  }
                  if (result == true) {
                    await _refreshData();
                  }
                },
                backgroundColor: const Color(0xFFE6BEFE),
                shape: const CircleBorder(),
                elevation: 4,
                child: Icon(
                  PhosphorIcons.plus(PhosphorIconsStyle.bold),
                  size: 20,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.pawPrint(PhosphorIconsStyle.duotone), color: const Color(0xFF5A4880), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Herd',
                    style: TextStyle(
                      color: Color(0xFF4F4F56),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      alignment: Alignment.center,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFE4E4E9), // Grey base background
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildSegmentBtn('Does', 0),
              _buildSegmentBtn('Bucks', 1),
              _buildSegmentBtn('Archive', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentBtn(String label, int index) {
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF3B3B43) : const Color(0xFF66666D),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kNeutral300),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular), color: kNeutral400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autocorrect: false,
                      enableSuggestions: false,
                      onTap: () {
                        _searchFocusNode.canRequestFocus = true;
                        _searchFocusNode.requestFocus();
                      },
                      onChanged: (value) => setState(() => _searchQuery = value),
                      onSubmitted: (_) {
                        _searchFocusNode.unfocus();
                        _searchFocusNode.canRequestFocus = false;
                      },
                      onTapOutside: (event) {
                        _searchFocusNode.unfocus();
                        _searchFocusNode.canRequestFocus = false;
                      },
                      onEditingComplete: () {
                        _searchFocusNode.unfocus();
                        _searchFocusNode.canRequestFocus = false;
                      },
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by name or ID',
                        hintStyle: TextStyle(color: kNeutral400, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(Icons.clear, size: 18, color: kNeutral500),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Group Button
          _buildIconBtnMenu(
            icon: PhosphorIcons.squaresFour(PhosphorIconsStyle.bold),
            isActive: _grouping != 'none',
            items: [
              _buildPopupItem('None', 'none', _grouping == 'none'),
              _buildPopupItem('Location', 'location', _grouping == 'location'),
              _buildPopupItem('Breed', 'breed', _grouping == 'breed'),
            ],
            onSelected: (v) => setState(() => _grouping = v),
          ),
          const SizedBox(width: 6),

          // Arrange / Sort Button
          _buildIconBtnMenu(
            icon: PhosphorIcons.arrowDown(PhosphorIconsStyle.bold),
            isActive: _sortQuery != 'default',
            items: [
              _buildPopupItem('Default (${_settings.sortDoeBuck})', 'default', _sortQuery == 'default'),
              _buildPopupItem('Breed', 'breed', _sortQuery == 'breed'),
              _buildPopupItem('Name', 'name', _sortQuery == 'name'),
              _buildPopupItem('Cage', 'cage', _sortQuery == 'cage'),
              _buildPopupItem('Age (Youngest)', 'age_asc', _sortQuery == 'age_asc'),
              _buildPopupItem('Age (Oldest)', 'age_desc', _sortQuery == 'age_desc'),
              _buildPopupItem('ID / Ear #', 'id', _sortQuery == 'id'),
            ],
            onSelected: (v) => setState(() => _sortQuery = v),
          ),
          const SizedBox(width: 6),

          // Filter Button
          _buildIconBtnMenu(
            icon: PhosphorIcons.funnel(PhosphorIconsStyle.bold),
            isActive: _breedFilter != 'All',
            items: _getUniqueBreeds().map((f) => _buildPopupItem(
              f,
              f,
              _breedFilter == f,
            )).toList(),
            onSelected: (v) => setState(() => _breedFilter = v),
          ),
        ],
      ),
    );
  }

  String _sortQuery = 'default';

  Widget _buildMenuOption(String label, String value, bool isSelected, Function(String) onSelect) {
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check, color: kLilacDeep) : null,
      onTap: () {
        onSelect(value);
        Navigator.pop(context);
      },
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String label,
    String value,
    bool isSelected,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: iTextDark,
                fontSize: 14,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, size: 16, color: kLilacDeep),
        ],
      ),
    );
  }

  Widget _buildIconBtnMenu({
    required IconData icon,
    required bool isActive,
    required List<PopupMenuEntry<String>> items,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      itemBuilder: (ctx) => items,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? kLilacWash : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? kLilacLight : kNeutral300),
        ),
        child: Icon(icon, size: 18, color: isActive ? kLilacDeep : kNeutral500),
      ),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kLilacWash,
        border: Border.all(color: kLilacWash),
        borderRadius: BorderRadius.circular(12),
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
                color: Color(0xFF7B6BA0),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_breedFilter != 'All') const Text(' • ', style: TextStyle(color: Color(0xFF7B6BA0))),
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

  List<String> _getCurrentTabStatuses() {
    if (_tabController.index == 0) {
      return [
        'All',
        'Open',
        'Bred',
        'Nursing',
        'Grow-Out',
        'Resting',
        'Quarantine',
      ];
    } else if (_tabController.index == 1) {
      return [
        'All',
        'Active',
        'Grow-Out',
        'Quarantine',
      ];
    } else {
      return [
        'All',
        'Sold',
        'Butchered',
        'Dead',
        'Cull',
        'Stud',
        'Donated',
      ];
    }
  }

  String _mapStatus(String status) {
    if (status == 'Bred') return 'Pregnant';
    if (status == 'Grow-Out' || status == 'Grow Out') return 'GrowOut';
    return status;
  }

  void _onSwipeGreyBar(bool isLeftSwipe) {
    final statuses = _getCurrentTabStatuses();
    int currentIndex = statuses.indexWhere((s) {
      final m = _mapStatus(s);
      return _currentFilter == m || (_currentFilter == 'All' && s == 'All');
    });
    if (currentIndex == -1) currentIndex = 0;

    if (isLeftSwipe) {
      if (currentIndex < statuses.length - 1) {
        setState(() {
          _currentFilter = _mapStatus(statuses[currentIndex + 1]);
        });
      }
    } else {
      if (currentIndex > 0) {
        setState(() {
          _currentFilter = _mapStatus(statuses[currentIndex - 1]);
        });
      }
    }
  }

  Widget _buildPipelineMenu() {
    final statuses = _getCurrentTabStatuses();

    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFF8F8A90),
        border: Border(bottom: BorderSide(color: Color(0xFF7A757C), width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: statuses.map((status) {
              final mappedStatus = _mapStatus(status);
              final isActive = _currentFilter == mappedStatus || (_currentFilter == 'All' && status == 'All');
              final isDefault = _tabController.index == 0 && _settings.defaultHerdFilter == mappedStatus;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _currentFilter = mappedStatus),
                onLongPress: () async {
                  await _settings.setDefaultHerdFilter(mappedStatus);
                  setState(() => _currentFilter = mappedStatus);
                  if (context.mounted) {
                    ToastUtils.showSuccess(
                      context,
                      'Default Herd page set to ${status.toUpperCase()}',
                    );
                  }
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isActive ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.65),
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (isDefault && status != 'All') ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.home_rounded,
                          size: 13,
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.65),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // GrowOut logic kept exactly as requested
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
                    color: const Color(0xFF7B6BA0).withOpacity(0.1),
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
                    color: daysToMaturity <= 0 ? const Color(0xFF7B6BA0).withOpacity(0.1) : const Color(0xFFF5A623).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    daysToMaturity <= 0 ? 'Ready' : '$daysToMaturity days',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: daysToMaturity <= 0 ? const Color(0xFF7B6BA0) : const Color(0xFFF5A623),
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
                            daysToMaturity <= 0 ? const Color(0xFF7B6BA0) : const Color(0xFFF5A623),
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
                      backgroundColor: const Color(0xFF7B6BA0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
              backgroundColor: const Color(0xFF7B6BA0),
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
              backgroundColor: const Color(0xFF7B6BA0),
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
      if (r.type == RabbitType.pedigree || r.id.startsWith('PED-') || r.id.startsWith('ped_')) return false;

      if (_breedFilter != 'All') {
        final normalizedRabbitBreed = _normalizeBreed(r.breed);
        final normalizedFilter = _normalizeBreed(_breedFilter);
        if (normalizedRabbitBreed.toLowerCase() != normalizedFilter.toLowerCase()) return false;
      }

      if (_currentFilter != 'All') {
        if (_currentFilter == 'Sold' && r.archiveReason != ArchiveReason.sold) return false;
        if (_currentFilter == 'Butchered' && r.archiveReason != ArchiveReason.butchered) return false;
        if (_currentFilter == 'Dead' && r.archiveReason != ArchiveReason.dead && (r.deathCause == null || r.deathCause!.isEmpty)) return false;
        if (_currentFilter == 'Cull' && r.archiveReason != ArchiveReason.cull && (r.cullReason == null || r.cullReason!.isEmpty)) return false;
        if (_currentFilter == 'Stud' && r.archiveReason != ArchiveReason.stud) return false;
        if (_currentFilter == 'Donated' && r.archiveReason != ArchiveReason.donated) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final fullName = r.fullName.toLowerCase();
        final earNum = (r.earNumber ?? '').toLowerCase();
        if (!r.name.toLowerCase().contains(query) &&
            !fullName.contains(query) &&
            !r.id.toLowerCase().contains(query) &&
            !earNum.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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

    return Column(
      children: [
        _buildCountHeader(filtered.length),
        Expanded(
          child: ListView.builder(
            controller: _archiveScrollController,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _buildRedesignedRabbitCard(filtered[index], isArchiveCard: true),
          ),
        ),
      ],
    );
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
              leading: const Icon(Icons.visibility_outlined, color: Color(0xFF7B6BA0)),
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
      await _db.restoreRabbit(rabbit.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rabbit.name} restored to active breeders'),
            backgroundColor: const Color(0xFF7B6BA0),
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
    List<Rabbit> activeList = _allRabbits.where((r) {
      if (r.type != type) return false;
      if (r.type == RabbitType.pedigree) return false;
      if (r.id.startsWith('PED-') || r.id.startsWith('ped_')) return false;
      if (r.status == RabbitStatus.archived || r.isArchived) return false;

      if (_breedFilter != 'All') {
        final normalizedRabbitBreed = _normalizeBreed(r.breed);
        final normalizedFilter = _normalizeBreed(_breedFilter);
        if (normalizedRabbitBreed.toLowerCase() != normalizedFilter.toLowerCase()) return false;
      }

      final statusName = r.status.toString().split('.').last.toLowerCase();
      final isQuarantined = statusName == 'quarantine' || !r.activeInRabbitry || (r.quarantineEndDate != null && DateTime.now().isBefore(r.quarantineEndDate!));

      bool isAge5MonthsOrMore = false;
      if (r.dateOfBirth != null) {
        final fiveMonthsDate = DateTime(r.dateOfBirth!.year, r.dateOfBirth!.month + 5, r.dateOfBirth!.day);
        isAge5MonthsOrMore = !DateTime.now().isBefore(fiveMonthsDate);
      }

      final isGrowOut = (statusName == 'growout' || statusName == 'weaned') && !isAge5MonthsOrMore;

      if (_currentFilter != 'Quarantine' && isQuarantined) return false;

      if (_currentFilter == 'GrowOut') {
        if (!isGrowOut) return false;
      } else if (_currentFilter == 'All') {
        // "ALL" tab includes ALL active herd members, including Grow-Out rabbits!
      } else {
        if (isGrowOut) return false;

        final filterName = _currentFilter.toLowerCase();
        if (filterName == 'bred' || filterName == 'pregnant') {
          if (!_isDoeBred(r)) return false;
        } else if (filterName == 'quarantine') {
          if (!isQuarantined) return false;
        } else if (filterName == 'resting') {
          if (statusName != 'resting') return false;
        } else if (filterName == 'nursing') {
          if (!_isDoeNursing(r)) return false;
        } else if (filterName == 'open') {
          if (_isDoeBred(r) || _isDoeNursing(r) || isQuarantined) return false;
          final effectiveStatus = (statusName == 'growout' && isAge5MonthsOrMore) ? 'open' : statusName;
          if (effectiveStatus != 'open') return false;
        } else if (filterName == 'active') {
          if (isQuarantined) return false;
          if (r.type == RabbitType.buck) {
            return r.activeInRabbitry && statusName != 'resting';
          }
          final effectiveStatus = (statusName == 'growout' && isAge5MonthsOrMore) ? 'active' : statusName;
          if (effectiveStatus != 'active') return false;
        } else {
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
        final fullName = r.fullName.toLowerCase();
        final earNum = (r.earNumber ?? '').toLowerCase();
        if (!r.name.toLowerCase().contains(query) &&
            !fullName.contains(query) &&
            !r.id.toLowerCase().contains(query) &&
            !earNum.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Apply Sorting to active list
    activeList.sort((a, b) {
      if (_sortQuery == 'breed') return a.breed.compareTo(b.breed);
      if (_sortQuery == 'cage') return (a.cage ?? '').compareTo(b.cage ?? '');
      if (_sortQuery == 'id') {
        final earA = (a.earNumber != null && a.earNumber!.trim().isNotEmpty) ? a.earNumber!.trim() : a.id.trim();
        final earB = (b.earNumber != null && b.earNumber!.trim().isNotEmpty) ? b.earNumber!.trim() : b.id.trim();
        final cmp = earA.toLowerCase().compareTo(earB.toLowerCase());
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (_sortQuery == 'name') return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (_sortQuery == 'age_asc') {
        final dobA = a.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dobB = b.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dobB.compareTo(dobA);
      }
      if (_sortQuery == 'age_desc') {
        final dobA = a.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dobB = b.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dobA.compareTo(dobB);
      }
      // Default: respect user's My Preference -> Sort Doe/Buck
      if (_settings.sortDoeBuck == 'Ear Number') {
        final earA = (a.earNumber != null && a.earNumber!.trim().isNotEmpty) ? a.earNumber!.trim() : a.id.trim();
        final earB = (b.earNumber != null && b.earNumber!.trim().isNotEmpty) ? b.earNumber!.trim() : b.id.trim();
        final cmp = earA.toLowerCase().compareTo(earB.toLowerCase());
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    List<Rabbit> filtered = activeList;

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

    if (_grouping == 'none') {
      return Column(
        children: [
          _buildCountHeader(filtered.length),
          Expanded(
            child: ListView.builder(
              controller: type == RabbitType.doe ? _doeScrollController : _buckScrollController,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
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
            controller: type == RabbitType.doe ? _doeScrollController : _buckScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            children: sortedKeys.map((key) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(
                      key.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: iTextLight,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
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

  Widget _buildCountHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '$count RABBITS',
            style: const TextStyle(
              fontSize: 12,
              color: iTextLight,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }

  String _getRabbitNameById(String? id) {
    if (id == null || id.trim().isEmpty) return '-';
    final trimmed = id.trim();

    if (_rabbitNameMap.containsKey(trimmed)) {
      final name = _rabbitNameMap[trimmed]!;
      if (name.isNotEmpty && !FormatUtils.isSystemId(name)) {
        return name;
      }
    }
    for (final r in _allRabbits) {
      if (r.id == trimmed) {
        return r.fullName.isNotEmpty ? r.fullName : r.name;
      }
    }
    for (final r in _archivedList) {
      if (r.id == trimmed) {
        return r.fullName.isNotEmpty ? r.fullName : r.name;
      }
    }
    final cached = _rabbitCache[trimmed];
    if (cached != null) {
      final n = cached.fullName.isNotEmpty ? cached.fullName : cached.name;
      if (n.isNotEmpty && !FormatUtils.isSystemId(n)) return n;
    }

    if (FormatUtils.isSystemId(trimmed)) {
      _fetchRabbitNameInBackground(trimmed);
      return '-';
    }

    return trimmed;
  }

  void _fetchRabbitNameInBackground(String id) {
    if (_fetchingIds.contains(id)) return;
    _fetchingIds.add(id);
    _db.getRabbit(id).then((r) {
      if (r != null && mounted) {
        final displayName = r.fullName.isNotEmpty ? r.fullName : r.name;
        setState(() {
          _rabbitCache[id] = r;
          if (displayName.isNotEmpty && !FormatUtils.isSystemId(displayName)) {
            _rabbitNameMap[id] = displayName;
          }
        });
      }
    }).catchError((_) {});
  }

  bool _isMissedLitter(Litter l) {
    if (l.missedLitter == true) return true;
    final String s = l.status.toLowerCase().trim();
    if (s == 'missed' || s == 'missed litter' || s == 'missed_litter' || s == 'not taken') {
      return true;
    }
    final int born = (l.totalKits != null && l.totalKits! > 0)
        ? l.totalKits!
        : (l.kits.isNotEmpty ? l.kits.length : 0);
    final int alive = l.kits.isNotEmpty
        ? l.kits.where((k) {
            final st = k.status.trim().toLowerCase();
            return st != 'dead' && st != 'died' && st != 'culled' && st != 'cull' && st != 'deceased';
          }).length
        : (l.aliveKits ?? born);

    if (born == 0 && alive == 0 && l.kits.isEmpty) {
      return true;
    }

    final notes = l.notes?.toLowerCase() ?? '';
    if ((notes.contains('missed') || notes.contains('not taken')) && born == 0 && l.kits.isEmpty) {
      return true;
    }

    return false;
  }

  int _getRabbitLittersCount(Rabbit rabbit) {
    return _litters
        .where((l) => (l.doeId == rabbit.id || l.buckId == rabbit.id) && !_isMissedLitter(l))
        .length;
  }

  int _getRabbitKitsCount(Rabbit rabbit) {
    final rabbitLitters = _litters.where((l) => (l.doeId == rabbit.id || l.buckId == rabbit.id) && !_isMissedLitter(l));
    int total = 0;
    for (var l in rabbitLitters) {
      if (l.kits.isNotEmpty) {
        final liveCount = l.kits.where((k) {
          final st = k.status.trim().toLowerCase();
          return st != 'dead' && st != 'died' && st != 'culled' && st != 'cull' && st != 'deceased';
        }).length;
        total += liveCount;
      } else if (l.aliveKits != null) {
        total += l.aliveKits!;
      } else if (l.totalKits != null && l.totalKits! > 0) {
        final dead = l.deadKits ?? 0;
        total += (l.totalKits! - dead).clamp(0, l.totalKits!);
      }
    }
    return total;
  }

  Widget _buildRedesignedRabbitCard(Rabbit rabbit, {bool isArchiveCard = false}) {
    final bool isDoe = rabbit.type == RabbitType.doe;
    final bool isArchive = isArchiveCard || rabbit.isArchived || rabbit.status == RabbitStatus.archived || _tabController.index == 2;

    final hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty;
    final photoPath = hasPhoto ? rabbit.photos!.first : null;
    final isPhotoValid = photoPath != null && File(photoPath).existsSync();

    final sireName = _getRabbitNameById(rabbit.sireId);
    final damName = _getRabbitNameById(rabbit.damId);
    final littersCount = _getRabbitLittersCount(rabbit);
    final kitsCount = _getRabbitKitsCount(rabbit);

    return GestureDetector(
      // Tapping anywhere on the card (except photo & 3-dots) → Breeding tab
      onTap: () => _navigateToDetail(rabbit, tabIndex: 1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5EA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          children: [
            // 1. Header: Full-width Name line, followed by Photo + Breed / Color / Age & Weight
            Container(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full-width Name line
                  Text.rich(
                    TextSpan(
                      children: [
                        if (rabbit.breederPrefix != null && rabbit.breederPrefix!.isNotEmpty)
                          TextSpan(
                            text: '${rabbit.breederPrefix} ',
                            style: const TextStyle(color: Color(0xFF4A4A4D), fontWeight: FontWeight.w700),
                          ),
                        TextSpan(
                          text: rabbit.name,
                          style: TextStyle(
                            color: isDoe
                                ? (isArchive ? const Color(0xFFF48FB1) : const Color(0xFFE04F9F))
                                : (isArchive ? const Color(0xFF80BFFF) : const Color(0xFF2196F3)),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Avatar — taps go to Profile tab (tab 0)
                      GestureDetector(
                        onTap: () => _navigateToDetail(rabbit, tabIndex: 0),
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDoe
                                  ? (isArchive ? const Color(0xFFF48FB1) : const Color(0xFFE04F9F))
                                  : (isArchive ? const Color(0xFF80BFFF) : const Color(0xFF2196F3)),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isPhotoValid
                                    ? Image.file(File(photoPath!), fit: BoxFit.cover, alignment: Alignment.center)
                                    : Image.asset('assets/images/app_logo.png', fit: BoxFit.cover, alignment: Alignment.center),
                                if (rabbit.salePrice != null)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: SaleRibbonPainter(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Right Info: Breed (+ 3 dots), Color, Age • Weight (+ Status)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Line 1: Breed + 3-dots menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    rabbit.breed,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A4A4D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => isArchive ? _showArchiveMenu(rabbit) : _showRabbitActions(rabbit),
                                  child: const SizedBox(
                                    width: 30,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Icon(Icons.more_horiz, color: Color(0xFF4A4A4D), size: 22),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (rabbit.color != null && rabbit.color!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              // Line 2: Color
                              Text(
                                rabbit.color!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A4A4D),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 2),
                            // Line 3: Age • Weight + Status letter directly under 3 dots (ALL tab & Archive only)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    rabbit.weight != null
                                        ? '${rabbit.age} • ${FormatUtils.formatWeight(rabbit.weight!)}'
                                        : rabbit.age,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A4A4D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_shouldShowStatusBadge(rabbit, isArchive: isArchive))
                                  isArchive
                                      ? _buildStatusBadge(rabbit, isArchive: true)
                                      : SizedBox(
                                          width: 30,
                                          child: Center(
                                            child: _buildStatusBadge(rabbit),
                                          ),
                                        ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Middle Stats Section
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEBE8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildStatsRow(
                    'Ear No.:',
                    rabbit.earNumber?.isNotEmpty == true ? rabbit.earNumber! : (rabbit.id.length >= 6 ? rabbit.id.substring(0, 6) : rabbit.id).toUpperCase(),
                    'Cage No.:',
                    rabbit.cage?.isNotEmpty == true ? rabbit.cage! : '-',
                    isDoe: isDoe,
                    isTinted: true,
                  ),
                  _buildSingleStatRow(
                    'Sire:',
                    sireName,
                    isDoe: isDoe,
                    isTinted: false,
                  ),
                  _buildSingleStatRow(
                    'Dam:',
                    damName,
                    isDoe: isDoe,
                    isTinted: true,
                  ),
                  _buildStatsRow(
                    'Litters:',
                    littersCount > 0 ? littersCount.toString().padLeft(2, '0') : '0',
                    'Kits:',
                    kitsCount > 0 ? kitsCount.toString().padLeft(2, '0') : '0',
                    isDoe: isDoe,
                    isTinted: false,
                  ),
                  _buildNotesRow(
                    'Notes:',
                    rabbit.notes?.isNotEmpty == true ? rabbit.notes! : '',
                    isDoe: isDoe,
                    isTinted: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isDoeNursing(Rabbit rabbit) {
    if (rabbit.type != RabbitType.doe || rabbit.status == RabbitStatus.archived) return false;

    final doeLitters = _litters.where((l) {
      final matchesDoe = (l.doeId.isNotEmpty && l.doeId.trim() == rabbit.id.trim()) ||
          (l.dam.isNotEmpty && l.dam.trim().toLowerCase() == rabbit.name.trim().toLowerCase()) ||
          (l.doeName.isNotEmpty && l.doeName.trim().toLowerCase() == rabbit.name.trim().toLowerCase());
      if (!matchesDoe) return false;
      final st = l.status.toLowerCase().trim();
      return st != 'archived' &&
          st != 'history_only' &&
          st != 'deleted_archive' &&
          st != 'weaned' &&
          st != 'not taken' &&
          st != 'died' &&
          st != 'dead';
    }).toList();

    if (doeLitters.isNotEmpty) {
      for (final litter in doeLitters) {
        // "Once the 7 week period is complete it can only be in the BRED page and not in Nursing any more."
        if (litter.ageDays >= 49) continue;
        final hasActiveKits = litter.kits.any((k) {
          final s = k.status.toLowerCase().trim();
          return s != 'dead' &&
              s != 'died' &&
              s != 'deceased' &&
              s != 'fostered' &&
              s != 'archived' &&
              s != 'sold' &&
              s != 'butchered' &&
              s != 'cull' &&
              s != 'weaned';
        });
        final aliveCount = litter.aliveKits ?? 0;
        final totalCount = litter.totalKits ?? 0;
        if ((litter.kits.isNotEmpty && hasActiveKits) ||
            aliveCount > 0 ||
            totalCount > 0 ||
            litter.status.toLowerCase().trim() == 'nursing') {
          return true;
        }
      }
      return false;
    }

    // Fallback if no litter record found but status is explicitly nursing or has current litter
    if (rabbit.status == RabbitStatus.nursing || (rabbit.currentLitterSize != null && rabbit.currentLitterSize! > 0)) {
      if (rabbit.kindleDate != null) {
        if (DateTime.now().difference(rabbit.kindleDate!).inDays >= 49) {
          return false;
        }
      }
      return true;
    }

    return false;
  }

  bool _isDoeBred(Rabbit rabbit) {
    if (rabbit.type != RabbitType.doe || rabbit.status == RabbitStatus.archived) return false;
    final statusName = rabbit.status.toString().split('.').last.toLowerCase();
    if (statusName == 'pregnant' || statusName == 'palpatedue') {
      return true;
    }
    if (rabbit.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = rabbit.dueDate!;
      final isUpcomingDue = !today.isAfter(DateTime(dueDate.year, dueDate.month, dueDate.day).add(const Duration(days: 5)));
      final isRecentlyBred = rabbit.lastBreedDate == null || today.difference(rabbit.lastBreedDate!).inDays <= 38;
      if (isUpcomingDue && isRecentlyBred) {
        return true;
      }
    }
    return false;
  }

  bool _isDoeNursingAndBred(Rabbit rabbit) {
    return _isDoeNursing(rabbit) && _isDoeBred(rabbit);
  }

  bool _shouldShowStatusBadge(Rabbit rabbit, {bool isArchive = false}) {
    if (isArchive || rabbit.status == RabbitStatus.archived) return true;
    return _currentFilter == 'All';
  }

  String _getStatusLetter(Rabbit rabbit) {
    if (rabbit.status == RabbitStatus.quarantine ||
        !rabbit.activeInRabbitry ||
        (rabbit.quarantineEndDate != null && DateTime.now().isBefore(rabbit.quarantineEndDate!))) {
      return 'Q';
    }
    if (_isDoeNursingAndBred(rabbit)) {
      return 'NB';
    }
    if (_isDoeNursing(rabbit)) {
      return 'N';
    }
    if (_isDoeBred(rabbit)) {
      return 'B';
    }
    switch (rabbit.status) {
      case RabbitStatus.open:
        return 'O';
      case RabbitStatus.pregnant:
        return 'B'; // Bred
      case RabbitStatus.palpateDue:
        return 'P'; // Palpate Due
      case RabbitStatus.nursing:
        return 'N';
      case RabbitStatus.resting:
        return 'R';
      case RabbitStatus.growout:
        return 'G';
      case RabbitStatus.quarantine:
        return 'Q';
      case RabbitStatus.active:
        return 'A';
      case RabbitStatus.inactive:
        return 'I';
      case RabbitStatus.archived:
        if (rabbit.archiveReason == ArchiveReason.sold) return 'SOLD';
        if (rabbit.archiveReason == ArchiveReason.dead) return 'DIED';
        if (rabbit.archiveReason == ArchiveReason.cull) return 'CULL';
        if (rabbit.archiveReason == ArchiveReason.butchered) return 'MEAT';
        if (rabbit.archiveReason == ArchiveReason.stud) return 'STUD';
        if (rabbit.archiveReason == ArchiveReason.donated) return 'DONATED';
        return 'A';
    }
  }

  Widget _buildStatusBadge(Rabbit rabbit, {bool isArchive = false}) {
    if (!_shouldShowStatusBadge(rabbit, isArchive: isArchive)) {
      return const SizedBox.shrink();
    }
    final String letter = _getStatusLetter(rabbit);
    final isArchived = isArchive || rabbit.isArchived || rabbit.status == RabbitStatus.archived || _tabController.index == 2;
    final isDoe = rabbit.type == RabbitType.doe;

    if (isArchived) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isDoe ? const Color(0xFFFCE4EC) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isDoe ? const Color(0xFFF48FB1) : const Color(0xFF80BFFF),
          ),
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: letter.length > 1 ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: isDoe ? const Color(0xFFF48FB1) : const Color(0xFF80BFFF),
          ),
        ),
      );
    }

    return Text(
      letter,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF636366),
      ),
    );
  }

  Widget _buildSingleStatRow(String label, String val, {required bool isDoe, required bool isTinted}) {
    final Color tintBg = isDoe ? const Color(0xFFFDF2F5) : const Color(0xFFEFF6FB);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      color: isTinted ? tintBg : Colors.white,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333336),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333336),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String label1, String val1, String label2, String val2, {required bool isDoe, required bool isTinted}) {
    final Color tintBg = isDoe ? const Color(0xFFFDF2F5) : const Color(0xFFEFF6FB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      color: isTinted ? tintBg : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  label1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333336),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    val1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333336),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  label2,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333336),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    val2,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333336),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesRow(String label, String val, {required bool isDoe, required bool isTinted}) {
    final Color tintBg = isDoe ? const Color(0xFFFDF2F5) : const Color(0xFFEFF6FB);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      color: isTinted ? tintBg : Colors.white,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333336),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333336),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBarnDrawer() async {
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
                          border: Border(bottom: BorderSide(color: kLilacWash)),
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
                                        const Text(
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
                                        color: _isBarnEditMode ? kLilacDeep : kLilacWash,
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
                                side: const BorderSide(color: kLilacDeep, width: 1.5),
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
          border: Border.all(color: isActive ? kLilacWash : Colors.transparent),
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
            border: Border.all(color: kLilacWash),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  barn.name.toUpperCase(),
                  style: const TextStyle(
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
                      borderRadius: BorderRadius.circular(12),
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
                          const Text(
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
                        border: Border.all(color: kLilacWash),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 12, color: kLilacDeep),
                          const SizedBox(width: 4),
                          const Text(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kLilacWash)),
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
    dataChangeNotifier.removeListener(_onDataChanged);
    _doeScrollController.dispose();
    _buckScrollController.dispose();
    _archiveScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }
}

