import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/litter.dart';
import '../models/barn.dart';
import '../models/transaction.dart' as finance;
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../models/rabbit.dart';
import '../models/breed.dart';
import 'rabbit_detail_screen.dart';
import 'kit_detail_screen.dart';
import 'pedigree_screen.dart';
import '../widgets/certificate_card.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../widgets/modals/log_birth_modal.dart';
import '../widgets/modals/wean_litter_modal.dart';
import '../services/app_event_service.dart';
import '../constants/app_colors.dart';
import 'dart:developer' as developer;

class LittersScreen extends StatefulWidget {
  final String? initialLitterId;
  const LittersScreen({Key? key, this.initialLitterId}) : super(key: key);

  @override
  LittersScreenState createState() => LittersScreenState();
}

class LittersScreenState extends State<LittersScreen> {
  final ScrollController _scrollController = ScrollController();

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  Future<void> refresh() async {
    await _refreshLitters();
  }

  final DatabaseService _db = DatabaseService();

  String _currentStage = 'All';
  String _searchQuery = '';
  String? _locationFilter;
  String _grouping = 'none';
  Map<String, String> _filters = {
    'age': 'all',
    'weight': 'all',
  };
  Map<String, bool> _expandedLitters = {};
  Map<String, Rabbit> _rabbitMap = {};

