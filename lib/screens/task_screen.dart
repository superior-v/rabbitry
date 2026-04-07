import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:io';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../models/rabbit.dart';
import '../widgets/modals/log_weight_modal.dart';
import '../widgets/modals/confirm_pregnancy_modal.dart';
import '../widgets/modals/log_birth_modal.dart';
import '../widgets/modals/wean_litter_modal.dart';
import '../widgets/modals/move_cage_modal.dart';
import '../widgets/modals/archive_modal.dart';
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

// Primary color constant for theme (mapping to the premium palette)
const kPrimary = kLilacDeep;
const kSuccess = Color(0xFF4CAF50);
const kError = Color(0xFFD94452);

class TaskScreen extends StatefulWidget {
  final VoidCallback? onScheduleAdded;
  const TaskScreen({Key? key, this.onScheduleAdded}) : super(key: key);

  @override
  TaskScreenState createState() => TaskScreenState();
}

class TaskScreenState extends State<TaskScreen> {
  final DatabaseService _db = DatabaseService();
  String _selectedCategory = 'All'; // Matches the tabs in tasks.html
  String _breedFilter = 'All';
  String _searchQuery = '';
  Set<int> _ignoredTasks = {};
  Set<String> _expandedGroups = {};
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _showUpcoming = false; // #7: Hidden by default

  List<Map<String, dynamic>> _todayTasks = [];
  List<Map<String, dynamic>> _upcomingTasks = [];
  List<String> _availableBreeds = [];
  Map<String, String> _rabbitBreedMap = {};

  int _activeLitters = 0;
  int _breederCount = 0;
  int _growOutCount = 0;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _breedingPlans = [];
  Map<String, String> _rabbitNameMap = {};

  @override
  void initState() {
    super.initState();
    _initTasks();
  }

  Future<void> _initTasks() async {
    if (!_hasLoadedOnce) setState(() => _isLoading = true);
    try { await _db.cleanupCompletedScheduledTasks(); } catch (e) {}
    try { await _db.backfillMissingPipelineTasks(); } catch (e) {}
    await _loadScheduledTasks();
    await _loadStats();
    await _loadContacts();
    await _loadBreedingPlans();
    if (mounted) setState(() { _isLoading = false; _hasLoadedOnce = true; });
  }

