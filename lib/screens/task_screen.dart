import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:io';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../models/rabbit.dart';
import '../services/notification_service.dart';
import '../widgets/modals/log_weight_modal.dart';
import '../widgets/modals/confirm_pregnancy_modal.dart';
import '../widgets/modals/log_birth_modal.dart';
import '../widgets/modals/wean_litter_modal.dart';
import '../widgets/modals/move_cage_modal.dart';
import '../widgets/modals/archive_modal.dart';
import '../models/transaction.dart' as finance_model;
import 'home_dashboard_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/modals/log_breeding_modal.dart';

// Primary color constant for theme (mapping to the premium palette)
const kPrimary = kLilacDeep;
const kSuccess = Color(0xFF4CAF50);
const kError = Color(0xFFD94452);
const kTaskHeaderPurple = Color(0xFFE6BEFE);

class TaskScreen extends StatefulWidget {
  final VoidCallback? onScheduleAdded;
  const TaskScreen({Key? key, this.onScheduleAdded}) : super(key: key);

  @override
  TaskScreenState createState() => TaskScreenState();
}

class TaskScreenState extends State<TaskScreen> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
    try {
      await _db.cleanupCompletedScheduledTasks();
    } catch (e) {}
    try {
      await _db.backfillMissingPipelineTasks();
    } catch (e) {}
    await _loadScheduledTasks();
    await _loadStats();
    await _loadContacts();
    await _loadBreedingPlans();
    if (mounted)
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
      });
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
      if (mounted)
        setState(() {
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
        if (r.breed.isNotEmpty) {
          breedMap[r.id] = r.breed;
          breedSet.add(r.breed);
        }
      }
      _rabbitBreedMap = breedMap;
      _rabbitNameMap = {
        for (final r in allRabbits)
          r.id: (r.breederPrefix != null && r.breederPrefix!.trim().isNotEmpty)
              ? '${r.breederPrefix!.trim()} ${r.name.trim()}'
              : r.name.trim()
      };
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

      final mergedToday = [
        ...today,
        ...pipelineToday
      ];
      mergedToday.sort((a, b) {
        final aDate = DateTime.tryParse(a['dueDate'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['dueDate'] ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      final mergedUpcoming = [
        ...upcoming,
        ...pipelineUpcoming
      ];
      mergedUpcoming.sort((a, b) {
        final aDate = DateTime.tryParse(a['dueDate'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['dueDate'] ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      if (mounted) {
        setState(() {
          _todayTasks = mergedToday;
          _upcomingTasks = mergedUpcoming;
        });
      }

      // Update daily digest notifications with latest task counts
      NotificationService.instance.scheduleDailyDigest().catchError((e) {
        print('🔔 Error updating daily digest from task_screen: $e');
      });
    } catch (e) {}
  }

  void _enrichTasksWithBreed(List<Map<String, dynamic>> tasks) {
    for (var task in tasks) {
      final rabbitId = task['rabbitId']?.toString();
      if (rabbitId != null && _rabbitBreedMap.containsKey(rabbitId)) {
        task['breed'] = _rabbitBreedMap[rabbitId];
        continue;
      }
      final entities = task['linkedEntities'];
      if (entities is List && entities.isNotEmpty) {
        for (var e in entities) {
          if (e is Map) {
            final eId = e['id']?.toString();
            if (eId != null && _rabbitBreedMap.containsKey(eId)) {
              task['breed'] = _rabbitBreedMap[eId];
              break;
            }
          }
        }
      }
    }
  }

  // #12: Skip finance popup for Reproduction/Pregnancy tasks
  static const _noCostCategories = {
    'Reproduction',
    'Pregnancy',
    'Kindling',
    'Mating',
    'Weaning',
    'reproduction',
    'pregnancy'
  };
  static const _noCostTypes = {
    'palpation',
    'nestbox',
    'nesting',
    'kindle',
    'birth',
    'wean',
    'mating',
    'open_breeding'
  };

  Future<void> _showTaskCostDialog(Map<String, dynamic> task) async {
    final isPipeline = task['isPipelineTask'] == true;

    // Manual (scheduled) tasks should complete directly without asking for cost.
    if (!isPipeline) {
      await _completeTaskDirect(task);
      return;
    }

    final taskCategory = task['category']?.toString();
    final taskType = task['taskType']?.toString();

    // Skip cost dialog for reproduction-type tasks or specific pipeline types
    if ((taskCategory != null && _noCostCategories.contains(taskCategory)) || (taskType != null && _noCostTypes.contains(taskType))) {
      await _completeTaskDirect(task);
      return;
    }

    final costController = TextEditingController();
    final taskTitle = task['title']?.toString() ?? task['name']?.toString() ?? 'Task';
    final rabbitId = task['rabbitId']?.toString();

    finance_model.TransactionType selectedType = finance_model.TransactionType.expense;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (selectedType == finance_model.TransactionType.income ? kSuccess : kPrimary).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(selectedType == finance_model.TransactionType.income ? Icons.add_chart_rounded : Icons.check_circle_outline, color: selectedType == finance_model.TransactionType.income ? kSuccess : kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Complete Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(taskTitle, style: const TextStyle(fontSize: 14, color: Color(0xFF787774))),
            const SizedBox(height: 20),

            // Toggle for Income/Expense
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kNeutral100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedType = finance_model.TransactionType.expense),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedType == finance_model.TransactionType.expense ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: selectedType == finance_model.TransactionType.expense
                              ? [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Text('Expense', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selectedType == finance_model.TransactionType.expense ? kPrimary : kNeutral500)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedType = finance_model.TransactionType.income),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedType == finance_model.TransactionType.income ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: selectedType == finance_model.TransactionType.income
                              ? [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Text('Income', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selectedType == finance_model.TransactionType.income ? kSuccess : kNeutral500)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(selectedType == finance_model.TransactionType.income ? 'Amount received?' : 'Any cost spent?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: selectedType == finance_model.TransactionType.income ? kSuccess : kPrimary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, {
                      'amount': 0.0,
                      'type': selectedType
                    }),
                child: const Text('No Amount', style: TextStyle(color: Color(0xFF787774)))),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(costController.text) ?? 0.0;
                Navigator.pop(ctx, {
                  'amount': amount,
                  'type': selectedType
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedType == finance_model.TransactionType.income ? kSuccess : kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final amount = result['amount'] as double;
    final type = result['type'] as finance_model.TransactionType;
    final isPageReloadNeeded = amount > 0;

    final taskTitle2 = task['title']?.toString() ?? task['name']?.toString() ?? 'Task';

    if (isPipeline) {
      final taskId = task['id']?.toString();
      if (taskId != null) {
        if (amount > 0) {
          await _db.completeTaskWithCost(taskId, amount, rabbitId, taskTitle: taskTitle2, taskCategory: taskCategory, type: type);
        } else {
          await _db.completeTask(taskId);
        }
      }
    } else {
      final taskId = task['id'] as int?;
      if (taskId == null) return;
      if (amount > 0) {
        await _db.markScheduledTaskCompletedWithCost(taskId, amount, taskTitle: taskTitle2, taskCategory: taskCategory, rabbitId: rabbitId, type: type);
      } else {
        await _db.markScheduledTaskCompleted(taskId);
      }
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
        await db.update(
            'tasks',
            {
              'completed': 0,
              'completedAt': null
            },
            where: 'id = ?',
            whereArgs: [
              taskId
            ]);
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
      if (_ignoredTasks.contains(trackId))
        _ignoredTasks.remove(trackId);
      else
        _ignoredTasks.add(trackId);
    });
  }

  Future<void> _handleTaskTap(String? taskType, String? rabbitId, String title) async {
    if (taskType == null) return;
    Rabbit? rabbit;
    if (rabbitId != null) {
      rabbit = await _db.getRabbit(rabbitId);
      if (rabbit == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rabbit not found'), backgroundColor: Color(0xFFD44C47)));
        return;
      }
    }

    switch (taskType) {
      case 'weight':
        if (rabbit != null)
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => LogWeightModal(
                  rabbit: rabbit!,
                  onComplete: () {
                    refresh();
                  }));
        break;
      case 'palpation':
        if (rabbit != null)
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              enableDrag: false,
              backgroundColor: Colors.transparent,
              builder: (context) => ConfirmPregnancyModal(
                  doe: rabbit!,
                  onComplete: () {
                    refresh();
                  }));
        break;
      case 'nesting':
        if (rabbit != null)
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => MoveCageModal(
                  rabbit: rabbit!,
                  onComplete: () {
                    refresh();
                  }));
        break;
      case 'kindle':
      case 'birth':
        if (rabbit != null)
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              enableDrag: false,
              backgroundColor: Colors.transparent,
              builder: (context) => LogBirthModal(
                  doe: rabbit!,
                  onComplete: () {
                    refresh();
                  }));
        break;
      case 'wean':
        if (rabbit != null)
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => WeanLitterModal(
                  doe: rabbit!,
                  onComplete: () {
                    refresh();
                  }));
        break;
      case 'butcher':
        if (rabbit != null)
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ArchiveModal(
                  rabbit: rabbit!,
                  onComplete: () {
                    refresh();
                  }));
        break;
      default:
        break;
    }
  }

  int _getFilteredTodayTasksCount() {
    int count = 0;
    for (var task in _todayTasks) {
      if (task['completedAt'] != null) continue;
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
      if (task['completedAt'] != null) continue;
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
      case 'Breeding':
        return [
          'breeding',
          'mating',
          'kindling',
          'weaning',
          'pregnancy',
          'reproduction',
          'birth',
          'palpation',
          'nestbox',
          'open_breeding'
        ].contains(cat);
      case 'Health':
        return [
          'medical',
          'health',
          'weight',
          'quarantine',
          'quarantine_end',
          'nail trim'
        ].contains(cat);
      case 'Operations':
        return [
          'housing',
          'operations',
          'butchering',
          'butcher',
          'custom',
          'general',
          'maintenance',
          'other'
        ].contains(cat);
      default:
        return taskCategory?.toLowerCase() == _selectedCategory.toLowerCase();
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
    return kNeutral100;
  }

  Color _getCategoryTextColor(String? cat) {
    return kNeutral700;
  }

  IconData _getCategoryIcon(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if ([
      'reproduction',
      'mating',
      'pregnancy'
    ].contains(c)) return PhosphorIcons.heart(PhosphorIconsStyle.duotone);
    if ([
      'kindling',
      'birth'
    ].contains(c)) return PhosphorIcons.baby(PhosphorIconsStyle.duotone);
    if ([
      'health',
      'medical'
    ].contains(c)) return PhosphorIcons.firstAid(PhosphorIconsStyle.duotone);
    if ([
      'weight'
    ].contains(c)) return PhosphorIcons.scales(PhosphorIconsStyle.duotone);
    if ([
      'operations',
      'housing'
    ].contains(c)) return PhosphorIcons.broom(PhosphorIconsStyle.duotone);
    if ([
      'butchering'
    ].contains(c)) return PhosphorIcons.scissors(PhosphorIconsStyle.duotone);
    return PhosphorIcons.clipboardText(PhosphorIconsStyle.duotone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEDAFE),
      appBar: _buildHeader(),
      body: (_isLoading && !_hasLoadedOnce)
          ? const Center(child: CircularProgressIndicator(color: kNeutral700, strokeWidth: 2))
          : Column(
              children: [
                _buildTabs(),
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
                    child: _buildTaskList(),
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: const Color(0xFFE6BEFE),
      elevation: 0,
      centerTitle: true,
      leadingWidth: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.checkSquareOffset(PhosphorIconsStyle.duotone), color: const Color(0xFF5A4880), size: 24),
          const SizedBox(width: 8),
          const Text(
            'Tasks',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Color(0xFF4F4F56),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _showFilterModal(),
          icon: Stack(
            children: [
              Icon(PhosphorIcons.funnel(PhosphorIconsStyle.duotone), color: const Color(0xFF787880)),
              if (_breedFilter != 'All')
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: kNeutral700,
                      shape: BoxShape.circle,
                      border: Border.all(color: kTaskHeaderPurple, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showSearchModal(),
          icon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone), color: const Color(0xFF787880)),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kNeutral300, height: 1),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: const Color(0xFF8F8A90),
      height: 46,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildTabPill('All'),
            const SizedBox(width: 20),
            _buildTabPill('Operations'),
            const SizedBox(width: 20),
            _buildTabPill('Breeding'),
            const SizedBox(width: 20),
            _buildTabPill('Health'),
            const SizedBox(width: 20),
            _buildTabPill('Breeding Plan'),
            const SizedBox(width: 20),
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
            label.toUpperCase(),
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
  }

  void _onSwipeGreyBar(bool isLeftSwipe) {
    const categories = [
      'All',
      'Operations',
      'Breeding',
      'Health',
      'Breeding Plan',
      'Contacts'
    ];
    int currentIndex = categories.indexOf(_selectedCategory);
    if (currentIndex == -1) currentIndex = 0;

    if (isLeftSwipe) {
      if (currentIndex < categories.length - 1) {
        setState(() => _selectedCategory = categories[currentIndex + 1]);
      }
    } else {
      if (currentIndex > 0) {
        setState(() => _selectedCategory = categories[currentIndex - 1]);
      }
    }
  }

  Widget _buildFAB() {
    return SizedBox(
      width: 46,
      height: 46,
      child: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          if (_selectedCategory == 'Breeding Plan') {
            _showAddBreedingPlanDialog();
          } else if (_selectedCategory == 'Contacts') {
            _showAddContactDialog();
          } else {
            _showNewScheduleDialog(context);
          }
        },
        backgroundColor: const Color(0xFFE6BEFE),
        elevation: 4,
        shape: const CircleBorder(),
        child: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget header,
    required List<Widget> tasks,
    required bool isEmpty,
    required String emptyText,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: header,
          ),
          const SizedBox(height: 6),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(emptyText, style: TextStyle(fontSize: 13, color: kNeutral500)),
            )
          else
            ...tasks,
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_selectedCategory == 'Breeding Plan') {
      return _buildBreedingPlanView();
    }
    if (_selectedCategory == 'Contacts') {
      return _buildContactsView();
    }

    final todayTasks = _getFilteredTodayTasks();
    final upcomingTasks = _getFilteredUpcomingTasks();
    final archivedTasks = _getFilteredArchivedTasks();

    return Container(
      color: const Color(0xFFEEDAFE),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        children: [
          // DUE SECTION IN LIGHT GREY CARD
          _buildSectionCard(
            header: _buildSectionTitle('TODAY & OVERDUE', _getFilteredTodayTasksCount()),
            tasks: todayTasks,
            isEmpty: todayTasks.isEmpty && !_isLoading,
            emptyText: _isFilterActive() ? 'No tasks match your filter' : 'No tasks due currently',
          ),

          const SizedBox(height: 6),

          // UPCOMING SECTION IN LIGHT GREY CARD
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _buildUpcomingSectionHeader(),
                ),
                if (_showUpcoming) ...[
                  const SizedBox(height: 6),
                  if (upcomingTasks.isEmpty && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        _isFilterActive() ? 'No upcoming tasks match your filter' : 'No upcoming tasks',
                        style: TextStyle(fontSize: 13, color: kNeutral500),
                      ),
                    )
                  else
                    ...upcomingTasks,
                ],
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ARCHIVE SECTION IN LIGHT GREY CARD
          _buildSectionCard(
            header: _buildSectionTitle('ARCHIVE', _getFilteredArchivedTasksCount()),
            tasks: archivedTasks,
            isEmpty: archivedTasks.isEmpty && !_isLoading,
            emptyText: _isFilterActive() ? 'No archived tasks match your filter' : 'No archived tasks',
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4B5563),
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (count > 0)
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'UPCOMING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.6,
                    ),
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
      if (task['completedAt'] != null) continue;
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
      if (task['completedAt'] != null) continue;
      if (!_shouldShowCategory(task['category'] ?? 'Operations')) continue;
      if (!_shouldShowBreed(task['breed']?.toString())) continue;
      if (!_matchesSearch(task['name'] ?? task['task'] ?? 'Task', null, _getTaskLocation(task))) continue;
      filtered.add(task);
    }
    return _buildGroupedTaskWidgets(filtered, isToday: false);
  }

  int _getFilteredArchivedTasksCount() {
    int count = 0;
    final seen = <String>{};
    for (var task in [
      ..._todayTasks,
      ..._upcomingTasks
    ]) {
      if (task['completedAt'] == null) continue;
      final idKey = '${task['isPipelineTask'] == true ? 'p' : 's'}_${task['id']}';
      if (seen.contains(idKey)) continue;
      seen.add(idKey);
      if (!_shouldShowCategory(task['category'] ?? 'Operations')) continue;
      if (!_shouldShowBreed(task['breed']?.toString())) continue;
      if (!_matchesSearch(task['name'] ?? task['task'] ?? 'Task', null, _getTaskLocation(task))) continue;
      count++;
    }
    return count;
  }

  List<Widget> _getFilteredArchivedTasks() {
    final filtered = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (var task in [
      ..._todayTasks,
      ..._upcomingTasks
    ]) {
      if (task['completedAt'] == null) continue;
      final idKey = '${task['isPipelineTask'] == true ? 'p' : 's'}_${task['id']}';
      if (seen.contains(idKey)) continue;
      seen.add(idKey);
      if (!_shouldShowCategory(task['category'] ?? 'Operations')) continue;
      if (!_shouldShowBreed(task['breed']?.toString())) continue;
      if (!_matchesSearch(task['name'] ?? task['task'] ?? 'Task', null, _getTaskLocation(task))) continue;
      filtered.add(task);
    }
    return _buildGroupedTaskWidgets(filtered, isToday: false);
  }

  String _getTaskBunnyName(Map<String, dynamic> task) {
    final rabbitId = task['rabbitId']?.toString();
    if (rabbitId != null && _rabbitNameMap.containsKey(rabbitId)) {
      return _rabbitNameMap[rabbitId]!;
    }
    final entities = task['linkedEntities'];
    if (entities is List && entities.isNotEmpty) {
      final names = entities
          .map((e) {
            if (e is Map) {
              final id = e['id']?.toString();
              if (id != null && _rabbitNameMap.containsKey(id)) {
                return _rabbitNameMap[id]!;
              }
              return e['name']?.toString();
            }
            return e?.toString();
          })
          .where((n) => n != null && n.isNotEmpty && n != 'Unlinked')
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return '';
  }

  List<Widget> _buildGroupedTaskWidgets(List<Map<String, dynamic>> tasks, {required bool isToday}) {
    // Group tasks by normalized task name + due date
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var task in tasks) {
      final name = (task['name'] ?? task['task'] ?? 'Task').toString().trim().toLowerCase();
      final dueDateStr = (task['dueDate'] ?? '').toString().split('T')[0];
      final key = '${name}___${dueDateStr.isNotEmpty ? dueDateStr : (isToday ? 'today' : 'upcoming')}';
      groups.putIfAbsent(key, () => []).add(task);
    }

    List<Widget> widgets = [];
    int rowIndex = 0;

    for (var entry in groups.entries) {
      final groupTasks = entry.value;
      final rowBgColor = rowIndex.isEven ? const Color(0xFFF2F2F7) : Colors.white;
      final firstTask = groupTasks.first;
      final name = firstTask['name'] ?? firstTask['task'] ?? 'Task';
      final taskCategory = firstTask['category'] ?? 'Operations';
      final dueDate = DateTime.tryParse(firstTask['dueDate'] ?? '');
      final isOverdue = dueDate != null && dueDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
      final isDueToday = dueDate != null && dueDate.year == DateTime.now().year && dueDate.month == DateTime.now().month && dueDate.day == DateTime.now().day;

      String dateStr;
      if (isOverdue) {
        final diff = DateTime.now().difference(dueDate!).inDays;
        dateStr = '$diff day${diff > 1 ? 's' : ''} overdue';
      } else if (isDueToday || isToday) {
        dateStr = 'Today';
      } else if (dueDate != null) {
        final diff = dueDate.difference(DateTime.now()).inDays;
        dateStr = '${DateFormat('MMM d').format(dueDate)} ($diff d)';
      } else {
        dateStr = isToday ? 'Today' : 'Upcoming';
      }

      if (groupTasks.length == 1) {
        final task = groupTasks.first;
        final bunnyName = _getTaskBunnyName(task);
        widgets.add(_buildSingleTask(
          title: name,
          category: taskCategory,
          categoryColor: _getCategoryColor(taskCategory),
          categoryTextColor: _getCategoryTextColor(taskCategory),
          icon: _getCategoryIcon(taskCategory),
          bunnyName: bunnyName,
          date: dateStr,
          isOverdue: isOverdue,
          taskType: task['taskType']?.toString() ?? 'scheduled',
          rabbitId: task['rabbitId']?.toString(),
          task: task,
          backgroundColor: rowBgColor,
        ));
      } else {
        widgets.add(_buildGroupedTaskCard(
          title: name,
          date: dateStr,
          isOverdue: isOverdue,
          isToday: isDueToday || isToday,
          groupTasks: groupTasks,
          backgroundColor: rowBgColor,
        ));
      }
      rowIndex++;
    }

    return widgets;
  }

  Widget _buildGroupedTaskCard({
    required String title,
    required String date,
    required bool isOverdue,
    required bool isToday,
    required List<Map<String, dynamic>> groupTasks,
    Color backgroundColor = Colors.white,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Task Name + Date
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue
                        ? const Color(0xFFEF4444)
                        : isToday
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                    fontWeight: (isOverdue || isToday) ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Indented list of bunnies
            ...groupTasks.map((task) {
              final isCompleted = task['completedAt'] != null;
              final rawId = task['id'];
              final trackId = rawId is int ? rawId : rawId?.hashCode;
              final isIgnored = trackId != null && _ignoredTasks.contains(trackId);
              final bunnyName = _getTaskBunnyName(task);
              final displayName = bunnyName.isNotEmpty ? bunnyName : 'Unlinked';

              return Padding(
                padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Small circle Checkbox matching single task style
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isIgnored
                          ? null
                          : () {
                              if (isCompleted) {
                                _handleTaskUncomplete(task);
                              } else {
                                _handleTaskComplete(task);
                              }
                            },
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? const Color(0xFFD6C3F9) : Colors.transparent,
                          border: Border.all(
                            color: isCompleted ? const Color(0xFFD6C3F9) : const Color(0xFFD1D5DB),
                            width: 1.5,
                          ),
                        ),
                        child: isCompleted
                            ? const Center(
                                child: Icon(Icons.check, size: 10, color: Colors.white),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Indented dash and Bunny name in purple
                    Expanded(
                      child: Text(
                        '- $displayName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (isCompleted || isIgnored) ? const Color(0xFF9CA3AF) : const Color(0xFF8B5CF6),
                          decoration: (isCompleted || isIgnored) ? TextDecoration.lineThrough : null,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 3 dots
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showTaskOptionsSheet(task),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        child: Icon(Icons.more_horiz, size: 22, color: Color(0xFF787774)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleTask({
    required String title,
    required String category,
    required Color categoryColor,
    required Color categoryTextColor,
    required IconData icon,
    required String bunnyName,
    required String date,
    required bool isOverdue,
    String? taskType,
    String? rabbitId,
    Map<String, dynamic>? task,
    Color backgroundColor = Colors.white,
  }) {
    final isCompleted = task?['completedAt'] != null;
    final rawId = task?['id'];
    final trackId = rawId is int ? rawId : rawId?.hashCode;
    final isIgnored = trackId != null && _ignoredTasks.contains(trackId);
    final isToday = date == 'Today';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isIgnored ? null : () => _showTaskOptionsSheet(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1: Small circle checkbox matching text height
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isIgnored
                        ? null
                        : () {
                            if (task != null) {
                              if (isCompleted) {
                                _handleTaskUncomplete(task);
                              } else {
                                _handleTaskComplete(task);
                              }
                            }
                          },
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? const Color(0xFFD6C3F9) : Colors.transparent,
                        border: Border.all(
                          color: isCompleted ? const Color(0xFFD6C3F9) : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                      ),
                      child: isCompleted
                          ? const Center(
                              child: Icon(Icons.check, size: 10, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Column 2: Content (Task name NOT bold + Bunny name in purple)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500, // NOT BOLD
                          color: (isCompleted || isIgnored) ? kNeutral400 : const Color(0xFF1F2937),
                          decoration: (isCompleted || isIgnored) ? TextDecoration.lineThrough : null,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bunnyName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          bunnyName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B5CF6),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Column 3: Due date status
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? const Color(0xFFEF4444)
                          : isToday
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                      fontWeight: (isOverdue || isToday) ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Column 4: Options Menu (3 dots)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showTaskOptionsSheet(task),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    child: Icon(Icons.more_horiz, size: 22, color: Color(0xFF787774)),
                  ),
                ),
              ],
            ),
          ),
        ),
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
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
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            InkWell(
              onTap: () async {
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
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTaskFromMultiple({required String title, required String category, required String date, required bool isOverdue, required List<Map<String, dynamic>> tasks, Color backgroundColor = Colors.white}) {
    final categoryColor = _getCategoryColor(category);
    final categoryTextColor = _getCategoryTextColor(category);
    final icon = _getCategoryIcon(category);
    final groupId = '$title-group';
    final isExpanded = _expandedGroups.contains(groupId);
    final allIgnored = tasks.every((t) {
      final id = t['id'];
      final trackId = id is int ? id : id?.hashCode;
      return trackId != null && _ignoredTasks.contains(trackId);
    });
    final subTasks = tasks.map((t) {
      final entities = t['linkedEntities'];
      String name = 'Unknown';
      String loc = '';
      if (entities is List && entities.isNotEmpty) {
        final first = entities.first;
        if (first is Map) {
          name = first['name']?.toString() ?? 'Unknown';
          loc = first['cage']?.toString() ?? first['barn']?.toString() ?? '';
        }
      }
      return {
        'dbId': t['id'],
        'name': name,
        'location': loc.isNotEmpty ? loc : _getTaskLocation(t),
        'task': t
      };
    }).toList();
    return _buildGroupContainer(
        title: title,
        count: tasks.length,
        category: category,
        categoryColor: categoryColor,
        categoryTextColor: categoryTextColor,
        icon: icon,
        date: date,
        isOverdue: isOverdue,
        groupId: groupId,
        isExpanded: isExpanded,
        allIgnored: allIgnored,
        subTasks: subTasks,
        backgroundColor: backgroundColor,
        onGroupIgnore: () => setState(() {
              if (allIgnored) {
                for (var t in tasks) {
                  final id = t['id'];
                  final tid = id is int ? id : id?.hashCode;
                  if (tid != null) _ignoredTasks.remove(tid);
                }
              } else {
                for (var t in tasks) {
                  final id = t['id'];
                  final tid = id is int ? id : id?.hashCode;
                  if (tid != null) _ignoredTasks.add(tid);
                }
              }
            }),
        onGroupComplete: () async {
          final allCompleted = tasks.every((t) => t['completedAt'] != null);
          if (allCompleted) {
            for (var t in tasks) await _handleTaskUncomplete(t, reload: false);
          } else {
            for (var t in tasks) {
              if (t['completedAt'] == null) await _handleTaskComplete(t, reload: false);
            }
          }
          await _loadScheduledTasks();
          await _loadStats();
        });
  }

  Widget _buildGroupTaskFromEntities({required Map<String, dynamic> task, required bool isToday, Color backgroundColor = Colors.white}) {
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
    final subTasks = entities.map((e) {
      final em = e is Map ? e : {};
      return {
        'dbId': rawId,
        'name': em['name']?.toString() ?? 'Unknown',
        'location': em['cage']?.toString() ?? em['barn']?.toString() ?? '',
        'task': task
      };
    }).toList();
    return _buildGroupContainer(
        title: title,
        count: entities.length,
        category: category,
        categoryColor: _getCategoryColor(category),
        categoryTextColor: _getCategoryTextColor(category),
        icon: _getCategoryIcon(category),
        date: dateStr,
        isOverdue: isOverdue,
        groupId: groupId,
        isExpanded: isExpanded,
        allIgnored: isIgnored,
        subTasks: subTasks,
        backgroundColor: backgroundColor,
        onGroupIgnore: rawId != null ? () => _handleTaskIgnore(rawId) : null,
        onGroupComplete: () async {
          if (task['completedAt'] != null)
            await _handleTaskUncomplete(task);
          else
            await _handleTaskComplete(task);
        });
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
    Color backgroundColor = Colors.white,
    VoidCallback? onGroupIgnore,
    VoidCallback? onGroupComplete,
  }) {
    final isGroupCompleted = subTasks.every((sub) => (sub['task'] as Map<String, dynamic>?)?['completedAt'] != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
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
            borderRadius: BorderRadius.circular(6),
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
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
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
                            child: isSubCompleted ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
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
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildSectionTitle('PLANNED MATINGS', _breedingPlans.length),
        const SizedBox(height: 16),
        if (_breedingPlans.isEmpty) _buildEmptyState('No planned matings scheduled.') else ..._breedingPlans.map((plan) => _buildBreedingPlanCard(plan)).toList(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildContactsView() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildSectionTitle('BREEDER CONTACTS', _contacts.length),
        const SizedBox(height: 16),
        if (_contacts.isEmpty) _buildEmptyState('No contacts added yet.') else ..._contacts.map((contact) => _buildContactCard(contact)).toList(),
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
    final today = DateTime.now();
    final isFuture = date != null && date.isAfter(DateTime(today.year, today.month, today.day));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                if (isFuture) {
                  // Planned date has NOT arrived yet — block logging
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Breeding Not Yet Due'),
                      content: Text(
                        'Breeding can only be logged on or after ${FormatUtils.formatDateShort(date!)}.\n\nPlease come back on the planned date to log this breeding.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK', style: TextStyle(color: kLilacDeep, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                // Planned date has arrived — show normal confirmation
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Log Planned Mating?'),
                    content: Text(
                      'The planned mating date (${FormatUtils.formatDateShort(date!)}) has occurred. Would you like to log it now?',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Log Breeding', style: TextStyle(color: kLilacDeep, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final doe = await _db.getRabbit(plan['doeId']);
                  final buck = await _db.getRabbit(plan['buckId']);
                  if (doe == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error: Doe not found'), backgroundColor: Color(0xFFD44C47)),
                    );
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => LogBreedingModal(
                      doe: doe,
                      buck: buck,
                      initialBreedDate: date,
                      deleteBreedingPlanId: plan['id'],
                      onComplete: () {
                        _loadBreedingPlans();
                        HomeDashboardScreen.switchToTab(0);
                      },
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFBCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), color: const Color(0xFFB5567A), size: 20),
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
                ],
              ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Breeding Plan?'),
        content: const Text('Are you sure you want to remove this planned mating?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: kError))),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteBreedingPlan(id);
      _loadBreedingPlans();
    }
  }

  void _showSearchModal() {
    final searchController = TextEditingController(text: _searchQuery);
    showDialog(
        context: context,
        builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Search Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(hintText: 'Search by task name, breed, location...', prefixIcon: const Icon(Icons.search, color: Color(0xFF787774)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                      onSubmitted: (value) {
                        setState(() => _searchQuery = value.trim());
                        Navigator.pop(context);
                      }),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() => _searchQuery = '');
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF787774), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Clear'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: () {
                              setState(() => _searchQuery = searchController.text.trim());
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Search'))),
                  ]),
                ]),
              ),
            ));
  }

  void _showFilterModal() {
    final allBreeds = [
      'All',
      ..._availableBreeds
    ];
    showDialog(
        context: context,
        builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Material(
                    color: Colors.transparent,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Filter by Breed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        if (_breedFilter != 'All')
                          TextButton(
                              onPressed: () {
                                setState(() => _breedFilter = 'All');
                                Navigator.pop(context);
                              },
                              child: const Text('Clear', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600)))
                        else
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ]),
                      const SizedBox(height: 8),
                      if (_availableBreeds.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No breeds found.\nAdd breeds to your rabbits first.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF9B9A97)))))
                      else
                        ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: SingleChildScrollView(
                                child: Column(
                                    children: allBreeds.map((breed) {
                              final isSelected = _breedFilter == breed;
                              return InkWell(
                                  onTap: () {
                                    setState(() => _breedFilter = breed);
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      margin: const EdgeInsets.only(bottom: 4),
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
    String selectedFrequency = 'Select date';
    String selectedLinkType = 'unlinked';
    bool isCustomTask = false;
    DateTime? selectedCustomDate = DateTime.now();
    Rabbit? selectedRabbitForLink;
    final customTaskController = TextEditingController();
    final _db2 = DatabaseService();
    List<Map<String, dynamic>> taskDirectoryItems = [];
    try {
      taskDirectoryItems = await _db2.getAllTaskDirectoryItems();
    } catch (e) {}

    List<Rabbit> allRabbitsList = [];
    try {
      final fetchedRabbits = await _db2.getAllRabbits();
      allRabbitsList = fetchedRabbits.where((r) => r.status != RabbitStatus.archived).toList();
    } catch (e) {}

    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(builder: (context, setDialogState) {
            Widget buildCategoryRadio(String label, String value) {
              final bool isSelected = (value == 'Custom' && isCustomTask) ||
                  (!isCustomTask && selectedCategory.toLowerCase() == value.toLowerCase());
              return GestureDetector(
                onTap: () {
                  setDialogState(() {
                    if (value == 'Custom') {
                      selectedCategory = 'Custom';
                      isCustomTask = true;
                      selectedTask = null;
                    } else {
                      selectedCategory = value;
                      isCustomTask = false;
                      selectedTask = null;
                      if (selectedCategory == 'Breeding') {
                        // If current selected rabbit is not a doe, clear selection
                        if (selectedRabbitForLink != null && selectedRabbitForLink!.type != RabbitType.doe) {
                          selectedRabbitForLink = null;
                          selectedLinkType = 'unlinked';
                        }
                      }
                    }
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF94A3B8),
                          width: isSelected ? 5.5 : 1.5,
                        ),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Task options per category
            List<String> currentTaskOptions;
            if (selectedCategory == 'Health') {
              currentTaskOptions = [
                'Nail Trim',
                'Deworm',
                'Coccidiosis Med',
                'Teeth Check',
                'Weight Check',
                '+ Custom...',
              ];
            } else if (selectedCategory == 'Breeding' || selectedCategory == 'Pregnancy') {
              currentTaskOptions = [
                'Palpation',
                'Add Nest Box',
                'Check for Kindle',
                '+ Custom...',
              ];
            } else if (selectedCategory == 'Operations') {
              currentTaskOptions = [
                'Clean Trays',
                'Top Off Feed',
                'Check Water',
                'Deep Clean',
                'Cage Maintenance',
                '+ Custom...',
              ];
            } else {
              currentTaskOptions = [
                'Clean Trays',
                'Nail Trim',
                'Health Check',
                '+ Custom...',
              ];
            }

            // Filter rabbits based on category: Breeding only shows DOES
            final isBreeding = selectedCategory == 'Breeding' || selectedCategory == 'Pregnancy';
            final availableRabbits = isBreeding
                ? allRabbitsList.where((r) => r.type == RabbitType.doe).toList()
                : allRabbitsList;

            String formatRabbitLabel(Rabbit r) {
              final prefix = (r.breederPrefix != null && r.breederPrefix!.trim().isNotEmpty)
                  ? '${r.breederPrefix!.trim()} '
                  : '';
              final ear = (r.earNumber != null && r.earNumber!.trim().isNotEmpty)
                  ? ' (${r.earNumber!.trim()})'
                  : '';
              return '$prefix${r.name}$ear';
            }

            BoxDecoration inputDec() => BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12));

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedCustomDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (picked != null) {
                setDialogState(() {
                  selectedCustomDate = picked;
                });
              }
            }

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
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle), child: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)))),
                    ]),
                    const SizedBox(height: 20),
                    const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                    Row(
                      children: [
                        Expanded(child: buildCategoryRadio('Operations', 'Operations')),
                        Expanded(child: buildCategoryRadio('Breeding', 'Breeding')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: buildCategoryRadio('Health', 'Health')),
                        Expanded(child: buildCategoryRadio('Custom', 'Custom')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!isCustomTask) ...[
                      const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Task', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: inputDec(),
                          child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                  value: (selectedTask == '+ Custom...') ? null : selectedTask,
                                  hint: const Text('Select a task...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                  items: currentTaskOptions.map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: e == '+ Custom...' ? FontStyle.italic : FontStyle.normal,
                                        color: e == '+ Custom...' ? kPrimary : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  )).toList(),
                                  onChanged: (val) {
                                    if (val == '+ Custom...') {
                                      setDialogState(() {
                                        isCustomTask = true;
                                        selectedTask = null;
                                      });
                                    } else {
                                      setDialogState(() {
                                        selectedTask = val;
                                      });
                                    }
                                  }))),
                    ] else ...[
                      const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Custom Task Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                      TextField(controller: customTaskController, decoration: InputDecoration(hintText: 'Enter custom task name...', hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary)))),
                    ],
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        isBreeding ? 'Link to Doe (Female Only)' : 'Link to Bunny (Optional)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                      ),
                    ),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: inputDec(),
                        child: DropdownButtonHideUnderline(
                            child: DropdownButton<Rabbit?>(
                                value: selectedRabbitForLink,
                                hint: Text(isBreeding ? 'Select a Doe...' : 'None (Unlinked)', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                items: [
                                  if (!isBreeding)
                                    const DropdownMenuItem<Rabbit?>(
                                      value: null,
                                      child: Text('None (Unlinked)', style: TextStyle(fontSize: 14)),
                                    ),
                                  ...availableRabbits.map((r) => DropdownMenuItem<Rabbit?>(
                                    value: r,
                                    child: Text(formatRabbitLabel(r), style: const TextStyle(fontSize: 14)),
                                  )).toList()
                                ],
                                onChanged: (val) => setDialogState(() {
                                  selectedRabbitForLink = val;
                                  if (val != null) {
                                    selectedLinkType = 'rabbit';
                                  } else {
                                    selectedLinkType = 'unlinked';
                                  }
                                })))),
                    const SizedBox(height: 14),
                    // Frequency is hidden for Breeding category!
                    if (!isBreeding) ...[
                      const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Frequency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: inputDec(),
                          child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                  value: selectedFrequency,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                  items: [
                                    'Select date',
                                    'Daily',
                                    'Weekly Starting',
                                    'Fortnightly Starting',
                                    'Monthly Starting',
                                    'Semi Annually starting',
                                    'Annually'
                                  ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      selectedFrequency = val!;
                                    });
                                    if (val != 'Daily') {
                                      pickDate();
                                    }
                                  }))),
                      const SizedBox(height: 14),
                    ],
                    // Date selector: always shown for Breeding or when Frequency is not Daily
                    if (isBreeding || selectedFrequency != 'Daily') ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          isBreeding ? 'Select a Date' : (selectedFrequency == 'Select date' ? 'Due Date' : 'Starting Date'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        ),
                      ),
                      InkWell(
                        onTap: pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: inputDec(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedCustomDate == null
                                    ? 'Choose date...'
                                    : FormatUtils.formatDate(selectedCustomDate!),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: selectedCustomDate == null ? const Color(0xFF94A3B8) : const Color(0xFF1F2937),
                                ),
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final finalTaskName = isCustomTask ? customTaskController.text.trim() : (selectedTask ?? '');
                            if (finalTaskName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47)));
                              return;
                            }
                            if (isBreeding && selectedRabbitForLink == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Doe for this breeding task'), backgroundColor: Color(0xFFD44C47)));
                              return;
                            }
                            final isDaily = !isBreeding && selectedFrequency == 'Daily';
                            final dueDate = isDaily ? DateTime.now() : (selectedCustomDate ?? DateTime.now());
                            final freqToSave = isBreeding ? 'Once' : (selectedFrequency == 'Select date' ? 'Once' : selectedFrequency);

                            List<Map<String, String>> entitiesToSave = [];
                            if (selectedRabbitForLink != null) {
                              entitiesToSave = [{
                                'id': selectedRabbitForLink!.id,
                                'name': selectedRabbitForLink!.name,
                                'code': selectedRabbitForLink!.cage ?? selectedRabbitForLink!.location ?? 'No cage'
                              }];
                            }

                            try {
                              await DatabaseService().insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': freqToSave,
                                'linkType': selectedRabbitForLink != null ? 'rabbit' : 'unlinked',
                                'linkedEntities': entitiesToSave,
                                'dueDate': dueDate.toIso8601String(),
                              });
                              Navigator.pop(dialogContext);
                              await _loadScheduledTasks();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Saved'), backgroundColor: kPrimary));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: const Color(0xFFD44C47)));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: const Text('Save Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
                        backgroundColor: const Color(0xFFE6BEFE),
                        foregroundColor: kLilacText,
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
                  items: does.map((d) => DropdownMenuItem(value: d.id, child: Text(d.fullName))).toList(),
                  onChanged: (val) => setDialogState(() => selectedDoeId = val),
                  underline: Container(height: 1, color: kNeutral300),
                ),
                const SizedBox(height: 16),
                const Text('Select Buck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral600)),
                DropdownButton<String>(
                  value: selectedBuckId,
                  hint: const Text('Choose Buck...', style: TextStyle(fontSize: 14)),
                  isExpanded: true,
                  items: bucks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.fullName))).toList(),
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
                        backgroundColor: const Color(0xFFE6BEFE),
                        foregroundColor: kLilacText,
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
                        GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle), child: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)))),
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
                                items: [
                                  'Operations',
                                  'Health',
                                  if (SettingsService.instance.meatProductionEnabled) 'Butchering',
                                  'Pregnancy',
                                  'Other'
                                ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
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
                                items: [
                                  'Daily',
                                  'Weekly',
                                  'Bi-Weekly',
                                  'Monthly',
                                  'Once'
                                ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
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
                                {
                                  'name': taskNameController.text.trim(),
                                  'category': selectedCategory,
                                  'frequency': selectedFrequency
                                },
                                where: 'id = ?',
                                whereArgs: [
                                  taskId
                                ],
                              );
                              Navigator.pop(dialogContext);
                              await _loadScheduledTasks();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Updated'), backgroundColor: kPrimary));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $e'), backgroundColor: const Color(0xFFD44C47)));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE6BEFE), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kLilacText)),
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
