import 'dart:io';
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

import '../widgets/modals/log_birth_modal.dart';
import '../constants/app_colors.dart';
import 'dart:developer' as developer;

class LittersScreen extends StatefulWidget {
  final String? initialLitterId;
  const LittersScreen({Key? key, this.initialLitterId}) : super(key: key);

  @override
  _LittersScreenState createState() => _LittersScreenState();
}

class _LittersScreenState extends State<LittersScreen> with SingleTickerProviderStateMixin {
  late TabController _viewTabController;

  final DatabaseService _db = DatabaseService(); // œ… ADD THIS

  String _currentStage = 'All';
  String _searchQuery = '';
  String? _locationFilter;
  String _grouping = 'none';
  Map<String, String> _filters = {
    'age': 'all',
    'weight': 'all',
  };
  Map<String, bool> _expandedLitters = {};

  List<Litter> litters = [];
  List<Barn> _barns = [];
  bool _isBarnEditMode = false;
  bool _isLoading = true; // œ… ADD THIS

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
    if (widget.initialLitterId != null) {
      _expandedLitters[widget.initialLitterId!] = true;
    }
    print(' initState called, loading litters...');
    _loadLitters();
  }

  Future<void> _loadLitters() async {
    setState(() => _isLoading = true);

    try {
      final existingLitters = await _db.getLitters();
      final barnsData = await _db.getAllBarns();
      setState(() {
        litters = existingLitters;
        _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
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

  // Ã¢Å“€¦ ADD THIS METHOD

  Future<void> _refreshLitters() async {
    try {
      final loadedLitters = await _db.getLitters();
      final barnsData = await _db.getAllBarns();
      setState(() {
        litters = loadedLitters;
        _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
      });
      print('Refreshed: ${litters.length} litters');
    } catch (e) {
      print('Error refreshing litters: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildViewTabs(),
          _buildSearchAndGroup(),
          if (_locationFilter != null) _buildFilterBanner(),
          _buildStageChips(),
          Expanded(
            child: TabBarView(
              controller: _viewTabController,
              children: [
                _buildLittersList(),
                _buildKitsList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'litter_fab',
        onPressed: _showAddLitterDialog,
        backgroundColor: kLilacDeep,
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(
          PhosphorIcons.plus(PhosphorIconsStyle.bold),
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kLilacWash,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone), color: kLilacDeep),
        onPressed: _showBarnDrawer,
      ),
      title: const Text(
        'Nursery Manager',
        style: TextStyle(
          color: kLilacText,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(PhosphorIcons.faders(PhosphorIconsStyle.duotone), color: kLilacDeep),
              onPressed: _showFilterModal,
            ),
            if (_filters['age'] != 'all' || _filters['weight'] != 'all')
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: kPink,
                    shape: BoxShape.circle,
                    border: Border.all(color: kLilacWash, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kNeutral100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNeutral200),
      ),
      child: TabBar(
        controller: _viewTabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: kLilacDeep,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: kLilacDeep.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        labelColor: Colors.white,
        unselectedLabelColor: kNeutral600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.package(PhosphorIconsStyle.duotone), size: 16),
                const SizedBox(width: 8),
                const Text('By Litter'),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.rabbit(PhosphorIconsStyle.duotone), size: 16),
                const SizedBox(width: 8),
                const Text('By Kit'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndGroup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: kNeutral100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kNeutral200),
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search ID or Name...',
                hintStyle: const TextStyle(color: kNeutral400, fontSize: 16),
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone), color: kNeutral500, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: PhosphorIcons.rows(PhosphorIconsStyle.duotone),
                  label: _grouping == 'none' ? 'Group: None' : 'Grouping: ${_grouping.toUpperCase()}',
                  onTap: _showGroupingModal,
                  isActive: _grouping != 'none',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: PhosphorIcons.funnel(PhosphorIconsStyle.duotone),
                  label: _filters['age'] == 'all' ? 'All Litters' : 'Age: ${_filters['age']}',
                  onTap: _showFilterModal,
                  isActive: _filters['age'] != 'all' || _filters['weight'] != 'all',
                ),
              ),
            ],
          ),
        ],
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

  void _showGroupingModal() {
    showModalBottomSheet(
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

  Widget _buildStageChips() {
    final stages = [
      {'label': 'All', 'icon': null},
      {'label': 'Nursing', 'icon': PhosphorIcons.baby(PhosphorIconsStyle.fill)},
      {'label': 'Weaned', 'icon': PhosphorIcons.carrot(PhosphorIconsStyle.fill)},
      {'label': 'GrowOut', 'icon': PhosphorIcons.trendUp(PhosphorIconsStyle.fill)},
      {'label': 'Mature', 'icon': PhosphorIcons.star(PhosphorIconsStyle.fill)},
      {'label': 'Quarantine', 'icon': PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill)},
      {'label': 'Archive', 'icon': PhosphorIcons.archive(PhosphorIconsStyle.fill)},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stages.length,
        itemBuilder: (context, index) {
          final stage = stages[index];
          final isActive = _currentStage == stage['label'];

          return GestureDetector(
            onTap: () => setState(() => _currentStage = stage['label'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? kLilacDeep : Colors.white,
                border: Border.all(color: isActive ? kLilacDeep : kNeutral300),
                borderRadius: BorderRadius.circular(100),
                boxShadow: isActive
                    ? [BoxShadow(color: kLilacDeep.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stage['icon'] != null) ...[
                    Icon(stage['icon'] as IconData, size: 14, color: isActive ? Colors.white : kNeutral500),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    stage['label'] as String,
                    style: TextStyle(
                      color: isActive ? Colors.white : kNeutral700,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
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

  List<Litter> _getFilteredLitters() {
    return litters.where(
      (
        litter,
      ) {
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final searchText = '${litter.id} ${litter.sire} ${litter.dam} ${litter.breed}'.toLowerCase();
          if (!searchText.contains(
            query,
          )) return false;
        }

        // Location filter
        if (_locationFilter != null && litter.location != _locationFilter) return false;

        // Age filter
        if (_filters['age'] == 'young' && litter.ageDays >= 28) return false;
        if (_filters['age'] == 'mid' && (litter.ageDays < 28 || litter.ageDays > 56)) return false;
        if (_filters['age'] == 'old' && litter.ageDays <= 56) return false;

        // Filter kits by stage - use the same logic as kit view
        final validKits = litter.kits
            .where(
              (kit) => _kitMatchesStage(kit),
            )
            .toList();

        return validKits.isNotEmpty;
      },
    ).toList();
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

  Widget _buildKitsList() {
    final filtered = _getFilteredLitters();
    List<Map<String, dynamic>> allKits = [];

    for (var litter in filtered) {
      for (var kit in litter.kits) {
        if (_kitMatchesStage(kit)) {
          allKits.add({'litter': litter, 'kit': kit});
        }
      }
    }

    if (allKits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.rabbit(PhosphorIconsStyle.duotone), size: 64, color: kNeutral200),
            const SizedBox(height: 16),
            const Text(
              'No kits found',
              style: TextStyle(color: kNeutral500, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allKits.length,
      itemBuilder: (context, index) {
        final item = allKits[index];
        return _buildStandardKitCard(item['litter'] as Litter, item['kit'] as Kit);
      },
    );
  }

  Widget _buildLitterCard(Litter litter) {
    final isExpanded = _expandedLitters[litter.id] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLilacLight),
        boxShadow: [
          BoxShadow(color: kNeutral900.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${litter.dam} × ${litter.sire}',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kNeutral900, letterSpacing: -0.2),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(100), border: Border.all(color: kNeutral200)),
                                child: Text(litter.id, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kNeutral500)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(PhosphorIcons.dna(PhosphorIconsStyle.bold), size: 12, color: kLilac),
                              const SizedBox(width: 4),
                              Text(litter.breed, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral600)),
                              const SizedBox(width: 6),
                              Text('• ${litter.ageDays} Days', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.duotone), size: 12, color: kLilac),
                              const SizedBox(width: 4),
                              Text('Born ${FormatUtils.formatDate(litter.dob)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                              const SizedBox(width: 12),
                              Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 12, color: kLilac),
                              const SizedBox(width: 4),
                              Text(litter.location.isNotEmpty ? litter.location : 'No Location', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildIconButton(icon: PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold), onTap: () => _showLitterActions(litter)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kNeutral50,
              border: Border(top: BorderSide(color: kNeutral100)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(isExpanded ? 0 : 16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: _buildStatusBadges(litter)),
                    Row(
                      children: [
                        Text('${litter.totalKitsCount} live kits', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNeutral400)),
                        const SizedBox(width: 12),
                        _buildViewKitsButton(litter, isExpanded),
                      ],
                    ),
                  ],
                ),
                if (litter.weanDate != null) ...[
                  const SizedBox(height: 6),
                  Text('Wean date: ${FormatUtils.formatDate(litter.weanDate!)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500)),
                ],
              ],
            ),
          ),
          if (isExpanded)
            Container(
              decoration: const BoxDecoration(color: kNeutral50, border: Border(top: BorderSide(color: kNeutral200))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...litter.kits.where((kit) => _kitMatchesStage(kit)).map((kit) => _buildKitRow(litter, kit)).toList(),
                  const SizedBox(height: 12),
                  _buildLitterActionButtons(litter),
                  const SizedBox(height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewKitsButton(Litter litter, bool isExpanded) {
    return GestureDetector(
      onTap: () => setState(() => _expandedLitters[litter.id] = !isExpanded),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: kNeutral300)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isExpanded ? 'Hide kits' : 'View kits', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral600)),
            const SizedBox(width: 4),
            Icon(isExpanded ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold) : PhosphorIcons.caretDown(PhosphorIconsStyle.bold), size: 14, color: kNeutral600),
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
        _buildMetaItem(PhosphorIcons.calendar(PhosphorIconsStyle.bold), FormatUtils.formatDate(litter.dob)),
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
      case 'nursing': return _StatusConfig(bgColor: kLilacWash, textColor: kLilacDeep);
      case 'weaned': return _StatusConfig(bgColor: kBlueWash, textColor: kBlueDeep);
      case 'growout': return _StatusConfig(bgColor: kPinkWash, textColor: kPinkDeep);
      case 'mature': return _StatusConfig(bgColor: const Color(0xFFE0F2F1), textColor: const Color(0xFF00695C));
      case 'sold': return _StatusConfig(bgColor: kNeutral200, textColor: kNeutral600);
      case 'butchered': return _StatusConfig(bgColor: kPinkWash, textColor: kPinkDeep);
      case 'dead': return _StatusConfig(bgColor: kPinkWash, textColor: const Color(0xFFB71C1C));
      case 'quarantine': return _StatusConfig(bgColor: const Color(0xFFFFF3E0), textColor: const Color(0xFFEF6C00));
      default: return _StatusConfig(bgColor: kNeutral100, textColor: kNeutral500);
    }
  }

  Widget _buildKitRow(Litter litter, Kit kit) {
    bool isOutcome = ['Sold', 'Butchered', 'Dead', 'Cull'].contains(kit.status);

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
            // Index Pill (matches HTML kit-id-pill)
            Container(
              width: 38,
              height: 24,
              decoration: BoxDecoration(
                color: isOutcome ? kNeutral200 : kLilacWash,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isOutcome ? kNeutral300 : kLilacLight),
              ),
              child: Center(
                child: Text(
                  kit.id,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOutcome ? kNeutral600 : kLilacText,
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
                          color: isOutcome ? kNeutral600 : kNeutral900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        kit.sex == 'M'
                            ? PhosphorIcons.genderMale(PhosphorIconsStyle.bold)
                            : (kit.sex == 'F' ? PhosphorIcons.genderFemale(PhosphorIconsStyle.bold) : PhosphorIcons.genderIntersex(PhosphorIconsStyle.bold)),
                        size: 14,
                        color: kit.sex == 'M' ? kBlueDeep : (kit.sex == 'F' ? kPinkDeep : kLilacDeep),
                      ),
                    ],
                  ),
                  if (kit.weight > 0)
                    Text(
                      'Weight: ${kit.weight}g',
                      style: const TextStyle(fontSize: 11, color: kNeutral500, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOutcome)
              _buildOutcomeBadge(kit.status)
            else
              Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), size: 16, color: kNeutral300),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeBadge(String status) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: config.bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: config.textColor)),
    );
  }

  Widget _buildStandardKitCard(Litter litter, Kit kit) {
    final statusConfig = _getStatusConfig(kit.status);
    final kitIndex = (litter.kits.indexOf(kit) + 1).toString().padLeft(2, '0');
    final codeTag = '${litter.id}-$kitIndex';

    return GestureDetector(
      onTap: () => _openKitDetail(litter, kit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLilacLight),
          boxShadow: [
            BoxShadow(color: kNeutral900.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKitAvatarHighRes(kit),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${kit.color} Kit',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kNeutral900, letterSpacing: -0.2),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(100), border: Border.all(color: kNeutral200)),
                              child: Text(codeTag, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kNeutral500)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(PhosphorIcons.dna(PhosphorIconsStyle.bold), size: 10, color: kLilacDeep.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text('${litter.dam} × ${litter.sire}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: kNeutral300)),
                            const SizedBox(width: 6),
                            Text(kit.sex == 'M' ? 'Buck' : (kit.sex == 'F' ? 'Doe' : 'Unknown'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                            const SizedBox(width: 4),
                            Icon(
                              kit.sex == 'M' ? PhosphorIcons.genderMale(PhosphorIconsStyle.bold) : (kit.sex == 'F' ? PhosphorIcons.genderFemale(PhosphorIconsStyle.bold) : PhosphorIcons.genderIntersex(PhosphorIconsStyle.bold)),
                              size: 10,
                              color: kit.sex == 'M' ? kBlueDeep : (kit.sex == 'F' ? kPinkDeep : kLilacDeep),
                            ),
                          ],
                        ),
                        // Third Row
                        Row(
                          children: [
                            Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 10, color: kLilacDeep.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text(litter.location, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                            const SizedBox(width: 6),
                            Text('• ${litter.breed} • ${litter.cage}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildIconButton(icon: PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.bold), onTap: () => _showKitActions(litter, kit)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kNeutral50,
                border: Border(top: BorderSide(color: kNeutral100)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusConfig.bgColor, borderRadius: BorderRadius.circular(100)),
                    child: Text(kit.status.toUpperCase(), style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: statusConfig.textColor, letterSpacing: 0.2)),
                  ),
                  Text('${kit.weight} lbs', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNeutral500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitAvatarHighRes(Kit kit) {
    Color bg = kit.sex == 'M' ? kBlueWash : (kit.sex == 'F' ? kPinkWash : kLilacWash);
    Color iconColor = kit.sex == 'M' ? kBlueDeep : (kit.sex == 'F' ? kPinkDeep : kLilacDeep);
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Icon(PhosphorIcons.rabbit(PhosphorIconsStyle.duotone), size: 20, color: iconColor)),
    );
  }

  Widget _buildKitAvatarMini(Kit kit) {
    Color bg = kit.sex == 'M' ? kBlueWash : (kit.sex == 'F' ? kPinkWash : kLilacWash);
    Color iconColor = kit.sex == 'M' ? kBlueDeep : (kit.sex == 'F' ? kPinkDeep : kLilacDeep);
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Icon(PhosphorIcons.rabbit(PhosphorIconsStyle.bold), size: 18, color: iconColor)),
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
        width: 32, height: 32,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kNeutral300)),
        child: Icon(icon, size: 16, color: kNeutral600),
      ),
    );
  }

  bool _kitMatchesStage(Kit kit) {
    final isArchiveStatus = ['Sold', 'Butchered', 'Dead', 'Cull'].contains(kit.status);
    if (_currentStage == 'All') return true;
    if (_currentStage == 'Archive') return isArchiveStatus;
    if (_currentStage == 'Quarantine') return kit.status == 'Quarantine';
    if (isArchiveStatus) return false;
    return kit.status == _currentStage;
  }

  void _openKitDetail(Litter litter, Kit kit) => _showKitActions(litter, kit);

  void _showLitterActions(Litter litter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Litter ${litter.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNeutral900, letterSpacing: -0.5)),
                      Text(litter.status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildActionOption(icon: PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), label: 'Edit Birth Info', color: kLilacDeep, onTap: () async {
              Navigator.pop(context);
              final doe = await _db.getRabbit(litter.doeId);
              if (doe != null && mounted) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => LogBirthModal(doe: doe, existingLitter: litter, onComplete: () => _loadLitters()),
                );
              }
            }),
            _buildActionOption(icon: PhosphorIcons.scissors(PhosphorIconsStyle.bold), label: 'Wean Litter', color: kNeutral600, onTap: () {
              Navigator.pop(context);
              _showWeanLitterDialog(litter);
            }),
            _buildActionOption(icon: PhosphorIcons.firstAid(PhosphorIconsStyle.bold), label: 'Health Record', color: kNeutral600, onTap: () {
              Navigator.pop(context);
              _showHealthRecordDialog(litter);
            }),
            _buildActionOption(icon: PhosphorIcons.scales(PhosphorIconsStyle.bold), label: 'Bulk Weigh', color: kNeutral600, onTap: () {
              Navigator.pop(context);
              _showBulkWeighDialog(litter);
            }),
            _buildActionOption(icon: PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.bold), label: 'Move Cage', color: kNeutral600, onTap: () {
              Navigator.pop(context);
              _showMoveCageDialog(litter);
            }),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: kNeutral100)),
            _buildActionOption(icon: PhosphorIcons.trash(PhosphorIconsStyle.bold), label: 'Delete Litter', color: kPinkDeep, onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(litter);
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showKitActions(Litter litter, Kit kit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kit ${litter.id}-${kit.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNeutral900, letterSpacing: -0.5)),
                        Text(kit.status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNeutral500)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 20), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildActionOption(icon: PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), label: 'Edit Details', color: kLilacDeep, onTap: () {
                Navigator.pop(context);
                _showEditKitDetails(litter, kit);
              }),
              if (kit.status == 'GrowOut')
                _buildActionOption(icon: PhosphorIcons.sparkle(PhosphorIconsStyle.bold), label: 'Promote to Mature', color: const Color(0xFF2E7B32), onTap: () {
                  Navigator.pop(context);
                  _promoteKitToMature(litter, kit);
                }),
              _buildActionOption(icon: PhosphorIcons.currencyDollar(PhosphorIconsStyle.bold), label: 'Sell Kit', color: kNeutral600, onTap: () {
                Navigator.pop(context);
                _showSellKitDialog(litter, kit);
              }),
              _buildActionOption(icon: PhosphorIcons.firstAid(PhosphorIconsStyle.bold), label: 'Health Record', color: kNeutral600, onTap: () {
                Navigator.pop(context);
                _showKitHealthRecord(litter, kit);
              }),
              if (SettingsService.instance.meatProductionEnabled)
                _buildActionOption(icon: PhosphorIcons.knife(PhosphorIconsStyle.bold), label: 'Harvest / Butcher', color: kNeutral600, onTap: () {
                  Navigator.pop(context);
                  _showButcherKitDialog(litter, kit);
                }),
              _buildActionOption(icon: PhosphorIcons.warning(PhosphorIconsStyle.bold), label: 'Quarantine', color: kNeutral600, onTap: () {
                Navigator.pop(context);
                _quarantineKit(litter, kit);
              }),
              _buildActionOption(icon: PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.bold), label: 'Foster Kit', color: kNeutral600, onTap: () {
                Navigator.pop(context);
                _showFosterKitDialog(litter, kit);
              }),
              _buildActionOption(icon: PhosphorIcons.scales(PhosphorIconsStyle.bold), label: 'Log Weight', color: kNeutral600, onTap: () {
                Navigator.pop(context);
                _logKitWeight(litter, kit);
              }),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: kNeutral100)),
              _buildActionOption(icon: PhosphorIcons.skull(PhosphorIconsStyle.bold), label: 'Mark as Died', color: kPinkDeep, onTap: () {
                Navigator.pop(context);
                _markKitAsDied(litter, kit);
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _promoteKitToMature(Litter litter, Kit kit) async {
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
                                              content: Text('${newRabbit?.name ?? "Kit"} promoted to ${isBuck ? 'Buck' : 'Doe'}!'),
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
                                        'Kit ${litter.id}-${kit.id}',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF37352F)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '${isBuck ? 'Male (Buck)' : 'Female (Doe)'} Ã¢‚¬¢ ${kit.color} Ã¢‚¬¢ ${kit.weight} ${FormatUtils.weightUnit}',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                                      ),
                                      Text(
                                        'Sire: ${litter.buckName} Ã¢‚¬¢ Dam: ${litter.doeName}',
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
                                    dateOfBirth != null ? '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}' : 'Not set',
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

  void _showSellKitDialog(Litter litter, Kit kit) {
    final TextEditingController priceController = TextEditingController();
    final TextEditingController buyerController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                    'Sell Kit',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kit ${litter.id}-${kit.id}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${kit.sex == 'M' ? 'Buck' : 'Doe'} • ${kit.color} • ${kit.weight} ${FormatUtils.weightUnit}',
                            style: const TextStyle(
                              fontSize: 14,
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
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
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
                    const Text(
                      'BUYER NAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
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
                        );
                      }
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
                    // Ã¢Å“€¦ ADD async
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

                      await _refreshLitters();
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kit marked as sold'),
                          backgroundColor: kLilacDeep,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLilacDeep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Record Sale',
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
              // Ã¢Å“€¦ ADD async
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
            child: const Text('Quarantine'),
          ),
        ],
      ),
    );
  }

  void _showEditKitDetails(Litter litter, Kit kit, {int initialTab = 0}) {
    String selectedSex = kit.sex;
    final colorController = TextEditingController(text: kit.color);
    final notesController = TextEditingController(text: kit.details);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Kit Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF787774))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSexChip('M', 'Male', Icons.male, const Color(0xFF2E7BB5), selectedSex, (val) => setDialogState(() => selectedSex = val)),
                    const SizedBox(width: 8),
                    _buildSexChip('F', 'Female', Icons.female, kFemaleColor, selectedSex, (val) => setDialogState(() => selectedSex = val)),
                    const SizedBox(width: 8),
                    _buildSexChip('U', 'U', Icons.help_outline, const Color(0xFF787774), selectedSex, (val) => setDialogState(() => selectedSex = val)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF787774))),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final colors = SettingsService.instance.colors;
                    if (textEditingValue.text.isEmpty) return colors;
                    return colors.where(
                      (c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                    );
                  },
                  initialValue: TextEditingValue(text: colorController.text),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    controller.addListener(() {
                      colorController.text = controller.text;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'e.g., Black, Broken',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  onSelected: (String color) {
                    colorController.text = color;
                  },
                ),
                const SizedBox(height: 20),
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF787774))),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Additional details...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                if (litterIndex != -1) {
                  final updatedKits = litters[litterIndex].kits.map((k) {
                    if (k.id == kit.id) {
                      return k.copyWith(
                        sex: selectedSex,
                        color: colorController.text.trim().isNotEmpty ? colorController.text.trim() : k.color,
                        details: notesController.text.trim(),
                      );
                    }
                    return k;
                  }).toList();

                  final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                  await _db.updateLitter(updatedLitter);
                  await _refreshLitters();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kit details updated')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSexChip(String value, String label, IconData icon, Color color, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? color : const Color(0xFFE9E9E7)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? color : const Color(0xFF787774)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? color : const Color(0xFF787774))),
          ],
        ),
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
    final fosterLitters = litters.where((l) => l.id != litter.id && l.status != 'archived').toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Foster Kit'),
          content: fosterLitters.isEmpty 
            ? const Text('No other active litters found to foster with.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select a foster mother:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedLitterId,
                    items: fosterLitters.map((l) => DropdownMenuItem(
                      value: l.id,
                      child: Text('Doe ${l.doeId} (Litter ${l.id})'),
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedLitterId = val),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Note: This will mark the kit as fostered and increase its information about the surrogate.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                  ),
                ],
              ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            if (fosterLitters.isNotEmpty)
              TextButton(
                onPressed: selectedLitterId == null ? null : () async {
                  Navigator.pop(context);
                  final target = fosterLitters.firstWhere((l) => l.id == selectedLitterId);
                  
                  // Update original kit status
                  final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                  if (litterIndex != -1) {
                    final updatedKits = litters[litterIndex].kits.map((k) {
                    if (k.id == kit.id) {
                      return k.copyWith(
                        status: 'Fostered',
                        details: '${k.details ?? ""}\nFostered to Doe ${target.doeId} (Litter ${target.id}) on ${DateTime.now().toIso8601String().split('T')[0]}'.trim(),
                      );
                    }
                    return k;
                  }).toList();

                  final updatedLitter = litters[litterIndex].copyWith(
                    kits: updatedKits,
                    aliveKits: (litters[litterIndex].aliveKits ?? 0) - 1,
                  );
                  
                  await _db.updateLitter(updatedLitter);
                  
                  // For now we just mark as Fostered in source. 
                  // In a future update, we could automatically ADD it to the target litter.
                  
                  await _refreshLitters();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kit marked as fostered to Doe ${target.doeId}')));
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
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
                              '${litter.dam} Ãƒ€” ${litter.sire}',
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
                                              '${litter.id}-K-${kit.id}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${kit.sex == 'M' ? 'Male' : kit.sex == 'F' ? 'Female' : 'Unknown'} Ã¢‚¬¢ ${kit.color} Ã¢‚¬¢ ${kit.weight} ${FormatUtils.weightUnit}',
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
                      // Ã¢Å“€¦ ADD async
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
        content: Text('Ã°Å¸€“¨Ã¯¸ Printing cage card...'),
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
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                litters.removeWhere((l) => l.id == litter.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Litter deleted'),
                  backgroundColor: Color(0xFFD44C47),
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
                        'Kit ${litter.id}-${kit.id}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        kit.status,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
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
                        content: Text('Kit restored'),
                        backgroundColor: Color(0xFF7B6BA0),
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
                    // Ã¢Å’ DELETE OR COMMENT OUT THIS LINE:
                    // Navigator.pop(context);

                    // Ã¢Å“€¦ The _buildMenuItem wrapper already pops the context,
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
                    // Ã¢Å“€¦ ADD: Show loading indicator
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

                      // Ã¢Å“€¦ Close loading dialog
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
                      // Ã¢Å“€¦ Handle errors
                      print('Ã¢Å’ Error updating kit: $e');
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

  void _showFilterModal() {
    showDialog(
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

  void _showAddLitterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddLitterSheet(
        barns: _barns,
        onComplete: () async {
          await _refreshLitters();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('œ… Litter added successfully'),
                backgroundColor: Color(0xFF7B6BA0),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _viewTabController.dispose();
    super.dispose();
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
  DateTime? _kindleDate;
  DateTime _dob = DateTime.now();

  final TextEditingController _litterIdController = TextEditingController();
  String? _selectedLocation;
  String? _selectedCage;
  List<String> _availableCages = [];
  final TextEditingController _totalKitsController = TextEditingController();
  final TextEditingController _aliveKitsController = TextEditingController();
  final TextEditingController _deadKitsController = TextEditingController(text: '0');

  bool _isLoading = true;
  bool _isSaving = false;

  // Kit details: list of {sex, color} for each alive kit
  List<Map<String, String>> _kitDetails = [];

  // Available options for kit sex and color
  final List<String> _sexOptions = [
    'U',
    'M',
    'F'
  ];
  List<String> get _colorOptions {
    final colors = SettingsService.instance.colors;
    final list = <String>[
      'Unknown'
    ];
    for (final c in colors) {
      if (c != 'Unknown' && c != 'Other') list.add(c);
    }
    if (!list.contains('Other')) list.add('Other');
    return list;
  }

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

      setState(() {
        _does = allRabbits.where((r) => r.type == RabbitType.doe && r.status != RabbitStatus.archived).toList();
        _bucks = allRabbits.where((r) => r.type == RabbitType.buck && r.status != RabbitStatus.archived).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Ã¢Å’ Error loading rabbits: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextLitterId() async {
    try {
      final nextId = await _db.getNextLitterId();
      if (mounted) {
        setState(() {
          _litterIdController.text = nextId;
        });
      }
    } catch (e) {
      print('Ã¢Å’ Error loading next litter ID: $e');
      // Fallback to timestamp-based ID
      _litterIdController.text = 'L-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  void _updateKitDetailsList() {
    final aliveKits = int.tryParse(_aliveKitsController.text) ?? 0;

    if (aliveKits > _kitDetails.length) {
      // Add new kit entries
      for (int i = _kitDetails.length; i < aliveKits; i++) {
        _kitDetails.add({
          'sex': 'U',
          'color': 'Unknown'
        });
      }
    } else if (aliveKits < _kitDetails.length) {
      // Remove extra kit entries
      _kitDetails = _kitDetails.sublist(0, aliveKits);
    }
    setState(() {});
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Litter',
                  style: TextStyle(
                    fontSize: 20,
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
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Litter ID
                      _buildSectionLabel('LITTER ID'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _litterIdController,
                        decoration: InputDecoration(
                          hintText: 'e.g., L-001',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Litter ID is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Doe Selection
                      _buildSectionLabel('DOE (MOTHER)'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedDoeId,
                        decoration: InputDecoration(
                          hintText: 'Select doe',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: _does.map((doe) {
                          return DropdownMenuItem(
                            value: doe.id,
                            child: Text('${doe.name} (${doe.id})'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedDoeId = value),
                        validator: (value) => value == null ? 'Please select a doe' : null,
                      ),
                      const SizedBox(height: 20),

                      // Buck Selection
                      _buildSectionLabel('BUCK (FATHER)'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedBuckId,
                        decoration: InputDecoration(
                          hintText: 'Select buck',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: _bucks.map((buck) {
                          return DropdownMenuItem(
                            value: buck.id,
                            child: Text('${buck.name} (${buck.id})'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedBuckId = value),
                        validator: (value) => value == null ? 'Please select a buck' : null,
                      ),
                      const SizedBox(height: 20),

                      // Breed Date
                      _buildSectionLabel('BREED DATE'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _breedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _breedDate = picked;
                              _kindleDate = picked.add(const Duration(days: 31));
                              _dob = _kindleDate!;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE9E9E7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(_breedDate),
                                style: const TextStyle(fontSize: 15),
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: Color(0xFF787774)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Kindle Date (Optional)
                      _buildSectionLabel('KINDLE DATE (OPTIONAL)'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _kindleDate ?? _breedDate.add(const Duration(days: 31)),
                            firstDate: _breedDate,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              _kindleDate = picked;
                              _dob = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE9E9E7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _kindleDate != null ? _formatDate(_kindleDate!) : 'Not set',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _kindleDate != null ? Colors.black87 : const Color(0xFF9B9A97),
                                ),
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: Color(0xFF787774)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date of Birth
                      _buildSectionLabel('DATE OF BIRTH'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dob,
                            firstDate: _breedDate,
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _dob = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE9E9E7)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(_dob),
                                style: const TextStyle(fontSize: 15),
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: Color(0xFF787774)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Location
                      _buildSectionLabel('LOCATION'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: _buildInputDecoration('Select location'),
                        validator: (value) => value == null || value.isEmpty ? 'Location is required' : null,
                        items: widget.barns
                            .expand((barn) => barn.rows.map((row) {
                                  return DropdownMenuItem<String>(
                                    value: row.name,
                                    child: Text('${row.name}  (${barn.name})'),
                                  );
                                }))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLocation = value;
                            _selectedCage = null;
                            _availableCages = [];
                            // Find cages for this row
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
                      const SizedBox(height: 20),

                      // Cage
                      _buildSectionLabel('CAGE'),
                      const SizedBox(height: 8),
                      _availableCages.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: _selectedCage,
                              decoration: _buildInputDecoration('Select cage'),
                              items: _availableCages.map((cage) {
                                return DropdownMenuItem<String>(
                                  value: cage,
                                  child: Text(cage),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedCage = value);
                              },
                            )
                          : TextFormField(
                              initialValue: _selectedCage,
                              decoration: _buildInputDecoration('Enter cage number'),
                              onChanged: (value) => _selectedCage = value,
                            ),
                      const SizedBox(height: 20),

                      // Total Kits Born
                      _buildSectionLabel('TOTAL KITS BORN'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _totalKitsController,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('0'),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          final num = int.tryParse(value!);
                          if (num == null || num < 0) return 'Invalid number';
                          return null;
                        },
                        onChanged: (value) {
                          final total = int.tryParse(value) ?? 0;
                          final dead = int.tryParse(_deadKitsController.text) ?? 0;
                          setState(() {
                            _aliveKitsController.text = (total - dead).toString();
                          });
                          _updateKitDetailsList();
                        },
                      ),
                      const SizedBox(height: 20),

                      // Dead Kits
                      _buildSectionLabel('DEAD KITS'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _deadKitsController,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('0'),
                        onChanged: (value) {
                          final total = int.tryParse(_totalKitsController.text) ?? 0;
                          final dead = int.tryParse(value) ?? 0;
                          setState(() {
                            _aliveKitsController.text = (total - dead).toString();
                          });
                          _updateKitDetailsList();
                        },
                      ),
                      const SizedBox(height: 20),

                      // Alive Kits (Auto-calculated)
                      _buildSectionLabel('ALIVE KITS'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _aliveKitsController,
                        readOnly: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7F7F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Kit Details Section
                      if (_kitDetails.isNotEmpty) ...[
                        _buildSectionLabel('KIT DETAILS'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE9E9E7)),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < _kitDetails.length; i++) ...[
                                if (i > 0) const Divider(height: 16),
                                _buildKitDetailRow(i),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFF7B6BA0)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Set sex and color for each kit. You can update details later.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF7B6BA0)),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  backgroundColor: const Color(0xFF7B6BA0),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Add Litter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ã¢Å“€¦ Helper method for section labels
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF787774),
        letterSpacing: 0.5,
      ),
    );
  }

  // Ã¢Å“€¦ Helper method for input decoration
  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String _formatDate(DateTime date) {
    return FormatUtils.formatDate(date);
  }

  Widget _buildKitDetailRow(int index) {
    final kitNum = index + 1;
    return Row(
      children: [
        // Kit number label
        SizedBox(
          width: 50,
          child: Text(
            'Kit $kitNum',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37352F),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Sex dropdown
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _kitDetails[index]['sex'],
            decoration: InputDecoration(
              labelText: 'Sex',
              labelStyle: const TextStyle(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
              ),
            ),
            items: _sexOptions.map((sex) {
              String label;
              switch (sex) {
                case 'M':
                  label = 'Male';
                  break;
                case 'F':
                  label = 'Female';
                  break;
                default:
                  label = 'Unknown';
              }
              return DropdownMenuItem(value: sex, child: Text(label, style: const TextStyle(fontSize: 13)));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _kitDetails[index]['sex'] = value ?? 'U';
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        // Color dropdown
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            value: _kitDetails[index]['color'],
            decoration: InputDecoration(
              labelText: 'Color',
              labelStyle: const TextStyle(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
              ),
            ),
            items: _colorOptions.map((color) {
              return DropdownMenuItem(value: color, child: Text(color, style: const TextStyle(fontSize: 13)));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _kitDetails[index]['color'] = value ?? 'Unknown';
              });
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveLitter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final doe = _does.firstWhere((d) => d.id == _selectedDoeId);
      final buck = _bucks.firstWhere((b) => b.id == _selectedBuckId);

      final totalKits = int.parse(_totalKitsController.text);
      final deadKits = int.parse(_deadKitsController.text);
      final aliveKits = totalKits - deadKits;

      // Create kits with collected details
      final kits = List.generate(aliveKits, (index) {
        final details = index < _kitDetails.length
            ? _kitDetails[index]
            : {
                'sex': 'U',
                'color': 'Unknown'
              };
        return Kit(
          id: '${index + 1}',
          sex: details['sex'] ?? 'U',
          color: details['color'] ?? 'Unknown',
          weight: 0.0,
          status: 'Nursing',
        );
      });

      final newLitter = Litter(
        id: _litterIdController.text,
        doeId: doe.id,
        doeName: doe.name,
        buckId: buck.id,
        buckName: buck.name,
        breedDate: _breedDate,
        kindleDate: _kindleDate,
        dob: _dob, // Ã¢Å“€¦ Include DOB
        location: _selectedLocation ?? '', // Ã¢Å“€¦ Include location
        cage: _selectedCage ?? '', // Ã¢Å“€¦ Include cage
        breed: doe.breed, // Ã¢Å“€¦ Include breed
        status: 'Nursing',
        sire: buck.name, // Ã¢Å“€¦ Include sire
        dam: doe.name, // Ã¢Å“€¦ Include dam
        totalKits: totalKits,
        aliveKits: aliveKits,
        deadKits: deadKits,
        kits: kits,
      );

      // Save to database
      await _db.updateLitter(newLitter);

      // Sync cage into barn row
      if ((_selectedLocation ?? '').isNotEmpty && (_selectedCage ?? '').isNotEmpty) {
        await _db.syncCageToBarn(_selectedLocation!, _selectedCage!);
      }

      // Create wean pipeline task for this litter
      final settings = SettingsService.instance;
      final weanDate = _dob.add(Duration(days: settings.weanAge * 7));
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

      Navigator.pop(context);
      widget.onComplete();
    } catch (e) {
      print('Ã¢Å’ Error saving litter: $e');
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
    _deadKitsController.dispose();
    super.dispose();
  }
}
class _StatusConfig { final Color bgColor; final Color textColor; _StatusConfig({required this.bgColor, required this.textColor}); }
