import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../widgets/quick_info_card.dart';
import '../widgets/genetics_card.dart';
import '../widgets/parentage_card.dart';
import '../widgets/registration_card.dart';
import '../widgets/breeding_pipeline_card.dart';
import '../widgets/litter_history_card.dart';
import '../widgets/tasks_card.dart';
import '../widgets/health_records_card.dart';
import '../widgets/stats_cards.dart';
import '../widgets/notes_card.dart';
import '../widgets/pedigree_inline_card.dart';
import '../widgets/documents_card.dart';
import '../widgets/certificate_card.dart';
import '../widgets/modals/log_weight_modal.dart';
import '../widgets/modals/health_record_modal.dart';
import '../widgets/modals/move_cage_modal.dart';
import '../widgets/modals/archive_modal.dart';
import 'add_rabbit_screen.dart';

class RabbitDetailScreen extends StatefulWidget {
  final Rabbit rabbit;

  const RabbitDetailScreen({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<RabbitDetailScreen> createState() => _RabbitDetailScreenState();
}

class _RabbitDetailScreenState extends State<RabbitDetailScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _showTabShadow = false;
  late Rabbit _currentRabbit;
  int _refreshCounter = 0;
  bool _isEditingMode = false;

  // Breeding stats
  List<Litter> _litters = [];
  bool _littersLoaded = false;

  @override
  void initState() {
    super.initState();
    _currentRabbit = widget.rabbit;
    _tabController = TabController(length: 5, vsync: this);
    _scrollController.addListener(_handleScroll);
    _loadBreedingStats();
  }

  Future<void> _loadBreedingStats() async {
    try {
      final littersData = await _db.getLittersByDoe(_currentRabbit.id);

      // Also check if rabbit is a sire (for bucks)
      final db = await _db.database;
      final sireLitters = await db.query(
        'litters',
        where: 'buckId = ?',
        whereArgs: [
          _currentRabbit.id
        ],
        orderBy: 'breedDate DESC',
      );

      // Combine and deduplicate
      final allLittersData = [
        ...littersData,
        ...sireLitters
      ];
      final seenIds = <String>{};
      final uniqueLitters = allLittersData.where((l) {
        final id = l['id'] as String?;
        if (id == null || seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();

      final litters = uniqueLitters.map((data) => Litter.fromMap(data)).toList();
      litters.sort((a, b) => (b.kindleDate ?? b.breedDate).compareTo(a.kindleDate ?? a.breedDate));

      if (mounted) {
        setState(() {
          _litters = litters;
          _littersLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading breeding stats: $e');
      if (mounted) {
        setState(() => _littersLoaded = true);
      }
    }
  }

  void _handleScroll() {
    setState(() {
      _showTabShadow = _scrollController.offset > 200;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ Request Permission
  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      return status.isGranted;
    } else {
      var status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      return status.isGranted;
    }
  }

  // ✅ Pick Image
  Future<void> _pickImage(ImageSource source) async {
    try {
      bool hasPermission = await _requestPermission(source);
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera ? 'Camera permission is required' : 'Gallery permission is required',
            ),
            backgroundColor: const Color(0xFFD44C47),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        // Update rabbit with new photo
        final updatedRabbit = _currentRabbit.copyWith(
          photos: [
            image.path
          ],
        );

        await _db.updateRabbit(updatedRabbit);

        setState(() {
          _currentRabbit = updatedRabbit;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Color(0xFF6366F1),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: const Color(0xFFD44C47),
        ),
      );
    }
  }

  // ✅ Show Image Picker Options
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
            const SizedBox(height: 20),
            const Text(
              'Change Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _buildPhotoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            _buildPhotoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_currentRabbit.photos != null && _currentRabbit.photos!.isNotEmpty)
              _buildPhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                onTap: () async {
                  Navigator.pop(context);
                  final updatedRabbit = _currentRabbit.copyWith(
                    photos: [],
                  );
                  await _db.updateRabbit(updatedRabbit);
                  setState(() => _currentRabbit = updatedRabbit);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile picture removed'),
                      backgroundColor: Color(0xFF6366F1),
                    ),
                  );
                },
                isDestructive: true,
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ Photo Option Widget
  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                fontSize: 15,
                color: isDestructive ? const Color(0xFFD44C47) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(),
            _buildHeroSection(),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileTab(),
            _buildBreedingTab(),
            _buildTasksTab(),
            _buildStatsTab(),
            _buildRecordsTab(),
          ],
        ),
      ),
    );
  }

  // AppBar
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF37352F)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '${_currentRabbit.name} (${_currentRabbit.id})',
        style: const TextStyle(
          color: Color(0xFF37352F),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Color(0xFF37352F)),
          onPressed: _openActionSheet,
        ),
      ],
    );
  }

  // Hero Section
  Widget _buildHeroSection() {
    final bool hasPhoto = _currentRabbit.photos != null && _currentRabbit.photos!.isNotEmpty;
    final String? photoPath = hasPhoto ? _currentRabbit.photos!.first : null;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
        ),
        child: Row(
          children: [
            // ✅ Avatar with Tap to Change
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF7F7F5),
                      border: Border.all(color: _currentRabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5), width: 2),
                      image: hasPhoto && photoPath != null && File(photoPath).existsSync()
                          ? DecorationImage(
                              image: FileImage(File(photoPath)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasPhoto && photoPath != null && File(photoPath).existsSync()
                        ? null
                        : Icon(
                            _currentRabbit.type == RabbitType.doe ? Icons.female : Icons.male,
                            size: 36,
                            color: _currentRabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _currentRabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5), width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 12,
                        color: _currentRabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentRabbit.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF37352F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Text(
                        '#${_currentRabbit.id}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF787774)),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFF787774))),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentRabbit.type == RabbitType.doe ? Icons.female : Icons.male,
                            size: 14,
                            color: _currentRabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentRabbit.type == RabbitType.doe ? 'Doe' : 'Buck',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _currentRabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
                            ),
                          ),
                        ],
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFF787774))),
                      Text(
                        _currentRabbit.breed,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF787774)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(
                        _getStatusText(_currentRabbit.status),
                        _getStatusColor(_currentRabbit.status),
                        _getStatusTextColor(_currentRabbit.status),
                      ),
                      _buildBadge(
                        _currentRabbit.location ?? 'Unassigned',
                        const Color(0xFFF7F7F5),
                        const Color(0xFF787774),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // Tab Bar
  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: false,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
            insets: EdgeInsets.symmetric(horizontal: 12),
          ),
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: const Color(0xFF1E293B),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          labelPadding: EdgeInsets.zero, // ✅ Remove label padding
          padding: EdgeInsets.zero, // ✅ Remove tab bar padding
          indicatorPadding: EdgeInsets.zero,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Breeding'),
            Tab(text: 'Tasks'),
            Tab(text: 'Stats'),
            Tab(text: 'Records'),
          ],
        ),
        showShadow: _showTabShadow,
      ),
    );
  }

  // Tab Contents
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuickInfoCard(
            key: ValueKey('${_currentRabbit.id}_$_refreshCounter'),
            rabbit: _currentRabbit,
            isEditing: false,
          ),
          const SizedBox(height: 16),
          GeneticsCard(rabbit: _currentRabbit, isEditing: false),
          const SizedBox(height: 16),
          ParentageCard(
            rabbit: _currentRabbit,
            onUpdated: () async {
              final refreshed = await _db.getRabbit(_currentRabbit.id);
              if (refreshed != null && mounted) {
                setState(() => _currentRabbit = refreshed);
              }
            },
          ),
          if (SettingsService.instance.showRabbitryEnabled) ...[
            const SizedBox(height: 16),
            RegistrationCard(rabbit: _currentRabbit),
          ],
        ],
      ),
    );
  }

  Widget _buildBreedingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          BreedingPipelineCard(rabbit: _currentRabbit),
          const SizedBox(height: 16),
          _buildBreedingStats(),
          const SizedBox(height: 16),
          LitterHistoryCard(rabbit: _currentRabbit),
        ],
      ),
    );
  }

  Widget _buildBreedingStats() {
    // Litters count
    final litterCount = _litters.length;

    // Avg litter size (totalKits)
    String avgSize = '--';
    if (_litters.isNotEmpty) {
      final littersWithKits = _litters.where((l) => (l.totalKits ?? 0) > 0).toList();
      if (littersWithKits.isNotEmpty) {
        final total = littersWithKits.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
        avgSize = (total / littersWithKits.length).toStringAsFixed(1);
      }
    }

    // Survival rate (alive / total across all litters)
    String survival = '--';
    if (_litters.isNotEmpty) {
      final totalBorn = _litters.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
      final totalAlive = _litters.fold<int>(0, (sum, l) => sum + (l.aliveKits ?? 0));
      if (totalBorn > 0) {
        survival = '${((totalAlive / totalBorn) * 100).round()}%';
      }
    }

    // Avg gestation (days between breedDate and kindleDate)
    String avgGest = '--';
    if (_litters.isNotEmpty) {
      final littersWithKindle = _litters.where((l) => l.kindleDate != null).toList();
      if (littersWithKindle.isNotEmpty) {
        final totalDays = littersWithKindle.fold<int>(
          0,
          (sum, l) => sum + l.kindleDate!.difference(l.breedDate).inDays,
        );
        avgGest = '${(totalDays / littersWithKindle.length).round()}d';
      }
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard(_littersLoaded ? '$litterCount' : '--', 'Litters')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(_littersLoaded ? avgSize : '--', 'Avg Size')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(_littersLoaded ? survival : '--', 'Survival')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(_littersLoaded ? avgGest : '--', 'Avg Gest.')),
      ],
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37352F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF787774)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TasksCard(rabbit: _currentRabbit),
          const SizedBox(height: 16),
          ScheduleCard(rabbit: _currentRabbit),
          const SizedBox(height: 16),
          HealthRecordsCard(rabbit: _currentRabbit),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StatsCards(
        rabbit: _currentRabbit,
        onAddTransaction: () => _showAddTransactionDialog(),
        onViewAllTransactions: () => _navigateToTransactions(),
      ),
    );
  }