  // Public method called from HomeDashboardScreen when Task tab is tapped
  Future<void> refresh() async {
    await _loadScheduledTasks();
    await _loadStats();
    await _loadContacts();
    await _loadBreedingPlans();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _db.getAllContacts();
      if (mounted) setState(() => _contacts = contacts);
    } catch (e) {}
  }

  Future<void> _loadBreedingPlans() async {
    try {
      final plans = await _db.getAllBreedingPlans();
      if (mounted) setState(() => _breedingPlans = plans);
    } catch (e) {}
  }


  Future<void> _loadStats() async {
    try {
      final litters = await _db.getLitters();
      final rabbits = await _db.getAllRabbits();
      if (mounted) setState(() {
        _activeLitters = litters.where((l) => l.status == 'Nursing' || l.status == 'nursing' || l.status == 'Weaned' || l.status == 'weaned').length;
        _breederCount = rabbits.where((r) => (r.type == RabbitType.doe || r.type == RabbitType.buck) && r.status != RabbitStatus.archived).length;
        _growOutCount = rabbits.where((r) => r.status == RabbitStatus.growout).length;
      });
    } catch (e) {}
  }

  Future<void> _loadScheduledTasks() async {
    try {
      final allRabbits = await _db.getAllRabbits();
      final breedMap = <String, String>{};
      final breedSet = <String>{};
      for (final r in allRabbits) {
        if (r.breed.isNotEmpty) { breedMap[r.id] = r.breed; breedSet.add(r.breed); }
      }
      _rabbitBreedMap = breedMap;
      _rabbitNameMap = {for (final r in allRabbits) r.id: r.name};
      _availableBreeds = breedSet.toList()..sort();

      final today = await _db.getTasksDueToday();
      final upcoming = await _db.getUpcomingScheduledTasks();
      List<Map<String, dynamic>> pipelineToday = [];
      List<Map<String, dynamic>> pipelineUpcoming = [];
      try {
        pipelineToday = await _db.getPipelineTasksDueToday();
        pipelineUpcoming = await _db.getUpcomingPipelineTasks();
      } catch (e) {}

      _enrichTasksWithBreed(today);
      _enrichTasksWithBreed(upcoming);
      _enrichTasksWithBreed(pipelineToday);
      _enrichTasksWithBreed(pipelineUpcoming);

      final mergedToday = [...today, ...pipelineToday];
      mergedToday.sort((a, b) {
        final aDate = DateTime.tryParse(a['dueDate'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['dueDate'] ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      final mergedUpcoming = [...upcoming, ...pipelineUpcoming];
      mergedUpcoming.sort((a, b) {
        final aDate = DateTime.tryParse(a['dueDate'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['dueDate'] ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      if (mounted) setState(() { _todayTasks = mergedToday; _upcomingTasks = mergedUpcoming; });
    } catch (e) {}
  }

  void _enrichTasksWithBreed(List<Map<String, dynamic>> tasks) {
    for (var task in tasks) {
      final rabbitId = task['rabbitId']?.toString();
      if (rabbitId != null && _rabbitBreedMap.containsKey(rabbitId)) {
        task['breed'] = _rabbitBreedMap[rabbitId]; continue;
      }
      final entities = task['linkedEntities'];
      if (entities is List && entities.isNotEmpty) {
        for (var e in entities) {
          if (e is Map) {
            final eId = e['id']?.toString();
            if (eId != null && _rabbitBreedMap.containsKey(eId)) { task['breed'] = _rabbitBreedMap[eId]; break; }
          }
        }
      }
    }
  }

  // #12: Skip finance popup for Reproduction/Pregnancy tasks
  static const _noCostCategories = {'Reproduction', 'Pregnancy', 'Kindling', 'Mating', 'Weaning', 'reproduction', 'pregnancy'};
  static const _noCostTypes = {'palpation', 'nestbox', 'nesting', 'kindle', 'birth', 'wean', 'mating', 'open_breeding'};

  Future<void> _showTaskCostDialog(Map<String, dynamic> task) async {
    final taskCategory = task['category']?.toString();
    final taskType = task['taskType']?.toString();

    // Skip cost dialog for reproduction-type tasks or specific pipeline types
    if ((taskCategory != null && _noCostCategories.contains(taskCategory)) ||
        (taskType != null && _noCostTypes.contains(taskType))) {
      await _completeTaskDirect(task);
      return;
    }

    final costController = TextEditingController();
    final taskTitle = task['title']?.toString() ?? task['name']?.toString() ?? 'Task';
    final rabbitId = task['rabbitId']?.toString();

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle_outline, color: kPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Task Complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(taskTitle, style: const TextStyle(fontSize: 14, color: Color(0xFF787774))),
          const SizedBox(height: 16),
          const Text('Any cost spent on this task?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${FormatUtils.currencySymbol}',
              prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 0.0), child: const Text('No Cost', style: TextStyle(color: Color(0xFF787774)))),
          ElevatedButton(
            onPressed: () { final cost = double.tryParse(costController.text) ?? 0.0; Navigator.pop(ctx, cost); },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final cost = result > 0 ? result : null;
    final isPipeline = task['isPipelineTask'] == true;
    final taskTitle2 = task['title']?.toString() ?? task['name']?.toString() ?? 'Task';

    if (isPipeline) {
      final taskId = task['id']?.toString();
      if (taskId != null) {
        if (cost != null) {
          await _db.completeTaskWithCost(taskId, cost, rabbitId, taskTitle: taskTitle2, taskCategory: taskCategory);
        } else { await _db.completeTask(taskId); }
      }
    } else {
      final taskId = task['id'] as int?;
      if (taskId == null) return;
      if (cost != null) {
        await _db.markScheduledTaskCompletedWithCost(taskId, cost, taskTitle: taskTitle2, taskCategory: taskCategory, rabbitId: rabbitId);
      } else { await _db.markScheduledTaskCompleted(taskId); }
    }
    await _loadScheduledTasks();
    await _loadStats();
  }

  Future<void> _completeTaskDirect(Map<String, dynamic> task) async {
    final isPipeline = task['isPipelineTask'] == true;
    if (isPipeline) {
      final taskId = task['id']?.toString();
      if (taskId != null) await _db.completeTask(taskId);
    } else {
      final taskId = task['id'] as int?;
      if (taskId != null) await _db.markScheduledTaskCompleted(taskId);
    }
    await _loadScheduledTasks();
    await _loadStats();
  }

  Future<void> _handleTaskComplete(Map<String, dynamic> task, {bool reload = true}) async {
    await _showTaskCostDialog(task);
  }

  Future<void> _handleTaskUncomplete(Map<String, dynamic> task, {bool reload = true}) async {
    final isPipeline = task['isPipelineTask'] == true;
    if (isPipeline) {
      final taskId = task['id']?.toString();
      if (taskId != null) {
        final db = await _db.database;
        await db.update('tasks', {'completed': 0, 'completedAt': null}, where: 'id = ?', whereArgs: [taskId]);
      }
    } else {
      final taskId = task['id'] as int?;
      if (taskId == null) return;
      await _db.unmarkScheduledTaskCompleted(taskId);
    }
    if (reload) await _loadScheduledTasks();
  }

  void _handleTaskIgnore(dynamic taskId) {
    if (taskId == null) return;
    final trackId = taskId is int ? taskId : taskId.hashCode;
    setState(() {
      if (_ignoredTasks.contains(trackId)) _ignoredTasks.remove(trackId);
      else _ignoredTasks.add(trackId);
    });
  }

  Future<void> _handleTaskTap(String? taskType, String? rabbitId, String title) async {
    if (taskType == null) return;
    Rabbit? rabbit;
    if (rabbitId != null) {
      rabbit = await _db.getRabbit(rabbitId);
      if (rabbit == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rabbit not found'), backgroundColor: Color(0xFFD44C47))); return; }
    }

    switch (taskType) {
      case 'weight':
        if (rabbit != null) showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (context) => LogWeightModal(rabbit: rabbit!, onComplete: () { refresh(); }));
        break;
      case 'palpation':
        if (rabbit != null) showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (context) => ConfirmPregnancyModal(doe: rabbit!, onComplete: () { refresh(); }));
        break;
      case 'nesting':
        if (rabbit != null) showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (context) => MoveCageModal(rabbit: rabbit!, onComplete: () { refresh(); }));
        break;
      case 'kindle': case 'birth':
        if (rabbit != null) showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (context) => LogBirthModal(doe: rabbit!, onComplete: () { refresh(); }));
        break;
      case 'wean':
        if (rabbit != null) showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (context) => WeanLitterModal(doe: rabbit!, onComplete: () { refresh(); }));
        break;
      case 'butcher':
        if (rabbit != null) showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (context) => ArchiveModal(rabbit: rabbit!, onComplete: () { refresh(); }));
        break;
      default: break;
    }
  }

  int _getFilteredTodayTasksCount() {
    int count = 0;
    for (var task in _todayTasks) {
      if (task['completedAt'] != null && SettingsService.instance.autoRemoveCompletedTasks) continue;
      if (_shouldShowCategory(task['category'] ?? 'Operations') && _shouldShowBreed(task['breed']?.toString()) && _matchesSearch(task['name'] ?? task['task'] ?? 'Task', null, _getTaskLocation(task))) {
        count++;
      }
    }
    return count;
  }

  int _getFilteredUpcomingTasksCount() {
    int count = 0;
    for (var task in _upcomingTasks) {
      if (task['completedAt'] != null && SettingsService.instance.autoRemoveCompletedTasks) continue;
      if (_shouldShowCategory(task['category'] ?? 'Operations') && _shouldShowBreed(task['breed']?.toString()) && _matchesSearch(task['name'] ?? task['task'] ?? 'Task', null, _getTaskLocation(task))) {
        count++;
      }
    }
    return count;
  }

  bool _isFilterActive() => _selectedCategory != 'All' || _breedFilter != 'All' || _searchQuery.isNotEmpty;

  bool _shouldShowCategory(String? taskCategory) {
    if (_selectedCategory == 'All') return true;
    final cat = taskCategory?.toLowerCase() ?? '';
    switch (_selectedCategory) {
      case 'Reproduction':
        return ['mating', 'kindling', 'weaning', 'pregnancy', 'reproduction'].contains(cat);
      case 'Health':
        return ['medical', 'health', 'weight'].contains(cat);
      case 'Operations':
        return ['housing', 'operations', 'butchering', 'butcher'].contains(cat);
      default:
        return taskCategory == _selectedCategory;
    }
  }

  bool _shouldShowBreed(String? breed) {
    if (_breedFilter == 'All') return true;
    return breed == _breedFilter;
  }

  bool _matchesSearch(String title, String? breed, String? location) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return title.toLowerCase().contains(query) || (breed?.toLowerCase().contains(query) ?? false) || (location?.toLowerCase().contains(query) ?? false);
  }

  String _getTaskLocation(Map<String, dynamic> task) {
    if (task['linkType'] == 'unlinked') return 'Unlinked';
    final entities = task['linkedEntities'];
    if (entities is List && entities.isNotEmpty) {
      final names = entities.map((e) => e is Map ? e['name']?.toString() : null).where((n) => n != null && n.isNotEmpty).toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    final lt = task['linkType']?.toString() ?? '';
    return lt.isEmpty ? 'Unlinked' : lt[0].toUpperCase() + lt.substring(1);
  }

  bool _isTaskOverdue(String? dueDateStr) {
    if (dueDateStr == null) return false;
    final dueDate = DateTime.tryParse(dueDateStr);
    return dueDate != null && dueDate.isBefore(DateTime.now());
  }

  String _formatDueDate(DateTime date) => FormatUtils.formatDateShort(date);

  Color _getCategoryColor(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (['reproduction', 'mating', 'kindling', 'weaning', 'pregnancy'].contains(c)) return kPinkWash;
    if (['health', 'medical', 'weight'].contains(c)) return kLilacWash;
    if (['operations', 'housing', 'butchering'].contains(c)) return kNeutral200;
    return kNeutral100;
  }

  Color _getCategoryTextColor(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (['reproduction', 'matting', 'kindling', 'weaning', 'pregnancy'].contains(c)) return const Color(0xFFD4809A);
    if (['health', 'medical', 'weight'].contains(c)) return kLilacDeep;
    if (['operations', 'housing', 'butchering'].contains(c)) return kNeutral700;
    return kNeutral600;
  }

  IconData _getCategoryIcon(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (['reproduction', 'mating', 'pregnancy'].contains(c)) return PhosphorIcons.heart(PhosphorIconsStyle.duotone);
    if (['kindling', 'birth'].contains(c)) return PhosphorIcons.baby(PhosphorIconsStyle.duotone);
    if (['health', 'medical'].contains(c)) return PhosphorIcons.firstAid(PhosphorIconsStyle.duotone);
    if (['weight'].contains(c)) return PhosphorIcons.scales(PhosphorIconsStyle.duotone);
    if (['operations', 'housing'].contains(c)) return PhosphorIcons.broom(PhosphorIconsStyle.duotone);
    if (['butchering'].contains(c)) return PhosphorIcons.scissors(PhosphorIconsStyle.duotone);
    return PhosphorIcons.clipboardText(PhosphorIconsStyle.duotone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildHeader(),
      body: (_isLoading && !_hasLoadedOnce)
          ? const Center(child: CircularProgressIndicator(color: kLilacDeep, strokeWidth: 2))
          : Column(
              children: [
                _buildTabs(),
                Expanded(child: _buildTaskList()),
              ],
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: kLilacWash,
      elevation: 0,
      centerTitle: false,
      leadingWidth: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const SizedBox(width: 8),
          Icon(PhosphorIcons.clipboardText(PhosphorIconsStyle.duotone), color: kLilacDeep, size: 28),
          const SizedBox(width: 10),
          const Text(
            'Tasks',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 19,
              color: kLilacText,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _showFilterModal(),
          icon: Stack(
            children: [
              Icon(PhosphorIcons.funnel(PhosphorIconsStyle.duotone), color: kLilacDeep),
              if (_breedFilter != 'All')
                Positioned(
                  top: 0,
                  right: 0,
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
        ),
        IconButton(
          onPressed: () => _showSearchModal(),
          icon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone), color: kLilacDeep),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kLilacLight, height: 1),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildTabPill('All'),
            const SizedBox(width: 8),
            _buildTabPill('Reproduction'),
            const SizedBox(width: 8),
            _buildTabPill('Health'),
            const SizedBox(width: 8),
            _buildTabPill('Operations'),
            const SizedBox(width: 8),
            _buildTabPill('Breeding Plan'),
            const SizedBox(width: 8),
            _buildTabPill('Contacts'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(String label) {
    final isActive = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? kLilacDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? kLilacDeep : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? Colors.white : kNeutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: null,
      onPressed: () => _showNewScheduleDialog(context),
      backgroundColor: kLilacDeep,
      elevation: 4,
      shape: const CircleBorder(),
      child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.duotone), color: Colors.white, size: 24),
    );
  }

  Widget _buildTaskList() {
    if (_selectedCategory == 'Breeding Plan') {
      return _buildBreedingPlanView();
    }
    if (_selectedCategory == 'Contacts') {
      return _buildContactsView();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // DUE SECTION
        _buildSectionTitle('DUE', _getFilteredTodayTasksCount()),
        const SizedBox(height: 12),
        ..._getFilteredTodayTasks(),
        if (_getFilteredTodayTasks().isEmpty && !_isLoading)
          _buildEmptyState(_isFilterActive() ? 'No tasks match your filter' : 'No tasks due currently'),

        const SizedBox(height: 24),

        // UPCOMING SECTION
        _buildUpcomingSectionHeader(),
        if (_showUpcoming) ...[
          const SizedBox(height: 12),
          ..._getFilteredUpcomingTasks(),
          if (_getFilteredUpcomingTasks().isEmpty && !_isLoading)
            _buildEmptyState(_isFilterActive() ? 'No upcoming tasks match your filter' : 'No upcoming tasks'),
        ],

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kNeutral500,
              letterSpacing: 0.6,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: kLilacWash,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kLilacText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSectionHeader() {
    return GestureDetector(
      onTap: () => setState(() => _showUpcoming = !_showUpcoming),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'UPCOMING',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kNeutral500,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: kNeutral100,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${_getFilteredUpcomingTasksCount()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kNeutral600,
                    ),
                  ),
                ),
              ],
            ),
            Icon(
              _showUpcoming ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
              size: 16,
              color: kNeutral500,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getFilteredTodayTasks() {
    List<Map<String, dynamic>> filtered = [];
    for (var task in _todayTasks) {
      if (task['completedAt'] != null && SettingsService.instance.autoRemoveCompletedTasks) continue;
      if (!_shouldShowCategory(task['category'] ?? 'Operations')) continue;
      if (!_shouldShowBreed(task['breed']?.toString())) continue;
      if (!_matchesSearch(task['name'] ?? task['task'] ?? 'Task', null, _getTaskLocation(task))) continue;
      filtered.add(task);
    }
    return _buildGroupedTaskWidgets(filtered, isToday: true);
  }

  List<Widget> _getFilteredUpcomingTasks() {
    List<Map<String, dynamic>> filtered = [];
    for (var task in _upcomingTasks) {
      if (task['completedAt'] != null && SettingsService.instance.autoRemoveCompletedTasks) continue;
      if (!_shouldShowCategory(task['category'] ?? 'Operations')) continue;
      if (!_shouldShowBreed(task['breed']?.toString())) continue;
      if (!_matchesSearch(task['name'] ?? task['task'] ?? 'Task', null, _getTaskLocation(task))) continue;
      filtered.add(task);
    }
    return _buildGroupedTaskWidgets(filtered, isToday: false);
  }

  List<Widget> _buildGroupedTaskWidgets(List<Map<String, dynamic>> tasks, {required bool isToday}) {
    List<Widget> widgets = [];
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var task in tasks) {
      final name = task['name'] ?? task['task'] ?? 'Task';
      groups.putIfAbsent(name, () => []);
      groups[name]!.add(task);
    }
    for (var entry in groups.entries) {
      final groupName = entry.key;
      final groupTasks = entry.value;
      final firstTask = groupTasks.first;
      final taskCategory = firstTask['category'] ?? 'Operations';
      if (groupTasks.length == 1) {
        final entities = firstTask['linkedEntities'];
        final entityCount = (entities is List) ? entities.length : 0;
        if (entityCount > 1) {
          widgets.add(_buildGroupTaskFromEntities(task: firstTask, isToday: isToday));
        } else {
          final taskLocation = _getTaskLocation(firstTask);
          final dueDate = DateTime.tryParse(firstTask['dueDate'] ?? '');
          final dateStr = isToday ? 'Today' : (dueDate != null ? _formatDueDate(dueDate) : 'Upcoming');
          widgets.add(_buildSingleTask(title: groupName, category: taskCategory, categoryColor: _getCategoryColor(taskCategory), categoryTextColor: _getCategoryTextColor(taskCategory), icon: _getCategoryIcon(taskCategory), breed: null, location: taskLocation, date: dateStr, isOverdue: isToday ? _isTaskOverdue(firstTask['dueDate']) : false, taskType: firstTask['taskType']?.toString() ?? 'scheduled', rabbitId: firstTask['rabbitId']?.toString(), task: firstTask));
        }
      } else {
        final dueDate = DateTime.tryParse(firstTask['dueDate'] ?? '');
        final dateStr = isToday ? 'Today' : (dueDate != null ? _formatDueDate(dueDate) : 'Upcoming');
        widgets.add(_buildGroupTaskFromMultiple(title: groupName, category: taskCategory, date: dateStr, isOverdue: isToday ? _isTaskOverdue(firstTask['dueDate']) : false, tasks: groupTasks));
      }
      widgets.add(const SizedBox(height: 0)); // Spacing handled by card margin
    }
    if (widgets.isNotEmpty && widgets.last is SizedBox) widgets.removeLast();
    return widgets;
  }

  Widget _buildSingleTask({
    required String title,
    required String category,
    required Color categoryColor,
    required Color categoryTextColor,
    required IconData icon,
    required String? breed,
    required String location,
    required String date,
    required bool isOverdue,
    String? taskType,
    String? rabbitId,
    Map<String, dynamic>? task,
  }) {
    final isCompleted = task?['completedAt'] != null;
    final rawId = task?['id'];
    final trackId = rawId is int ? rawId : rawId?.hashCode;
    final isIgnored = trackId != null && _ignoredTasks.contains(trackId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10), // Matches task-card margin-bottom in html
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Column 1: Checkbox (matches 32px column in html)
          SizedBox(
            width: 32,
            child: GestureDetector(
              onTap: isIgnored
                  ? null
                  : () {
                      if (task != null) {
                        if (isCompleted)
                          _handleTaskUncomplete(task);
                        else
                          _handleTaskComplete(task);
                      }
                    },
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2), // Matches checkbox-wrap padding-top in html
                decoration: BoxDecoration(
                  color: isCompleted ? kLilacDeep : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? kLilacDeep : kNeutral400,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Center(
                        child: Icon(Icons.check, size: 12, color: Colors.white),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8), // Gap: 10px (including margin) - matches html
          // Column 2: Content (1fr)
          Expanded(
            child: GestureDetector(
              onTap: isIgnored ? null : () => _handleTaskTap(taskType, rabbitId ?? task?['rabbitId']?.toString(), title),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: (isCompleted || isIgnored) ? kNeutral500 : kNeutral900,
                            decoration: (isCompleted || isIgnored) ? TextDecoration.lineThrough : null,
                            height: 1.35, // Matches line-height in html
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 13,
                          color: isOverdue ? kError : kNeutral600,
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildTag(category, categoryColor, categoryTextColor, icon: icon),
                      if (breed != null) _buildTag(breed, kNeutral200, kNeutral700),
                      if (location.isNotEmpty)
                        Text(
                          '• $location',
                          style: const TextStyle(fontSize: 13, color: kNeutral500),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Column 3: Options Menu (matches 36px column in html)
          SizedBox(
            width: 36,
            child: IconButton(
              onPressed: () => _showTaskOptionsSheet(task),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(PhosphorIcons.dotsThreeVertical(), color: kNeutral400, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color bgColor, Color textColor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskOptionsSheet(Map<String, dynamic>? task) {
    if (task == null) return;
    final isCompleted = task['completedAt'] != null;
    final rawId = task['id'];
    final trackId = rawId is int ? rawId : rawId?.hashCode;
    final isIgnored = trackId != null && _ignoredTasks.contains(trackId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: kNeutral300,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Task Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kNeutral900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.duotone), color: kNeutral500),
                  ),
                ],
              ),
            ),
            _buildActionRow(
              'Edit Task',
              PhosphorIcons.pencilSimple(PhosphorIconsStyle.duotone),
              kNeutral700,
              () {
                Navigator.pop(context);
                final isPipeline = task['isPipelineTask'] == true;
                if (!isPipeline) {
                  _showEditTaskDialog(task);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('System tasks cannot be edited directly.'), backgroundColor: kPrimary),
                  );
                }
              },
            ),
            _buildActionRow(
              isCompleted ? 'Mark Incomplete' : 'Mark Complete',
              isCompleted ? PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.duotone) : PhosphorIcons.checkCircle(PhosphorIconsStyle.duotone),
              kLilacDeep,
              () {
                Navigator.pop(context);
                if (isCompleted)
                  _handleTaskUncomplete(task);
                else
                  _handleTaskComplete(task);
              },
            ),
            _buildActionRow(
              isIgnored ? 'Restore Task' : 'Ignore Task',
              isIgnored ? PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.duotone) : PhosphorIcons.prohibit(PhosphorIconsStyle.duotone),
              isIgnored ? kLilacDeep : kNeutral700,
              () {
                Navigator.pop(context);
                _handleTaskIgnore(rawId);
              },
            ),
            _buildActionRow(
              'Delete Task',
              PhosphorIcons.trash(PhosphorIconsStyle.duotone),
              kError,
              () async {
                Navigator.pop(context);
                final isPipeline = task['isPipelineTask'] == true;
                if (isPipeline) {
                  await _db.deleteTask(task['id'].toString());
                } else {
                  final taskId = task['id'] as int?;
                  if (taskId != null) await _db.deleteScheduledTask(taskId);
                }
                await _loadScheduledTasks();
                await _loadStats();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTaskFromMultiple({required String title, required String category, required String date, required bool isOverdue, required List<Map<String, dynamic>> tasks}) {
    final categoryColor = _getCategoryColor(category);
    final categoryTextColor = _getCategoryTextColor(category);
    final icon = _getCategoryIcon(category);
    final groupId = '$title-group';
    final isExpanded = _expandedGroups.contains(groupId);
    final allIgnored = tasks.every((t) { final id = t['id']; final trackId = id is int ? id : id?.hashCode; return trackId != null && _ignoredTasks.contains(trackId); });
    final subTasks = tasks.map((t) {
      final entities = t['linkedEntities'];
      String name = 'Unknown'; String loc = '';
      if (entities is List && entities.isNotEmpty) {
        final first = entities.first;
        if (first is Map) { name = first['name']?.toString() ?? 'Unknown'; loc = first['cage']?.toString() ?? first['barn']?.toString() ?? ''; }
      }
      return {'dbId': t['id'], 'name': name, 'location': loc.isNotEmpty ? loc : _getTaskLocation(t), 'task': t};
    }).toList();
    return _buildGroupContainer(title: title, count: tasks.length, category: category, categoryColor: categoryColor, categoryTextColor: categoryTextColor, icon: icon, date: date, isOverdue: isOverdue, groupId: groupId, isExpanded: isExpanded, allIgnored: allIgnored, subTasks: subTasks,
      onGroupIgnore: () => setState(() { if (allIgnored) { for (var t in tasks) { final id = t['id']; final tid = id is int ? id : id?.hashCode; if (tid != null) _ignoredTasks.remove(tid); } } else { for (var t in tasks) { final id = t['id']; final tid = id is int ? id : id?.hashCode; if (tid != null) _ignoredTasks.add(tid); } } }),
      onGroupComplete: () async { final allCompleted = tasks.every((t) => t['completedAt'] != null); if (allCompleted) { for (var t in tasks) await _handleTaskUncomplete(t, reload: false); } else { for (var t in tasks) { if (t['completedAt'] == null) await _handleTaskComplete(t, reload: false); } } await _loadScheduledTasks(); await _loadStats(); });
  }

  Widget _buildGroupTaskFromEntities({required Map<String, dynamic> task, required bool isToday}) {
    final title = task['name'] ?? task['task'] ?? 'Task';
    final category = task['category'] ?? 'Operations';
    final rawId = task['id'];
    final trackId = rawId is int ? rawId : rawId?.hashCode;
    final dueDate = DateTime.tryParse(task['dueDate'] ?? '');
    final dateStr = isToday ? 'Today' : (dueDate != null ? _formatDueDate(dueDate) : 'Upcoming');
    final isOverdue = isToday ? _isTaskOverdue(task['dueDate']) : false;
    final entities = task['linkedEntities'] as List? ?? [];
    final groupId = '$title-entity-group';
    final isExpanded = _expandedGroups.contains(groupId);
    final isIgnored = trackId != null && _ignoredTasks.contains(trackId);
    final subTasks = entities.map((e) { final em = e is Map ? e : {}; return {'dbId': rawId, 'name': em['name']?.toString() ?? 'Unknown', 'location': em['cage']?.toString() ?? em['barn']?.toString() ?? '', 'task': task}; }).toList();
    return _buildGroupContainer(title: title, count: entities.length, category: category, categoryColor: _getCategoryColor(category), categoryTextColor: _getCategoryTextColor(category), icon: _getCategoryIcon(category), date: dateStr, isOverdue: isOverdue, groupId: groupId, isExpanded: isExpanded, allIgnored: isIgnored, subTasks: subTasks,
      onGroupIgnore: rawId != null ? () => _handleTaskIgnore(rawId) : null,
      onGroupComplete: () async { if (task['completedAt'] != null) await _handleTaskUncomplete(task); else await _handleTaskComplete(task); });
  }
  Widget _buildGroupContainer({
    required String title,
    required int count,
    required String category,
    required Color categoryColor,
    required Color categoryTextColor,
    required IconData icon,
    required String date,
    required bool isOverdue,
    required String groupId,
    required bool isExpanded,
    required bool allIgnored,
    required List<Map<String, dynamic>> subTasks,
    VoidCallback? onGroupIgnore,
    VoidCallback? onGroupComplete,
  }) {
    final isGroupCompleted = subTasks.every((sub) => (sub['task'] as Map<String, dynamic>?)?['completedAt'] != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded)
                _expandedGroups.remove(groupId);
              else
                _expandedGroups.add(groupId);
            }),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: allIgnored ? null : onGroupComplete,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isGroupCompleted ? kLilacDeep : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isGroupCompleted ? kLilacDeep : kNeutral400,
                          width: 2,
                        ),
                      ),
                      child: isGroupCompleted
                          ? const Center(
                              child: Icon(Icons.check, size: 16, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '$title ($count)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: (isGroupCompleted || allIgnored) ? kNeutral500 : kNeutral900,
                                  decoration: (isGroupCompleted || allIgnored) ? TextDecoration.lineThrough : null,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue ? kError : kNeutral600,
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Icon(
                                isExpanded ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
                                size: 18,
                                color: kNeutral400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildTag(category, categoryColor, categoryTextColor, icon: icon),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              decoration: const BoxDecoration(
                color: kNeutral50,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                children: subTasks.map((sub) {
                  final subName = sub['name'] as String? ?? 'Unknown';
                  final subLoc = sub['location'] as String? ?? '';
                  final subRawId = sub['dbId'];
                  final subTask = sub['task'] as Map<String, dynamic>?;
                  final isSubCompleted = subTask?['completedAt'] != null;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: kNeutral200)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        GestureDetector(
                          onTap: () {
                            if (subTask == null) return;
                            if (isSubCompleted)
                              _handleTaskUncomplete(subTask);
                            else
                              _handleTaskComplete(subTask);
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSubCompleted ? kLilacDeep : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSubCompleted ? kLilacDeep : kNeutral400,
                                width: 2,
                              ),
                            ),
                            child: isSubCompleted
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isSubCompleted ? kNeutral500 : kNeutral900,
                                  decoration: isSubCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (subLoc.isNotEmpty)
                                Text(
                                  subLoc,
                                  style: const TextStyle(fontSize: 12, color: kNeutral500),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            _isFilterActive() ? PhosphorIcons.funnelX() : PhosphorIcons.checkCircle(),
            size: 48,
            color: kLilacLight,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: kNeutral500,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isFilterActive()) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => setState(() {
                _breedFilter = 'All';
                _searchQuery = '';
                _selectedCategory = 'All';
              }),
              child: const Text(
                'Clear Filters',
                style: TextStyle(
                  color: kLilacDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreedingPlanView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildSectionTitle('PLANNED MATINGS', _breedingPlans.length),
        const SizedBox(height: 16),
        if (_breedingPlans.isEmpty)
          _buildEmptyState('No planned matings scheduled.')
        else
          ..._breedingPlans.map((plan) => _buildBreedingPlanCard(plan)).toList(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showAddBreedingPlanDialog(),
            icon: Icon(PhosphorIcons.plus(), size: 18),
            label: const Text('Add Breeding Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kLilacDeep,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: kLilac),
              ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildContactsView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildSectionTitle('BREEDER CONTACTS', _contacts.length),
        const SizedBox(height: 16),
        if (_contacts.isEmpty)
          _buildEmptyState('No contacts added yet.')
        else
          ..._contacts.map((contact) => _buildContactCard(contact)).toList(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showAddContactDialog(),
            icon: Icon(PhosphorIcons.userPlus(), size: 18),
            label: const Text('Add Contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kLilacDeep,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: kLilac),
              ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kLilacWash,
            child: Text(
              (contact['name'] as String).substring(0, 1).toUpperCase(),
              style: const TextStyle(color: kLilacDeep, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name'],
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kNeutral900),
                ),
                if (contact['farmName'] != null && contact['farmName'].isNotEmpty)
                  Text(
                    contact['farmName'],
                    style: const TextStyle(fontSize: 12, color: kNeutral600),
                  ),
                const SizedBox(height: 4),
                if (contact['phone'] != null && contact['phone'].isNotEmpty)
                  Row(
                    children: [
                      Icon(PhosphorIcons.phone(), size: 12, color: kNeutral400),
                      const SizedBox(width: 4),
                      Text(contact['phone'], style: const TextStyle(fontSize: 12, color: kNeutral500)),
                    ],
                  ),
              ],
            ),
          ),
          _buildContactMenu(contact),
        ],
      ),
    );
  }

  Widget _buildContactMenu(Map<String, dynamic> contact) {
    return PopupMenuButton<String>(
      icon: Icon(PhosphorIcons.dotsThreeVertical(), color: kNeutral400),
      onSelected: (val) {
        if (val == 'edit') _showAddContactDialog(existing: contact);
        if (val == 'delete') _deleteContact(contact['id']);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kError))),
      ],
    );
  }

  Future<void> _deleteContact(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: const Text('Are you sure you want to remove this contact?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: kError))),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteContact(id);
      _loadContacts();
    }
  }

  Widget _buildBreedingPlanCard(Map<String, dynamic> plan) {
    final doeName = _rabbitNameMap[plan['doeId']] ?? 'Unknown Doe';
    final buckName = _rabbitNameMap[plan['buckId']] ?? 'Unknown Buck';
    final date = DateTime.tryParse(plan['plannedDate'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kPinkWash, borderRadius: BorderRadius.circular(10)),
            child: Icon(PhosphorIcons.heart(), color: kPink, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$doeName × $buckName',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kNeutral900),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(PhosphorIcons.calendar(), size: 14, color: kNeutral400),
                    const SizedBox(width: 4),
                    Text(
                      date != null ? FormatUtils.formatDateShort(date) : 'No Date',
                      style: const TextStyle(fontSize: 13, color: kNeutral600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.trash(), color: kNeutral400, size: 20),
            onPressed: () => _deleteBreedingPlan(plan['id']),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBreedingPlan(String id) async {
    await _db.deleteBreedingPlan(id);
    _loadBreedingPlans();
  }

  void _showSearchModal() {
    final searchController = TextEditingController(text: _searchQuery);
    showDialog(context: context, builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Search Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: searchController, autofocus: true,
            decoration: InputDecoration(hintText: 'Search by task name, breed, location...', prefixIcon: const Icon(Icons.search, color: Color(0xFF787774)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            onSubmitted: (value) { setState(() => _searchQuery = value.trim()); Navigator.pop(context); }),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () { searchController.clear(); setState(() => _searchQuery = ''); Navigator.pop(context); }, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF787774), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Clear'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () { setState(() => _searchQuery = searchController.text.trim()); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Search'))),
          ]),
        ]),
      ),
    ));
  }

  void _showFilterModal() {
    final allBreeds = ['All', ..._availableBreeds];
    showDialog(context: context, builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Material(color: Colors.transparent, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Filter by Breed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (_breedFilter != 'All') TextButton(onPressed: () { setState(() => _breedFilter = 'All'); Navigator.pop(context); }, child: const Text('Clear', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600)))
            else IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 8),
          if (_availableBreeds.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No breeds found.\nAdd breeds to your rabbits first.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF9B9A97)))))
          else ConstrainedBox(constraints: const BoxConstraints(maxHeight: 400), child: SingleChildScrollView(child: Column(children: allBreeds.map((breed) {
            final isSelected = _breedFilter == breed;
            return InkWell(onTap: () { setState(() => _breedFilter = breed); Navigator.pop(context); }, borderRadius: BorderRadius.circular(12),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: isSelected ? kPrimary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: isSelected ? Border.all(color: kPrimary) : null),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(breed, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? kPrimary : Colors.black87)),
                  if (isSelected) const Icon(Icons.check, size: 18, color: kPrimary),
                ])));
          }).toList()))),
        ])),
      ),
    ));
  }

  void _showNewScheduleDialog(BuildContext context) async {
    String selectedCategory = 'Operations';
    String? selectedTask;
    String selectedFrequency = 'Weekly';
    String selectedLinkType = 'unlinked';
    bool isCustomTask = false;
    final customTaskController = TextEditingController();
    final _db2 = DatabaseService();
    List<Map<String, dynamic>> taskDirectoryItems = [];
    try { taskDirectoryItems = await _db2.getAllTaskDirectoryItems(); } catch (e) {}

    List<Map<String, String>> linkedEntities = [];
    final entityData = <String, List<Map<String, String>>>{'rabbit': [], 'litter': [], 'kit': []};
    try {
      final allRabbits = await _db2.getAllRabbits();
      entityData['rabbit'] = allRabbits.map((r) => {'id': r.id, 'name': r.name, 'code': r.cage ?? r.location ?? 'No cage'}).toList();
    } catch (e) {}

    showDialog(context: context, barrierDismissible: true, builder: (BuildContext dialogContext) {
      return StatefulBuilder(builder: (context, setDialogState) {
        List<String> directoryTasks = taskDirectoryItems.where((t) => (t['category'] as String).toLowerCase() == selectedCategory.toLowerCase()).map((t) => t['name'] as String).toList();
        List<String> currentTaskOptions;
        if (directoryTasks.isNotEmpty) { currentTaskOptions = directoryTasks; }
        else {
          if (selectedCategory == 'Operations') currentTaskOptions = ['Clean Trays', 'Top Off Feed', 'Check Water', 'Deep Clean'];
          else if (selectedCategory == 'Health') currentTaskOptions = ['Nail Trim', 'Health Check', 'Weighing', 'Ear Check'];
          else if (selectedCategory == 'Butchering') currentTaskOptions = ['Schedule Butcher', 'Prep Equipment', 'Process'];
          else if (selectedCategory == 'Pregnancy') currentTaskOptions = ['Palpation', 'Add Nest Box', 'Check for Kindle'];
          else currentTaskOptions = ['Inventory Check', 'General Maintenance'];
        }

        BoxDecoration inputDec() => BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12));

        return Dialog(backgroundColor: Colors.white, surfaceTintColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), insetPadding: const EdgeInsets.all(16),
          child: Container(width: double.infinity, constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.9), padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('New Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle), child: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)))),
              ]),
              const SizedBox(height: 20),
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: inputDec(),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: selectedCategory, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  items: ['Operations', 'Health', if (SettingsService.instance.meatProductionEnabled) 'Butchering', 'Pregnancy', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (val) => setDialogState(() { selectedCategory = val!; selectedTask = null; isCustomTask = false; })))),
              const SizedBox(height: 14),
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Task', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: inputDec(),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: isCustomTask ? 'custom' : selectedTask, hint: const Text('Select a task...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))), isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  items: [...currentTaskOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))), const DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: kPrimary)))],
                  onChanged: (val) => setDialogState(() { if (val == 'custom') { isCustomTask = true; selectedTask = null; } else { isCustomTask = false; selectedTask = val; } })))),
              if (isCustomTask) ...[const SizedBox(height: 8), TextField(controller: customTaskController, decoration: InputDecoration(hintText: 'Enter custom task name...', hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary))))],
              const SizedBox(height: 14),
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Frequency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: inputDec(),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: selectedFrequency, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  items: ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly', 'Once'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (val) => setDialogState(() => selectedFrequency = val!)))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () async {
                  final finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? 'Unknown Task');
                  if (finalTaskName.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47))); return; }
                  try {
                    await DatabaseService().insertScheduledTask({'name': finalTaskName, 'category': selectedCategory, 'frequency': selectedFrequency, 'linkType': selectedLinkType, 'linkedEntities': linkedEntities});
                    Navigator.pop(dialogContext);
                    await _loadScheduledTasks();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule Saved'), backgroundColor: kPrimary));
                  } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: const Color(0xFFD44C47))); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              )),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))))),
            ]))),
        );
      });
    });
  }

  Future<void> _showAddContactDialog({Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final farmController = TextEditingController(text: existing?['farmName'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    final emailController = TextEditingController(text: existing?['email'] ?? '');
    final notesController = TextEditingController(text: existing?['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Add Contact' : 'Edit Contact',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNeutral900),
                ),
                const SizedBox(height: 20),
                _buildDialogField('Name *', nameController),
                _buildDialogField('Farm Name', farmController),
                _buildDialogField('Phone', phoneController),
                _buildDialogField('Email', emailController),
                _buildDialogField('Notes', notesController, maxLines: 3),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        final contact = {
                          'id': existing?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          'name': nameController.text.trim(),
                          'farmName': farmController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'email': emailController.text.trim(),
                          'notes': notesController.text.trim(),
                          'createdAt': existing?['createdAt'] ?? DateTime.now().toIso8601String(),
                        };
                        if (existing == null) {
                          await _db.insertContact(contact);
                        } else {
                          await _db.updateContact(contact);
                        }
                        Navigator.pop(ctx);
                        _loadContacts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLilacDeep,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save Contact'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kNeutral300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacDeep)),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBreedingPlanDialog() async {
    final rabbits = await _db.getAllRabbits();
    final does = rabbits.where((r) => r.type == RabbitType.doe && r.status != RabbitStatus.archived).toList();
    final bucks = rabbits.where((r) => r.type == RabbitType.buck && r.status != RabbitStatus.archived).toList();
    
    String? selectedDoeId;
    String? selectedBuckId;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Future Breeding Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNeutral900),
                ),
                const SizedBox(height: 20),
                const Text('Select Doe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral600)),
                DropdownButton<String>(
                  value: selectedDoeId,
                  hint: const Text('Choose Doe...', style: TextStyle(fontSize: 14)),
                  isExpanded: true,
                  items: does.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                  onChanged: (val) => setDialogState(() => selectedDoeId = val),
                  underline: Container(height: 1, color: kNeutral300),
                ),
                const SizedBox(height: 16),
                const Text('Select Buck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral600)),
                DropdownButton<String>(
                  value: selectedBuckId,
                  hint: const Text('Choose Buck...', style: TextStyle(fontSize: 14)),
                  isExpanded: true,
                  items: bucks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setDialogState(() => selectedBuckId = val),
                  underline: Container(height: 1, color: kNeutral300),
                ),
                const SizedBox(height: 16),
                const Text('Planned Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral600)),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kNeutral300))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(FormatUtils.formatDateShort(selectedDate), style: const TextStyle(fontSize: 14)),
                        Icon(PhosphorIcons.calendar(), size: 16, color: kNeutral500),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedDoeId == null || selectedBuckId == null) return;
                        await _db.insertBreedingPlan({
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'doeId': selectedDoeId!,
                          'buckId': selectedBuckId!,
                          'plannedDate': selectedDate.toIso8601String(),
                          'createdAt': DateTime.now().toIso8601String(),
                        });
                        Navigator.pop(ctx);
                        _loadBreedingPlans();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLilacDeep,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save Plan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) async {
    final taskId = task['id'] as int?;
    if (taskId == null) return;

    String selectedCategory = task['category']?.toString() ?? 'Operations';
    String finalTaskName = task['name']?.toString() ?? task['task']?.toString() ?? '';
    String selectedFrequency = task['frequency']?.toString() ?? 'Weekly';
    final taskNameController = TextEditingController(text: finalTaskName);
    final _db2 = DatabaseService();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          BoxDecoration inputDec() => BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              );

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.9),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Edit Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Task Title', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                    TextField(
                      controller: taskNameController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: inputDec(),
                        child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                items: ['Operations', 'Health', if (SettingsService.instance.meatProductionEnabled) 'Butchering', 'Pregnancy', 'Other']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) => setDialogState(() => selectedCategory = val!)))),
                    const SizedBox(height: 14),
                    const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Frequency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: inputDec(),
                        child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                                value: selectedFrequency,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                items: ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly', 'Once']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) => setDialogState(() => selectedFrequency = val!)))),
                    const SizedBox(height: 24),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (taskNameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a task name'), backgroundColor: Color(0xFFD44C47)));
                              return;
                            }
                            try {
                              final db = await _db2.database;
                              await db.update(
                                'scheduled_tasks',
                                {'name': taskNameController.text.trim(), 'category': selectedCategory, 'frequency': selectedFrequency},
                                where: 'id = ?',
                                whereArgs: [taskId],
                              );
                              Navigator.pop(dialogContext);
                              await _loadScheduledTasks();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Updated'), backgroundColor: kPrimary));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $e'), backgroundColor: const Color(0xFFD44C47)));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        )),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))))),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
