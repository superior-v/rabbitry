import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/litter.dart';
import '../services/database_service.dart'; // ✅ ADD THIS
import '../models/rabbit.dart';

import 'dart:developer' as developer;

class LittersScreen extends StatefulWidget {
  @override
  _LittersScreenState createState() => _LittersScreenState();
}

class _LittersScreenState extends State<LittersScreen> with SingleTickerProviderStateMixin {
  late TabController _viewTabController;

  final DatabaseService _db = DatabaseService(); // ✅ ADD THIS

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
  bool _isLoading = true; // ✅ ADD THIS

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
    print('🎬 initState called, loading litters...');
    _loadLitters();
  }

  // ✅ ADD THIS METHOD
  Future<void> _loadLitters() async {
    setState(() => _isLoading = true);

    try {
      print('🔄 Loading litters...');

      // First clear old broken data and reinitialize
      final existingLitters = await _db.getLitters();

      // Check if data is broken (missing dob/location)
      bool hasBrokenData = existingLitters.any((l) => l.location == 'Unknown' || l.cage == 'N/A' || l.kits.isEmpty);

      if (existingLitters.isEmpty || hasBrokenData) {
        print('📦 No valid litters found, initializing sample data...');
        await _db.clearAllLitters();
        await _initializeSampleData();
      } else {
        print('📦 Database returned ${existingLitters.length} valid litters');
        setState(() {
          litters = existingLitters;
          _isLoading = false;
        });
        print('✅ Updated state: ${litters.length} litters, loading: false');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading litters: $e');
      print('Stack trace: $stackTrace');
      // Fallback to sample data
      await _db.clearAllLitters();
      await _initializeSampleData();
    }
  }

  // ✅ ADD THIS METHOD

  Future<void> _refreshLitters() async {
    try {
      final loadedLitters = await _db.getLitters();
      setState(() {
        litters = loadedLitters;
      });
      print('🔄 Refreshed: ${litters.length} litters');
    } catch (e) {
      print('❌ Error refreshing litters: $e');
    }
  }

  Future<void> _clearAndReinitialize() async {
    print('🗑️ Clearing old data and reinitializing...');
    setState(() => _isLoading = true);

    try {
      // Clear all existing litters
      await _db.clearAllLitters();
      print('✅ Cleared old litters');

      // Initialize fresh sample data
      await _initializeSampleData();

      // Reload from database
      await _loadLitters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Database reinitialized with sample data'),
            backgroundColor: Color(0xFF0F7B6C),
          ),
        );
      }
    } catch (e) {
      print('❌ Error reinitializing: $e');
      setState(() => _isLoading = false);
    }
  }