// Add Transaction Dialog
  void _showAddTransactionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Transaction',
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
                    // Type Selection
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeButton('Income', true, const Color(0xFF6B9E78)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTypeButton('Expense', false, const Color(0xFF8B5CF6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Amount
                    const Text(
                      'AMOUNT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: FormatUtils.currencyHint,
                        prefixText: FormatUtils.currencySymbol,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Category
                    const Text(
                      'CATEGORY',
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
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'feed', child: Text('Feed')),
                        DropdownMenuItem(value: 'medical', child: Text('Medical')),
                        DropdownMenuItem(value: 'sale', child: Text('Sale')),
                        DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 20),

                    // Description
                    const Text(
                      'DESCRIPTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter details...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date
                    const Text(
                      'DATE',
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
                        await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Jan 20, 2026',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF787774)),
                          ],
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
                        content: Text('Transaction added successfully'),
                        backgroundColor: Color(0xFF6366F1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Transaction',
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

  Widget _buildTypeButton(String label, bool isSelected, Color color) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? color : const Color(0xFF787774),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToTransactions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full transaction history - Coming soon'),
        backgroundColor: Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRecordsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          NotesCard(rabbit: _currentRabbit),
          const SizedBox(height: 16),
          PedigreeInlineCard(
            rabbit: _currentRabbit,
            onUpdated: () async {
              final updated = await DatabaseService().getRabbit(_currentRabbit.id);
              if (updated != null && mounted) {
                setState(() => _currentRabbit = updated);
              }
            },
          ),
          const SizedBox(height: 16),
          DocumentsCard(rabbit: _currentRabbit),
          const SizedBox(height: 16),
          CertificateCard(rabbit: _currentRabbit),
        ],
      ),
    );
  }

  // Helper Methods
  String _getStatusText(RabbitStatus status) {
    switch (status) {
      case RabbitStatus.open:
        return 'Open';
      case RabbitStatus.pregnant:
        return 'Bred';
      case RabbitStatus.palpateDue:
        return 'Bred';
      case RabbitStatus.nursing:
        return 'Nursing';
      case RabbitStatus.resting:
        return 'Resting';
      case RabbitStatus.active:
        return 'Active';
      case RabbitStatus.inactive:
        return 'Inactive';
      case RabbitStatus.growout:
        return 'Grow Out';
      case RabbitStatus.quarantine:
        return 'Quarantine';
      case RabbitStatus.archived:
        return 'Archived';
    }
  }

  Color _getStatusColor(RabbitStatus status) {
    switch (status) {
      case RabbitStatus.open:
        return const Color(0xFFEDF3EE);
      case RabbitStatus.pregnant:
        return const Color(0xFFF3E8FF);
      case RabbitStatus.palpateDue:
        return const Color(0xFFFFF9E6);
      case RabbitStatus.nursing:
        return const Color(0xFFEBF2FA);
      case RabbitStatus.resting:
        return const Color(0xFFF7F7F5);
      case RabbitStatus.active:
        return const Color(0xFFEDF3EE);
      case RabbitStatus.inactive:
        return const Color(0xFFF7F7F5);
      case RabbitStatus.growout:
        return const Color(0xFFFFF9E6);
      case RabbitStatus.quarantine:
        return const Color(0xFFFDE8E8);
      case RabbitStatus.archived:
        return const Color(0xFFF7F7F5);
    }
  }

  Color _getStatusTextColor(RabbitStatus status) {
    switch (status) {
      case RabbitStatus.open:
        return const Color(0xFF6B9E78);
      case RabbitStatus.pregnant:
        return const Color(0xFF9C6ADE);
      case RabbitStatus.palpateDue:
        return const Color(0xFF8B5CF6);
      case RabbitStatus.nursing:
        return const Color(0xFF5B8AD0);
      case RabbitStatus.resting:
        return const Color(0xFF787774);
      case RabbitStatus.active:
        return const Color(0xFF6B9E78);
      case RabbitStatus.inactive:
        return const Color(0xFF787774);
      case RabbitStatus.growout:
        return const Color(0xFF8B5CF6);
      case RabbitStatus.quarantine:
        return const Color(0xFFC47070);
      case RabbitStatus.archived:
        return const Color(0xFF9B9A97);
    }
  }

  // Action Methods
  void _openActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_currentRabbit.name} (${_currentRabbit.id})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF787774),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuItem(Icons.edit, 'Edit Rabbit', _showEditRabbitScreen),
                    _buildMenuItem(Icons.swap_horiz, 'Move Cage', _showMoveCageModal),
                    _buildMenuItem(Icons.scale, 'Log Weight', _showLogWeightModal),
                    _buildMenuItem(Icons.medical_services, 'Add Health Record', _showHealthRecordModal),
                    _buildMenuItem(Icons.camera_alt, 'Change Photo', _showImagePickerOptions),
                    const Divider(),
                    _buildMenuItem(Icons.archive, 'Archive Rabbit', _showArchiveModal, isDestructive: true),
                    _buildMenuItem(Icons.delete_forever, 'Delete Rabbit', _confirmDeleteRabbit, isDestructive: true),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  /// Refresh rabbit data from DB after an action
  Future<void> _refreshRabbitData() async {
    final updated = await _db.getRabbit(_currentRabbit.id);
    if (updated != null && mounted) {
      setState(() {
        _currentRabbit = updated;
        _refreshCounter++;
      });
    }
    _loadBreedingStats();
  }

  void _confirmDeleteRabbit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Rabbit'),
        content: Text(
          'Are you sure you want to permanently delete "${_currentRabbit.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              await _db.deleteRabbit(_currentRabbit.id);
              if (mounted) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context, true); // pop detail screen
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('${_currentRabbit.name} deleted'),
                    backgroundColor: const Color(0xFFC47070),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFC47070), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showEditRabbitScreen() async {
    Navigator.pop(context); // close action sheet
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRabbitScreen(editRabbit: _currentRabbit),
      ),
    );
    if (result == true) {
      await _refreshRabbitData();
    }
  }

  void _showMoveCageModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoveCageModal(
        rabbit: _currentRabbit,
        onComplete: () {
          Navigator.pop(context);
          _refreshRabbitData();
        },
      ),
    );
  }

  void _showLogWeightModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogWeightModal(
        rabbit: _currentRabbit,
        onComplete: () {
          Navigator.pop(context);
          _refreshRabbitData();
        },
      ),
    );
  }

  void _showHealthRecordModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HealthRecordModal(
        rabbit: _currentRabbit,
        onComplete: () {
          Navigator.pop(context);
          _refreshRabbitData();
        },
      ),
    );
  }

  void _showArchiveModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArchiveModal(
        rabbit: _currentRabbit,
        onComplete: () {
          Navigator.pop(context);
          // Go back to herd screen after archiving
          Navigator.pop(context);
        },
      ),
    );
  }

  void _printCageCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🖨️ Printing cage card...'),
        backgroundColor: Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFC47070) : const Color(0xFF787774),
              size: 24,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? const Color(0xFFC47070) : const Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tab Bar Delegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool showShadow;

  _TabBarDelegate(this.tabBar, {this.showShadow = false});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
        boxShadow: showShadow
            ? [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))
              ]
            : null,
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return showShadow != oldDelegate.showShadow;
  }
}