  List<Litter> litters = [];
  List<Barn> _barns = [];
  bool _isBarnEditMode = false;
  bool _isLoading = true;
  bool _keyboardWasOpen = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialLitterId != null) {
      _expandedLitters[widget.initialLitterId!] = true;
    }
    print(' initState called, loading litters...');
    _loadLitters();
    dataChangeNotifier.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) _refreshLitters();
  }

  Future<void> _loadLitters() async {
    setState(() => _isLoading = true);

    try {
      final existingLitters = await _db.getLitters();
      final barnsData = await _db.getAllBarns();
      final List<Rabbit> rabbitsData = await _db.getAllRabbits();
      final Map<String, Rabbit> rMap = {for (final Rabbit r in rabbitsData) r.id: r};
      setState(() {
        litters = existingLitters;
        _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
        _rabbitMap = rMap;
        _isLoading = false;
      });
      print(' Loaded ${litters.length} litters from database');
    } catch (e, stackTrace) {
      print('Error loading litters: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        litters = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshLitters() async {
    try {
      final loadedLitters = await _db.getLitters();
      final barnsData = await _db.getAllBarns();
      final List<Rabbit> rabbitsData = await _db.getAllRabbits();
      final Map<String, Rabbit> rMap = {for (final Rabbit r in rabbitsData) r.id: r};
      setState(() {
        litters = loadedLitters;
        _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
        _rabbitMap = rMap;
      });
      print('Refreshed: ${litters.length} litters');
    } catch (e) {
      print('Error refreshing litters: $e');
    }
  }

  String _getRabbitFullName(String? rabbitId, String fallbackName) {
    if (rabbitId != null && _rabbitMap.containsKey(rabbitId)) {
      final r = _rabbitMap[rabbitId]!;
      if ((r.breederPrefix ?? '').isNotEmpty) {
        return '${r.breederPrefix} ${r.name}'.trim();
      }
      return r.name;
    }
    return fallbackName;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF9FC),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep),
          ),
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

    return Scaffold(
      backgroundColor: const Color(0xFFEEDAFE),
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              color: const Color(0xFFE6BEFE),
              child: Column(
                children: [
                  _buildTopMetricCards(),
                  _buildSearchAndGroup(),
                  if (_locationFilter != null) _buildFilterBanner(),
                ],
              ),
            ),
            _buildStageChips(),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (DragEndDetails details) {
                  final velocity = details.primaryVelocity ?? 0.0;
                  if (velocity < -150) {
                    _onSwipeGreyBar(true);
                  } else if (velocity > 150) {
                    _onSwipeGreyBar(false);
                  }
                },
                child: _buildLittersList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 46,
        height: 46,
        child: FloatingActionButton(
          heroTag: 'litter_fab',
          onPressed: () async {
            _searchFocusNode.canRequestFocus = false;
            FocusScope.of(context).unfocus();
            await _showAddLitterDialog();
            _searchFocusNode.canRequestFocus = true;
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
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(50),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE6BEFE),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.baby(PhosphorIconsStyle.duotone), color: const Color(0xFF4A3477), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Nursery Manager',
                    style: TextStyle(
                      color: Color(0xFF2C2C2E),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopMetricCards() {
    final activeLitters = litters.where((litter) {
      final lStatus = litter.status.toLowerCase().trim();
      if (lStatus == 'died' ||
          lStatus == 'dead' ||
          lStatus == 'archived' ||
          lStatus == 'sold' ||
          lStatus == 'not taken') {
        return false;
      }

      if (litter.kits.isNotEmpty) {
        final activeKitCount = litter.kits.where((k) {
          final st = k.status.toLowerCase().trim();
          return st != 'sold' &&
              st != 'dead' &&
              st != 'died' &&
              st != 'deceased' &&
              st != 'butchered' &&
              st != 'cull' &&
              !k.isArchived;
        }).length;
        if (activeKitCount == 0) return false;
      } else {
        final int effectiveAlive = (litter.aliveKits ?? 0) + (litter.deadKits ?? 0);
        if (effectiveAlive == 0) return false;
      }
      return true;
    }).length;

    int nursingKits = 0;
    int weanedKitsCount = 0;

    for (final litter in litters) {
      final lStatus = litter.status.toLowerCase().trim();
      if (lStatus == 'died' || lStatus == 'dead' || lStatus == 'archived' || lStatus == 'sold' || lStatus == 'not taken') continue;

      if (litter.kits.isNotEmpty) {
        for (final kit in litter.kits) {
          if (kit.isArchived) continue;
          final st = kit.status.toLowerCase().trim();
          if (st == 'dead' || st == 'died' || st == 'deceased' || st == 'sold' || st == 'butchered' || st == 'cull') continue;
          if (st == 'weaned' || st == 'growout' || st == 'grow out' || st == 'grow-out' || lStatus == 'weaned') {
            weanedKitsCount++;
          } else {
            nursingKits++;
          }
        }
      } else {
        final count = litter.aliveKits ?? litter.totalKits ?? 0;
        if (lStatus == 'weaned') {
          weanedKitsCount += count;
        } else {
          nursingKits += count;
        }
      }
    }

    final weanedDisplay = '$weanedKitsCount';

    return Container(
      width: double.infinity,
      color: const Color(0xFFE6BEFE),
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
              _buildMetricCard(
                count: '$activeLitters',
                label: 'Litters',
              ),
              _buildMetricCard(
                count: '$nursingKits',
                label: 'Nursing',
              ),
              _buildMetricCard(
                count: weanedDisplay,
                label: 'Weaned',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String count, required String label}) {
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
                count,
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

  Widget _buildSearchAndGroup() {
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular), color: kNeutral400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      focusNode: _searchFocusNode,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      onTapOutside: (event) => _searchFocusNode.unfocus(),
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSquareIconButton(
            icon: PhosphorIcons.squaresFour(PhosphorIconsStyle.bold),
            isActive: _grouping != 'none',
            onTap: () async {
              _searchFocusNode.canRequestFocus = false;
              FocusScope.of(context).unfocus();
              await _showGroupingModal();
              _searchFocusNode.canRequestFocus = true;
            },
          ),
          const SizedBox(width: 6),
          _buildSquareIconButton(
            icon: PhosphorIcons.arrowDown(PhosphorIconsStyle.bold),
            isActive: false,
            onTap: () async {
              _searchFocusNode.canRequestFocus = false;
              FocusScope.of(context).unfocus();
              await _showBarnDrawer();
              _searchFocusNode.canRequestFocus = true;
            },
          ),
          const SizedBox(width: 6),
          _buildSquareIconButton(
            icon: PhosphorIcons.funnel(PhosphorIconsStyle.bold),
            isActive: _filters['age'] != 'all' || _filters['weight'] != 'all',
            onTap: _showFilterModal,
          ),
        ],
      ),
    );
  }

  Widget _buildSquareIconButton({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
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

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? kLilacWash : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? kLilacLight : kNeutral300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? kLilacDeep : kNeutral600),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? kLilacText : kNeutral700,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGroupingModal() async {
    _searchFocusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group By',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNeutral900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 20),
            _buildGroupingOption('none', 'None', PhosphorIcons.rows(PhosphorIconsStyle.bold)),
            _buildGroupingOption('location', 'Location', PhosphorIcons.mapPin(PhosphorIconsStyle.bold)),
            _buildGroupingOption('dam', 'Dam', PhosphorIcons.genderFemale(PhosphorIconsStyle.bold)),
            _buildGroupingOption('breed', 'Breed', PhosphorIcons.rabbit(PhosphorIconsStyle.bold)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    _searchFocusNode.canRequestFocus = true;
  }

  Widget _buildGroupingOption(String value, String label, IconData icon) {
    bool isSelected = _grouping == value;
    return GestureDetector(
      onTap: () {
        setState(() => _grouping = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? kLilacWash : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? kLilacLight : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? kLilacDeep : kNeutral600),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? kLilacText : kNeutral700,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: kLilacDeep, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kBlueWash,
        border: Border.all(color: kBlueLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 16, color: kBlueDeep),
          const SizedBox(width: 8),
          const Text('Filtering by: ', style: TextStyle(color: kBlueText, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(_locationFilter!, style: const TextStyle(color: kBlueText, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _locationFilter = null),
            child: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 16, color: kBlueDeep),
          ),
        ],
      ),
    );
  }

  void _onSwipeGreyBar(bool isLeftSwipe) {
    const stages = [
      'All',
      'Nursing',
      'Weaned',
      'GrowOut',
      'Quarantine',
      'Archive'
    ];
    int currentIndex = stages.indexOf(_currentStage);
    if (currentIndex == -1) currentIndex = 0;

    if (isLeftSwipe) {
      if (currentIndex < stages.length - 1) {
        FocusScope.of(context).unfocus();
        setState(() => _currentStage = stages[currentIndex + 1]);
      }
    } else {
      if (currentIndex > 0) {
        FocusScope.of(context).unfocus();
        setState(() => _currentStage = stages[currentIndex - 1]);
      }
    }
  }

  Widget _buildStageChips() {
    final stages = [
      'All',
      'Nursing',
      'Weaned',
      'GrowOut',
      'Quarantine',
      'Archive'
    ];
    final displayLabels = {
      'All': 'ALL',
      'Nursing': 'NURSING',
      'Weaned': 'WEANED',
      'GrowOut': 'GROW-OUT',
      'Quarantine': 'QUARANTINE',
      'Archive': 'ARCHIVE',
    };

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF8F8A90),
        border: Border(bottom: BorderSide(color: Color(0xFF7A757C), width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stages.length,
        itemBuilder: (context, index) {
          final stage = stages[index];
          final isActive = _currentStage == stage;

          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _currentStage = stage);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isActive ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  displayLabels[stage] ?? stage.toUpperCase(),
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.65),
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Litter> _getFilteredLitters() {
    final filteredList = litters.where(
      (
        litter,
      ) {
        final lStatus = litter.status.toLowerCase().trim();
        final cStage = _currentStage.toLowerCase();

        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final searchText = '${litter.id} ${litter.sire} ${litter.dam} ${litter.breed}'.toLowerCase();
          if (!searchText.contains(query)) return false;
        }

        // Location filter
        if (_locationFilter != null && litter.location != _locationFilter) return false;

        // Archive stage
        if (cStage == 'archive') {
          return lStatus == 'archived' || lStatus == 'died' || lStatus == 'dead' || lStatus == 'cull';
        }

        // ✅ HIDE litters with 0 alive/sold/dead kits or archived/not taken status
        final int kitCount = litter.kits.where((k) =>
          k.status.toLowerCase() != 'butchered' &&
          k.status.toLowerCase() != 'cull'
        ).length;
        final int effectiveAlive = (litter.kits.isNotEmpty)
            ? kitCount
            : ((litter.aliveKits ?? 0) + (litter.deadKits ?? 0));

        if (effectiveAlive == 0 ||
            lStatus == 'archived' ||
            lStatus == 'not taken') {
          return false;
        }

        // Age filter
        if (_filters['age'] == 'young' && litter.ageDays >= 28) return false;
        if (_filters['age'] == 'mid' && (litter.ageDays < 28 || litter.ageDays > 56)) return false;
        if (_filters['age'] == 'old' && litter.ageDays <= 56) return false;

        if (cStage == 'all') {
          return lStatus != 'died' && lStatus != 'dead' && lStatus != 'archived' && lStatus != 'not taken';
        }

        final bool is7WeeksOrOlder = litter.ageDays >= 49;

        if (cStage == 'growout' || cStage == 'grow out' || cStage == 'grow-out') {
          final hasGrowoutKits = litter.kits.any((kit) => _kitMatchesStage(kit, litter));
          return hasGrowoutKits || lStatus == 'growout' || lStatus == 'grow out' || lStatus == 'grow-out';
        }
        if (cStage == 'weaned') {
          final hasWeanedKits = litter.kits.any((kit) => _kitMatchesStage(kit, litter));
          return hasWeanedKits || lStatus == 'weaned' || (is7WeeksOrOlder && (lStatus == 'nursing' || lStatus == '' || lStatus == 'active'));
        }
        if (cStage == 'nursing') {
          if (lStatus == 'weaned' || is7WeeksOrOlder) return false;
          final hasNursingKits = litter.kits.any((kit) => _kitMatchesStage(kit, litter));
          return hasNursingKits || lStatus == 'nursing' || lStatus == '' || lStatus == 'active';
        }
        if (cStage == 'quarantine') {
          return lStatus == 'quarantine';
        }

        return lStatus == cStage;
      },
    ).toList();

    // Requirement 7: Sort tiles from Oldest Kindle date (top) to latest kindle date (bottom)
    filteredList.sort((a, b) {
      final dateA = a.kindleDate ?? a.dob ?? a.breedDate;
      final dateB = b.kindleDate ?? b.dob ?? b.breedDate;
      return dateA.compareTo(dateB); // Ascending order
    });

    return filteredList;
  }

  Widget _buildLittersList() {
    final filtered = _getFilteredLitters();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.archive(PhosphorIconsStyle.duotone), size: 64, color: kNeutral200),
            const SizedBox(height: 16),
            const Text(
              'No litters found',
              style: TextStyle(color: kNeutral500, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
            ),
          ],
        ),
      );
    }

    if (_grouping == 'none') {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _buildLitterCard(filtered[index]),
      );
    }

    // Grouped view
    Map<String, List<Litter>> groups = {};
    for (var litter in filtered) {
      String key = litter.breed;
      if (_grouping == 'dam') key = litter.dam;
      if (_grouping == 'location') key = litter.location;
      groups.putIfAbsent(key, () => []).add(litter);
    }

    List<String> sortedKeys = groups.keys.toList()..sort();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: sortedKeys.map((key) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _grouping == 'location' ? PhosphorIcons.mapPin(PhosphorIconsStyle.bold) : PhosphorIcons.package(PhosphorIconsStyle.bold),
                    size: 14,
                    color: kNeutral400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    key.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            ...groups[key]!.map((litter) => _buildLitterCard(litter)),
          ],
        );
      }).toList(),
    );
  }

  void _showEditLitterDialog(Litter litter) async {
    final doe = await _db.getRabbit(litter.doeId);
    if (doe != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => LogBirthModal(doe: doe, existingLitter: litter, onComplete: () => _refreshLitters()),
      );
    }
  }

  void _showAddKitDialog(Litter litter) async {
    // Basic kit addition logic
    final updatedKits = List<Kit>.from(litter.kits);
    final nextId = (updatedKits.isEmpty ? 0 : updatedKits.map((k) => int.tryParse(k.id) ?? 0).reduce((a, b) => a > b ? a : b)) + 1;

    updatedKits.add(Kit(
      id: nextId.toString(),
      sex: 'U',
      color: 'Unknown',
      weight: 0.0,
      status: 'Nursing',
    ));

    final updatedLitter = litter.copyWith(
      kits: updatedKits,
      totalKits: (litter.totalKits ?? 0) + 1,
      aliveKits: (litter.aliveKits ?? 0) + 1,
    );
    await _db.updateLitter(updatedLitter);
    await _refreshLitters();
  }



  DateTime _getEffectiveWeanDate(Litter litter) {
    if (litter.weanDate != null) return litter.weanDate!;
    final int weanWeeks = SettingsService.instance.weanAge;
    final birth = litter.dob ?? litter.kindleDate;
    if (birth != null) {
      return birth.add(Duration(days: weanWeeks * 7));
    }
    return litter.breedDate.add(Duration(days: 31 + weanWeeks * 7));
  }

  String _formatNurseryDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat("MMM d ''yy").format(date);
  }

  String _formatNurseryAge(Litter litter) {
    final dob = litter.dob ?? litter.kindleDate;
    int days = litter.ageDays;
    if (dob != null) {
      final now = DateTime.now();
      if (dob.isAfter(now)) return '0d';
      days = now.difference(dob).inDays;
    }
    if (days <= 0) return '0d';
    final int weeks = days ~/ 7;
    final int remDays = days % 7;
    if (weeks == 0) return '${remDays}d';
    if (remDays == 0) return '${weeks}w';
    return '${weeks}w ${remDays}d';
  }

  String _ageString(int days, {DateTime? dob}) {
    if (dob != null) {
      final now = DateTime.now();
      if (dob.isAfter(now)) return '0d';
      days = now.difference(dob).inDays;
    }
    if (days <= 0) return '0d';
    final int weeks = days ~/ 7;
    final int remDays = days % 7;
    if (weeks == 0) return '${remDays}d';
    if (remDays == 0) return '${weeks}w';
    return '${weeks}w ${remDays}d';
  }

  Widget _buildParentNameText(Rabbit? rabbit, String fallbackName, bool isDoe) {
    final prefix = (rabbit?.breederPrefix ?? '').trim();
    final name = (rabbit?.name ?? fallbackName).trim();
    final nameColor = isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3);

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: '$prefix ',
              style: const TextStyle(
                color: Color(0xFF787774),
                fontWeight: FontWeight.w700,
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              color: nameColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLitterCard(Litter litter) {
    final isExpanded = _expandedLitters[litter.id] ?? false;
    final doeRabbit = _rabbitMap[litter.doeId];
    final buckRabbit = _rabbitMap[litter.buckId];
    final weanDate = _getEffectiveWeanDate(litter);
    final int weanDays = SettingsService.instance.weanAge * 7;
    final bool isWeanPassed = litter.ageDays >= weanDays || litter.status.toLowerCase() == 'weaned';

    final List<Kit> displayKits = litter.kits.isNotEmpty
        ? (_currentStage.toLowerCase() == 'all'
            ? litter.kits.where((k) => !k.isArchived || k.status.toLowerCase() == 'sold' || k.status.toLowerCase() == 'dead' || k.status.toLowerCase() == 'died').toList()
            : litter.kits.where((k) => _kitMatchesStage(k, litter)).toList())
        : List.generate(
            litter.aliveKits ?? litter.totalKitsCount,
            (i) => Kit(
              id: 'K-${i + 1}',
              sex: 'U',
              color: 'Unknown',
              weight: 0.0,
              status: 'Nursing',
            ),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Column(
        children: [
          // 1. Top Section (Doe avatar, center info, Buck avatar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Doe (Mother) Avatar - Left (Larger photo size)
                _buildCircularAvatar(litter.doeId),
                const SizedBox(width: 8),
                // Center Info: Doe name, Buck name, Age, Wean date
                Expanded(
                  child: Column(
                    children: [
                      _buildParentNameText(doeRabbit, litter.dam, true),
                      const SizedBox(height: 1),
                      _buildParentNameText(buckRabbit, litter.sire, false),
                      const SizedBox(height: 2),
                      Text(
                        'Age: ${_formatNurseryAge(litter)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Wean: ',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF555555),
                            ),
                          ),
                          Text(
                            _formatNurseryDate(weanDate),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: !isWeanPassed
                                  ? const Color(0xFFE53935) // Red before wean date
                                  : const Color(0xFF2E7B32), // Green after wean date
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Buck (Father) Avatar - Right (Larger photo size)
                _buildCircularAvatar(litter.buckId),
              ],
            ),
          ),

          const SizedBox(height: 2),

          // 2. Info Section (Born/Alive, DOB, Bred, Cage, 3 dots, Litter ID expander)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kNeutral200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeutral300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left Column: 4 lines
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Born: ${litter.totalKits ?? 0}  Alive: ${litter.aliveKits ?? litter.totalKitsCount}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'DOB: ${_formatNurseryDate(litter.dob ?? litter.kindleDate)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Bred: ${_formatNurseryDate(litter.breedDate)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Cage: ${litter.cage.isNotEmpty ? litter.cage : '-'}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right Column: 3 dots at top, Litter ID pill at bottom aligned with Cage
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              _searchFocusNode.canRequestFocus = false;
                              FocusScope.of(context).unfocus();
                              await _showLitterActions(litter);
                              _searchFocusNode.canRequestFocus = true;
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(top: 2, right: 4),
                              child: Icon(Icons.more_horiz, size: 22, color: Color(0xFF787774)),
                            ),
                          ),
                          // Place litter ID here with v/arrow toggle
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                final wasOpen = _expandedLitters[litter.id] ?? false;
                                _expandedLitters.clear(); // Auto-retract previous open litters
                                if (!wasOpen) {
                                  _expandedLitters[litter.id] = true;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE5E5EA)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    litter.id,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7B6BA0),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 15,
                                    color: const Color(0xFF7B6BA0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isExpanded) ...[
                  const Divider(height: 20),
                  if (displayKits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
                      child: Text('No kits in this litter', style: TextStyle(color: kNeutral500, fontSize: 12)),
                    )
                  else
                    ...displayKits.map((kit) => _buildKitRow(litter, kit)).toList(),
                  const SizedBox(height: 8),
                  _buildLitterNotesBox(litter),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLitterNotesBox(Litter litter) {
    final hasNotes = litter.notes != null && litter.notes!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DFFA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B6BA0).withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notes_rounded, size: 16, color: Color(0xFF6B2D6D)),
              SizedBox(width: 6),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A3E6D),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasNotes ? litter.notes!.trim() : 'No notes recorded.',
            style: TextStyle(
              fontSize: 12.5,
              color: hasNotes ? const Color(0xFF333333) : const Color(0xFF8E8E93),
              height: 1.35,
              fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularAvatar(String? rabbitId) {
    return FutureBuilder<Rabbit?>(
      future: rabbitId != null ? _db.getRabbit(rabbitId) : null,
      builder: (context, snapshot) {
        final rabbit = snapshot.data;
        if (rabbit != null && rabbit.photos != null && rabbit.photos!.isNotEmpty) {
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1.2),
              image: DecorationImage(
                image: FileImage(File(rabbit.photos!.first)),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1)),
              ],
            ),
          );
        }
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/profilelogo.png',
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChipStatus(String status) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: config.textColor),
      ),
    );
  }

  Widget _defaultLitterAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/images/profilelogo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildRoundedStatusBadge(String status) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: config.textColor),
      ),
    );
  }

  Widget _buildViewKitsButton(Litter litter, bool isExpanded) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _expandedLitters[litter.id] = !isExpanded);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isExpanded ? 'Hide kits' : 'View kits',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF777777)),
            ),
            const SizedBox(width: 4),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: const Color(0xFF777777),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentRow(Litter litter) {
    return Row(
      children: [
        Icon(PhosphorIcons.genderFemale(PhosphorIconsStyle.bold), size: 12, color: kPinkDeep.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(litter.dam, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral700)),
        const SizedBox(width: 8),
        Icon(PhosphorIcons.genderMale(PhosphorIconsStyle.bold), size: 12, color: kBlueDeep.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(litter.sire, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral700)),
      ],
    );
  }

  Widget _buildMetaGrid(Litter litter) {
    return Row(
      children: [
        _buildMetaItem(PhosphorIcons.calendar(PhosphorIconsStyle.bold), _formatTileDate(litter.dob)),
        const SizedBox(width: 12),
        _buildMetaItem(PhosphorIcons.house(PhosphorIconsStyle.bold), litter.location.isNotEmpty ? litter.location : 'No Location'),
        const SizedBox(width: 12),
        _buildMetaItem(PhosphorIcons.hash(PhosphorIconsStyle.bold), 'Size: ${litter.totalKitsCount}'),
      ],
    );
  }

  Widget _buildMetaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: kLilacDeep.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral500)),
      ],
    );
  }

  List<Widget> _buildStatusBadges(Litter litter) {
    return litter.distinctStatuses.map((status) {
      final config = _getStatusConfig(status);
      return Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: config.bgColor, borderRadius: BorderRadius.circular(100)),
        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: config.textColor, letterSpacing: 0.2)),
      );
    }).toList();
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'nursing':
        return _StatusConfig(bgColor: kLilacWash, textColor: kLilacDeep);
      case 'weaned':
        return _StatusConfig(bgColor: kBlueWash, textColor: kBlueDeep);
      case 'growout':
        return _StatusConfig(bgColor: kPinkWash, textColor: kPinkDeep);
      case 'mature':
        return _StatusConfig(bgColor: const Color(0xFFE0F2F1), textColor: const Color(0xFF00695C));
      case 'sold':
        return _StatusConfig(bgColor: kNeutral200, textColor: kNeutral600);
      case 'butchered':
        return _StatusConfig(bgColor: kPinkWash, textColor: kPinkDeep);
      case 'dead':
        return _StatusConfig(bgColor: kPinkWash, textColor: const Color(0xFFB71C1C));
      case 'quarantine':
        return _StatusConfig(bgColor: const Color(0xFFFFF3E0), textColor: const Color(0xFFEF6C00));
      default:
        return _StatusConfig(bgColor: kNeutral100, textColor: kNeutral500);
    }
  }

  Widget _buildKitRow(Litter litter, Kit kit) {
    final String kStatus = kit.status.toLowerCase().trim();
    final bool isOutcome = [
      'sold',
      'butchered',
      'dead',
      'died',
      'deceased',
      'cull'
    ].contains(kStatus);

    final bool isFosteredIn = kit.id.startsWith('F-') ||
        kit.id.startsWith('foster_') ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered from'));
    final bool isFosteredOut = kStatus == 'fostered' ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered to'));

    String displayKitId;
    if (isFosteredIn) {
      final fosteredKitsInLitter = litter.kits.where((k) =>
        k.id.startsWith('F-') ||
        k.id.startsWith('foster_') ||
        (k.details != null && k.details!.toLowerCase().contains('fostered from'))
      ).toList();
      final fosterIndex = fosteredKitsInLitter.indexOf(kit) + 1;
      displayKitId = 'F-${fosterIndex > 0 ? fosterIndex : 1}';
    } else {
      final numericPart = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
      displayKitId = 'K-${numericPart.isEmpty ? (litter.kits.indexOf(kit) + 1) : numericPart}';
    }

    return InkWell(
      onTap: () => _openKitDetail(litter, kit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kNeutral200)),
          color: isOutcome ? kNeutral100 : Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Index Pill (matches top tile corner radius)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              height: 24,
              constraints: const BoxConstraints(minWidth: 40),
              decoration: BoxDecoration(
                color: isFosteredIn
                    ? const Color(0xFF3A3A3C) // Dark grey base for foster kits
                    : (isOutcome ? kNeutral200 : kLilacWash),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFosteredIn
                      ? const Color(0xFF55555A)
                      : (isOutcome ? kNeutral300 : kLilacLight),
                ),
              ),
              child: Center(
                child: Text(
                  displayKitId,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isFosteredIn
                        ? const Color(0xFFE2BFFB) // Light purple number
                        : (isOutcome ? kNeutral600 : kLilacText),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        kit.color,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isOutcome ? kNeutral600 : const Color(0xFF37352F),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        kit.sex == 'M' ? PhosphorIcons.genderMale(PhosphorIconsStyle.bold) : (kit.sex == 'F' ? PhosphorIcons.genderFemale(PhosphorIconsStyle.bold) : PhosphorIcons.genderIntersex(PhosphorIconsStyle.bold)),
                        size: 14,
                        color: kit.sex == 'M' ? kBlueDeep : (kit.sex == 'F' ? kPinkDeep : kLilacDeep),
                      ),
                    ],
                  ),
                  if (kit.weight > 0)
                    Text(
                      'Weight: ${FormatUtils.formatWeight(kit.weight)}',
                      style: const TextStyle(fontSize: 11, color: kNeutral500, fontWeight: FontWeight.w500),
                    ),
                  if (kit.details != null && kit.details!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      kit.details!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF7B6BA0), fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOutcome) ...[
              _buildOutcomeBadge(kit.status, litter, kit),
              const SizedBox(width: 6),
            ],
            Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), size: 16, color: kNeutral300),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeBadge(String status, [Litter? litter, Kit? kit]) {
    final s = status.toLowerCase();
    if (s == 'sold') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24), // Solid dark tag
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.tag(PhosphorIconsStyle.fill), size: 10, color: Colors.white),
            const SizedBox(width: 3),
            const Text(
              'SOLD',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    if (s == 'dead' || s == 'died') {
      return GestureDetector(
        onLongPress: (litter != null && kit != null)
            ? () => _showReverseKitDiedDialog(litter, kit)
            : null,
        onTap: (litter != null && kit != null)
            ? () => _showReverseKitDiedDialog(litter, kit)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE), // Light red wash
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFE57373)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.close, size: 11, color: Color(0xFFD32F2F)),
              SizedBox(width: 3),
              Text(
                'Kit Died',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD32F2F),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: config.bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: config.textColor)),
    );
  }

  Widget _buildStandardKitCard(Litter litter, Kit kit) {
    final bool isMale = kit.sex == 'M';
    final bool isFemale = kit.sex == 'F';
    final Color headerColor = isMale ? kBlueLight : (isFemale ? kPinkLight : kLilacLight);
    final Color genderColor = isMale ? kBlueDeep : (isFemale ? kPinkDeep : kLilacDeep);
    final IconData genderIcon = isMale ? Icons.male : (isFemale ? Icons.female : Icons.help_outline);

    final kitIndex = (litter.kits.indexOf(kit) + 1).toString().padLeft(2, '0');
    final String displayId = '${litter.id} ($kitIndex)';

    return Container(
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
          // 1. Colored Header (Gender Tinted)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kit Avatar
                _buildKitAvatar(litter, kit),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$displayId  -  ${kit.color}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(genderIcon, size: 16, color: genderColor),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showKitActions(litter, kit),
                            child: const Icon(Icons.more_horiz, size: 22, color: Color(0xFF787774)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${litter.doeName} X ${litter.buckName}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB388FF)),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Born ${_formatTileDate(litter.dob)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 3),

          // 2. Middle Stats Section (Grey)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kNeutral200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeutral300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cage: ${litter.cage.isNotEmpty ? litter.cage : 'N/A'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF555555)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Age:  ${_ageString(litter.ageDays, dob: litter.dob ?? litter.kindleDate)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF555555)),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wean Dt.: ${_formatTileDate(_getEffectiveWeanDate(litter))}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF555555)),
                    ),
                    if (kit.weight > 0)
                      Text(
                        '${kit.weight} ${FormatUtils.weightUnit}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF777777)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 3),

          // 3. Bottom Actions Section (White)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F3F3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChipStatus(kit.status),
                      if (kit.details != null && kit.details!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          kit.details!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                _buildViewLitterButton(litter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitAvatar(Litter litter, Kit kit) {
    if (kit.imagePath != null && kit.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(kit.imagePath!),
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultKitPlaceholder(),
        ),
      );
    }
    return _defaultKitPlaceholder();
  }

  Widget _defaultKitPlaceholder() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/profilelogo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildViewLitterButton(Litter litter) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _expandedLitters[litter.id] = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View Litter',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF777777)),
            ),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF777777)),
          ],
        ),
      ),
    );
  }

  Widget _buildKitAvatarHighRes(Kit kit) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/profilelogo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildKitAvatarMini(Kit kit) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/images/profilelogo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildKitMeta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: kNeutral400),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kNeutral500)),
      ],
    );
  }

  Widget _buildLitterActionButtons(Litter litter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(child: _buildSmallActionBtn(icon: PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), label: 'Edit', onTap: () => _showEditLitterDialog(litter))),
          const SizedBox(width: 8),
          Expanded(child: _buildSmallActionBtn(icon: PhosphorIcons.plusCircle(PhosphorIconsStyle.bold), label: 'Add Kit', onTap: () => _showAddKitDialog(litter))),
          const SizedBox(width: 8),
          _buildIconButton(icon: PhosphorIcons.dotsThreeOutlineVertical(PhosphorIconsStyle.bold), onTap: () => _showLitterActions(litter)),
        ],
      ),
    );
  }

  Widget _buildSmallActionBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kNeutral300)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: kNeutral600),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral700)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kNeutral300)),
        child: Icon(icon, size: 16, color: kNeutral600),
      ),
    );
  }

  String _formatTileDate(DateTime date) {
    return FormatUtils.formatDate(date);
  }

  bool _kitMatchesStage(Kit kit, [Litter? litter]) {
    final status = kit.status.trim().toLowerCase();
    final stage = _currentStage.trim().toLowerCase();
    final isArchiveStatus = kit.isArchived;

    if (stage == 'all') return !isArchiveStatus || status == 'sold' || status == 'dead' || status == 'died';
    if (stage == 'archive') return isArchiveStatus;

    if (status == 'sold' || status == 'dead' || status == 'died') {
      if (litter != null) {
        final lStatus = litter.status.toLowerCase().trim();
        final int weanDays = SettingsService.instance.weanAge * 7;
        final bool isWeanPassed = litter.ageDays >= weanDays || lStatus == 'weaned';
        if (stage == 'nursing') {
          return !isWeanPassed && lStatus != 'weaned' && lStatus != 'growout' && lStatus != 'grow out' && lStatus != 'grow-out' && lStatus != 'quarantine';
        }
        if (stage == 'weaned') {
          return (isWeanPassed || lStatus == 'weaned') && lStatus != 'growout' && lStatus != 'grow out' && lStatus != 'grow-out' && lStatus != 'quarantine';
        }
        if (stage == 'growout' || stage == 'grow out' || stage == 'grow-out') {
          return lStatus == 'growout' || lStatus == 'grow out' || lStatus == 'grow-out';
        }
        if (stage == 'quarantine') {
          return lStatus == 'quarantine';
        }
      }
      return true;
    }

    if (isArchiveStatus) return false;

    if (stage == 'quarantine') return status == 'quarantine';
    if (stage == 'growout' || stage == 'grow out' || stage == 'grow-out') {
      return status == 'growout' || status == 'grow out' || status == 'grow-out';
    }
    if (stage == 'weaned') {
      return status == 'weaned';
    }
    if (stage == 'nursing') {
      return status == 'nursing' || status == 'fostered' || status == '' || status == 'active';
    }

    return status == stage;
  }

  void _openKitDetail(Litter litter, Kit kit) => _showKitActions(litter, kit);

  Future<void> _moveKitToGrowOut(Litter litter, Kit kit) async {
    await _moveKitToStage(litter, kit, 'GrowOut');
  }

  Future<void> _showLitterActions(Litter litter) async {
    _searchFocusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();

    final lStatus = litter.status.toLowerCase().trim();
    final bool allKitsSold = litter.kits.isNotEmpty &&
        litter.kits.every((k) =>
            k.status.toLowerCase() == 'sold' ||
            k.status.toLowerCase() == 'cull' ||
            k.status.toLowerCase() == 'butchered' ||
            k.status.toLowerCase() == 'dead' ||
            k.status.toLowerCase() == 'died');

    String effectiveStage = _currentStage.toLowerCase();
    if (effectiveStage == 'all') {
      if (lStatus == 'archived' || lStatus == 'cull' || lStatus == 'died' || lStatus == 'sold') {
        effectiveStage = 'archive';
      } else if (lStatus == 'quarantine') {
        effectiveStage = 'quarantine';
      } else if (lStatus == 'growout' || lStatus == 'grow out' || lStatus == 'grow-out') {
        effectiveStage = 'growout';
      } else if (lStatus == 'weaned') {
        effectiveStage = 'weaned';
      } else {
        effectiveStage = 'nursing';
      }
    }

    List<Widget> actionPills = [];

    // When all kits of a Doe are SOLD: Show only Edit Birth Info, Move to Archive, Delete Litter
    if (allKitsSold || lStatus == 'sold' || effectiveStage == 'archive') {
      actionPills = [
        _buildLitterActionPill(
          label: 'Edit Birth Info',
          onTap: () async {
            Navigator.pop(context);
            final doe = await _db.getRabbit(litter.doeId);
            if (doe != null && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                backgroundColor: Colors.transparent,
                builder: (context) => LogBirthModal(
                  doe: doe,
                  existingLitter: litter,
                  onComplete: () => _refreshLitters(),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Archive',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Archived');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Delete Litter',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(litter);
          },
        ),
      ];
    } else if (effectiveStage == 'nursing') {
      // Nursing: Edit Birth Info, Foster Litter, Move, Move to Archive, Litter Died / Cull in Red, Delete Litter in Red
      actionPills = [
        _buildLitterActionPill(
          label: 'Edit Birth Info',
          onTap: () async {
            Navigator.pop(context);
            final doe = await _db.getRabbit(litter.doeId);
            if (doe != null && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                backgroundColor: Colors.transparent,
                builder: (context) => LogBirthModal(
                  doe: doe,
                  existingLitter: litter,
                  onComplete: () => _refreshLitters(),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Foster Litter',
          onTap: () {
            Navigator.pop(context);
            _showFosterKitsModal(context, litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move',
          onTap: () {
            Navigator.pop(context);
            _showMoveLitterModal(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Archive',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Archived');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Litter Died / Cull',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _markLitterAsDied(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Delete Litter',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(litter);
          },
        ),
      ];
    } else if (effectiveStage == 'weaned') {
      // Weaned: Edit Birth Info, Move to Nursing, Move to Grow-Out, Move to Cage No., Sell Litter, Move to Quarantine, Move to Archive, Litter Died / Cull in Red, Delete Litter in Red
      actionPills = [
        _buildLitterActionPill(
          label: 'Edit Birth Info',
          onTap: () async {
            Navigator.pop(context);
            final doe = await _db.getRabbit(litter.doeId);
            if (doe != null && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                backgroundColor: Colors.transparent,
                builder: (context) => LogBirthModal(
                  doe: doe,
                  existingLitter: litter,
                  onComplete: () => _refreshLitters(),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Nursing',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Nursing');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Grow-Out',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'GrowOut');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Cage No.',
          onTap: () {
            Navigator.pop(context);
            _showMoveCageDialog(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Sell Litter',
          onTap: () {
            Navigator.pop(context);
            _showSellLitterDialog(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Quarantine',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Quarantine');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Archive',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Archived');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Litter Died / Cull',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _markLitterAsDied(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Delete Litter',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(litter);
          },
        ),
      ];
    } else if (effectiveStage == 'growout') {
      // Grow out: Edit Birth Info, Move to Nursing, Move to Weaned, Move to Cage No., Sell Litter, Move to Quarantine, Move to Archive, Litter Died / Cull in Red, Delete Litter in Red
      actionPills = [
        _buildLitterActionPill(
          label: 'Edit Birth Info',
          onTap: () async {
            Navigator.pop(context);
            final doe = await _db.getRabbit(litter.doeId);
            if (doe != null && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                backgroundColor: Colors.transparent,
                builder: (context) => LogBirthModal(
                  doe: doe,
                  existingLitter: litter,
                  onComplete: () => _refreshLitters(),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Nursing',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Nursing');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Weaned',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Weaned');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Cage No.',
          onTap: () {
            Navigator.pop(context);
            _showMoveCageDialog(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Sell Litter',
          onTap: () {
            Navigator.pop(context);
            _showSellLitterDialog(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Quarantine',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Quarantine');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Archive',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Archived');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Litter Died / Cull',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _markLitterAsDied(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Delete Litter',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(litter);
          },
        ),
      ];
    } else if (effectiveStage == 'quarantine') {
      // Quarantine: Edit Birth Info, Move to Nursing, Move to Weaned, Move to Grow-Out, Move to Cage No., Sell Litter, Move to Archive, Litter Died / Cull in Red, Delete Litter in Red
      actionPills = [
        _buildLitterActionPill(
          label: 'Edit Birth Info',
          onTap: () async {
            Navigator.pop(context);
            final doe = await _db.getRabbit(litter.doeId);
            if (doe != null && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                backgroundColor: Colors.transparent,
                builder: (context) => LogBirthModal(
                  doe: doe,
                  existingLitter: litter,
                  onComplete: () => _refreshLitters(),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Nursing',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Nursing');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Weaned',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Weaned');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Grow-Out',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'GrowOut');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Cage No.',
          onTap: () {
            Navigator.pop(context);
            _showMoveCageDialog(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Sell Litter',
          onTap: () {
            Navigator.pop(context);
            _showSellLitterDialog(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Archive',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Archived');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Litter Died / Cull',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _markLitterAsDied(litter);
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Delete Litter',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(litter);
          },
        ),
      ];
    } else {
      actionPills = [
        _buildLitterActionPill(
          label: 'Edit Birth Info',
          onTap: () async {
            Navigator.pop(context);
            final doe = await _db.getRabbit(litter.doeId);
            if (doe != null && mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                backgroundColor: Colors.transparent,
                builder: (context) => LogBirthModal(
                  doe: doe,
                  existingLitter: litter,
                  onComplete: () => _refreshLitters(),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Move to Archive',
          onTap: () async {
            Navigator.pop(context);
            await _moveLitterToStage(litter, 'Archived');
          },
        ),
        const SizedBox(height: 10),
        _buildLitterActionPill(
          label: 'Delete Litter',
          isDestructive: true,
          onTap: () {
            Navigator.pop(context);
            _showDeleteConfirmation(litter);
          },
        ),
      ];
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Litter ${litter.id}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            litter.status.isNotEmpty
                                ? (litter.status[0].toUpperCase() + litter.status.substring(1))
                                : 'Nursing',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF2C2C2E), size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Soft Purple/Lilac Container holding white pill buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE6F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: actionPills,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _searchFocusNode.canRequestFocus = true;
  }

  Future<void> _showMoveLitterModal(Litter litter) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Move Litter ${litter.id}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Select destination stage or cage',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF2C2C2E), size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Soft Purple/Lilac Container holding white pill buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE6F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildLitterActionPill(
                        label: 'Move to Weaned',
                        onTap: () async {
                          Navigator.pop(context);
                          await _moveLitterToStage(litter, 'Weaned');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildLitterActionPill(
                        label: 'Move to Grow-Out',
                        onTap: () async {
                          Navigator.pop(context);
                          await _moveLitterToStage(litter, 'GrowOut');
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildLitterActionPill(
                        label: 'Move to Cage No.',
                        onTap: () {
                          Navigator.pop(context);
                          _showMoveCageDialog(litter);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildLitterActionPill(
                        label: 'Move to Quarantine',
                        onTap: () async {
                          Navigator.pop(context);
                          await _moveLitterToStage(litter, 'Quarantine');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveLitterToStage(Litter litter, String targetStage) async {
    try {
      final index = litters.indexWhere((l) => l.id == litter.id);
      if (index == -1) return;

      final int weanDays = SettingsService.instance.weanAge * 7;
      final List<Kit> updatedKits = litters[index].kits.map<Kit>((k) {
        if (!k.isArchived && k.status.toLowerCase() != 'dead' && k.status.toLowerCase() != 'died' && k.status.toLowerCase() != 'sold' && k.status.toLowerCase() != 'butchered') {
          return k.copyWith(
            status: targetStage == 'Archived' ? 'Cull' : targetStage,
          );
        }
        return k;
      }).toList();

      final DateTime? updatedWeanDate = targetStage == 'Weaned'
          ? (litters[index].weanDate ?? DateTime.now())
          : (targetStage == 'Nursing' ? DateTime.now().add(Duration(days: weanDays)) : litters[index].weanDate);

      final updatedLitter = litters[index].copyWith(
        status: targetStage,
        kits: updatedKits,
        weanDate: updatedWeanDate,
      );

      if (targetStage == 'Nursing' && litter.doeId.isNotEmpty) {
        final aliveNursing = updatedKits.where((k) => !k.isArchived && k.status != 'Dead' && k.status != 'Died').length;
        await _db.restoreDoeNursingStatus(litter.doeId, updatedLitter.copyWith(aliveKits: aliveNursing));
      }

      await _db.updateLitter(updatedLitter);

      if (targetStage == 'Weaned' || targetStage == 'GrowOut' || targetStage == 'Archived') {
        await _db.checkAndUpdateDoeStatusIfLitterEmpty(litter.doeId);
      }

      notifyDataChanged();
      await _refreshLitters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Litter ${litter.id} moved to $targetStage'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error moving litter: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildLitterActionPill({
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isDestructive ? Border.all(color: const Color(0xFFFFCDD2), width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDestructive ? const Color(0xFFE53935) : const Color(0xFF2C2C2E),
          ),
        ),
      ),
    );
  }

  void _markLitterAsDied(Litter litter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark Litter as Died'),
        content: Text('Are you sure you want to mark all kits in Litter ${litter.id} as died? This will reset the doe to Open.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final updatedKits = litter.kits.map((k) {
                  if (!k.isArchived && k.status != 'Sold' && k.status != 'Butchered') {
                    return k.copyWith(status: 'Died');
                  }
                  return k;
                }).toList();

                final updatedLitter = litter.copyWith(
                  kits: updatedKits,
                  status: 'Died',
                  aliveKits: 0,
                  deadKits: (litter.deadKits ?? 0) + (litter.aliveKits ?? litter.kits.length),
                );

                await _db.updateLitter(updatedLitter);
                await _db.checkAndUpdateDoeStatusIfLitterEmpty(litter.doeId);
                await _refreshLitters();

                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Litter ${litter.id} marked as died'),
                      backgroundColor: const Color(0xFF7B6BA0),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD44C47),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _getKitDisplayTag(Litter litter, Kit kit) {
    final bool isFosteredIn = kit.id.startsWith('F-') ||
        kit.id.startsWith('foster_') ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered from'));

    if (isFosteredIn) {
      if (kit.id.startsWith('F-')) return kit.id;
      final fosteredKits = litter.kits.where((k) =>
        k.id.startsWith('F-') ||
        k.id.startsWith('foster_') ||
        (k.details != null && k.details!.toLowerCase().contains('fostered from'))
      ).toList();
      final idx = fosteredKits.indexOf(kit) + 1;
      return 'F-${idx > 0 ? idx : 1}';
    } else {
      final numericPart = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
      final idx = (numericPart.isNotEmpty && numericPart.length <= 4)
          ? numericPart
          : (litter.kits.indexOf(kit) + 1).toString();
      return 'K-$idx';
    }
  }

  void _showKitActions(Litter litter, Kit kit) {
    final DateTime? kitDob = litter.dob ?? litter.kindleDate;
    final int kitAgeDays = kitDob != null
        ? DateTime.now().difference(kitDob).inDays
        : litter.ageDays;
    final int weanDays = SettingsService.instance.weanAge * 7;
    final bool isWeanAgeReached = kitAgeDays >= weanDays;

    final String kStatus = kit.status.toLowerCase().trim();
    final String lStatus = litter.status.toLowerCase().trim();

    String kitStage = 'nursing';
    if (kStatus == 'quarantine' || (kStatus.isEmpty && lStatus == 'quarantine')) {
      kitStage = 'quarantine';
    } else if (kStatus == 'growout' || kStatus == 'grow out' || kStatus == 'grow-out' || (kStatus.isEmpty && (lStatus == 'growout' || lStatus == 'grow out' || lStatus == 'grow-out'))) {
      kitStage = 'growout';
    } else if (kStatus == 'weaned' || (kStatus.isEmpty && (lStatus == 'weaned' || (litter.weanDate != null && DateTime.now().isAfter(litter.weanDate!)) || isWeanAgeReached))) {
      kitStage = 'weaned';
    } else if (kStatus == 'sold' || kStatus == 'dead' || kStatus == 'died') {
      // Determine stage for sold/dead kit based on age and litter status
      if (lStatus == 'quarantine') {
        kitStage = 'quarantine';
      } else if (lStatus == 'growout' || lStatus == 'grow out' || lStatus == 'grow-out') {
        kitStage = 'growout';
      } else if (lStatus == 'weaned' || isWeanAgeReached) {
        kitStage = 'weaned';
      } else {
        kitStage = 'nursing';
      }
    } else {
      kitStage = 'nursing';
    }

    final bool isFosteredIn = kit.id.startsWith('F-') ||
        kit.id.startsWith('foster_') ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered from'));
    final bool isFosteredOut = kit.status.toLowerCase() == 'fostered' ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered to'));
    final bool isFostered = isFosteredIn || isFosteredOut;

    final String kitTag = _getKitDisplayTag(litter, kit);
    final List<Widget> actions = [];

    if (kitStage == 'nursing') {
      // 1. Nursing
      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Foster Kit
      if (isFostered) {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Foster',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelFosterKit(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Foster Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showFosterKitDialog(litter, kit);
          },
        ));
      }

      // - Sell Kit / Cancel Sale
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Weaned
      actions.add(_buildCompactActionTile(
        label: 'Move to Weaned',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Weaned');
        },
      ));

      // - Move to Grow out
      actions.add(_buildCompactActionTile(
        label: 'Move to Grow out',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'GrowOut');
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Quarantine
      actions.add(_buildCompactActionTile(
        label: 'Quarantine',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Quarantine');
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    } else if (kitStage == 'weaned') {
      // 2. Weaned
      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Sell Kit
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Nursing
      actions.add(_buildCompactActionTile(
        label: 'Move to Nursing',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Nursing');
        },
      ));

      // - Move to Grow out
      actions.add(_buildCompactActionTile(
        label: 'Move to Grow out',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'GrowOut');
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Birth Certificate
      actions.add(_buildCompactActionTile(
        label: 'Birth Certificate',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitBirthCertificate(litter, kit);
        },
      ));

      // - Pedigree
      actions.add(_buildCompactActionTile(
        label: 'Pedigree',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitPedigree(litter, kit);
        },
      ));

      // - Quarantine
      actions.add(_buildCompactActionTile(
        label: 'Quarantine',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Quarantine');
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    } else if (kitStage == 'growout') {
      // 3. Grow-Out
      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Sell Kit
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Nursing
      actions.add(_buildCompactActionTile(
        label: 'Move to Nursing',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Nursing');
        },
      ));

      // - Move to Weaned
      actions.add(_buildCompactActionTile(
        label: 'Move to Weaned',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Weaned');
        },
      ));

      // - Move to Herd (Under 6 months status Inactive or growout in Herd)
      actions.add(_buildCompactActionTile(
        label: 'Move to Herd',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          final bool isUnder6Months = kitAgeDays < 180;
          _promoteKitToMature(litter, kit, isGrowOut: isUnder6Months);
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Birth Certificate
      actions.add(_buildCompactActionTile(
        label: 'Birth Certificate',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitBirthCertificate(litter, kit);
        },
      ));

      // - Pedigree
      actions.add(_buildCompactActionTile(
        label: 'Pedigree',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitPedigree(litter, kit);
        },
      ));

      // - Quarantine
      actions.add(_buildCompactActionTile(
        label: 'Quarantine',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Quarantine');
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    } else if (kitStage == 'quarantine') {
      // 4. Quarantine
      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Sell Kit
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Nursing
      actions.add(_buildCompactActionTile(
        label: 'Move to Nursing',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Nursing');
        },
      ));

      // - Move to Weaned
      actions.add(_buildCompactActionTile(
        label: 'Move to Weaned',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Weaned');
        },
      ));

      // - Move to Grow-out
      actions.add(_buildCompactActionTile(
        label: 'Move to Grow-out',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'GrowOut');
        },
      ));

      // - Move to Herd
      actions.add(_buildCompactActionTile(
        label: 'Move to Herd',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          final bool isUnder6Months = kitAgeDays < 180;
          _promoteKitToMature(litter, kit, isGrowOut: isUnder6Months);
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Birth Certificate
      actions.add(_buildCompactActionTile(
        label: 'Birth Certificate',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitBirthCertificate(litter, kit);
        },
      ));

      // - Pedigree
      actions.add(_buildCompactActionTile(
        label: 'Pedigree',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitPedigree(litter, kit);
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    }

    String displayStageName;
    if (kitStage == 'growout') {
      displayStageName = 'Grow Out';
    } else {
      displayStageName = kitStage.isNotEmpty
          ? (kitStage[0].toUpperCase() + kitStage.substring(1))
          : 'Nursing';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kit $kitTag',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayStageName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF2C2C2E), size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE6F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 3.4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveKitToStage(Litter litter, Kit kit, String targetStage) async {
    try {
      final index = litters.indexWhere((l) => l.id == litter.id);
      if (index == -1) return;

      final updatedKits = litters[index].kits.map((k) {
        if (k.id == kit.id) {
          return k.copyWith(status: targetStage == 'Archived' ? 'Cull' : targetStage);
        }
        return k;
      }).toList();

      final allKitsInTargetOrOutcome = updatedKits.every((k) =>
          k.status.toLowerCase() == targetStage.toLowerCase() ||
          k.status.toLowerCase() == 'sold' ||
          k.status.toLowerCase() == 'dead' ||
          k.status.toLowerCase() == 'died' ||
          k.status.toLowerCase() == 'butchered' ||
          k.status.toLowerCase() == 'cull');

      final bool hasAnyNursing = updatedKits.any((k) {
        final s = k.status.toLowerCase().trim();
        return s == 'nursing' || s == 'fostered';
      });

      final int weanDays = SettingsService.instance.weanAge * 7;
      final DateTime? updatedWeanDate = targetStage == 'Weaned'
          ? (litters[index].weanDate ?? DateTime.now())
          : (targetStage == 'Nursing' ? DateTime.now().add(Duration(days: weanDays)) : litters[index].weanDate);

      final updatedLitter = litters[index].copyWith(
        kits: updatedKits,
        status: allKitsInTargetOrOutcome
            ? targetStage
            : (hasAnyNursing ? 'Nursing' : targetStage),
        weanDate: updatedWeanDate,
      );

      if (targetStage == 'Nursing' && litter.doeId.isNotEmpty) {
        final aliveNursing = updatedKits.where((k) => !k.isArchived && k.status != 'Dead' && k.status != 'Died').length;
        await _db.restoreDoeNursingStatus(litter.doeId, updatedLitter.copyWith(aliveKits: aliveNursing));
      }

      await _db.updateLitter(updatedLitter);
      if (targetStage == 'Weaned' || targetStage == 'GrowOut' || targetStage == 'Archived') {
        await _db.checkAndUpdateDoeStatusIfLitterEmpty(litter.doeId);
      }

      notifyDataChanged();
      await _refreshLitters();

      if (mounted) {
        final displayStage = targetStage == 'GrowOut' ? 'Grow out' : targetStage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kit ${_getKitDisplayTag(litter, kit)} moved to $displayStage'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error moving kit: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showKitBirthCertificate(Litter litter, Kit kit) {
    final kitRabbit = Rabbit(
      id: kit.id,
      name: kit.id.startsWith('K-') || kit.id.startsWith('F-') ? 'Kit ${kit.id}' : kit.id,
      breed: litter.breed,
      type: kit.sex == 'M' ? RabbitType.buck : RabbitType.doe,
      color: kit.color,
      dateOfBirth: litter.dob ?? litter.kindleDate,
      weight: kit.weight > 0 ? kit.weight : null,
      sireId: litter.buckId,
      damId: litter.doeId,
      status: RabbitStatus.open,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Birth Certificate Preview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2C2C2E)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CertificateCard(rabbit: kitRabbit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKitPedigree(Litter litter, Kit kit) {
    final kitRabbit = Rabbit(
      id: kit.id,
      name: kit.id.startsWith('K-') || kit.id.startsWith('F-') ? 'Kit ${kit.id}' : kit.id,
      breed: litter.breed,
      type: kit.sex == 'M' ? RabbitType.buck : RabbitType.doe,
      color: kit.color,
      dateOfBirth: litter.dob ?? litter.kindleDate,
      weight: kit.weight > 0 ? kit.weight : null,
      sireId: litter.buckId,
      damId: litter.doeId,
      status: RabbitStatus.open,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PedigreeScreen(
          rabbitId: kitRabbit.id,
          initialRabbit: kitRabbit,
        ),
      ),
    );
  }

  Widget _buildCompactActionTile({
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final effectiveTextColor = textColor ?? const Color(0xFF2C2C2E);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: effectiveTextColor),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _cancelFosterKit(Litter currentLitter, Kit fosteredKit) async {
    try {
      final allLitters = await _db.getLitters();
      final db = await _db.database;

      final detailsText = fosteredKit.details ?? '';
      final bool isCurrentSurrogate = fosteredKit.id.startsWith('foster_') ||
          fosteredKit.id.startsWith('F-') ||
          detailsText.toLowerCase().contains('fostered from');

      Litter? birthLitter;
      Litter? surrogateLitter;
      String? originalKitId;

      if (isCurrentSurrogate) {
        // Kit is in the surrogate litter -> return to original mother's litter
        surrogateLitter = currentLitter;

        // Check if ID encodes source: foster_<sourceLitterId>_<kitId>
        if (fosteredKit.id.startsWith('foster_')) {
          final parts = fosteredKit.id.split('_');
          if (parts.length >= 3) {
            final sourceLitterId = parts[1];
            originalKitId = parts.sublist(2).join('_');
            birthLitter = allLitters.where((l) => l.id == sourceLitterId).firstOrNull;
          }
        }

        // Try extracting dam name from details: "Fostered from <name>"
        if (birthLitter == null) {
          final matchFrom = RegExp(r'Fostered from ([^\n•\[]+)', caseSensitive: false).firstMatch(detailsText);
          if (matchFrom != null) {
            final originalDamName = matchFrom.group(1)?.trim();
            if (originalDamName != null && originalDamName.isNotEmpty) {
              birthLitter = allLitters.where((l) =>
                l.id != currentLitter.id &&
                (l.doeName.toLowerCase() == originalDamName.toLowerCase() ||
                 l.dam.toLowerCase() == originalDamName.toLowerCase() ||
                 l.doeName.toLowerCase().contains(originalDamName.toLowerCase()) ||
                 originalDamName.toLowerCase().contains(l.doeName.toLowerCase()))
              ).firstOrNull;
            }
          }
        }

        // Fallback: look for any other litter with a kit marked 'Fostered'
        birthLitter ??= allLitters.where((l) =>
          l.id != currentLitter.id &&
          l.kits.any((k) => k.status.toLowerCase() == 'fostered')
        ).firstOrNull;

        if (birthLitter != null) {
          bool matched = false;
          final updatedBirthKits = birthLitter.kits.map((k) {
            if (!matched && (
              (originalKitId != null && k.id == originalKitId) ||
              k.id == fosteredKit.id ||
              k.status.toLowerCase() == 'fostered'
            )) {
              matched = true;
              return k.copyWith(status: 'Nursing', details: null);
            }
            return k;
          }).toList();

          if (!matched) {
            final cleanId = 'K-${birthLitter.kits.length + 1}';
            updatedBirthKits.add(fosteredKit.copyWith(
              id: cleanId,
              status: 'Nursing',
              details: null,
            ));
          }

          final birthAlive = updatedBirthKits.where((k) =>
            !k.isArchived &&
            k.status.toLowerCase() != 'dead' &&
            k.status.toLowerCase() != 'died' &&
            k.status.toLowerCase() != 'fostered'
          ).length;

          await db.update('litters', {
            'kits': jsonEncode(updatedBirthKits.map((k) => k.toMap()).toList()),
            'currentAlive': birthAlive,
            'aliveBorn': birthAlive,
            'status': 'Nursing',
            'updatedAt': DateTime.now().toIso8601String(),
          }, where: 'id = ?', whereArgs: [birthLitter.id]);

          if (birthLitter.doeId.isNotEmpty) {
            await _db.restoreDoeNursingStatus(birthLitter.doeId, birthLitter.copyWith(aliveKits: birthAlive));
          }
        }

        // Remove ONLY this kit from surrogate litter (currentLitter)
        final updatedSurrogateKits = currentLitter.kits.where((k) => k.id != fosteredKit.id).toList();
        final surrogateAlive = updatedSurrogateKits.where((k) =>
          !k.isArchived &&
          k.status.toLowerCase() != 'dead' &&
          k.status.toLowerCase() != 'died' &&
          k.status.toLowerCase() != 'fostered'
        ).length;

        await db.update('litters', {
          'kits': jsonEncode(updatedSurrogateKits.map((k) => k.toMap()).toList()),
          'currentAlive': surrogateAlive,
          'aliveBorn': surrogateAlive,
          'updatedAt': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [currentLitter.id]);

        await _db.checkAndUpdateDoeStatusIfLitterEmpty(currentLitter.doeId);

      } else {
        // Kit is currently sitting in original litter marked as 'Fostered'
        birthLitter = currentLitter;

        final matchTo = RegExp(r'Fostered to ([^\n•\[]+)', caseSensitive: false).firstMatch(detailsText);
        String? targetDoeName;
        if (matchTo != null) {
          targetDoeName = matchTo.group(1)?.trim();
          if (targetDoeName != null && targetDoeName.isNotEmpty) {
            surrogateLitter = allLitters.where((l) =>
              l.id != currentLitter.id &&
              (l.doeName.toLowerCase() == targetDoeName!.toLowerCase() ||
               l.dam.toLowerCase() == targetDoeName!.toLowerCase() ||
               l.doeName.toLowerCase().contains(targetDoeName!.toLowerCase()) ||
               targetDoeName!.toLowerCase().contains(l.doeName.toLowerCase()))
            ).firstOrNull;
          }
        }

        // Fallback: look for surrogate litter that has a kit referencing this birth dam/litter
        surrogateLitter ??= allLitters.where((l) =>
          l.id != currentLitter.id &&
          l.kits.any((k) =>
            k.id == 'foster_${birthLitter!.id}_${fosteredKit.id}' ||
            k.id == fosteredKit.id ||
            (k.details != null && k.details!.toLowerCase().contains('fostered from') && k.details!.contains(birthLitter!.doeName))
          )
        ).firstOrNull;

        if (surrogateLitter != null) {
          bool removed = false;
          final updatedTargetKits = surrogateLitter.kits.where((k) {
            if (!removed && (
              k.id == 'foster_${birthLitter!.id}_${fosteredKit.id}' ||
              k.id == fosteredKit.id ||
              (k.details != null && k.details!.toLowerCase().contains('fostered from') && k.color == fosteredKit.color)
            )) {
              removed = true;
              return false;
            }
            return true;
          }).toList();

          final targetAlive = updatedTargetKits.where((k) =>
            !k.isArchived &&
            k.status.toLowerCase() != 'dead' &&
            k.status.toLowerCase() != 'died' &&
            k.status.toLowerCase() != 'fostered'
          ).length;

          await db.update('litters', {
            'kits': jsonEncode(updatedTargetKits.map((k) => k.toMap()).toList()),
            'currentAlive': targetAlive,
            'aliveBorn': targetAlive,
            'updatedAt': DateTime.now().toIso8601String(),
          }, where: 'id = ?', whereArgs: [surrogateLitter.id]);

          await _db.checkAndUpdateDoeStatusIfLitterEmpty(surrogateLitter.doeId);
        }

        // Restore kit in birth (current) litter
        final updatedBirthKits = currentLitter.kits.map((k) {
          if (k.id == fosteredKit.id) {
            return k.copyWith(status: 'Nursing', details: null);
          }
          return k;
        }).toList();

        final birthAlive = updatedBirthKits.where((k) =>
          !k.isArchived &&
          k.status.toLowerCase() != 'dead' &&
          k.status.toLowerCase() != 'died' &&
          k.status.toLowerCase() != 'fostered'
        ).length;

        await db.update('litters', {
          'kits': jsonEncode(updatedBirthKits.map((k) => k.toMap()).toList()),
          'currentAlive': birthAlive,
          'aliveBorn': birthAlive,
          'status': 'Nursing',
          'updatedAt': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [currentLitter.id]);

        if (currentLitter.doeId.isNotEmpty) {
          await _db.restoreDoeNursingStatus(currentLitter.doeId, currentLitter.copyWith(aliveKits: birthAlive));
        }
      }

      notifyDataChanged();
      await _refreshLitters();

      if (mounted) {
        final momName = birthLitter?.doeName.isNotEmpty == true ? birthLitter!.doeName : 'mother';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foster cancelled. Kit returned to mother ($momName).'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling foster: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _cancelKitSale(Litter litter, Kit kit) async {
    try {
      final db = await _db.database;
      final dob = litter.kindleDate ?? litter.dob;
      final int ageDays = dob != null
          ? DateTime.now().difference(dob).inDays
          : litter.ageDays;
      final String restoredStatus = ageDays >= 49 ? 'Weaned' : 'Nursing';

      // 1. Delete matching finance transactions
      final cleanNumeric = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
      await db.delete(
        'transactions',
        where: 'litterId = ? AND (kitId = ? OR kitId = ? OR description LIKE ?)',
        whereArgs: [litter.id, kit.id, cleanNumeric, '%Kit ${litter.id}-${kit.id}%'],
      );

      // 2. Restore kit in litter
      final updatedKits = litter.kits.map((k) {
        if (k.id == kit.id) {
          final cleanDetails = (k.details != null && (k.details!.toLowerCase().contains('sold to') || k.details!.toLowerCase().startsWith('sold'))) ? null : k.details;
          return k.copyWith(status: restoredStatus, price: null, details: cleanDetails);
        }
        return k;
      }).toList();

      final aliveCount = updatedKits.where((k) =>
        !k.isArchived &&
        k.status.toLowerCase() != 'dead' &&
        k.status.toLowerCase() != 'died' &&
        k.status.toLowerCase() != 'fostered'
      ).length;

      final updatedLitter = litter.copyWith(
        kits: updatedKits,
        status: (litter.status.toLowerCase() == 'sold' || litter.status.toLowerCase() == 'archived') ? restoredStatus : litter.status,
      );

      await _db.updateLitter(updatedLitter);

      if (updatedLitter.doeId.isNotEmpty) {
        await _db.restoreDoeNursingStatus(updatedLitter.doeId, updatedLitter);
      }

      notifyDataChanged();
      await _refreshLitters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale cancelled. Kit restored to $restoredStatus.'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling sale: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showReverseKitDiedDialog(Litter litter, Kit kit) async {
    final kitTag = _getKitDisplayTag(litter, kit);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.favorite, color: Color(0xFFE04F9F), size: 24),
            SizedBox(width: 8),
            Text(
              'Reverse Action?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Do you want to reverse this action and bring Kit $kitTag back to life in the nursery?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7B32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Bring Back to Life',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _reverseKitDied(litter, kit);
    }
  }

  Future<void> _reverseKitDied(Litter litter, Kit kit) async {
    try {
      final dob = litter.kindleDate ?? litter.dob;
      final int ageDays = dob != null
          ? DateTime.now().difference(dob).inDays
          : litter.ageDays;
      final int weanDays = SettingsService.instance.weanAge * 7;
      final String restoredStatus = (ageDays >= weanDays || litter.status.toLowerCase() == 'weaned')
          ? 'Weaned'
          : 'Nursing';

      final updatedKits = litter.kits.map((k) {
        if (k.id == kit.id) {
          final cleanDetails = (k.details != null && (k.details!.toLowerCase().contains('deceased') || k.details!.toLowerCase().contains('died')))
              ? null
              : k.details;
          return k.copyWith(status: restoredStatus, details: cleanDetails);
        }
        return k;
      }).toList();

      final currentDeadKits = (litter.deadKits ?? 0);
      final newDeadKits = currentDeadKits > 0 ? currentDeadKits - 1 : 0;

      final updatedLitter = litter.copyWith(
        kits: updatedKits,
        deadKits: newDeadKits,
        status: (litter.status.toLowerCase() == 'died' || litter.status.toLowerCase() == 'archived')
            ? restoredStatus
            : litter.status,
      );

      await _db.updateLitter(updatedLitter);

      if (updatedLitter.doeId.isNotEmpty) {
        await _db.restoreDoeNursingStatus(updatedLitter.doeId, updatedLitter);
      }

      notifyDataChanged();
      await _refreshLitters();

      if (mounted) {
        final kitTag = _getKitDisplayTag(litter, kit);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kit $kitTag restored to $restoredStatus.'),
            backgroundColor: const Color(0xFF2E7B32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring kit: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _promoteKitToMature(Litter litter, Kit kit, {bool isGrowOut = false}) async {
    // Generate next rabbit ID
    String nextId = '';
    try {
      final allRabbits = await _db.getAllRabbits();
      final archivedRabbits = await _db.getArchivedRabbits();
      final allIds = [
        ...allRabbits,
        ...archivedRabbits
      ].map((r) => r.id).toList();
      int maxNum = 0;
      for (final id in allIds) {
        final match = RegExp(r'^R-(\d+)$').firstMatch(id);
        if (match != null) {
          final num = int.tryParse(match.group(1)!) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      }
      nextId = 'R-${(maxNum + 1).toString().padLeft(4, '0')}';
    } catch (_) {
      nextId = 'R-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }

    // Load breeds for autocomplete
    List<Breed> availableBreeds = [];
    try {
      availableBreeds = await _db.getAllBreeds();
    } catch (_) {}

    bool isBuck = kit.sex == 'M';
    final nameController = TextEditingController(text: 'Kit ${kit.id}');
    final idController = TextEditingController(text: nextId);
    final breedController = TextEditingController(text: litter.breed);
    final colorController = TextEditingController(text: kit.color);
    final weightController = TextEditingController(text: kit.weight > 0 ? kit.weight.toString() : '');
    final notesController = TextEditingController(text: 'Promoted from litter ${litter.id}');
    String? selectedLocation = litter.location.isNotEmpty ? litter.location : null;
    String? selectedCage = litter.cage.isNotEmpty ? litter.cage : null;
    DateTime? dateOfBirth = litter.dob;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Build cage list from selected location
            List<String> cageNames = [];
            if (selectedLocation != null) {
              final matchingBarn = _barns.where((b) => b.name == selectedLocation).toList();
              if (matchingBarn.isNotEmpty) {
                for (final row in matchingBarn.first.rows) {
                  cageNames.addAll(row.cages);
                }
              }
            }
            if (selectedCage != null && !cageNames.contains(selectedCage)) {
              selectedCage = null;
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, color: Color(0xFF7B6BA0), size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Promote to ${isBuck ? 'Buck' : 'Doe'}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF37352F)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      // Validation
                                      if (nameController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter a name'), backgroundColor: Color(0xFFD44C47)),
                                        );
                                        return;
                                      }
                                      if (breedController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter a breed'), backgroundColor: Color(0xFFD44C47)),
                                        );
                                        return;
                                      }

                                      setSheetState(() => isSaving = true);

                                      try {
                                        final newRabbit = await _db.promoteKitToBreeder(
                                          litter,
                                          kit,
                                          customName: nameController.text,
                                          customId: idController.text.isNotEmpty ? idController.text : null,
                                          type: isBuck ? RabbitType.buck : RabbitType.doe,
                                          breed: breedController.text,
                                          status: isGrowOut ? RabbitStatus.growout : RabbitStatus.open,
                                          location: selectedLocation,
                                          cage: selectedCage,
                                          dateOfBirth: dateOfBirth,
                                          color: colorController.text.isNotEmpty ? colorController.text : null,
                                          weight: weightController.text.isNotEmpty ? double.tryParse(weightController.text) : null,
                                          notes: notesController.text.isNotEmpty ? notesController.text : null,
                                        );

                                        await _refreshLitters();

                                        if (mounted) {
                                          Navigator.pop(context); // close sheet

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${newRabbit?.name ?? "Kit"} moved to Breeders Directory as ${isGrowOut ? 'Grow Out' : (isBuck ? 'Buck' : 'Doe')}!'),
                                              backgroundColor: const Color(0xFF7B6BA0),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );

                                          // Navigate to the new rabbit's detail screen
                                          if (newRabbit != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => RabbitDetailScreen(rabbit: newRabbit),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        setSheetState(() => isSaving = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: isSaving ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B6BA0))) : Text('SAVE', style: TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 22),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Form body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kit info banner
                          Container(
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Color(0xFFF7EDE3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF7B6BA0).withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isBuck ? Color(0xFF2E7BB5).withOpacity(0.15) : Color(0xFF9C6ADE).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isBuck ? Icons.male : Icons.female,
                                    color: isBuck ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                                    size: 26,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kit ${_getKitDisplayTag(litter, kit)}',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF37352F)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '${isBuck ? 'Male (Buck)' : 'Female (Doe)'} • ${kit.color} • ${kit.weight} ${FormatUtils.weightUnit}',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                                      ),
                                      Text(
                                        'Sire: ${litter.buckName} • Dam: ${litter.doeName}',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),

                          // Rabbit Type
                          Text('Rabbit Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(() => isBuck = false),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: !isBuck ? kFemaleColor : Colors.white,
                                      border: Border.all(color: !isBuck ? kFemaleColor : Color(0xFFE9E9E7)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.female, color: !isBuck ? Colors.white : kFemaleColor, size: 20),
                                        SizedBox(width: 6),
                                        Text('Doe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: !isBuck ? Colors.white : kFemaleColor)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(() => isBuck = true),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isBuck ? Color(0xFF2E7BB5) : Colors.white,
                                      border: Border.all(color: isBuck ? Color(0xFF2E7BB5) : Color(0xFFE9E9E7)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.male, color: isBuck ? Colors.white : Color(0xFF2E7BB5), size: 20),
                                        SizedBox(width: 6),
                                        Text('Buck', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isBuck ? Colors.white : Color(0xFF2E7BB5))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Rabbit ID
                          _buildPromoteTextField(idController, 'Rabbit ID', Icons.tag, readOnly: true),
                          SizedBox(height: 16),

                          // Name
                          _buildPromoteTextField(nameController, 'Name *', Icons.pets, hint: 'Enter rabbit name'),
                          SizedBox(height: 16),

                          // Breed
                          Text('Breed *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue val) {
                              final names = availableBreeds.map((b) => b.name).toList();
                              if (val.text.isEmpty) return names;
                              return names.where((n) => n.toLowerCase().contains(val.text.toLowerCase()));
                            },
                            initialValue: TextEditingValue(text: breedController.text),
                            fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
                              ctrl.addListener(() => breedController.text = ctrl.text);
                              return TextField(
                                controller: ctrl,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: 'e.g., New Zealand White',
                                  prefixIcon: Icon(Icons.category, color: Color(0xFF787774)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF7B6BA0), width: 2)),
                                ),
                              );
                            },
                            onSelected: (v) => breedController.text = v,
                          ),
                          SizedBox(height: 16),

                          // Location
                          Text('Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _barns.any((b) => b.name == selectedLocation) ? selectedLocation : null,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.location_on, color: Color(0xFF787774)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
                            ),
                            hint: Text(_barns.isEmpty ? 'No barns added yet' : 'Select Location'),
                            items: _barns.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))).toList(),
                            onChanged: (v) {
                              setSheetState(() {
                                selectedLocation = v;
                                selectedCage = null;
                              });
                            },
                          ),
                          SizedBox(height: 16),

                          // Cage
                          Text('Cage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey(selectedLocation),
                            value: selectedCage,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.home, color: Color(0xFF787774)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
                            ),
                            hint: Text(selectedLocation == null
                                ? 'Select a location first'
                                : cageNames.isEmpty
                                    ? 'No cages in this barn'
                                    : 'Select Cage'),
                            items: cageNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setSheetState(() => selectedCage = v),
                          ),
                          SizedBox(height: 16),

                          // Date of Birth
                          Text('Date of Birth', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: dateOfBirth ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setSheetState(() => dateOfBirth = date);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Color(0xFFE9E9E7)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cake, color: Color(0xFF787774)),
                                  SizedBox(width: 12),
                                  Text(
                                    dateOfBirth != null ? FormatUtils.formatDate(dateOfBirth!) : 'Not set',
                                    style: TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                  Spacer(),
                                  Icon(Icons.calendar_today, color: Color(0xFF787774), size: 20),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Color
                          _buildPromoteTextField(colorController, 'Color', Icons.palette, hint: 'e.g., White, Black'),
                          SizedBox(height: 16),

                          // Weight
                          _buildPromoteTextField(weightController, FormatUtils.weightLabel(), Icons.monitor_weight, hint: '0.0', keyboardType: TextInputType.number),
                          SizedBox(height: 16),

                          // Notes
                          _buildPromoteTextField(notesController, 'Notes', Icons.notes, hint: 'Optional notes'),
                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget _buildPromoteTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Color(0xFF787774)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF7B6BA0), width: 2)),
      ),
    );
  }

  void _showSellLitterDialog(Litter litter) {
    final TextEditingController priceController = TextEditingController();
    final TextEditingController buyerController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header matching Log Birth purple theme
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFEADBEE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A3E6D).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sell Litter',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4A3E6D),
                            letterSpacing: 0.3,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F2FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8DFFA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Litter ${litter.id}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4A3E6D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${litter.doeName} x ${litter.buckName ?? 'Unknown'} • ${litter.aliveKits} active kits',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF787774),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'SALE PRICE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B2D6D),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '${FormatUtils.currencySymbol} ',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE0D8ED), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF7B6BA0),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'BUYER NAME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B2D6D),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _db.getContacts(),
                        builder: (context, snapshot) {
                          final contacts = snapshot.data ?? [];
                          return Autocomplete<String>(
                            initialValue: TextEditingValue(text: buyerController.text),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return contacts
                                  .map((c) => c['name'] as String)
                                  .where((name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (String selection) {
                              buyerController.text = selection;
                            },
                            fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                              fieldController.addListener(() {
                                buyerController.text = fieldController.text;
                              });
                              return TextField(
                                controller: fieldController,
                                focusNode: focusNode,
                                onSubmitted: (value) => onFieldSubmitted(),
                                decoration: InputDecoration(
                                  hintText: 'Select or enter buyer',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE0D8ED), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7B6BA0),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);

                      final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                      if (litterIndex != -1) {
                        final updatedKits = litters[litterIndex].kits.map((k) {
                          if (k.status.toLowerCase() != 'dead' && k.status.toLowerCase() != 'died' && k.status.toLowerCase() != 'sold') {
                            return k.copyWith(
                              status: 'Sold',
                              details: 'Sold to ${buyerController.text}',
                              price: double.tryParse(priceController.text),
                            );
                          }
                          return k;
                        }).toList();

                        final updatedLitter = litters[litterIndex].copyWith(
                          kits: updatedKits,
                          status: 'Sold',
                          aliveKits: 0,
                        );
                        await _db.updateLitter(updatedLitter);

                        final salePrice = double.tryParse(priceController.text);
                        if (salePrice != null && salePrice > 0) {
                          final transaction = finance.Transaction(
                            id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
                            type: finance.TransactionType.income,
                            category: finance.TransactionCategory.soldKit,
                            amount: salePrice,
                            date: DateTime.now(),
                            description: 'Sold Litter ${litter.id}',
                            notes: buyerController.text.isNotEmpty ? 'Buyer: ${buyerController.text}' : null,
                            linkType: finance.LinkType.litter,
                            litterId: litter.id,
                          );
                          await _db.insertTransaction(transaction);
                        }

                        await _loadLitters();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Litter marked as sold'),
                              backgroundColor: Color(0xFF6B2D6D),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEDE8F5),
                      foregroundColor: const Color(0xFF6B2D6D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Record Sale',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF6B2D6D),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSellKitDialog(Litter litter, Kit kit) {
    final TextEditingController priceController = TextEditingController();
    final TextEditingController buyerController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header matching Log Birth purple theme
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFEADBEE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A3E6D).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sell Kit',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4A3E6D),
                            letterSpacing: 0.3,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F2FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8DFFA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kit ${_getKitDisplayTag(litter, kit)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4A3E6D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${kit.sex == 'M' ? 'Buck' : 'Doe'} • ${kit.color} • ${kit.weight} ${FormatUtils.weightUnit}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF787774),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'SALE PRICE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B2D6D),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '${FormatUtils.currencySymbol} ',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE0D8ED), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF7B6BA0),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'BUYER NAME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B2D6D),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _db.getContacts(),
                        builder: (context, snapshot) {
                          final contacts = snapshot.data ?? [];
                          return Autocomplete<String>(
                            initialValue: TextEditingValue(text: buyerController.text),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return contacts
                                  .map((c) => c['name'] as String)
                                  .where((name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (String selection) {
                              buyerController.text = selection;
                            },
                            fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                              fieldController.addListener(() {
                                buyerController.text = fieldController.text;
                              });
                              return TextField(
                                controller: fieldController,
                                focusNode: focusNode,
                                onSubmitted: (value) => onFieldSubmitted(),
                                decoration: InputDecoration(
                                  hintText: 'Select or enter buyer',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE0D8ED), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF7B6BA0),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);

                      final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                      if (litterIndex != -1) {
                        final updatedKits = litters[litterIndex].kits.map((k) {
                          if (k.id == kit.id) {
                            return k.copyWith(
                              status: 'Sold',
                              details: 'Sold to ${buyerController.text}',
                              price: double.tryParse(priceController.text),
                            );
                          }
                          return k;
                        }).toList();

                        final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                        await _db.updateLitter(updatedLitter);

                        // Create finance transaction for kit sale
                        final salePrice = double.tryParse(priceController.text);
                        if (salePrice != null && salePrice > 0) {
                          final transaction = finance.Transaction(
                            id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
                            type: finance.TransactionType.income,
                            category: finance.TransactionCategory.soldKit,
                            amount: salePrice,
                            date: DateTime.now(),
                            description: 'Sold Kit ${litter.id}-${kit.id}',
                            notes: buyerController.text.isNotEmpty ? 'Buyer: ${buyerController.text}' : null,
                            linkType: finance.LinkType.litter,
                            litterId: litter.id,
                            kitId: kit.id.toString(),
                            kitColor: kit.color,
                            kitSex: kit.sex,
                            buyerInfo: buyerController.text.isNotEmpty ? buyerController.text : null,
                          );
                          await _db.insertTransaction(transaction);
                        }

                        notifyDataChanged();
                        await _refreshLitters();
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kit marked as sold'),
                            backgroundColor: Color(0xFF6B2D6D),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEDE8F5),
                      foregroundColor: const Color(0xFF6B2D6D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Record Sale',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF6B2D6D),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKitHealthRecord(Litter litter, Kit kit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Health Record - Kit ${kit.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TYPE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 2,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'vaccination', child: Text('Vaccination')),
                        DropdownMenuItem(value: 'treatment', child: Text('Treatment')),
                        DropdownMenuItem(value: 'checkup', child: Text('Check-up')),
                        DropdownMenuItem(value: 'injury', child: Text('Injury')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CONDITION / ISSUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        final issues = SettingsService.instance.healthIssues.map((i) => i['name'] ?? '').where((n) => n.isNotEmpty).toList();
                        if (textEditingValue.text.isEmpty) return issues;
                        return issues.where((i) => i.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      fieldViewBuilder: (ctx2, textController, focusNode, onSubmitted) {
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'e.g. Snuffles, Sore Hocks...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF7B6BA0),
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter health notes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Health record added'),
                        backgroundColor: Color(0xFF7B6BA0),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6BA0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Record',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showButcherKitDialog(Litter litter, Kit kit) {
    final TextEditingController yieldController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Harvest / Butcher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Record harvest information for kit ${kit.id}?'),
            const SizedBox(height: 16),
            TextField(
              controller: yieldController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: FormatUtils.weightLabel('Dressed Weight'),
                hintText: '0.0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // ÃƒÂ¢Ã…â€œâ‚¬Â¦ ADD async
              Navigator.pop(context);

              final litterIndex = litters.indexWhere((l) => l.id == litter.id);
              if (litterIndex != -1) {
                final updatedKits = litters[litterIndex].kits.map((k) {
                  if (k.id == kit.id) {
                    return k.copyWith(
                      status: 'Butchered',
                      details: 'Yield ${yieldController.text}${FormatUtils.weightUnit}',
                    );
                  }
                  return k;
                }).toList();

                final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                await _db.updateLitter(updatedLitter);
                await _refreshLitters();
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kit harvest recorded'),
                    backgroundColor: Color(0xFF7B6BA0),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF7B6BA0)),
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _quarantineKit(Litter litter, Kit kit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quarantine Kit'),
        content: Text('Move kit ${kit.id} to quarantine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final litterIndex = litters.indexWhere((l) => l.id == litter.id);
              if (litterIndex != -1) {
                final updatedKits = litters[litterIndex].kits.map((k) {
                  if (k.id == kit.id) {
                    return k.copyWith(status: 'Quarantine');
                  }
                  return k;
                }).toList();

                final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                await _db.updateLitter(updatedLitter);
                await _refreshLitters();
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kit moved to quarantine'),
                    backgroundColor: Color(0xFFD97706),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Quarantine'),
          ),
        ],
      ),
    );
  }

  void _showEditKitDetails(Litter litter, Kit kit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditKitDetailsScreen(
          litter: litter,
          kit: kit,
          onSaved: () => _refreshLitters(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _logKitWeight(Litter litter, Kit kit) {
    final TextEditingController weightController = TextEditingController(
      text: kit.weight.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Weight'),
        content: TextField(
          controller: weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: FormatUtils.weightLabel(),
            suffixText: FormatUtils.weightUnit,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final litterIndex = litters.indexWhere((l) => l.id == litter.id);
              if (litterIndex != -1) {
                final updatedKits = litters[litterIndex].kits.map((k) {
                  if (k.id == kit.id) {
                    return k.copyWith(
                      weight: double.tryParse(weightController.text) ?? k.weight,
                    );
                  }
                  return k;
                }).toList();

                final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                await _db.updateLitter(updatedLitter);
                await _refreshLitters();
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Weight updated'),
                    backgroundColor: Color(0xFF7B6BA0),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF7B6BA0)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFosterKitDialog(Litter litter, Kit kit) {
    String? selectedLitterId;
    final fosterLitters = litters.where((l) =>
      l.id != litter.id &&
      l.doeId != litter.doeId &&
      l.status.toLowerCase() == 'nursing' &&
      l.status.toLowerCase() != 'archived' &&
      l.status.toLowerCase() != 'weaned'
    ).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Foster Kit', style: TextStyle(fontWeight: FontWeight.w700)),
          content: fosterLitters.isEmpty
              ? const Text('No active nursing litters found to foster with.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a nursing foster mother:'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedLitterId,
                      items: fosterLitters
                          .map((l) {
                            final fosterDoeName = l.doeName.isNotEmpty ? l.doeName : l.dam;
                            final shortLitterId = l.id.length > 6 ? l.id.substring(l.id.length - 4) : l.id;
                            final nursingKitsCount = l.kits.where((k) => k.status.toLowerCase() == 'nursing' || (!k.isArchived && k.status != 'Dead' && k.status != 'Died')).length;
                            return DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                '$fosterDoeName (Litter #$shortLitterId • $nursingKitsCount nursing kits)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedLitterId = val),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Note: This will transfer the kit to the surrogate doe with a note indicating its birth dam.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                    ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
            ),
            if (fosterLitters.isNotEmpty)
              ElevatedButton(
                onPressed: selectedLitterId == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        final target = fosterLitters.firstWhere((l) => l.id == selectedLitterId);
                        await _handleFosterKits(litter, target, [kit.id]);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6BA0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  void _showFosterKitsModal(BuildContext context, Litter sourceLitter) async {
    final allLitters = await _db.getLitters();
    final candidates = allLitters.where((l) =>
      l.id != sourceLitter.id &&
      l.doeId != sourceLitter.doeId &&
      l.status.toLowerCase() == 'nursing' &&
      l.status.toLowerCase() != 'archived' &&
      l.status.toLowerCase() != 'weaned'
    ).toList();

    final aliveKits = sourceLitter.kits.where((k) =>
      !k.isArchived &&
      k.status.toLowerCase() != 'fostered' &&
      k.status.toLowerCase() != 'dead' &&
      k.status.toLowerCase() != 'died'
    ).toList();

    if (aliveKits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active kits to foster in this litter'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF7B6BA0),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Litter? selectedTarget;
        final Set<String> selectedKitIds = {};

        return StatefulBuilder(builder: (ctx, setModalState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Foster Kits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2C2C2E))),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SELECT KITS TO FOSTER',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF787880), letterSpacing: 0.5),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (selectedKitIds.length == aliveKits.length) {
                              selectedKitIds.clear();
                            } else {
                              selectedKitIds.addAll(aliveKits.map((k) => k.id));
                            }
                          });
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                        child: Text(
                          selectedKitIds.length == aliveKits.length ? 'Deselect All' : 'Select All (${aliveKits.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7B6BA0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...aliveKits.map((kit) {
                            final numericPart = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
                            final kitLabel = 'K-${numericPart.isEmpty ? (sourceLitter.kits.indexOf(kit) + 1) : numericPart}';
                            final isChecked = selectedKitIds.contains(kit.id);
                            return CheckboxListTile(
                              value: isChecked,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF7B6BA0),
                              onChanged: (v) => setModalState(() {
                                if (v == true) {
                                  selectedKitIds.add(kit.id);
                                } else {
                                  selectedKitIds.remove(kit.id);
                                }
                              }),
                              title: Text(
                                '$kitLabel • ${kit.color.isNotEmpty ? kit.color : 'Unknown'} (${kit.sex})',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: kit.weight > 0 ? Text('Weight: ${kit.weight}g', style: const TextStyle(fontSize: 11)) : null,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          }),
                          const SizedBox(height: 16),
                          const Text(
                            'FOSTER INTO (SURROGATE DOE)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF787880), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 8),
                          if (candidates.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
                              child: const Text('No other active nursing litters available to foster into.', style: TextStyle(color: Color(0xFF856404), fontSize: 13)),
                            )
                          else
                            ...candidates.map((targetLitter) {
                              final doeName = targetLitter.doeName.isNotEmpty ? targetLitter.doeName : targetLitter.dam;
                              final shortLitterId = targetLitter.id.length > 6 ? targetLitter.id.substring(targetLitter.id.length - 4) : targetLitter.id;
                              final count = targetLitter.kits.where((k) => k.status.toLowerCase() == 'nursing' || (!k.isArchived && k.status != 'Dead' && k.status != 'Died')).length;
                              return RadioListTile<Litter>(
                                value: targetLitter,
                                groupValue: selectedTarget,
                                contentPadding: EdgeInsets.zero,
                                activeColor: const Color(0xFF7B6BA0),
                                onChanged: (v) => setModalState(() => selectedTarget = v),
                                title: Text(doeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                subtitle: Text('Litter #$shortLitterId • $count active kits', style: const TextStyle(fontSize: 12, color: Color(0xFF787880))),
                                dense: true,
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (selectedKitIds.isNotEmpty && selectedTarget != null)
                          ? () async {
                              Navigator.pop(ctx);
                              await _handleFosterKits(sourceLitter, selectedTarget!, selectedKitIds.toList());
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B6BA0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        selectedKitIds.isEmpty
                            ? 'Select Kits to Foster'
                            : (selectedTarget == null
                                ? 'Select Target Doe'
                                : 'Foster ${selectedKitIds.length} Kit${selectedKitIds.length > 1 ? 's' : ''}'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _handleFosterKits(Litter source, Litter target, List<String> kitIds) async {
    try {
      final db = await _db.database;
      final sourceDamName = source.doeName.isNotEmpty ? source.doeName : source.dam;
      final targetDoeName = target.doeName.isNotEmpty ? target.doeName : target.dam;

      // Count existing foster kits in target litter for F-1, F-2 naming
      int existingTargetFosterCount = target.kits.where((k) =>
        k.status.toLowerCase() == 'fostered' ||
        (k.details != null && k.details!.toLowerCase().contains('fostered')) ||
        k.id.startsWith('F-') ||
        k.id.startsWith('foster_')
      ).length;

      // Mark moved kits with foster note and structured ID
      final List<Kit> kitsToMove = [];
      for (final k in source.kits.where((k) => kitIds.contains(k.id))) {
        existingTargetFosterCount++;
        final existingNote = k.details ?? '';
        final fosterNote = 'Fostered from $sourceDamName';
        final newDetails = existingNote.contains(fosterNote)
            ? existingNote
            : (existingNote.isEmpty ? fosterNote : '$existingNote • $fosterNote');
        kitsToMove.add(k.copyWith(
          id: 'foster_${source.id}_${k.id}',
          status: 'Nursing',
          details: newDetails,
        ));
      }

      // Mark source kits as Fostered
      final updatedSourceKits = source.kits.map((k) {
        if (kitIds.contains(k.id)) {
          return k.copyWith(status: 'Fostered', details: 'Fostered to $targetDoeName');
        }
        return k;
      }).toList();

      // Add kits to target litter
      final targetKits = [...target.kits, ...kitsToMove];

      // Update source litter
      final sourceAliveCount = updatedSourceKits.where((k) =>
        !k.isArchived &&
        k.status.toLowerCase() != 'fostered' &&
        k.status.toLowerCase() != 'dead' &&
        k.status.toLowerCase() != 'died'
      ).length;

      await db.update('litters', {
        'kits': jsonEncode(updatedSourceKits.map((k) => k.toMap()).toList()),
        'currentAlive': sourceAliveCount,
        'aliveBorn': sourceAliveCount,
        if (sourceAliveCount == 0) 'status': 'Fostered',
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [source.id]);

      // Update target litter
      final targetAliveCount = targetKits.where((k) =>
        !k.isArchived &&
        k.status.toLowerCase() != 'dead' &&
        k.status.toLowerCase() != 'died'
      ).length;

      await db.update('litters', {
        'kits': jsonEncode(targetKits.map((k) => k.toMap()).toList()),
        'currentAlive': targetAliveCount,
        'aliveBorn': targetAliveCount,
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [target.id]);

      // Check if source doe has remaining active nursing kits; if not, change doe status to OPEN
      await _db.checkAndUpdateDoeStatusIfLitterEmpty(source.doeId);

      await _refreshLitters();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${kitsToMove.length} kit${kitsToMove.length > 1 ? 's' : ''} fostered to $targetDoeName'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fostering kits: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _markKitAsDied(Litter litter, Kit kit) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Died'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Record cause of death (optional):'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g., Runt, illness',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final litterIndex = litters.indexWhere((l) => l.id == litter.id);
              if (litterIndex != -1) {
                final updatedKits = litters[litterIndex].kits.map((k) {
                  if (k.id == kit.id) {
                    return k.copyWith(
                      status: 'Dead',
                      details: reasonController.text.isNotEmpty ? reasonController.text : 'Deceased',
                    );
                  }
                  return k;
                }).toList();

                final updatedLitter = litters[litterIndex].copyWith(
                  kits: updatedKits,
                  aliveKits: (litters[litterIndex].aliveKits ?? 0) - 1,
                  deadKits: (litters[litterIndex].deadKits ?? 0) + 1,
                );

                await _db.updateLitter(updatedLitter);
                await _db.checkAndUpdateDoeStatusIfLitterEmpty(litter.doeId);
                await _refreshLitters();
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kit marked as deceased'),
                    backgroundColor: Color(0xFF787774),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD44C47)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildKitActionOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color == const Color(0xFFD44C47) ? color : const Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color == const Color(0xFFD44C47) ? color : const Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeanLitterDialog(Litter litter) {
    // Get only nursing kits (eligible for weaning)
    final nursingKits = litter.kits.where((k) => k.status == 'Nursing').toList();
    // Track which kits are selected for weaning (all selected by default)
    Set<String> selectedKitIds = nursingKits.map((k) => k.id).toSet();
    bool weanAll = true;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Wean Litter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Litter info card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Litter ${litter.id}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${litter.dam} × ${litter.sire}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF787774),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Born: ${_formatDate(litter.dob)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF787774),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Wean mode toggle
                      const Text(
                        'WEAN MODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                weanAll = true;
                                selectedKitIds = nursingKits.map((k) => k.id).toSet();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: weanAll ? const Color(0xFFF0ECFE) : Colors.white,
                                  border: Border.all(
                                    color: weanAll ? const Color(0xFF7B6BA0) : const Color(0xFFE9E9E7),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    'Wean All (${nursingKits.length})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: weanAll ? const Color(0xFF7B6BA0) : const Color(0xFF787774),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                weanAll = false;
                                selectedKitIds.clear();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !weanAll ? const Color(0xFFF0ECFE) : Colors.white,
                                  border: Border.all(
                                    color: !weanAll ? const Color(0xFF7B6BA0) : const Color(0xFFE9E9E7),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    'Select Kits',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: !weanAll ? const Color(0xFF7B6BA0) : const Color(0xFF787774),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Kit selection list (only shown in Select Kits mode)
                      if (!weanAll) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SELECT KITS TO WEAN (${selectedKitIds.length}/${nursingKits.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF787774),
                                letterSpacing: 0.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                if (selectedKitIds.length == nursingKits.length) {
                                  selectedKitIds.clear();
                                } else {
                                  selectedKitIds = nursingKits.map((k) => k.id).toSet();
                                }
                              }),
                              child: Text(
                                selectedKitIds.length == nursingKits.length ? 'Deselect All' : 'Select All',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7B6BA0),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE9E9E7)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: nursingKits.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final kit = entry.value;
                              final isSelected = selectedKitIds.contains(kit.id);
                              return InkWell(
                                onTap: () => setModalState(() {
                                  if (isSelected) {
                                    selectedKitIds.remove(kit.id);
                                  } else {
                                    selectedKitIds.add(kit.id);
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFDF3E8) : Colors.white,
                                    border: idx < nursingKits.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF0F0EE))) : null,
                                    borderRadius: idx == 0
                                        ? const BorderRadius.vertical(top: Radius.circular(10))
                                        : idx == nursingKits.length - 1
                                            ? const BorderRadius.vertical(bottom: Radius.circular(10))
                                            : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF7B6BA0) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFF9B9A97),
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      // Kit avatar
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: kit.sex == 'M'
                                              ? const Color(0xFFEBF8FF)
                                              : kit.sex == 'F'
                                                  ? const Color(0xFFFFF0F5)
                                                  : const Color(0xFFF7F7F5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.pets,
                                            size: 16,
                                            color: kit.sex == 'M'
                                                ? const Color(0xFF2E7BB5)
                                                : kit.sex == 'F'
                                                    ? const Color(0xFF9C6ADE)
                                                    : const Color(0xFF787774),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Kit ${_getKitDisplayTag(litter, kit)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${kit.sex == 'M' ? 'Male' : kit.sex == 'F' ? 'Female' : 'Unknown'} • ${kit.color} • ${kit.weight} ${FormatUtils.weightUnit}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF787774),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Wean date
                      const Text(
                        'WEAN DATE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: litter.dob,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(selectedDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Color(0xFF787774),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFF7B6BA0),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                weanAll ? 'All ${nursingKits.length} nursing kits will be moved to "Weaned" stage' : '${selectedKitIds.length} selected kit${selectedKitIds.length == 1 ? '' : 's'} will be moved to "Weaned" stage',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7B6BA0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedKitIds.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(context);

                            final index = litters.indexWhere((l) => l.id == litter.id);
                            if (index != -1) {
                              final updatedKits = litters[index].kits.map((k) {
                                // Only wean selected kits
                                if (selectedKitIds.contains(k.id) && k.status == 'Nursing') {
                                  return k.copyWith(status: 'Weaned');
                                }
                                return k;
                              }).toList();

                              final updatedLitter = litters[index].copyWith(
                                kits: updatedKits,
                                weanDate: selectedDate,
                              );

                              await _db.updateLitter(updatedLitter);
                              await _refreshLitters();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${selectedKitIds.length} kit${selectedKitIds.length == 1 ? '' : 's'} weaned successfully'),
                                  backgroundColor: const Color(0xFF7B6BA0),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B6BA0),
                      disabledBackgroundColor: const Color(0xFFE9E9E7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      weanAll ? 'Wean All Kits' : 'Wean ${selectedKitIds.length} Kit${selectedKitIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHealthRecordDialog(Litter litter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Health Record',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TYPE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 2,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'vaccination', child: Text('Vaccination')),
                        DropdownMenuItem(value: 'treatment', child: Text('Treatment')),
                        DropdownMenuItem(value: 'checkup', child: Text('Check-up')),
                        DropdownMenuItem(value: 'injury', child: Text('Injury')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CONDITION / ISSUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        final issues = SettingsService.instance.healthIssues.map((i) => i['name'] ?? '').where((n) => n.isNotEmpty).toList();
                        if (textEditingValue.text.isEmpty) return issues;
                        return issues.where((i) => i.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      fieldViewBuilder: (ctx2, textController, focusNode, onSubmitted) {
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'e.g. Snuffles, Sore Hocks...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF7B6BA0),
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter health notes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Health record added'),
                        backgroundColor: Color(0xFF7B6BA0),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6BA0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Record',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkWeighDialog(Litter litter) {
    final TextEditingController totalWeightController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bulk Weigh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kits Alive',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF787774),
                            ),
                          ),
                          Text(
                            '${litter.aliveKits}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'TOTAL WEIGHT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: totalWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: FormatUtils.weightHint,
                        suffixText: FormatUtils.weightUnit,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.calculate,
                            size: 16,
                            color: Color(0xFF7B6BA0),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Average per kit will be calculated automatically',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7B6BA0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Weight recorded successfully'),
                        backgroundColor: Color(0xFF7B6BA0),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6BA0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Weight',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveCageDialog(Litter litter) {
    String? selectedLocation = litter.location;
    String? selectedCage = litter.cage;
    List<String> availableCages = [];

    // Pre-populate available cages for current location
    for (var barn in _barns) {
      for (var row in barn.rows) {
        if (row.name == selectedLocation) {
          availableCages = List.from(row.cages);
          break;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Move Cage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _barns.any((b) => b.rows.any((r) => r.name == selectedLocation)) ? selectedLocation : null,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF7B6BA0),
                              width: 2,
                            ),
                          ),
                        ),
                        items: _barns
                            .expand((barn) => barn.rows.map((row) {
                                  return DropdownMenuItem<String>(
                                    value: row.name,
                                    child: Text('${row.name}  (${barn.name})'),
                                  );
                                }))
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedLocation = value;
                            selectedCage = null;
                            availableCages = [];
                            for (var barn in _barns) {
                              for (var row in barn.rows) {
                                if (row.name == value) {
                                  availableCages = List.from(row.cages);
                                  break;
                                }
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'CAGE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      availableCages.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: availableCages.contains(selectedCage) ? selectedCage : null,
                              decoration: InputDecoration(
                                hintText: 'Select cage',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7B6BA0),
                                    width: 2,
                                  ),
                                ),
                              ),
                              items: availableCages.map((cage) {
                                return DropdownMenuItem<String>(
                                  value: cage,
                                  child: Text(cage),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setModalState(() => selectedCage = value);
                              },
                            )
                          : TextField(
                              controller: TextEditingController(text: selectedCage),
                              onChanged: (value) => selectedCage = value,
                              decoration: InputDecoration(
                                hintText: 'Enter cage number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7B6BA0),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // ÃƒÂ¢Ã…â€œâ‚¬Â¦ ADD async
                      Navigator.pop(context);

                      final index = litters.indexWhere((l) => l.id == litter.id);
                      if (index != -1) {
                        final updatedLitter = litters[index].copyWith(
                          location: selectedLocation ?? litters[index].location,
                          cage: selectedCage ?? litters[index].cage,
                        );

                        await _db.updateLitter(updatedLitter);
                        // Sync cage into barn row
                        final loc = selectedLocation ?? litters[index].location;
                        final cg = selectedCage ?? litters[index].cage;
                        if (loc.isNotEmpty && cg.isNotEmpty) {
                          await _db.syncCageToBarn(loc, cg);
                        }
                        await _refreshLitters();
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cage moved successfully'),
                            backgroundColor: Color(0xFF7B6BA0),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B6BA0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Move Litter',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _printCageCard(Litter litter) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ÃƒÂ°Ã…Â¸â‚¬â€œÂ¨ÃƒÂ¯Â¸Â Printing cage card...'),
        backgroundColor: Color(0xFF7B6BA0),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteConfirmation(Litter litter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Litter?'),
        content: Text('Are you sure you want to delete litter ${litter.id}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _db.deleteLitter(litter.id);
                await _refreshLitters();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Litter deleted'),
                      backgroundColor: Color(0xFFD44C47),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting litter: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD44C47)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return FormatUtils.formatDate(date);
  }

  void _showKitMenu(
    Litter litter,
    Kit kit,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kit ${_getKitDisplayTag(litter, kit)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        kit.status,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (kit.isArchived) ...[
              _buildMenuItem(
                Icons.restore,
                'Restore to Active',
                true,
                () async {
                  Navigator.pop(context);
                  final dob = litter.kindleDate ?? litter.dob;
                  final ageDays = dob != null
                      ? DateTime.now().difference(dob).inDays
                      : litter.ageDays;
                  final String restoredStatus = ageDays >= 49 ? 'Weaned' : 'Nursing';

                  final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                  if (litterIndex != -1) {
                    final updatedKits = litters[litterIndex].kits.map((k) {
                      if (k.id == kit.id) {
                        return k.copyWith(status: restoredStatus, price: null, details: null);
                      }
                      return k;
                    }).toList();

                    final aliveCount = updatedKits.where((k) =>
                      !k.isArchived &&
                      k.status.toLowerCase() != 'dead' &&
                      k.status.toLowerCase() != 'died' &&
                      k.status.toLowerCase() != 'fostered'
                    ).length;

                    final updatedLitter = litters[litterIndex].copyWith(
                      kits: updatedKits,
                      aliveKits: aliveCount,
                      status: (litters[litterIndex].status.toLowerCase() == 'sold' || litters[litterIndex].status.toLowerCase() == 'archived') ? 'Nursing' : litters[litterIndex].status,
                    );
                    await _db.updateLitter(updatedLitter);

                    if (updatedLitter.doeId.isNotEmpty) {
                      await _db.restoreDoeNursingStatus(updatedLitter.doeId, updatedLitter);
                    }

                    notifyDataChanged();
                    await _refreshLitters();
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kit restored to $restoredStatus'),
                        backgroundColor: const Color(0xFF7B6BA0),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              _buildMenuItem(
                Icons.delete_outline,
                'Delete Record',
                false,
                () {
                  setState(() {
                    final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                    if (litterIndex != -1) {
                      litters[litterIndex] = litters[litterIndex].copyWith(
                        kits: litters[litterIndex].kits.where((k) => k.id != kit.id).toList(),
                      );
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kit deleted'),
                      backgroundColor: Color(0xFFD44C47),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                isDestructive: true,
              ),
            ] else ...[
              if (kit.status == 'Nursing')
                _buildMenuItem(
                  Icons.content_cut,
                  'Wean Kit',
                  true,
                  () async {
                    // ÃƒÂ¢ÂÃ…â€™ DELETE OR COMMENT OUT THIS LINE:
                    // Navigator.pop(context);

                    // ÃƒÂ¢Ã…â€œâ‚¬Â¦ The _buildMenuItem wrapper already pops the context,
                    // so we just run the logic directly:

                    final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                    if (litterIndex != -1) {
                      final updatedKits = litters[litterIndex].kits.map((k) {
                        if (k.id == kit.id) {
                          return k.copyWith(status: 'Weaned');
                        }
                        return k;
                      }).toList();

                      final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                      await _db.updateLitter(updatedLitter);
                      await _refreshLitters();
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kit weaned'),
                          backgroundColor: Color(0xFF7B6BA0),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              if (kit.status == 'Weaned')
                _buildMenuItem(
                  Icons.trending_up,
                  'Grow Out',
                  true,
                  () async {
                    // ÃƒÂ¢Ã…â€œâ‚¬Â¦ ADD: Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B6BA0)),
                        ),
                      ),
                    );

                    try {
                      final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                      if (litterIndex != -1) {
                        final updatedKits = litters[litterIndex].kits.map((k) {
                          if (k.id == kit.id) {
                            return k.copyWith(status: 'GrowOut');
                          }
                          return k;
                        }).toList();

                        final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                        await _db.updateLitter(updatedLitter);
                        await _refreshLitters();
                      }

                      // ÃƒÂ¢Ã…â€œâ‚¬Â¦ Close loading dialog
                      if (mounted) {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kit moved to grow out'),
                            backgroundColor: Color(0xFF7B6BA0),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      // ÃƒÂ¢Ã…â€œâ‚¬Â¦ Handle errors
                      print('ÃƒÂ¢ÂÃ…â€™ Error updating kit: $e');
                      if (mounted) {
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              if (kit.status == 'GrowOut')
                _buildMenuItem(
                  Icons.star,
                  'Promote to Mature',
                  true,
                  () {
                    _promoteKitToMature(litter, kit);
                  },
                ),
              _buildMenuItem(
                Icons.attach_money,
                'Sell Kit',
                false,
                () {
                  _showSellKitDialog(litter, kit);
                },
              ),
              _buildMenuItem(
                Icons.medical_services_outlined,
                'Health Record',
                false,
                () {
                  _showKitHealthRecord(litter, kit);
                },
              ),
              if (SettingsService.instance.meatProductionEnabled)
                _buildMenuItem(
                  Icons.restaurant,
                  'Harvest / Butcher',
                  false,
                  () {
                    _showButcherKitDialog(litter, kit);
                  },
                ),
              _buildMenuItem(
                Icons.warning_amber,
                'Quarantine',
                false,
                () {
                  _quarantineKit(litter, kit);
                },
              ),
              _buildMenuItem(
                Icons.scale,
                'Log Weight',
                false,
                () {
                  _logKitWeight(litter, kit);
                },
              ),
              _buildMenuItem(
                Icons.dangerous,
                'Mark as Died',
                false,
                () {
                  _markKitAsDied(litter, kit);
                },
                isDestructive: true,
              ),
            ],
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String label,
    bool isPrimary,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(
          context,
        );
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? Color(
                  0xFFEDE9FE,
                )
              : Colors.transparent,
          border: isPrimary
              ? Border(
                  left: BorderSide(
                    color: Color(
                      0xFF7B6BA0,
                    ),
                    width: 4,
                  ),
                )
              : Border(
                  bottom: BorderSide(
                    color: Color(
                      0xFFF7F7F5,
                    ),
                  ),
                ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? Color(
                      0xFFD44C47,
                    )
                  : (isPrimary
                      ? Color(
                          0xFF7B6BA0,
                        )
                      : Color(
                          0xFF787774,
                        )),
              size: 24,
            ),
            SizedBox(
              width: 14,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive
                    ? Color(
                        0xFFD44C47,
                      )
                    : (isPrimary
                        ? Color(
                            0xFF7B6BA0,
                          )
                        : Colors.black87),
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BARN/CAGE HELPERS ====================

  int _countLittersInLocation(String location, [String? cage]) {
    return litters.where((l) {
      if (cage != null) {
        return l.location == location && l.cage == cage;
      }
      return l.location == location;
    }).length;
  }

  int _countLittersInBarn(Barn barn) {
    int total = 0;
    for (var row in barn.rows) {
      total += _countLittersInLocation(row.name);
    }
    return total;
  }

  int _getTotalLitters() {
    return litters.length;
  }

  int _getUnassignedLitterCount() {
    return litters.where((l) => l.location.isEmpty || l.location == 'Unknown' || l.location == 'Unassigned').length;
  }

  // ==================== BARN DRAWER ====================

  Future<void> _showBarnDrawer() async {
    await showGeneralDialog(
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
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7F7F5),
                          border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
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
                                        Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone), color: const Color(0xFF7B6BA0), size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'BARN & CAGES',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF787774),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Manage your layout',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9B9A97),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isBarnEditMode ? const Color(0xFF7B6BA0) : Colors.white,
                                      border: Border.all(
                                        color: _isBarnEditMode ? const Color(0xFF7B6BA0) : const Color(0xFFE9E9E7),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isBarnEditMode ? 'Done' : 'Manage',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _isBarnEditMode ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          _isBarnEditMode ? Icons.check : Icons.edit,
                                          size: 16,
                                          color: _isBarnEditMode ? Colors.white : Colors.black87,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Body
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (!_isBarnEditMode) ...[
                              _buildBarnTreeItem(
                                icon: Icons.grid_view,
                                label: 'All Locations',
                                count: _getTotalLitters(),
                                isActive: _locationFilter == null,
                                onTap: () {
                                  setState(() => _locationFilter = null);
                                  Navigator.pop(context);
                                },
                              ),
                              _buildBarnTreeItem(
                                icon: Icons.warning_amber,
                                label: 'Unassigned',
                                count: _getUnassignedLitterCount(),
                                isActive: _locationFilter == 'Unassigned',
                                onTap: () {
                                  setState(() => _locationFilter = 'Unassigned');
                                  Navigator.pop(context);
                                },
                                isWarning: true,
                              ),
                              Container(
                                height: 1,
                                color: const Color(0xFFE9E9E7),
                                margin: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ],
                            ..._barns.map((barn) => _buildLitterBarnSection(
                                  barn,
                                  setModalState,
                                  context,
                                )),
                          ],
                        ),
                      ),
                      // Add Barn button in edit mode
                      if (_isBarnEditMode)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE9E9E7))),
                          ),
                          child: ElevatedButton(
                            onPressed: () => _addBarn(setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEDE9FE),
                              foregroundColor: const Color(0xFF7B6BA0),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Add New Barn / Building',
                                  style: TextStyle(fontWeight: FontWeight.w600),
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
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEDE9FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: const Color(0xFF7B6BA0)) : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isWarning ? const Color(0xFFD97706) : (isActive ? const Color(0xFF7B6BA0) : const Color(0xFF787774)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isWarning ? const Color(0xFFD97706) : (isActive ? const Color(0xFF7B6BA0) : Colors.black87),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFFF7F7F5),
                border: Border.all(
                  color: isActive ? const Color(0xFF7B6BA0) : const Color(0xFFE9E9E7),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF7B6BA0) : const Color(0xFF787774),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLitterBarnSection(Barn barn, StateSetter setModalState, BuildContext dialogContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(top: 16, bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  barn.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF37352F),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_isBarnEditMode && _countLittersInBarn(barn) == 0)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF9B9A97)),
                  onPressed: () => _deleteBarn(barn, setModalState),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        ...barn.rows.map((row) {
          return Container(
            margin: const EdgeInsets.only(left: 10, bottom: 6),
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFE9E9E7), width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isBarnEditMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_countLittersInLocation(row.name) == 0)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF9B9A97)),
                            onPressed: () => _deleteRow(barn, row, setModalState),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  )
                else
                  _buildBarnTreeItem(
                    icon: Icons.view_list,
                    label: row.name,
                    count: _countLittersInLocation(row.name),
                    isActive: _locationFilter == row.name,
                    onTap: () {
                      setState(() => _locationFilter = row.name);
                      Navigator.pop(dialogContext);
                    },
                  ),
                if (_isBarnEditMode)
                  ...row.cages.map((cage) {
                    final cageCount = _countLittersInLocation(row.name, cage);
                    return Container(
                      margin: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                      padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Color(0xFFE9E9E7), width: 2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cage,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
                          ),
                          if (cageCount == 0)
                            IconButton(
                              icon: const Icon(Icons.close, size: 14, color: Color(0xFF9B9A97)),
                              onPressed: () => _deleteCage(barn, row, cage, setModalState),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            const Text(
                              'Occupied',
                              style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97)),
                            ),
                        ],
                      ),
                    );
                  }),
                if (_isBarnEditMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      onTap: () => _addCage(barn, row, setModalState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF7B6BA0)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Color(0xFF7B6BA0)),
                            SizedBox(width: 4),
                            Text(
                              'Add Cage',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7B6BA0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (_isBarnEditMode)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: GestureDetector(
              onTap: () => _addRow(barn, setModalState),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF7B6BA0)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF7B6BA0)),
                    SizedBox(width: 4),
                    Text(
                      'Add Row',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B6BA0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==================== BARN MANAGEMENT ACTIONS ====================

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final barnId = 'barn_${DateTime.now().millisecondsSinceEpoch}';
      final newBarn = Barn(id: barnId, name: controller.text, rows: []);
      await _db.insertBarn(newBarn.toMap());
      await _refreshLitters();
      setModalState(() {});
    }
  }

  void _addRow(Barn barn, StateSetter setModalState) async {
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setModalState(() {
        barn.rows.add(BarnRow(name: controller.text, cages: []));
      });
      await _db.updateBarn(barn.toMap());
      await _refreshLitters();
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setModalState(() {
        row.cages.add(controller.text);
      });
      await _db.updateBarn(barn.toMap());
      await _refreshLitters();
    }
  }

  void _deleteBarn(Barn barn, StateSetter setModalState) async {
    if (_countLittersInBarn(barn) > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete barn with active litters')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
      await _refreshLitters();
      setModalState(() {});
    }
  }

  void _deleteRow(Barn barn, BarnRow row, StateSetter setModalState) async {
    if (_countLittersInLocation(row.name) > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete row with active litters')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
      await _refreshLitters();
    }
  }

  void _deleteCage(Barn barn, BarnRow row, String cage, StateSetter setModalState) async {
    if (_countLittersInLocation(row.name, cage) > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cage has active litters')),
        );
      }
      return;
    }

    setModalState(() {
      row.cages.remove(cage);
    });
    await _db.updateBarn(barn.toMap());
    await _refreshLitters();
  }

  Future<void> _showFilterModal() async {
    await showDialog(
      context: context,
      builder: (
        context,
      ) =>
          StatefulBuilder(
        builder: (
          context,
          setModalState,
        ) {
          return Center(
            child: Container(
              width: MediaQuery.of(
                    context,
                  ).size.width *
                  0.9,
              margin: EdgeInsets.symmetric(
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.all(
                      16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter List',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                          ),
                          onPressed: () => Navigator.pop(
                            context,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Age',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(
                              0xFF787774,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip(
                              'Any',
                              'age',
                              'all',
                              setModalState,
                            ),
                            _buildFilterChip(
                              'Under 4 Wks',
                              'age',
                              'young',
                              setModalState,
                            ),
                            _buildFilterChip(
                              '4-8 Wks',
                              'age',
                              'mid',
                              setModalState,
                            ),
                            _buildFilterChip(
                              '8+ Wks',
                              'age',
                              'old',
                              setModalState,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Text(
                          'Weight',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(
                              0xFF787774,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip(
                              'Any',
                              'weight',
                              'all',
                              setModalState,
                            ),
                            _buildFilterChip(
                              'Under 2 ${FormatUtils.weightUnit}',
                              'weight',
                              'light',
                              setModalState,
                            ),
                            _buildFilterChip(
                              '2 ${FormatUtils.weightUnit} +',
                              'weight',
                              'heavy',
                              setModalState,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                              );
                              setState(
                                () {},
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(
                                0xFF7B6BA0,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                            child: Text(
                              'Apply Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String category,
    String value,
    StateSetter setModalState,
  ) {
    final isSelected = _filters[category] == value;

    return GestureDetector(
      onTap: () {
        setModalState(
          () {
            _filters[category] = value;
          },
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(
                  0xFFEDE9FE,
                )
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Color(
                    0xFF7B6BA0,
                  )
                : Color(
                    0xFFE9E9E7,
                  ),
          ),
          borderRadius: BorderRadius.circular(
            8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected
                ? Color(
                    0xFF7B6BA0,
                  )
                : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddLitterDialog() async {
    _searchFocusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (ctx) => AddLitterSheet(
        barns: _barns,
        onComplete: () async {
          await _refreshLitters();
        },
      ),
    );
    _searchFocusNode.canRequestFocus = true;
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Litter added successfully'),
          backgroundColor: Color(0xFF7B6BA0),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class AddLitterSheet extends StatefulWidget {
  final VoidCallback onComplete;
  final List<Barn> barns;

  const AddLitterSheet({Key? key, required this.onComplete, required this.barns}) : super(key: key);

  @override
  State<AddLitterSheet> createState() => _AddLitterSheetState();
}

class _AddLitterSheetState extends State<AddLitterSheet> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  List<Rabbit> _does = [];
  List<Rabbit> _bucks = [];

  String? _selectedDoeId;
  String? _selectedBuckId;
  DateTime _breedDate = DateTime.now().subtract(const Duration(days: 31));
  DateTime _dob = DateTime.now();

  final TextEditingController _litterIdController = TextEditingController();
  final TextEditingController _totalKitsController = TextEditingController();
  final TextEditingController _aliveKitsController = TextEditingController();
  final TextEditingController _doesProducedController = TextEditingController();
  final TextEditingController _bucksProducedController = TextEditingController();
  final TextEditingController _peanutsProducedController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedLocation;
  String? _selectedCage;
  List<String> _availableCages = [];

  bool _isMissedLitter = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRabbits();
    _loadNextLitterId();
  }

  Future<void> _loadRabbits() async {
    setState(() => _isLoading = true);

    try {
      final allRabbits = await _db.getAllRabbits();

      if (mounted) {
        setState(() {
          _does = allRabbits.where((r) => r.type == RabbitType.doe && r.status != RabbitStatus.archived).toList();
          _bucks = allRabbits.where((r) => r.type == RabbitType.buck && r.status != RabbitStatus.archived).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading rabbits: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextLitterId() async {
    try {
      final nextId = await _db.getNextPastLitterId();
      if (mounted) {
        setState(() {
          _litterIdController.text = nextId;
        });
      }
    } catch (e) {
      print('Error loading next litter ID: $e');
      if (mounted) {
        _litterIdController.text = 'P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      }
    }
  }

  void _onDoeSelected(String? doeId) {
    setState(() {
      _selectedDoeId = doeId;
      if (doeId != null) {
        final doeMatches = _does.where((d) => d.id == doeId).toList();
        if (doeMatches.isNotEmpty) {
          final doe = doeMatches.first;
          // Auto pre-fill buck if available
          if (doe.lastBreedBuckId != null && doe.lastBreedBuckId!.isNotEmpty) {
            final buckExists = _bucks.any((b) => b.id == doe.lastBreedBuckId);
            if (buckExists) {
              _selectedBuckId = doe.lastBreedBuckId;
            }
          }
          // Auto pre-fill breed date if available
          if (doe.lastBreedDate != null) {
            _breedDate = doe.lastBreedDate!;
          }
          // Auto pre-fill location & cage if available
          if (doe.location != null && doe.location!.isNotEmpty) {
            _selectedLocation = doe.location;
            _availableCages = [];
            for (var barn in widget.barns) {
              for (var row in barn.rows) {
                if (row.name == doe.location) {
                  _availableCages = row.cages;
                  break;
                }
              }
            }
            if (doe.cage != null && doe.cage!.isNotEmpty) {
              _selectedCage = doe.cage;
            }
          }
        }
      }
    });
  }

  Widget _buildRabbitNameWidget(Rabbit rabbit, {double fontSize = 15}) {
    final isDoe = rabbit.type == RabbitType.doe;
    final nameColor = isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3);
    final prefix = (rabbit.breederPrefix ?? '').trim();
    final name = rabbit.name.trim();
    final ear = (rabbit.earNumber?.trim().isNotEmpty == true
            ? rabbit.earNumber!.trim()
            : (rabbit.id.length >= 6 ? rabbit.id.substring(0, 6) : rabbit.id).trim())
        .toUpperCase();

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: '$prefix ',
              style: const TextStyle(
                color: Color(0xFF787774),
                fontWeight: FontWeight.w700,
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              color: nameColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ear.isNotEmpty && !name.toUpperCase().endsWith(ear))
            TextSpan(
              text: ' $ear',
              style: TextStyle(
                color: nameColor,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      style: TextStyle(fontSize: fontSize),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400, fontSize: 14),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF4F4F56), size: 18) : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                FormatUtils.formatDate(value),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F4F56), size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBreedDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _breedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _breedDate = picked;
      });
    }
  }

  Future<void> _selectDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: _breedDate,
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header matching Log Breeding & Log Birth Purple Theme
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE6BEFE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3E6D).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Past Litter',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A3E6D),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B6BA0)),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Litter ID
                      _buildOutlinedField(
                        label: 'Litter ID',
                        controller: _litterIdController,
                        prefixIcon: Icons.tag,
                        validator: (value) => value?.isEmpty ?? true ? 'Litter ID is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // 2. Doe Selection
                      _does.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFE58F)),
                              ),
                              child: const Text(
                                'No does available. Please add a doe first.',
                                style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedDoeId,
                              selectedItemBuilder: (context) {
                                return _does.map((doe) => _buildRabbitNameWidget(doe, fontSize: 14.5)).toList();
                              },
                              items: _does.map((doe) {
                                return DropdownMenuItem<String>(
                                  value: doe.id,
                                  child: _buildRabbitNameWidget(doe, fontSize: 14.5),
                                );
                              }).toList(),
                              onChanged: _onDoeSelected,
                              validator: (value) => value == null ? 'Please select a doe' : null,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
                              decoration: InputDecoration(
                                labelText: 'Select Doe (Mother)',
                                labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                prefixIcon: const Icon(Icons.female_rounded, color: Color(0xFFE04F9F), size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                      const SizedBox(height: 14),

                      // 3. Buck Selection
                      _bucks.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFE58F)),
                              ),
                              child: const Text(
                                'No bucks available. Please add a buck first.',
                                style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedBuckId,
                              selectedItemBuilder: (context) {
                                return _bucks.map((buck) => _buildRabbitNameWidget(buck, fontSize: 14.5)).toList();
                              },
                              items: _bucks.map((buck) {
                                return DropdownMenuItem<String>(
                                  value: buck.id,
                                  child: _buildRabbitNameWidget(buck, fontSize: 14.5),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedBuckId = value),
                              validator: (value) => value == null ? 'Please select a buck' : null,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
                              decoration: InputDecoration(
                                labelText: 'Select Buck (Father)',
                                labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                prefixIcon: const Icon(Icons.male_rounded, color: Color(0xFF2196F3), size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                      const SizedBox(height: 14),

                      // 4. Bred Date & Date of Birth side by side
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePickerField(
                              label: 'Bred Date',
                              value: _breedDate,
                              onTap: () => _selectBreedDate(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDatePickerField(
                              label: 'Date of Birth',
                              value: _dob,
                              onTap: () => _selectDob(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. If not Missed Litter, show Kit Counts
                      if (!_isMissedLitter) ...[
                        // Row: Kits Born & Kits Alive
                        Row(
                          children: [
                            Expanded(
                              child: _buildOutlinedField(
                                label: 'Kits Born',
                                controller: _totalKitsController,
                                keyboardType: TextInputType.number,
                                hint: '0',
                                onChanged: (val) {
                                  if (_aliveKitsController.text.isEmpty || int.tryParse(_aliveKitsController.text) == null) {
                                    _aliveKitsController.text = val;
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildOutlinedField(
                                label: 'Kits Alive',
                                controller: _aliveKitsController,
                                keyboardType: TextInputType.number,
                                hint: '0',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row: Does & Bucks
                        Row(
                          children: [
                            Expanded(
                              child: _buildOutlinedField(
                                label: 'Does',
                                controller: _doesProducedController,
                                keyboardType: TextInputType.number,
                                hint: '0',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildOutlinedField(
                                label: 'Bucks',
                                controller: _bucksProducedController,
                                keyboardType: TextInputType.number,
                                hint: '0',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Peanuts
                        _buildOutlinedField(
                          label: 'Peanuts',
                          controller: _peanutsProducedController,
                          keyboardType: TextInputType.number,
                          hint: '0',
                        ),
                        const SizedBox(height: 14),

                        // Notes Box
                        _buildOutlinedField(
                          label: 'Notes',
                          controller: _notesController,
                          hint: 'Enter notes about this litter...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 6. Missed Litter Tab / Toggle
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _isMissedLitter = !_isMissedLitter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: _isMissedLitter ? const Color(0xFFFFF3CD) : kLilacWash,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isMissedLitter ? const Color(0xFFFFE58F) : kLilacLight,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Missed Litter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: _isMissedLitter ? const Color(0xFF856404) : kLilacText,
                                    ),
                                  ),
                                  if (_isMissedLitter)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Doe did not conceive. Status will reset to Open.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF856404), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                ],
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _isMissedLitter ? const Color(0xFF7B6BA0) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isMissedLitter ? const Color(0xFF7B6BA0) : const Color(0xFFC7C7CC),
                                    width: 1.5,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedAlign(
                                      duration: const Duration(milliseconds: 200),
                                      alignment: _isMissedLitter ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_isMissedLitter) ...[
                        _buildOutlinedField(
                          label: 'Notes',
                          controller: _notesController,
                          hint: 'Notes on missed breeding...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 7. Location and Cage in the last (side by side)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedLocation,
                              decoration: InputDecoration(
                                labelText: 'Location',
                                labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: widget.barns
                                  .expand((barn) => barn.rows.map((row) {
                                        return DropdownMenuItem<String>(
                                          value: row.name,
                                          child: Text(row.name, style: const TextStyle(fontSize: 14)),
                                        );
                                      }))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedLocation = value;
                                  _selectedCage = null;
                                  _availableCages = [];
                                  for (var barn in widget.barns) {
                                    for (var row in barn.rows) {
                                      if (row.name == value) {
                                        _availableCages = row.cages;
                                        break;
                                      }
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _availableCages.isNotEmpty
                                ? DropdownButtonFormField<String>(
                                    value: _selectedCage,
                                    decoration: InputDecoration(
                                      labelText: 'Cage',
                                      labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                      floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                      floatingLabelBehavior: FloatingLabelBehavior.always,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: _availableCages.map((cage) {
                                      return DropdownMenuItem<String>(
                                        value: cage,
                                        child: Text(cage, style: const TextStyle(fontSize: 14)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _selectedCage = value);
                                    },
                                  )
                                : TextFormField(
                                    initialValue: _selectedCage,
                                    decoration: InputDecoration(
                                      labelText: 'Cage',
                                      labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                      floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                                      floatingLabelBehavior: FloatingLabelBehavior.always,
                                      hintText: 'e.g., A-1',
                                      hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400, fontSize: 14),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onChanged: (value) => _selectedCage = value,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

          // Footer Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE9E9E7))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveLitter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6BEFE),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(kLilacText),
                        ),
                      )
                    : Text(
                        _isMissedLitter ? 'Log Missed Litter' : 'Add Past Litter',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kLilacText,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLitter() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDoeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doe'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedBuckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a buck'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final doe = _does.firstWhere((d) => d.id == _selectedDoeId);
      final buck = _bucks.firstWhere((b) => b.id == _selectedBuckId);

      final totalKits = _isMissedLitter ? 0 : (int.tryParse(_totalKitsController.text) ?? 0);
      final aliveKits = _isMissedLitter ? 0 : (int.tryParse(_aliveKitsController.text) ?? totalKits);
      final deadKits = _isMissedLitter ? 0 : (totalKits - aliveKits).clamp(0, totalKits);
      final doesCount = _isMissedLitter ? 0 : (int.tryParse(_doesProducedController.text) ?? 0);
      final bucksCount = _isMissedLitter ? 0 : (int.tryParse(_bucksProducedController.text) ?? 0);
      final peanutsCount = _isMissedLitter ? 0 : (int.tryParse(_peanutsProducedController.text) ?? 0);
      final notesText = _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null;

      final settings = SettingsService.instance;
      final weanDays = settings.weanAge * 7;
      final ageDays = DateTime.now().difference(_dob).inDays;
      final bool isWeaned = ageDays >= weanDays;
      final String kitStatus = isWeaned ? 'Weaned' : 'Nursing';
      final String litterStatus = _isMissedLitter ? 'archived' : (isWeaned ? 'Weaned' : 'Nursing');

      // Create kits with collected sex distribution if provided
      final kits = List.generate(aliveKits, (index) {
        String sex = 'U';
        if (index < doesCount) {
          sex = 'F';
        } else if (index < doesCount + bucksCount) {
          sex = 'M';
        }
        return Kit(
          id: '${index + 1}',
          sex: sex,
          color: 'Unknown',
          weight: 0.0,
          status: kitStatus,
        );
      });

      final newLitter = Litter(
        id: _litterIdController.text.trim().isNotEmpty
            ? _litterIdController.text.trim()
            : await _db.getNextPastLitterId(),
        doeId: doe.id,
        doeName: doe.name,
        buckId: buck.id,
        buckName: buck.name,
        breedDate: _breedDate,
        dob: _dob,
        kindleDate: _dob,
        location: _selectedLocation ?? doe.location ?? '',
        cage: _selectedCage ?? doe.cage ?? '',
        breed: doe.breed,
        status: litterStatus,
        sire: buck.name,
        dam: doe.name,
        totalKits: totalKits,
        aliveKits: aliveKits,
        deadKits: deadKits,
        doesProduced: doesCount,
        bucksProduced: bucksCount,
        peanutsProduced: peanutsCount,
        notes: notesText,
        missedLitter: _isMissedLitter,
        kits: kits,
      );

      // Save to database
      await _db.updateLitter(newLitter);

      // Update doe status accordingly
      final db = await _db.database;
      if (_isMissedLitter || isWeaned || aliveKits == 0) {
        await db.update(
          'rabbits',
          {
            'status': RabbitStatus.open.toString(),
            'kindleDate': null,
            'currentLitterSize': 0,
            'weanDate': null,
            'dueDate': null,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [doe.id],
        );
      } else {
        final weanDate = _dob.add(Duration(days: weanDays));
        await db.update(
          'rabbits',
          {
            'status': RabbitStatus.nursing.toString(),
            'kindleDate': null,
            'currentLitterSize': aliveKits,
            'weanDate': weanDate.toIso8601String(),
            'dueDate': null,
            'lastBreedDate': _breedDate.toIso8601String(),
            'lastBreedBuckId': buck.id,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [doe.id],
        );

        // Create wean pipeline task if not yet past wean date
        if (weanDate.isAfter(DateTime.now())) {
          await _db.insertTask({
            'id': 'task_wean_${DateTime.now().millisecondsSinceEpoch}',
            'rabbitId': doe.id,
            'litterId': newLitter.id,
            'title': 'Wean Litter',
            'description': '$aliveKits kits ready for weaning',
            'taskType': 'wean',
            'dueDate': weanDate.toIso8601String(),
            'completed': 0,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }

      await _db.syncAllNursingDoes();

      // Sync cage into barn row
      if ((_selectedLocation ?? '').isNotEmpty && (_selectedCage ?? '').isNotEmpty) {
        await _db.syncCageToBarn(_selectedLocation!, _selectedCage!);
      }

      notifyDataChanged();
      Navigator.pop(context, true);
      widget.onComplete();
    } catch (e) {
      print('Error saving litter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFD44C47),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _litterIdController.dispose();
    _totalKitsController.dispose();
    _aliveKitsController.dispose();
    _doesProducedController.dispose();
    _bucksProducedController.dispose();
    _peanutsProducedController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class _StatusConfig {
  final Color bgColor;
  final Color textColor;
  _StatusConfig({required this.bgColor, required this.textColor});
}

class EditKitDetailsScreen extends StatefulWidget {
  final Litter litter;
  final Kit kit;
  final VoidCallback onSaved;

  const EditKitDetailsScreen({
    Key? key,
    required this.litter,
    required this.kit,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<EditKitDetailsScreen> createState() => _EditKitDetailsScreenState();
}

class _EditKitDetailsScreenState extends State<EditKitDetailsScreen> {
  late String _selectedSex;
  String? _localImagePath;
  late TextEditingController _colorController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedSex = widget.kit.sex;
    _localImagePath = widget.kit.imagePath;

    final String rawColor = widget.kit.color.trim();
    // 1. Color field shows Broken...REMOVE it. It should be blank.
    final String initialColor = (rawColor.toLowerCase() == 'broken' ||
            rawColor.toLowerCase() == 'unknown' ||
            rawColor.toLowerCase() == 'brown tort' ||
            rawColor.isEmpty)
        ? ''
        : rawColor;

    _colorController = TextEditingController(text: initialColor);
    _weightController = TextEditingController(
      text: widget.kit.weight > 0 ? widget.kit.weight.toString() : '',
    );
    _notesController = TextEditingController(text: widget.kit.details ?? '');
  }

  @override
  void dispose() {
    _colorController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      setState(() => _localImagePath = image.path);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2E2D32)),
            ),
            const SizedBox(height: 12),
            _buildPhotoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            _buildPhotoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            if (_localImagePath != null && _localImagePath!.isNotEmpty)
              _buildPhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _localImagePath = null);
                },
                isDestructive: true,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFD44C47) : const Color(0xFF787774),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDestructive ? const Color(0xFFD44C47) : const Color(0xFF2E2D32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 17, color: Color(0xFF4F4F56), fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(fontSize: 17, color: Color(0xFF4F4F56), fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
      ),
    );
  }

  Future<void> _saveKit() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = DatabaseService();
      final litters = await db.getLitters();
      final litterIndex = litters.indexWhere((l) => l.id == widget.litter.id);
      if (litterIndex != -1) {
        final updatedKits = litters[litterIndex].kits.map<Kit>((k) {
          if (k.id == widget.kit.id) {
            return k.copyWith(
              sex: _selectedSex,
              color: _colorController.text.trim(),
              weight: double.tryParse(_weightController.text) ?? k.weight,
              details: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
              imagePath: _localImagePath,
            );
          }
          return k;
        }).toList();

        final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
        await db.updateLitter(updatedLitter);
        widget.onSaved();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kit details updated'),
            backgroundColor: Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSexOption(String value, String label, IconData? icon, Color activeColor) {
    final bool isSelected = _selectedSex == value;
    return InkWell(
      onTap: () => setState(() => _selectedSex = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFC7C7CC)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF4F4F56),
                size: 18,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF4F4F56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color saveColor = _selectedSex == 'F'
        ? const Color(0xFFEC4899)
        : (_selectedSex == 'M' ? const Color(0xFF2E7BB5) : const Color(0xFF7B6BA0));

    return Scaffold(
      backgroundColor: const Color(0xFFF1ECF7), // Purple page background matching Add New Rabbit
      appBar: AppBar(
        backgroundColor: const Color(0xFFE6BEFE), // Top bar purple matching Add New Rabbit
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF4F4F56)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Kit Details',
          style: TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveKit,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _isSaving ? Colors.grey : saveColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Gender Selection (Buck / Doe / Unsexed) - Unsexed without logo to prevent overflow
            Row(
              children: [
                Expanded(child: _buildSexOption('M', 'Buck', Icons.male, const Color(0xFF2E7BB5))),
                const SizedBox(width: 8),
                Expanded(child: _buildSexOption('F', 'Doe', Icons.female, const Color(0xFFEC4899))),
                const SizedBox(width: 8),
                Expanded(child: _buildSexOption('U', 'Unsexed', null, const Color(0xFF7B6BA0))),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Profile picture circular section with camera badge like Add New Rabbit page
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF7F7F5),
                            border: Border.all(
                              color: saveColor,
                              width: 3,
                            ),
                            image: _localImagePath != null && _localImagePath!.isNotEmpty
                                ? DecorationImage(
                                    image: FileImage(File(_localImagePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _localImagePath == null || _localImagePath!.isEmpty
                              ? Icon(
                                  _selectedSex == 'F'
                                      ? Icons.female
                                      : (_selectedSex == 'M' ? Icons.male : Icons.pets),
                                  size: 50,
                                  color: saveColor,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: saveColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_localImagePath != null && _localImagePath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _showImagePickerOptions,
                      child: Text(
                        'Change Photo',
                        style: TextStyle(
                          color: saveColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Color Autocomplete (Box with text in top left corner)
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final colors = SettingsService.instance.colors;
                if (textEditingValue.text.isEmpty) return colors;
                return colors.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              initialValue: TextEditingValue(text: _colorController.text),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                controller.addListener(() {
                  _colorController.text = controller.text;
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 17),
                  decoration: _buildInputDecoration('Color'),
                );
              },
              onSelected: (String color) {
                _colorController.text = color;
              },
            ),
            const SizedBox(height: 12),

            // 4. Weight field (Box with text in top left corner)
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 17),
              decoration: _buildInputDecoration(FormatUtils.weightLabel()).copyWith(
                suffixText: FormatUtils.weightUnit,
                hintText: '0.0',
              ),
            ),
            const SizedBox(height: 12),

            // 5. Notes field (Box with text in top left corner)
            TextField(
              controller: _notesController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 17),
              decoration: _buildInputDecoration('Notes').copyWith(
                hintText: 'Add any notes...',
                hintStyle: const TextStyle(fontSize: 15, color: Color(0xFFCCCBC8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