// Add this method around line 62 (after _refreshLitters)

  Future<void> _initializeSampleData() async {
    try {
      print('📦 Creating sample litters...');

      final sampleLitters = [
        Litter(
          id: 'L-101',
          doeId: 'D-101',
          doeName: 'Luna',
          buckId: 'B-01',
          buckName: 'Thumper',
          breedDate: DateTime.now().subtract(const Duration(days: 45)),
          kindleDate: DateTime.now().subtract(const Duration(days: 14)),
          dob: DateTime.now().subtract(const Duration(days: 14)),
          location: 'Maternity Row',
          cage: 'A-02',
          breed: 'New Zealand White',
          status: 'Nursing',
          sire: 'Thumper',
          dam: 'Luna',
          totalKits: 8,
          aliveKits: 8,
          deadKits: 0,
          kits: [
            Kit(id: '1', sex: 'M', color: 'White', weight: 0.5, status: 'Nursing'),
            Kit(id: '2', sex: 'F', color: 'White', weight: 0.4, status: 'Nursing'),
            Kit(id: '3', sex: 'M', color: 'White', weight: 0.6, status: 'Nursing'),
            Kit(id: '4', sex: 'F', color: 'White', weight: 0.5, status: 'Nursing'),
            Kit(id: '5', sex: 'M', color: 'White', weight: 0.4, status: 'Nursing'),
            Kit(id: '6', sex: 'F', color: 'White', weight: 0.5, status: 'Nursing'),
            Kit(id: '7', sex: 'M', color: 'White', weight: 0.6, status: 'Nursing'),
            Kit(id: '8', sex: 'F', color: 'White', weight: 0.5, status: 'Nursing'),
          ],
        ),
        Litter(
          id: 'L-102',
          doeId: 'D-102',
          doeName: 'Snowball',
          buckId: 'B-01',
          buckName: 'Roger',
          breedDate: DateTime.now().subtract(const Duration(days: 60)),
          kindleDate: DateTime.now().subtract(const Duration(days: 28)),
          dob: DateTime.now().subtract(const Duration(days: 28)),
          location: 'Nursery 1',
          cage: 'B-03',
          breed: 'Californian',
          status: 'Weaned',
          sire: 'Roger',
          dam: 'Snowball',
          totalKits: 6,
          aliveKits: 6,
          deadKits: 0,
          weanDate: DateTime.now().subtract(const Duration(days: 7)),
          kits: [
            Kit(id: '1', sex: 'M', color: 'Black/White', weight: 1.2, status: 'Weaned'),
            Kit(id: '2', sex: 'F', color: 'Black/White', weight: 1.1, status: 'Weaned'),
            Kit(id: '3', sex: 'M', color: 'Black/White', weight: 1.3, status: 'Weaned'),
            Kit(id: '4', sex: 'F', color: 'Black/White', weight: 1.0, status: 'Weaned'),
            Kit(id: '5', sex: 'M', color: 'Black/White', weight: 1.2, status: 'Weaned'),
            Kit(id: '6', sex: 'F', color: 'Black/White', weight: 1.1, status: 'Weaned'),
          ],
        ),
        Litter(
          id: 'L-103',
          doeId: 'D-103',
          doeName: 'Bella',
          buckId: 'B-02',
          buckName: 'Buck',
          breedDate: DateTime.now().subtract(const Duration(days: 90)),
          kindleDate: DateTime.now().subtract(const Duration(days: 56)),
          dob: DateTime.now().subtract(const Duration(days: 56)),
          location: 'Grow Pen A',
          cage: 'GP-A',
          breed: 'Rex',
          status: 'GrowOut',
          sire: 'Buck',
          dam: 'Bella',
          totalKits: 5,
          aliveKits: 4,
          deadKits: 1,
          weanDate: DateTime.now().subtract(const Duration(days: 28)),
          kits: [
            Kit(id: '1', sex: 'M', color: 'Castor', weight: 3.5, status: 'GrowOut'),
            Kit(id: '2', sex: 'F', color: 'Castor', weight: 3.2, status: 'GrowOut'),
            Kit(id: '3', sex: 'M', color: 'Red', weight: 3.8, status: 'GrowOut'),
            Kit(id: '4', sex: 'F', color: 'Castor', weight: 3.4, status: 'Sold', price: 45.0, details: 'Sold to John'),
            Kit(id: '5', sex: 'M', color: 'Black', weight: 2.1, status: 'Dead', details: 'Runt'),
          ],
        ),
      ];

      print('💾 Saving ${sampleLitters.length} litters to database...');

      for (var litter in sampleLitters) {
        await _db.updateLitter(litter);
        print('  ✅ Saved: ${litter.id} - ${litter.dam} x ${litter.sire} (${litter.kits.length} kits)');
      }

      print('✅ Sample litters saved, reloading...');

      // Reload from database to verify
      final reloaded = await _db.getLitters();
      print('🔄 Reloaded ${reloaded.length} litters from database');

      for (var l in reloaded) {
        print('  📋 ${l.id}: dob=${l.dob}, loc=${l.location}, kits=${l.kits.length}');
      }

      setState(() {
        litters = reloaded;
        _isLoading = false;
      });

      print('✅ State updated: ${litters.length} litters loaded');
    } catch (e, stackTrace) {
      print('❌ Error initializing sample data: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Nursery Manager',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            PhosphorIconsDuotone.warehouse,
            color: Colors.black87,
          ),
          onPressed: _showBarnDrawer,
        ),
        title: Text(
          'Nursery Manager',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: Colors.black87,
                ),
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
                      color: Color(
                        0xFF0F7B6C,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildViewTabs(),
          _buildSearchAndGroup(),
          if (_locationFilter != null) _buildFilterBanner(),
          SizedBox(
            height: 12,
          ),
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
        onPressed: () => _showAddLitterDialog(), // ✅ ADD THIS
        backgroundColor: Color(0xFF0F7B6C),
        shape: CircleBorder(),
        child: Icon(
          Icons.add,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildViewTabs() {
    return Container(
      margin: EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Color(
          0xFFF7F7F5,
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: TabBar(
        controller: _viewTabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.05,
              ),
              blurRadius: 4,
              offset: Offset(
                0,
                2,
              ),
            ),
          ],
        ),
        indicatorPadding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        labelColor: Color(
          0xFF0F7B6C,
        ),
        unselectedLabelColor: Color(
          0xFF787774,
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                ),
                SizedBox(
                  width: 6,
                ),
                Text(
                  'By Litter',
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pets,
                  size: 18,
                ),
                SizedBox(
                  width: 6,
                ),
                Text(
                  'By Kit',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndGroup() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Color(
                  0xFFF7F7F5,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
                border: Border.all(
                  color: Color(
                    0xFFE9E9E7,
                  ),
                ),
              ),
              child: TextField(
                onChanged: (
                  value,
                ) =>
                    setState(
                  () => _searchQuery = value,
                ),
                style: TextStyle(
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search ID or Name...',
                  hintStyle: TextStyle(
                    color: Color(
                      0xFF9B9A97,
                    ),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(
                      0xFF787774,
                    ),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 8,
          ),
          PopupMenuButton<String>(
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(
                  0xFFF7F7F5,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
                border: Border.all(
                  color: Color(
                    0xFFE9E9E7,
                  ),
                ),
              ),
              child: Icon(
                Icons.view_agenda_outlined,
                color: Colors.black87,
                size: 20,
              ),
            ),
            onSelected: (
              value,
            ) =>
                setState(
              () => _grouping = value,
            ),
            itemBuilder: (
              context,
            ) =>
                [
              PopupMenuItem(
                value: 'none',
                child: Text(
                  'Group: None',
                ),
              ),
              PopupMenuItem(
                value: 'location',
                child: Text(
                  'Group: Location',
                ),
              ),
              PopupMenuItem(
                value: 'dam',
                child: Text(
                  'Group: Dam',
                ),
              ),
              PopupMenuItem(
                value: 'breed',
                child: Text(
                  'Group: Breed',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Color(
          0xFFEBF8FF,
        ),
        border: Border.all(
          color: Color(
            0xFF2E7BB5,
          ),
        ),
        borderRadius: BorderRadius.circular(
          8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            size: 16,
            color: Color(
              0xFF2E7BB5,
            ),
          ),
          SizedBox(
            width: 8,
          ),
          Text(
            'Filtering by: ',
            style: TextStyle(
              color: Color(
                0xFF2E7BB5,
              ),
              fontSize: 14,
            ),
          ),
          Text(
            _locationFilter!,
            style: TextStyle(
              color: Color(
                0xFF2E7BB5,
              ),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          GestureDetector(
            onTap: () => setState(
              () => _locationFilter = null,
            ),
            child: Icon(
              Icons.close,
              size: 18,
              color: Color(
                0xFF2E7BB5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageChips() {
    List<Map<String, dynamic>> stages = [
      {
        'label': 'All',
        'icon': null,
      },
      {
        'label': 'Nursing',
        'icon': Icons.child_care,
      },
      {
        'label': 'Weaned',
        'icon': Icons.food_bank,
      },
      {
        'label': 'GrowOut',
        'icon': Icons.trending_up,
      },
      {
        'label': 'Mature',
        'icon': Icons.star,
      },
      {
        'label': 'Quarantine',
        'icon': Icons.warning_amber,
      },
      {
        'label': 'Archive',
        'icon': Icons.archive,
      },
    ];

    return Container(
      height: 44,
      margin: EdgeInsets.only(
        bottom: 12,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: stages.length,
        itemBuilder: (
          context,
          index,
        ) {
          final stage = stages[index];
          final isActive = _currentStage == stage['label'];

          return GestureDetector(
            onTap: () => setState(
              () => _currentStage = stage['label'],
            ),
            child: Container(
              margin: EdgeInsets.only(
                right: 8,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? Color(
                        0xFF37352F,
                      )
                    : Colors.white,
                border: Border.all(
                  color: isActive
                      ? Color(
                          0xFF37352F,
                        )
                      : Color(
                          0xFFE9E9E7,
                        ),
                ),
                borderRadius: BorderRadius.circular(
                  20,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stage['icon'] != null) ...[
                    Icon(
                      stage['icon'],
                      size: 14,
                      color: isActive
                          ? Colors.white
                          : Color(
                              0xFF787774,
                            ),
                    ),
                    SizedBox(
                      width: 6,
                    ),
                  ],
                  Text(
                    stage['label'],
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Color(
                              0xFF787774,
                            ),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

        // Filter kits by stage
        final validKits = litter.kits.where(
          (
            kit,
          ) {
            final isArchiveStatus = [
              'Sold',
              'Butchered',
              'Dead',
              'Cull',
            ].contains(
              kit.status,
            );

            if (_currentStage == 'Archive') {
              return isArchiveStatus;
            } else if (_currentStage != 'All') {
              if (isArchiveStatus || kit.status == 'Quarantine') {
                return _currentStage == 'Quarantine' && kit.status == 'Quarantine';
              }
              return kit.status == _currentStage || litter.status == _currentStage;
            }
            return true;
          },
        ).toList();

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
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Color(
                0xFFE9E9E7,
              ),
            ),
            SizedBox(
              height: 16,
            ),
            Text(
              'No litters found',
              style: TextStyle(
                color: Color(
                  0xFF787774,
                ),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (_grouping == 'none') {
      return ListView.builder(
        padding: EdgeInsets.all(
          16,
        ),
        itemCount: filtered.length,
        itemBuilder: (
          context,
          index,
        ) =>
            _buildLitterCard(
          filtered[index],
        ),
      );
    }

    // Grouped view
    Map<String, List<Litter>> groups = {};
    for (var litter in filtered) {
      String key = litter.breed;
      if (_grouping == 'dam') key = litter.dam;
      if (_grouping == 'location') key = litter.location;
      groups
          .putIfAbsent(
            key,
            () => [],
          )
          .add(
            litter,
          );
    }

    List<String> sortedKeys = groups.keys.toList()..sort();

    return ListView(
      padding: EdgeInsets.all(
        16,
      ),
      children: sortedKeys.map(
        (
          key,
        ) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      _grouping == 'location' ? Icons.location_on : Icons.pets,
                      size: 16,
                      color: Color(
                        0xFF9B9A97,
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Text(
                      key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(
                          0xFF9B9A97,
                        ),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              ...groups[key]!.map(
                (
                  litter,
                ) =>
                    _buildLitterCard(
                  litter,
                ),
              ),
            ],
          );
        },
      ).toList(),
    );
  }

  Widget _buildLitterCard(
    Litter litter,
  ) {
    final isExpanded = _expandedLitters[litter.id] ?? false;
    final malePercent = litter.totalKitsCount > 0 ? (litter.maleCount / litter.totalKitsCount) * 100 : 0;

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Color(
            0xFFE9E9E7,
          ),
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        children: [
          // Main Card Content
          Padding(
            padding: EdgeInsets.all(
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center, // Aligns items vertically
                            spacing: 4, // Horizontal gap between items
                            runSpacing: 4, // Vertical gap if it wraps to a new line
                            children: [
                              Text(
                                litter.id,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(
                                width: 8,
                              ),
                              ..._buildStatusBadges(
                                litter,
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 4,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.biotech,
                                size: 12,
                                color: Color(
                                  0xFF787774,
                                ),
                              ),
                              SizedBox(
                                width: 4,
                              ),
                              Text(
                                '${litter.breed} • ${litter.dam} x ${litter.sire}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(
                                    0xFF787774,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                      ),
                      onPressed: () => _showLitterMenu(
                        litter,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),

                // Data Row
                Container(
                  margin: EdgeInsets.only(
                    top: 12,
                  ),
                  padding: EdgeInsets.only(
                    top: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(
                          0xFFE9E9E7,
                        ),
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildDataPoint(
                        'AGE',
                        litter.ageDisplay,
                      ),
                      SizedBox(
                        width: 16,
                      ),
                      _buildDataPoint(
                        'COUNT',
                        '${litter.totalKitsCount} Live',
                      ),
                      SizedBox(
                        width: 16,
                      ),
                      _buildDataPoint(
                        'TOTAL WT',
                        '${litter.totalWeight.toStringAsFixed(1)} lbs',
                      ),
                      Spacer(),
                      _buildRatioBar(
                        litter,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expandable Kit List
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: Color(
                  0xFFFAFAFA,
                ),
                border: Border(
                  top: BorderSide(
                    color: Color(
                      0xFFE9E9E7,
                    ),
                  ),
                ),
              ),
              child: Column(
                children: litter.kits
                    .map(
                      (
                        kit,
                      ) =>
                          _buildKitRow(
                        litter,
                        kit,
                      ),
                    )
                    .toList(),
              ),
            ),

          // Expand Toggle
          InkWell(
            onTap: () {
              setState(
                () {
                  _expandedLitters[litter.id] = !isExpanded;
                },
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                8,
              ),
              decoration: BoxDecoration(
                color: Color(
                  0xFFF7F7F5,
                ),
                border: Border(
                  top: BorderSide(
                    color: Color(
                      0xFFE9E9E7,
                    ),
                  ),
                ),
              ),
              child: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Color(
                  0xFF9B9A97,
                ),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusBadges(
    Litter litter,
  ) {
    return litter.distinctStatuses.map(
      (
        status,
      ) {
        return Container(
          margin: EdgeInsets.only(
            right: 4,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: _getStatusColor(
              status,
            ).withOpacity(
              0.1,
            ),
            borderRadius: BorderRadius.circular(
              4,
            ),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(
                status,
              ),
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    ).toList();
  }

  Color _getStatusColor(
    String status,
  ) {
    switch (status) {
      case 'Nursing':
        return Color(
          0xFF2E7BB5,
        );
      case 'Weaned':
        return Color(
          0xFF9C6ADE,
        );
      case 'GrowOut':
        return Color(
          0xFF459F89,
        );
      case 'Mature':
        return Color(
          0xFF0F7B6C,
        );
      case 'Quarantine':
        return Color(
          0xFFD97706,
        );
      case 'Sold':
        return Color(
          0xFF0F7B6C,
        );
      case 'Butchered':
        return Color(
          0xFF787774,
        );
      case 'Dead':
        return Color(
          0xFF37352F,
        );
      default:
        return Color(
          0xFF787774,
        );
    }
  }

  Widget _buildDataPoint(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Color(
              0xFF9B9A97,
            ),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(
          height: 2,
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRatioBar(
    Litter litter,
  ) {
    final malePercent = litter.totalKitsCount > 0 ? (litter.maleCount / litter.totalKitsCount) * 100 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'RATIO',
          style: TextStyle(
            fontSize: 10,
            color: Color(
              0xFF9B9A97,
            ),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(
          height: 4,
        ),
        Container(
          width: 60,
          height: 6,
          decoration: BoxDecoration(
            color: Color(
              0xFFF1F1EF,
            ),
            borderRadius: BorderRadius.circular(
              3,
            ),
          ),
          child: Row(
            children: [
              if (litter.maleCount > 0)
                Container(
                  width: 60 * (malePercent / 100),
                  decoration: BoxDecoration(
                    color: Color(
                      0xFFA3CBEB,
                    ),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(
                        3,
                      ),
                    ),
                  ),
                ),
              if (litter.femaleCount > 0)
                Container(
                  width: 60 * ((100 - malePercent) / 100),
                  decoration: BoxDecoration(
                    color: Color(
                      0xFFDBC4F0,
                    ),
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(
                        3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 4,
        ),
        Text(
          '${litter.maleCount}M / ${litter.femaleCount}F',
          style: TextStyle(
            fontSize: 10,
            color: Color(
              0xFF9B9A97,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKitRow(
    Litter litter,
    Kit kit,
  ) {
    Color avatarColor = Color(0xFFEEEEEE);
    Color iconColor = Color(0xFF999999);

    if (kit.sex == 'M') {
      avatarColor = Color(0xFFEBF8FF);
      iconColor = Color(0xFF2E7BB5);
    } else if (kit.sex == 'F') {
      avatarColor = Color(0xFFF3E8FF);
      iconColor = Color(0xFF9C6ADE);
    }

    return InkWell(
      // ✅ Change GestureDetector to InkWell
      onTap: () {
        print('Kit tapped: ${litter.id}-${kit.id}'); // ✅ Add debug print
        _showKitActions(litter, kit);
      },
      child: Container(
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE9E9E7),
            ),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pets,
                size: 16,
                color: iconColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kit #${kit.id}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    kit.color,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF787774),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(kit.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    kit.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(kit.status),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${kit.weight} lbs',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitsList() {
    final filtered = _getFilteredLitters();
    List<Map<String, dynamic>> allKits = [];

    for (var litter in filtered) {
      for (var kit in litter.kits) {
        allKits.add(
          {
            'litter': litter,
            'kit': kit,
          },
        );
      }
    }

    if (allKits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Color(
                0xFFE9E9E7,
              ),
            ),
            SizedBox(
              height: 16,
            ),
            Text(
              'No kits found',
              style: TextStyle(
                color: Color(
                  0xFF787774,
                ),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(
        16,
      ),
      itemCount: allKits.length,
      itemBuilder: (
        context,
        index,
      ) {
        final item = allKits[index];
        final litter = item['litter'] as Litter;
        final kit = item['kit'] as Kit;

        // Archive style card
        if (kit.isArchived) {
          return _buildArchiveKitCard(
            litter,
            kit,
          );
        }

        // Standard kit card
        return _buildStandardKitCard(
          litter,
          kit,
        );
      },
    );
  }

  Widget _buildStandardKitCard(
    Litter litter,
    Kit kit,
  ) {
    Color avatarColor = Color(
      0xFFEEEEEE,
    );
    Color iconColor = Color(
      0xFF999999,
    );

    if (kit.sex == 'M') {
      avatarColor = Color(
        0xFFEBF8FF,
      );
      iconColor = Color(
        0xFF2E7BB5,
      );
    } else if (kit.sex == 'F') {
      avatarColor = Color(
        0xFFF3E8FF,
      );
      iconColor = Color(
        0xFF9C6ADE,
      );
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: 10,
      ),
      padding: EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Color(
            0xFFE9E9E7,
          ),
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets,
              size: 24,
              color: iconColor,
            ),
          ),
          SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${litter.id}-${kit.id}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Text(
                      '${kit.color} Kit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 4,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.biotech,
                      size: 12,
                      color: Color(
                        0xFF787774,
                      ),
                    ),
                    SizedBox(
                      width: 4,
                    ),
                    Text(
                      '${litter.dam} x ${litter.sire}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(
                          0xFF787774,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 4,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: Color(
                        0xFF787774,
                      ),
                    ),
                    SizedBox(
                      width: 4,
                    ),
                    Text(
                      '${litter.location} • ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(
                          0xFF787774,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.scale,
                      size: 12,
                      color: Color(
                        0xFF787774,
                      ),
                    ),
                    SizedBox(
                      width: 4,
                    ),
                    Text(
                      '${kit.weight} lbs',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(
                          0xFF787774,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              size: 20,
            ),
            onPressed: () => _showKitMenu(
              litter,
              kit,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveKitCard(
    Litter litter,
    Kit kit,
  ) {
    Color badgeColor = Color(
      0xFF0F7B6C,
    );
    Color badgeBg = Color(
      0xFFE6FFFA,
    );
    String badgeLabel = kit.status;

    if (kit.status == 'Butchered') {
      badgeColor = Color(
        0xFF37352F,
      );
      badgeBg = Color(
        0xFFF1F1EF,
      );
    } else if (kit.status == 'Dead') {
      badgeColor = Colors.white;
      badgeBg = Color(
        0xFF37352F,
      );
    } else if (kit.status == 'Cull') {
      badgeColor = Color(
        0xFFD44C47,
      );
      badgeBg = Color(
        0xFFFFF5F5,
      );
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
      ),
      padding: EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Color(
            0xFFE9E9E7,
          ),
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Color(
                0xFFF7F7F5,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets,
              size: 28,
              color: Color(
                0xFF9B9A97,
              ),
            ),
          ),
          SizedBox(
            width: 16,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${litter.id}-${kit.id}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      width: 6,
                    ),
                    Text(
                      '${kit.color} Kit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 4,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: Color(
                        0xFF787774,
                      ),
                    ),
                    SizedBox(
                      width: 4,
                    ),
                    Text(
                      'Archive • -',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(
                          0xFF787774,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 6,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(
                      6,
                    ),
                    border: kit.status == 'Sold'
                        ? Border.all(
                            color: badgeColor,
                          )
                        : (kit.status == 'Butchered'
                            ? Border.all(
                                color: Color(
                                  0xFF787774,
                                ),
                              )
                            : null),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(
                        width: 6,
                      ),
                      Text(
                        badgeLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (kit.price != null || kit.details != null) ...[
                  SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      if (kit.price != null) ...[
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: Color(
                            0xFF787774,
                          ),
                        ),
                        Text(
                          '\$${kit.price!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(
                              0xFF787774,
                            ),
                          ),
                        ),
                        if (kit.details != null)
                          SizedBox(
                            width: 12,
                          ),
                      ],
                      if (kit.details != null) ...[
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(
                            0xFF787774,
                          ),
                        ),
                        SizedBox(
                          width: 4,
                        ),
                        Text(
                          kit.details!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(
                              0xFF787774,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              size: 20,
            ),
            onPressed: () => _showKitMenu(
              litter,
              kit,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showLitterMenu(Litter litter) {
    _showLitterActions(litter);
  }

  void _showLitterActions(Litter litter) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Litter ${litter.id}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        litter.status,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildActionOption(
              icon: Icons.content_cut_outlined,
              label: 'Wean Litter',
              color: const Color(0xFF0F7B6C),
              onTap: () {
                Navigator.pop(context);
                _showWeanLitterDialog(litter);
              },
            ),
            _buildActionOption(
              icon: Icons.medical_services_outlined,
              label: 'Health Record',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _showHealthRecordDialog(litter);
              },
            ),
            _buildActionOption(
              icon: Icons.scale_outlined,
              label: 'Bulk Weigh',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _showBulkWeighDialog(litter);
              },
            ),
            _buildActionOption(
              icon: Icons.swap_horiz,
              label: 'Move Cage',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _showMoveCageDialog(litter);
              },
            ),
            _buildActionOption(
              icon: Icons.print_outlined,
              label: 'Print Cage Card',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _printCageCard(litter);
              },
            ),
            const Divider(height: 1, thickness: 1),
            _buildActionOption(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: const Color(0xFFD44C47),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(litter);
              },
            ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kit ${litter.id}-${kit.id}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kit.status,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Promote to Mature
            if (kit.status == 'GrowOut')
              _buildKitActionOption(
                icon: Icons.star_outline,
                label: 'Promote to Mature',
                color: const Color(0xFF0F7B6C),
                onTap: () {
                  Navigator.pop(context);
                  _promoteKitToMature(litter, kit);
                },
              ),

            // Sell Kit
            _buildKitActionOption(
              icon: Icons.attach_money,
              label: 'Sell Kit',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _showSellKitDialog(litter, kit);
              },
            ),

            // Health Record
            _buildKitActionOption(
              icon: Icons.medical_services_outlined,
              label: 'Health Record',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _showKitHealthRecord(litter, kit);
              },
            ),

            // Harvest/Butcher
            _buildKitActionOption(
              icon: Icons.restaurant_outlined,
              label: 'Harvest / Butcher',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _showButcherKitDialog(litter, kit);
              },
            ),

            // Quarantine
            _buildKitActionOption(
              icon: Icons.warning_amber_outlined,
              label: 'Quarantine',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _quarantineKit(litter, kit);
              },
            ),

            // Log Weight
            _buildKitActionOption(
              icon: Icons.scale_outlined,
              label: 'Log Weight',
              color: const Color(0xFF787774),
              onTap: () {
                Navigator.pop(context);
                _logKitWeight(litter, kit);
              },
            ),

            const Divider(height: 1, thickness: 1),

            // Mark as Died
            _buildKitActionOption(
              icon: Icons.close,
              label: 'Mark as Died',
              color: const Color(0xFFD44C47),
              onTap: () {
                Navigator.pop(context);
                _markKitAsDied(litter, kit);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _promoteKitToMature(Litter litter, Kit kit) {
    final TextEditingController nameController = TextEditingController(text: 'Kit ${kit.id}');
    final TextEditingController idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Promote to Active Breeder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create a new rabbit entry as an active breeder.',
              style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Rabbit Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: InputDecoration(
                labelText: 'Rabbit ID (optional)',
                hintText: 'Auto-generated if empty',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF0F7B6C)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sex: ${kit.sex == 'M' ? 'Male (Buck)' : 'Female (Doe)'}\nColor: ${kit.color}\nWeight: ${kit.weight} lbs',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0F7B6C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
                  ),
                ),
              );

              try {
                // Promote kit to breeder using database service
                final newRabbit = await _db.promoteKitToBreeder(
                  litter,
                  kit,
                  customName: nameController.text.isNotEmpty ? nameController.text : null,
                  customId: idController.text.isNotEmpty ? idController.text : null,
                );

                // Reload litters
                await _refreshLitters();

                // Close loading
                if (mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kit promoted to breeder: ${newRabbit?.name ?? "Unknown"}'),
                      backgroundColor: const Color(0xFF0F7B6C),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F7B6C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Promote', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                            '${kit.sex == 'M' ? 'Buck' : 'Doe'} • ${kit.color} • ${kit.weight} lbs',
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
                        hintText: '\$0.00',
                        prefixText: '\$',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F7B6C),
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
                    TextField(
                      controller: buyerController,
                      decoration: InputDecoration(
                        hintText: 'Enter buyer name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F7B6C),
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
                    // ✅ ADD async
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
                      await _refreshLitters();
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kit marked as sold'),
                          backgroundColor: Color(0xFF0F7B6C),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B6C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F7B6C),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F7B6C),
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
                        backgroundColor: Color(0xFF0F7B6C),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B6C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                labelText: 'Dressed Weight (lbs)',
                hintText: '0.0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
              // ✅ ADD async
              Navigator.pop(context);

              final litterIndex = litters.indexWhere((l) => l.id == litter.id);
              if (litterIndex != -1) {
                final updatedKits = litters[litterIndex].kits.map((k) {
                  if (k.id == kit.id) {
                    return k.copyWith(
                      status: 'Butchered',
                      details: 'Yield ${yieldController.text}lbs',
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
                    backgroundColor: Color(0xFF0F7B6C),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F7B6C)),
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
            labelText: 'Weight (lbs)',
            suffixText: 'lbs',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
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
                    backgroundColor: Color(0xFF0F7B6C),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F7B6C)),
            child: const Text('Save'),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(8),
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
    final TextEditingController weanedCountController = TextEditingController(
      text: litter.aliveKits.toString(),
    );
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                      const Text(
                        'NUMBER WEANED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weanedCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter count',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF0F7B6C),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                            borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFF0F7B6C),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Weaning will move kits to "Grow-out" stage',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF0F7B6C),
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
                    onPressed: () async {
                      // ✅ ADD async
                      Navigator.pop(context);

                      final index = litters.indexWhere((l) => l.id == litter.id);
                      if (index != -1) {
                        final updatedKits = litters[index].kits.map((k) {
                          return k.copyWith(status: 'Weaned');
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
                          const SnackBar(
                            content: Text('Litter weaned successfully'),
                            backgroundColor: Color(0xFF0F7B6C),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F7B6C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Wean Litter',
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F7B6C),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F7B6C),
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
                        backgroundColor: Color(0xFF0F7B6C),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B6C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                        hintText: '0.0 lbs',
                        suffixText: 'lbs',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F7B6C),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.calculate,
                            size: 16,
                            color: Color(0xFF0F7B6C),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Average per kit will be calculated automatically',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0F7B6C),
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
                        backgroundColor: Color(0xFF0F7B6C),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B6C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                        value: selectedLocation,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF0F7B6C),
                              width: 2,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Maternity Row', child: Text('Maternity Row')),
                          DropdownMenuItem(value: 'Nursery 1', child: Text('Nursery 1')),
                          DropdownMenuItem(value: 'Grow Pen A', child: Text('Grow Pen A')),
                          DropdownMenuItem(value: 'Bank 1', child: Text('Bank 1')),
                        ],
                        onChanged: (value) {
                          setModalState(() => selectedLocation = value);
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
                      TextField(
                        controller: TextEditingController(text: selectedCage),
                        onChanged: (value) => selectedCage = value,
                        decoration: InputDecoration(
                          hintText: 'e.g., A-01',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF0F7B6C),
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
                      // ✅ ADD async
                      Navigator.pop(context);

                      final index = litters.indexWhere((l) => l.id == litter.id);
                      if (index != -1) {
                        final updatedLitter = litters[index].copyWith(
                          location: selectedLocation ?? litters[index].location,
                          cage: selectedCage ?? litters[index].cage,
                        );

                        await _db.updateLitter(updatedLitter);
                        await _refreshLitters();
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cage moved successfully'),
                            backgroundColor: Color(0xFF0F7B6C),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F7B6C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
        content: Text('🖨️ Printing cage card...'),
        backgroundColor: Color(0xFF0F7B6C),
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
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
                        backgroundColor: Color(0xFF0F7B6C),
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
                    // ❌ DELETE OR COMMENT OUT THIS LINE:
                    // Navigator.pop(context);

                    // ✅ The _buildMenuItem wrapper already pops the context,
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
                          backgroundColor: Color(0xFF0F7B6C),
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
                    // ✅ ADD: Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
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

                      // ✅ Close loading dialog
                      if (mounted) {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kit moved to grow out'),
                            backgroundColor: Color(0xFF0F7B6C),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      // ✅ Handle errors
                      print('❌ Error updating kit: $e');
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
                  () async {
                    // ✅ Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
                        ),
                      ),
                    );

                    try {
                      final litterIndex = litters.indexWhere((l) => l.id == litter.id);
                      if (litterIndex != -1) {
                        final updatedKits = litters[litterIndex].kits.map((k) {
                          if (k.id == kit.id) {
                            return k.copyWith(status: 'Mature');
                          }
                          return k;
                        }).toList();

                        final updatedLitter = litters[litterIndex].copyWith(kits: updatedKits);
                        await _db.updateLitter(updatedLitter);
                        await _refreshLitters();
                      }

                      // ✅ Close loading
                      if (mounted) {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kit promoted to mature'),
                            backgroundColor: Color(0xFF0F7B6C),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      print('❌ Error promoting kit: $e');
                      if (mounted) {
                        Navigator.pop(context);
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
                  0xFFE8F5F3,
                )
              : Colors.transparent,
          border: isPrimary
              ? Border(
                  left: BorderSide(
                    color: Color(
                      0xFF0F7B6C,
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
                          0xFF0F7B6C,
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
                            0xFF0F7B6C,
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

  void _showBarnDrawer() {
    // Similar to herd screen barn drawer
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Barn Filter',
      barrierColor: Colors.black54,
      transitionDuration: Duration(
        milliseconds: 300,
      ),
      pageBuilder: (
        context,
        animation,
        secondaryAnimation,
      ) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(
                    context,
                  ).size.width *
                  0.85,
              height: MediaQuery.of(
                context,
              ).size.height,
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      50,
                      20,
                      20,
                    ),
                    decoration: BoxDecoration(
                      color: Color(
                        0xFFF7F7F5,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Color(
                            0xFFE9E9E7,
                          ),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsDuotone.warehouse,
                          color: Color(
                            0xFF0F7B6C,
                          ),
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'BARN FILTER',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(
                              0xFF787774,
                            ),
                          ),
                        ),
                        Spacer(),
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
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(
                        12,
                      ),
                      children: [
                        _buildLocationItem(
                          'All Locations',
                          null,
                          24,
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        Text(
                          'BARN A',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(
                              0xFF9B9A97,
                            ),
                          ),
                        ),
                        _buildLocationItem(
                          'Maternity Row',
                          'Maternity Row',
                          8,
                        ),
                        _buildLocationItem(
                          'Nursery 1',
                          'Nursery 1',
                          10,
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        Text(
                          'OUTDOOR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(
                              0xFF9B9A97,
                            ),
                          ),
                        ),
                        _buildLocationItem(
                          'Grow Pen A',
                          'Grow Pen A',
                          6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
      ) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(
              -1.0,
              0.0,
            ),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildLocationItem(
    String label,
    String? location,
    int count,
  ) {
    final isActive = _locationFilter == location;

    return GestureDetector(
      onTap: () {
        setState(
          () => _locationFilter = location,
        );
        Navigator.pop(
          context,
        );
      },
      child: Container(
        padding: EdgeInsets.all(
          12,
        ),
        margin: EdgeInsets.only(
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Color(
                  0xFFE8F5F3,
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            8,
          ),
          border: isActive
              ? Border.all(
                  color: Color(
                    0xFF0F7B6C,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? Color(
                          0xFF0F7B6C,
                        )
                      : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white
                    : Color(
                        0xFFF7F7F5,
                      ),
                border: Border.all(
                  color: isActive
                      ? Color(
                          0xFF0F7B6C,
                        )
                      : Color(
                          0xFFE9E9E7,
                        ),
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Color(
                          0xFF0F7B6C,
                        )
                      : Color(
                          0xFF787774,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                              'Under 2 lbs',
                              'weight',
                              'light',
                              setModalState,
                            ),
                            _buildFilterChip(
                              '2 lbs +',
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
                                0xFF0F7B6C,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  8,
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
                  0xFFE8F5F3,
                )
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Color(
                    0xFF0F7B6C,
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
                    0xFF0F7B6C,
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
        onComplete: () async {
          await _refreshLitters();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Litter added successfully'),
                backgroundColor: Color(0xFF0F7B6C),
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

  const AddLitterSheet({Key? key, required this.onComplete}) : super(key: key);

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
  final TextEditingController _locationController = TextEditingController(text: 'Maternity Row');
  final TextEditingController _cageController = TextEditingController();
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
  final List<String> _colorOptions = [
    'Unknown',
    'Black',
    'White',
    'Brown',
    'Gray',
    'Spotted',
    'Tan',
    'Agouti',
    'Broken',
    'Other',
  ];

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
      print('❌ Error loading rabbits: $e');
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
      print('❌ Error loading next litter ID: $e');
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
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
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
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
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
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
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
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
                            borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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
                      TextFormField(
                        controller: _locationController,
                        decoration: _buildInputDecoration('Enter location'),
                        validator: (value) => value?.isEmpty ?? true ? 'Location is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Cage
                      _buildSectionLabel('CAGE'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cageController,
                        decoration: _buildInputDecoration('Enter cage number'),
                        validator: (value) => value?.isEmpty ?? true ? 'Cage is required' : null,
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
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFF0F7B6C)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Set sex and color for each kit. You can update details later.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF0F7B6C)),
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
                  backgroundColor: const Color(0xFF0F7B6C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

  // ✅ Helper method for section labels
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

  // ✅ Helper method for input decoration
  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
        dob: _dob, // ✅ Include DOB
        location: _locationController.text, // ✅ Include location
        cage: _cageController.text, // ✅ Include cage
        breed: doe.breed, // ✅ Include breed
        status: 'Nursing',
        sire: buck.name, // ✅ Include sire
        dam: doe.name, // ✅ Include dam
        totalKits: totalKits,
        aliveKits: aliveKits,
        deadKits: deadKits,
        kits: kits,
      );

      // Save to database
      await _db.updateLitter(newLitter);

      Navigator.pop(context);
      widget.onComplete();
    } catch (e) {
      print('❌ Error saving litter: $e');
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
    _locationController.dispose();
    _cageController.dispose();
    _totalKitsController.dispose();
    _aliveKitsController.dispose();
    _deadKitsController.dispose();
    super.dispose();
  }
}
