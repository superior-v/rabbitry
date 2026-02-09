import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../models/barn.dart';
import '../services/database_service.dart';
import '../widgets/rabbit_card.dart';
import 'dart:io';
import 'rabbit_detail_screen.dart';
import 'add_rabbit_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/action_sheets/rabbit_action_sheet.dart';

class HerdScreen extends StatefulWidget {
  const HerdScreen({Key? key}) : super(key: key);

  @override
  _HerdScreenState createState() => _HerdScreenState();
}

class _HerdScreenState extends State<HerdScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentFilter = 'All';
  String _searchQuery = '';
  String? _locationFilter;
  String _grouping = 'none';
  bool _isBarnEditMode = false;

  final DatabaseService _db = DatabaseService();

  List<Rabbit> _allRabbits = [];
  List<Rabbit> _archivedList = [];
  List<Barn> _barns = [];
  bool _isLoading = true;

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

      print('📊 Loaded ${rabbits.length} rabbits, ${archivedRabbits.length} archived');

      for (var rabbit in rabbits) {
        final hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty;
        final photoPath = hasPhoto ? rabbit.photos!.first : null;
        final exists = photoPath != null ? File(photoPath).existsSync() : false;
        print('  📸 ${rabbit.name}: hasPhoto=$hasPhoto, path=$photoPath, exists=$exists');
      }

      if (rabbits.isEmpty && barnsData.isEmpty) {
        print('! Database empty, initializing sample data...');
        await _initializeSampleData();
        final reloadedRabbits = await _db.getAllRabbits();
        final reloadedArchived = await _db.getArchivedRabbits();
        final reloadedBarns = await _db.getAllBarns();

        if (mounted) {
          setState(() {
            _allRabbits = reloadedRabbits;
            _archivedList = reloadedArchived;
            _barns = reloadedBarns.map((b) => Barn.fromMap(b)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _allRabbits = rabbits;
            _archivedList = archivedRabbits;
            _barns = barnsData.map((b) => Barn.fromMap(b)).toList();
            _isLoading = false;
          });
        }
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
        });
      }
    }
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
        });
      }

      print('✅ Herd data refreshed: ${rabbits.length} rabbits');
    } catch (e) {
      print('❌ Error refreshing herd data: $e');
    }
  }

  Future<void> _initializeSampleData() async {
    final sampleRabbits = [
      Rabbit(
        id: 'D-101',
        name: 'Luna',
        type: RabbitType.doe,
        status: RabbitStatus.pregnant,
        location: 'Row A',
        cage: 'A-02',
        breed: 'Rex',
        notes: 'Due: Feb 10 • 5 Days left',
        dateOfBirth: DateTime(2023, 3, 15),
        weight: 4.5,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        lastBreedDate: DateTime.now().subtract(const Duration(days: 26)),
      ),
      Rabbit(
        id: 'D-105',
        name: 'Bella',
        type: RabbitType.doe,
        status: RabbitStatus.pregnant,
        location: 'Row A',
        cage: 'A-05',
        breed: 'NZ White',
        notes: 'Due: Feb 12 • 7 Days left',
        dateOfBirth: DateTime(2023, 4, 20),
        weight: 5.0,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        lastBreedDate: DateTime.now().subtract(const Duration(days: 24)),
      ),
      Rabbit(
        id: 'D-102',
        name: 'Misty',
        type: RabbitType.doe,
        status: RabbitStatus.palpateDue,
        location: 'Row A',
        cage: 'A-04',
        breed: 'Rex',
        notes: 'Day 14 Check',
        dateOfBirth: DateTime(2023, 5, 10),
        weight: 4.2,
        palpationDate: DateTime.now(),
        lastBreedDate: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Rabbit(
        id: 'D-108',
        name: 'Ginger',
        type: RabbitType.doe,
        status: RabbitStatus.nursing,
        location: 'Row B',
        cage: 'B-02',
        breed: 'Dutch',
        notes: '8 Kits • 4 Weeks old',
        dateOfBirth: DateTime(2022, 11, 5),
        weight: 4.8,
        kindleDate: DateTime.now().subtract(const Duration(days: 28)),
        currentLitterSize: 8,
        weanDate: DateTime.now().add(const Duration(days: 28)),
      ),
      Rabbit(
        id: 'D-112',
        name: 'Snowball',
        type: RabbitType.doe,
        status: RabbitStatus.open,
        location: 'Row B',
        cage: 'B-05',
        breed: 'NZ White',
        notes: 'Last weaned: Dec 12',
        dateOfBirth: DateTime(2022, 8, 15),
        weight: 5.2,
      ),
      Rabbit(
        id: 'D-115',
        name: 'Cinnamon',
        type: RabbitType.doe,
        status: RabbitStatus.resting,
        location: 'Row B',
        cage: 'B-06',
        breed: 'Rex',
        notes: 'Resting after weaning',
        dateOfBirth: DateTime(2023, 1, 10),
        weight: 4.6,
      ),
      Rabbit(
        id: 'B-01',
        name: 'Roger',
        type: RabbitType.buck,
        status: RabbitStatus.active,
        location: 'Row A',
        cage: 'A-01',
        breed: 'NZ White',
        notes: '10.5 lbs',
        dateOfBirth: DateTime(2022, 6, 10),
        weight: 10.5,
      ),
      Rabbit(
        id: 'B-02',
        name: 'Thumper',
        type: RabbitType.buck,
        status: RabbitStatus.active,
        location: 'Row A',
        cage: 'A-03',
        breed: 'Rex',
        notes: 'Proven',
        dateOfBirth: DateTime(2022, 7, 20),
        weight: 9.8,
      ),
      Rabbit(
        id: 'B-03',
        name: 'Chester',
        type: RabbitType.buck,
        status: RabbitStatus.inactive,
        location: 'Row B',
        cage: 'B-01',
        breed: 'Dutch',
        notes: 'Retired breeder',
        dateOfBirth: DateTime(2021, 5, 15),
        weight: 8.5,
      ),
    ];

    for (var rabbit in sampleRabbits) {
      await _db.insertRabbit(rabbit);
    }

    final sampleBarns = [
      Barn(
        id: 'barn_a',
        name: 'BARN A',
        rows: [
          BarnRow(
            name: 'Row A',
            cages: [
              'A-01',
              'A-02',
              'A-03',
              'A-04',
              'A-05',
              'A-06',
              'A-07',
              'A-08'
            ],
          ),
        ],
      ),
      Barn(
        id: 'barn_b',
        name: 'BARN B',
        rows: [
          BarnRow(
            name: 'Row B',
            cages: [
              'B-01',
              'B-02',
              'B-03',
              'B-04',
              'B-05',
              'B-06',
              'B-07',
              'B-08',
              'B-09',
              'B-10',
              'B-11'
            ],
          ),
        ],
      ),
      Barn(
        id: 'outdoor',
        name: 'OUTDOOR',
        rows: [
          BarnRow(
            name: 'Bank 1',
            cages: [
              '1',
              '2',
              '3',
              '4',
              '5',
              '6'
            ],
          ),
        ],
      ),
      Barn(
        id: 'quarantine',
        name: 'QUARANTINE',
        rows: [
          BarnRow(
            name: 'Quarantine',
            cages: [
              'Q-01',
              'Q-02'
            ],
          ),
        ],
      ),
    ];

    for (var barn in sampleBarns) {
      await _db.insertBarn(barn.toMap());
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

    // 1. Force evict ALL photo caches (both old and potentially new photos)
    if (rabbit.photos != null && rabbit.photos!.isNotEmpty) {
      for (var path in rabbit.photos!) {
        try {
          await FileImage(File(path)).evict();
        } catch (e) {
          print('Error evicting image cache: $e');
        }
      }
    }

    // 2. Refresh the data from the database
    await _refreshData();

    // 3. Force image cache to clear for all rabbits in the list
    for (var r in _allRabbits) {
      if (r.photos != null && r.photos!.isNotEmpty) {
        for (var path in r.photos!) {
          try {
            await FileImage(File(path)).evict();
          } catch (e) {
            print('Error evicting image cache: $e');
          }
        }
      }
    }

    // 4. Force a complete rebuild
    if (mounted) {
      setState(() {
        // Force rebuild by reassigning the list
        _allRabbits = List.from(_allRabbits);
      });
    }
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
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1E293B)),
            onPressed: _showBarnDrawer,
          ),
          title: const Text(
            'Breeders Directory',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 17,
              fontWeight: FontWeight.w600,
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
          icon: Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone)),
          onPressed: _showBarnDrawer,
        ),
        title: const Text(
          'Breeders Directory',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
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
              color: const Color(0xFF0F7B6C),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRabbitList(RabbitType.doe),
                  _buildRabbitList(RabbitType.buck),
                  _buildArchivedList(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index != 2
          ? FloatingActionButton(
              heroTag: 'herd_fab',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddRabbitScreen(),
                  ),
                );

                if (result == true) {
                  await _refreshData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🐰 Rabbit added successfully'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF0F7B6C),
                      ),
                    );
                  }
                }
              },
              backgroundColor: const Color(0xFF0F7B6C),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCleanTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSingleTab('Does', PhosphorIconsRegular.genderFemale, 0, const Color(0xFF9C6ADE)), // Purple
          _buildSingleTab('Bucks', PhosphorIconsRegular.genderMale, 1, const Color(0xFF2E7BB5)), // Blue
          _buildSingleTab('Archive', PhosphorIconsRegular.archive, 2, const Color(0xFF787774)), // Gray
        ],
      ),
    );
  }

  Widget _buildSingleTab(String label, IconData icon, int index, Color activeColor) {
    final isActive = _tabController.index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {
            _currentFilter = 'All';
            _locationFilter = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : const Color(0xFF787774),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? activeColor : const Color(0xFF787774),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndGroup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE9E9E7)),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search ID or Name...',
                  hintStyle: TextStyle(color: Color(0xFF9B9A97), fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF787774), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE9E9E7)),
              ),
              child: const Icon(Icons.view_agenda_outlined, color: Colors.black87, size: 20),
            ),
            onSelected: (value) => setState(() => _grouping = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'none', child: Text('Group: None')),
              PopupMenuItem(value: 'location', child: Text('Group: Location')),
              PopupMenuItem(value: 'breed', child: Text('Group: Breed')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF8FF),
        border: Border.all(color: const Color(0xFF2E7BB5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Color(0xFF2E7BB5)),
          const SizedBox(width: 8),
          const Text(
            'Filtering by: ',
            style: TextStyle(color: Color(0xFF2E7BB5), fontSize: 14),
          ),
          Text(
            _locationFilter!,
            style: const TextStyle(
              color: Color(0xFF2E7BB5),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _locationFilter = null),
            child: const Icon(Icons.close, size: 18, color: Color(0xFF2E7BB5)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    List<String> filters = [];

    if (_tabController.index == 0) {
      filters = [
        'All',
        'Open',
        'PalpateDue',
        'Pregnant',
        'Nursing',
        'Resting',
        'Growout',
        'Quarantine'
      ];
    } else if (_tabController.index == 1) {
      filters = [
        'All',
        'Active',
        'Inactive',
        'Growout',
        'Quarantine'
      ];
    } else {
      filters = [
        'All',
        'Sold',
        'Butchered',
        'Dead',
        'Cull'
      ];
    }

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length + (_tabController.index != 2 ? 1 : 0), // Add 1 for separator
        itemBuilder: (context, index) {
          // Add separator before Growout
          if (_tabController.index != 2) {
            final separatorIndex = _tabController.index == 0 ? 6 : 3;
            if (index == separatorIndex) {
              return Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                color: const Color(0xFFE9E9E7),
              );
            }

            // Adjust index after separator
            final adjustedIndex = index > separatorIndex ? index - 1 : index;
            final filter = filters[adjustedIndex];
            final isActive = _currentFilter == filter;

            return GestureDetector(
              onTap: () => setState(() => _currentFilter = filter),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF37352F) : Colors.white,
                  border: Border.all(
                    color: isActive ? const Color(0xFF37352F) : const Color(0xFFE9E9E7),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF787774),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }

          // Archive tab (no separator)
          final filter = filters[index];
          final isActive = _currentFilter == filter;

          return GestureDetector(
            onTap: () => setState(() => _currentFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF37352F) : Colors.white,
                border: Border.all(
                  color: isActive ? const Color(0xFF37352F) : const Color(0xFFE9E9E7),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF787774),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchivedList() {
    List<Rabbit> filtered = _archivedList.where((r) {
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: Color(0xFFE9E9E7)),
            SizedBox(height: 16),
            Text(
              'No archived rabbits',
              style: TextStyle(
                color: Color(0xFF787774),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildArchiveCard(filtered[index]),
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
                    color: const Color(0xFF0F7B6C).withOpacity(0.3),
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
                        color: const Color(0xFF0F7B6C),
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
              'Price: \$${rabbit.salePrice?.toStringAsFixed(2) ?? '0.00'}',
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
              'Yield: ${rabbit.butcherYield?.toStringAsFixed(1) ?? '0.0'} lbs',
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
              leading: const Icon(Icons.visibility_outlined, color: Color(0xFF0F7B6C)),
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
            backgroundColor: const Color(0xFF0F7B6C),
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

      if (_currentFilter != 'All') {
        final statusName = r.status.toString().split('.').last.toLowerCase();
        final filterName = _currentFilter.toLowerCase();
        if (statusName != filterName) return false;
      }

      if (_locationFilter != null) {
        if (_locationFilter == 'Unassigned') {
          if (r.location != null && r.location!.isNotEmpty && r.location != 'Unassigned') return false;
        } else {
          if (r.location != _locationFilter) return false;
        }
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
            if (_currentFilter != 'All' || _searchQuery.isNotEmpty || _locationFilter != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _currentFilter = 'All';
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
      return ListView.builder(
        padding: EdgeInsets.zero, // Changed from EdgeInsets.all(16)
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final rabbit = filtered[index];
          final photoHash = rabbit.photos?.join('_') ?? 'no_photo';

          return Dismissible(
            key: Key(rabbit.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 12, left: 0, right: 0), // Removed horizontal margin
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(0), // Changed to 0 for edge-to-edge
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 32),
            ),
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Rabbit?'),
                  content: Text('Are you sure you want to delete ${filtered[index].name}?'),
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
            },
            onDismissed: (direction) => _deleteRabbit(rabbit.id),
            child: RabbitCard(
              key: ValueKey('${rabbit.id}_$photoHash'),
              rabbit: rabbit,
              onTap: () => _showRabbitActions(rabbit),
              onLongPress: () => _navigateToDetail(rabbit),
            ),
          );
        },
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

    return ListView(
      padding: EdgeInsets.zero, // Changed from EdgeInsets.all(16)
      children: sortedKeys.map((key) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // Keep horizontal padding for headers only
              child: Row(
                children: [
                  Icon(
                    _grouping == 'location' ? Icons.location_on_outlined : Icons.pets_outlined,
                    size: 16,
                    color: key == 'Unassigned' ? const Color(0xFFD97706) : const Color(0xFF9B9A97),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9B9A97),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${groups[key]!.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...groups[key]!.map((rabbit) => RabbitCard(
                  key: ValueKey('${rabbit.id}_${DateTime.now().millisecondsSinceEpoch}_${rabbit.photos?.length ?? 0}'),
                  rabbit: rabbit,
                  onTap: () => _showRabbitActions(rabbit),
                  onLongPress: () => _navigateToDetail(rabbit),
                )),
          ],
        );
      }).toList(),
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
                                        Icon(PhosphorIcons.warehouse(PhosphorIconsStyle.duotone), color: const Color(0xFF0F7B6C), size: 20),
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
                                      color: _isBarnEditMode ? const Color(0xFF0F7B6C) : Colors.white,
                                      border: Border.all(
                                        color: _isBarnEditMode ? const Color(0xFF0F7B6C) : const Color(0xFFE9E9E7),
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
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (!_isBarnEditMode) ...[
                              _buildBarnTreeItem(
                                icon: Icons.grid_view,
                                label: 'All Locations',
                                count: _getTotalRabbits(),
                                isActive: _locationFilter == null,
                                onTap: () {
                                  setState(() => _locationFilter = null);
                                  Navigator.pop(context);
                                },
                              ),
                              _buildBarnTreeItem(
                                icon: Icons.warning_amber,
                                label: 'Unassigned',
                                count: _getUnassignedCount(),
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
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE9E9E7))),
                          ),
                          child: ElevatedButton(
                            onPressed: () => _addBarn(setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8F5F3),
                              foregroundColor: const Color(0xFF0F7B6C),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFF0F7B6C), width: 1.5),
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
          color: isActive ? const Color(0xFFE8F5F3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: const Color(0xFF0F7B6C)) : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isWarning ? const Color(0xFFD97706) : (isActive ? const Color(0xFF0F7B6C) : const Color(0xFF787774)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isWarning ? const Color(0xFFD97706) : (isActive ? const Color(0xFF0F7B6C) : Colors.black87),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFFF7F7F5),
                border: Border.all(
                  color: isActive ? const Color(0xFF0F7B6C) : const Color(0xFFE9E9E7),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF0F7B6C) : const Color(0xFF787774),
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
            color: const Color(0xFFE8F5F3),
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
              if (_isBarnEditMode && _countRabbitsInBarn(barn) == 0)
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
                        if (_countRabbitsInLocation(row.name) == 0)
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
                    count: _countRabbitsInLocation(row.name),
                    isActive: _locationFilter == row.name,
                    onTap: () {
                      setState(() => _locationFilter = row.name);
                      Navigator.pop(dialogContext);
                    },
                  ),
                if (_isBarnEditMode)
                  ...row.cages.map((cage) {
                    final cageCount = _countRabbitsInLocation(row.name, cage);
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
                          border: Border.all(color: const Color(0xFF0F7B6C)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Color(0xFF0F7B6C)),
                            SizedBox(width: 4),
                            Text(
                              'Add Cage',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F7B6C),
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
                  border: Border.all(color: const Color(0xFF0F7B6C)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF0F7B6C)),
                    SizedBox(width: 4),
                    Text(
                      'Add Row',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F7B6C),
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
    super.dispose();
  }
}
