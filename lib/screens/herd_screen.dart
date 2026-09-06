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
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/action_sheets/rabbit_action_sheet.dart';
import 'home_dashboard_screen.dart';

// Re-defining for local scope consistency or using imported ones
const kPrimary = Color(0xFF5E4A8A);
const kDoeTheme = Color(0xFFB5567A);
const kDoeIcon = Color(0xFFD4809A);
const kBuckTheme = Color(0xFF3A7BB8);
const kBuckIcon = Color(0xFF5B9BD5);
const kArchiveTheme = Color(0xFF8E8E93);
const kArchiveIcon = Color(0xFF636366);
const kSuccess = Color(0xFF4CAF50);
const kError = Color(0xFFD94452);
const kWarning = Color(0xFFF59E0B);

// New Design Tokens
const Color hLilacWash = Color(0xFFF4F0FA);
const Color hPinkWash = Color(0xFFFDF2F5);
const Color hBlueWash = Color(0xFFEFF6FB);
const Color hNeutral50 = Color(0xFFF9F9F9);
const Color hNeutral100 = Color(0xFFF9F9FB);
const Color hNeutral200 = Color(0xFFF2F2F7);
const Color hNeutral300 = Color(0xFFE5E5EA);
const Color hNeutral400 = Color(0xFFD1D1D6);
const Color hNeutral500 = Color(0xFFAEAEB2);
const Color hNeutral600 = Color(0xFF8E8E93);
const Color hNeutral700 = Color(0xFF636366);
const Color hNeutral800 = Color(0xFF3A3A3C);
const Color hNeutral900 = Color(0xFF2C2C2E);
const Color hLilacDeep = Color(0xFF7B6BA0);
const Color hLilacLight = Color(0xFFE8DFFA);
const Color hLilacText = Color(0xFF5A4880);
const Color hPinkDeep = Color(0xFFC47A8B);
const Color hPinkLight = Color(0xFFF8D7E0);
const Color hBlueDeep = Color(0xFF4A7FA0);
const Color hBlueLight = Color(0xFFD6E9F5);

// Specific constants to match the provided image
const Color iHeaderBg = Color(0xFFE6BEFE);
const Color iAppBg = Color(0xFFEEDAFE);
const Color iTextDark = Color(0xFF3F3B46);
const Color iTextLight = Color(0xFFA5A1AE);

class HerdScreen extends StatefulWidget {
  const HerdScreen({Key? key}) : super(key: key);

  @override
  _HerdScreenState createState() => _HerdScreenState();
}

class _HerdScreenState extends State<HerdScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentFilter = 'All'; // This is for status
  String _breedFilter = 'All'; // This is for breed
  String _searchQuery = '';
  String? _locationFilter;
  String _grouping = 'none';
  bool _isBarnEditMode = false;
  bool _isSearchEnabled = false; // New flag for the ultimate focus block
  bool _keyboardWasOpen = false;

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
    // Start with focus disabled to prevent auto-popup
    _searchFocusNode.canRequestFocus = false;
    _searchFocusNode.addListener(_handleSearchFocusChange);
    _loadData();
  }

  void _handleSearchFocusChange() {
    if (!_searchFocusNode.hasFocus && mounted && _isSearchEnabled) {
      setState(() {
        _isSearchEnabled = false;
        _searchFocusNode.canRequestFocus = false;
      });
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
      print('ðŸ”„ Loading herd data...');
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

      print('ðŸ“Š Loaded ${rabbits.length} rabbits, ${archivedRabbits.length} archived, ${growOutKits.length} grow-out kits');

      for (var rabbit in rabbits) {
        final hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty;
        final photoPath = hasPhoto ? rabbit.photos!.first : null;
        final exists = photoPath != null ? File(photoPath).existsSync() : false;
        print('  ðŸ“¸ ${rabbit.name}: hasPhoto=$hasPhoto, path=$photoPath, exists=$exists');
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

  Future<void> _confirmAndDeleteBreed(String breedName) async {
    if (breedName == 'All') return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Breed Category?'),
        content: Text('Remove "$breedName" from breed filters and update any rabbits assigned to this breed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.clearBreedName(breedName);
      
      final replacement = breedName.toLowerCase() == 'hotot' ? 'Dwarf Hotot' : '';
      for (var r in _allRabbits) {
        if (r.breed.toLowerCase() == breedName.toLowerCase()) {
          r.breed = replacement;
        }
      }

      if (_breedFilter.toLowerCase() == breedName.toLowerCase()) {
        _breedFilter = 'All';
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Breed category "$breedName" removed'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    try {
      print('ðŸ”„ Refreshing herd data...');
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
        backgroundColor: iAppBg,
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(hLilacDeep)),
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
    final screenTextTheme = GoogleFonts.nunitoSansTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: iAppBg,
      body: Theme(
        data: Theme.of(context).copyWith(textTheme: screenTextTheme),
        child: Column(
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
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: hLilacDeep,
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
      ),
      floatingActionButton: _tabController.index < 2
          ? FloatingActionButton(
              heroTag: 'herd_fab',
              onPressed: () async {
                _searchFocusNode.canRequestFocus = false;
                FocusScope.of(context).unfocus();
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddRabbitScreen()));
                if (mounted) {
                  setState(() {
                    _isSearchEnabled = false;
                    _searchFocusNode.canRequestFocus = false;
                  });
                  FocusScope.of(context).unfocus();
                }
                if (result == true) {
                  await _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ðŸ° Rabbit added successfully'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating, backgroundColor: hLilacDeep),
                    );
                  }
                }
              },
              backgroundColor: const Color(0xFFE6BEFE),
              shape: const CircleBorder(),
              elevation: 6,
              child: Icon(
                PhosphorIcons.plus(PhosphorIconsStyle.bold),
                size: 28,
                color: const Color(0xFF463466),
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
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        _searchFocusNode.canRequestFocus = false;
                        FocusScope.of(context).unfocus();
                        await _showBarnDrawer();
                        if (mounted) {
                          setState(() {
                            _isSearchEnabled = false;
                            _searchFocusNode.canRequestFocus = false;
                          });
                          FocusScope.of(context).unfocus();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.regular), color: const Color(0xFF787880), size: 23),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 8, offset: const Offset(0, 2))
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular), color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: const TextStyle(fontSize: 14, color: iTextDark, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search by name or ID...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
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
                      child: Icon(Icons.clear, size: 18, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Group Button
          _buildIconBtnMenu(
            icon: PhosphorIcons.squaresFour(PhosphorIconsStyle.regular),
            isActive: _grouping != 'none',
            items: [
              _buildPopupItem('None', 'none', _grouping == 'none'),
              _buildPopupItem('Location', 'location', _grouping == 'location'),
              _buildPopupItem('Breed', 'breed', _grouping == 'breed'),
            ],
            onSelected: (v) => setState(() => _grouping = v),
          ),
          const SizedBox(width: 8),

          // Filter Button
          _buildIconBtnMenu(
            icon: PhosphorIcons.funnel(PhosphorIconsStyle.regular),
            isActive: _breedFilter != 'All',
            items: _getUniqueBreeds().map((f) => _buildPopupItem(
              f,
              f,
              _breedFilter == f,
              onDelete: f == 'All' ? null : () => _confirmAndDeleteBreed(f),
            )).toList(),
            onSelected: (v) => setState(() => _breedFilter = v),
          ),
          const SizedBox(width: 8),

          // Sort Button
          _buildIconBtnMenu(
            icon: PhosphorIcons.arrowDown(PhosphorIconsStyle.regular),
            isActive: _sortQuery != 'name',
            items: [
              _buildPopupItem('Breed', 'breed', _sortQuery == 'breed'),
              _buildPopupItem('Name', 'name', _sortQuery == 'name'),
              _buildPopupItem('Cage', 'cage', _sortQuery == 'cage'),
              _buildPopupItem('Age (Youngest)', 'age_asc', _sortQuery == 'age_asc'),
              _buildPopupItem('Age (Oldest)', 'age_desc', _sortQuery == 'age_desc'),
              _buildPopupItem('ID / Ear #', 'id', _sortQuery == 'id'),
            ],
            onSelected: (v) => setState(() => _sortQuery = v),
          ),
        ],
      ),
    );
  }

  String _sortQuery = 'name';

  Widget _buildMenuOption(String label, String value, bool isSelected, Function(String) onSelect) {
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check, color: hLilacDeep) : null,
      onTap: () {
        onSelect(value);
        Navigator.pop(context);
      },
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String label,
    String value,
    bool isSelected, {
    VoidCallback? onDelete,
  }) {
    final isBreedCategoryItem = onDelete != null && value != 'All';
    return PopupMenuItem<String>(
      value: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          if (isBreedCategoryItem) {
            Navigator.pop(context);
            onDelete();
          }
        },
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
            if (isBreedCategoryItem)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                ),
              )
            else if (isSelected) ...[
              const Icon(Icons.check, size: 16, color: hLilacDeep)
            ],
          ],
        ),
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
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      itemBuilder: (ctx) => items,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, size: 20, color: isActive ? hLilacDeep : Colors.grey.shade500),
      ),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: hLilacWash,
        border: Border.all(color: hLilacWash),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: hLilacDeep),
          const SizedBox(width: 8),
          const Text(
            'Filtering: ',
            style: TextStyle(color: hLilacDeep, fontSize: 14),
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
                color: hLilacDeep,
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
            child: const Icon(Icons.close, size: 18, color: hLilacDeep),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineMenu() {
    List<String> statuses = [];
    if (_tabController.index == 0) {
      statuses = [
        'All',
        'Open',
        'Bred',
        'Nursing',
        'Resting',
        'Grow Out',
        'Quarantine'
      ];
    } else if (_tabController.index == 1) {
      statuses = [
        'All',
        'Active',
        'Inactive',
        'Grow Out',
        'Quarantine'
      ];
    } else {
      statuses = [
        'All',
        'Sold',
        'Butchered',
        'Dead',
        'Cull'
      ];
    }

    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFF8F8A90),
        border: Border(bottom: BorderSide(color: Color(0xFF7A757C), width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          final mappedStatus = status == 'Bred' ? 'Pregnant' : (status == 'Grow Out' ? 'GrowOut' : status);
          final isActive = _currentFilter == mappedStatus || (_currentFilter == 'All' && status == 'All');

          return GestureDetector(
            onTap: () => setState(() => _currentFilter = mappedStatus),
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isActive ? Colors.white : Colors.transparent,
                    width: 2.2,
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.65),
                    letterSpacing: 0.45,
                  ),
                ),
              ),
            ),
          );
        },
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
      if (_breedFilter != 'All') {
        final normalizedRabbitBreed = _normalizeBreed(r.breed);
        final normalizedFilter = _normalizeBreed(_breedFilter);
        if (normalizedRabbitBreed.toLowerCase() != normalizedFilter.toLowerCase()) return false;
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
            Icon(PhosphorIcons.archive(PhosphorIconsStyle.duotone), size: 64, color: hNeutral200),
            const SizedBox(height: 16),
            const Text(
              'No archived rabbits',
              style: TextStyle(
                color: hNeutral600,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (context, index) => _buildRedesignedRabbitCard(filtered[index]),
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
      await _db.markOpenForBreeding(rabbit.id);

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
    List<Rabbit> filtered = _allRabbits.where((r) {
      if (r.type != type) return false;
      if (r.status == RabbitStatus.archived) return false;

      if (_breedFilter != 'All') {
        final normalizedRabbitBreed = _normalizeBreed(r.breed);
        final normalizedFilter = _normalizeBreed(_breedFilter);
        if (normalizedRabbitBreed.toLowerCase() != normalizedFilter.toLowerCase()) return false;
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
        final dobA = a.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dobB = b.dateOfBirth ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dobB.compareTo(dobA);
      }
      if (_sortQuery == 'age_desc') {
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
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          key.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '${groups[key]!.length}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
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

  Widget _buildCountHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

  Widget _buildRedesignedRabbitCard(Rabbit rabbit) {
    final bool isDoe = rabbit.type == RabbitType.doe;
    final bool isArchive = rabbit.status == RabbitStatus.archived;

    final hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty;
    final photoPath = hasPhoto ? rabbit.photos!.first : null;
    final isPhotoValid = photoPath != null && File(photoPath).existsSync();

    return GestureDetector(
      // Tapping anywhere on the card (except photo & 3-dots) → Breeding tab
      onTap: () => isArchive ? _showArchiveMenu(rabbit) : _navigateToDetail(rabbit, tabIndex: 1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
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
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            // 1. Inset Colored Header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Photo Avatar — taps go to Profile tab (tab 0)
                  GestureDetector(
                    onTap: () => isArchive ? null : _navigateToDetail(rabbit, tabIndex: 0),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isArchive ? const Color(0xFF8E8E93) : (isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3)),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: isPhotoValid
                            ? Image.file(File(photoPath!), fit: BoxFit.cover)
                            : Container(
                                color: Colors.white,
                                child: Image.asset('assets/images/profilelogo.png', fit: BoxFit.contain),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Center Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (rabbit.breederPrefix != null && rabbit.breederPrefix!.isNotEmpty)
                                TextSpan(
                                  text: '${rabbit.breederPrefix} ',
                                  style: const TextStyle(color: Color(0xFF787774), fontWeight: FontWeight.w700),
                                ),
                              TextSpan(
                                text: rabbit.name,
                                style: TextStyle(
                                  color: isArchive ? const Color(0xFF636366) : (isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3)),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${rabbit.breed}${rabbit.color != null && rabbit.color!.isNotEmpty ? ' • ${rabbit.color}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF787774),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rabbit.weight != null
                              ? '${rabbit.age} • ${FormatUtils.formatWeight(rabbit.weight!)}'
                              : rabbit.age,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF787774),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Status and Menu
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isDoe || rabbit.status == RabbitStatus.quarantine || isArchive) ...[
                        _buildStatusBadge(rabbit),
                        const SizedBox(height: 6),
                      ],
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => isArchive ? _showArchiveMenu(rabbit) : _showRabbitActions(rabbit),
                        child: const Padding(
                          // Larger tap area for 3-dots menu
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Icon(Icons.more_vert, color: Color(0xFF787774), size: 22),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildStatsRow(
                    'EAR NO.:',
                    rabbit.earNumber?.isNotEmpty == true ? rabbit.earNumber! : (rabbit.id.length >= 6 ? rabbit.id.substring(0, 6) : rabbit.id).toUpperCase(),
                    'CAGE NO.:',
                    rabbit.cage?.isNotEmpty == true ? rabbit.cage! : '',
                    isDoe: isDoe,
                    isTinted: true,
                  ),
                  _buildStatsRow(
                    'SIRE:',
                    rabbit.sireId?.isNotEmpty == true ? rabbit.sireId! : '',
                    'LITTERS:',
                    rabbit.type == RabbitType.doe ? (rabbit.currentLitterSize?.toString() ?? '0') : '',
                    isDoe: isDoe,
                    isTinted: false,
                  ),
                  _buildStatsRow(
                    'DAM:',
                    rabbit.damId?.isNotEmpty == true ? rabbit.damId! : '',
                    'KITS:',
                    '',
                    isDoe: isDoe,
                    isTinted: true,
                  ),
                  _buildNotesRow(
                    'NOTES:',
                    rabbit.notes?.isNotEmpty == true ? rabbit.notes! : '',
                    isTinted: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Rabbit rabbit) {
    final isDoe = rabbit.type == RabbitType.doe;
    final isArchive = rabbit.status == RabbitStatus.archived;
    final String label = isArchive ? 'ARCHIVED' : rabbit.statusText.toUpperCase();
    final Color badgeBg = isArchive ? const Color(0xFFF2F2F7) : (isDoe ? const Color(0xFFFDF2F5) : const Color(0xFFEFF6FB));
    final Color badgeText = isArchive ? const Color(0xFF636366) : (isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeText.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: badgeText,
        ),
      ),
    );
  }

  Widget _buildStatsRow(String label1, String val1, String label2, String val2, {required bool isDoe, required bool isTinted}) {
    final Color tintBg = isDoe ? const Color(0xFFFDF2F5) : const Color(0xFFEFF6FB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: isTinted ? tintBg : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(label1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF787774))),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    val1,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
                Text(label2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF787774))),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    val2,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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

  Widget _buildNotesRow(String label, String val, {required bool isTinted}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: isTinted ? const Color(0xFFFDF2F5) : Colors.white,
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF787774))),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF555555)),
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
                          color: hLilacWash,
                          border: Border(bottom: BorderSide(color: hLilacWash)),
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
                                        Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone), color: hLilacDeep, size: 22),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'BARN & CAGES',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: hLilacText,
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
                                        color: hLilacText.withOpacity(0.7),
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
                                      color: _isBarnEditMode ? hLilacDeep : Colors.white,
                                      border: Border.all(
                                        color: _isBarnEditMode ? hLilacDeep : hLilacWash,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _isBarnEditMode ? 'Done' : 'Manage',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _isBarnEditMode ? Colors.white : hLilacDeep,
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
                                child: Divider(color: hNeutral200, height: 1),
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
                            border: Border(top: BorderSide(color: hNeutral200)),
                          ),
                          child: ElevatedButton(
                            onPressed: () => _addBarn(setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hLilacWash,
                              foregroundColor: hLilacDeep,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: hLilacDeep, width: 1.5),
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
          color: isActive ? hLilacWash : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? hLilacWash : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? hLilacDeep : (isWarning ? kError : hNeutral600)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? hLilacDeep : (isWarning ? kError : hNeutral700),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.5) : hNeutral100,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? hLilacDeep : hNeutral600,
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
            color: hLilacWash,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hLilacWash),
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
                    color: hLilacDeep,
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
                      Icon(PhosphorIcons.square(PhosphorIconsStyle.duotone), size: 14, color: hNeutral500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: hNeutral800),
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
                      color: hNeutral50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hNeutral200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cage,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: hNeutral700),
                        ),
                        if (cageCount == 0)
                          IconButton(
                            icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 12, color: hNeutral400),
                            onPressed: () => _deleteCage(barn, row, cage, setModalState),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const Text(
                            'Occupied',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: hNeutral400),
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
                        border: Border.all(color: hLilacWash),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 12, color: hLilacDeep),
                          const SizedBox(width: 4),
                          const Text(
                            'Add Cage',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hLilacDeep),
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
                foregroundColor: hLilacDeep,
                backgroundColor: hLilacWash,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: hLilacWash)),
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
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }
}

