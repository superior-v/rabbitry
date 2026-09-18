import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';
import '../services/format_utils.dart';
import 'package:intl/intl.dart';

// ================================================================
//  TASKS CARD — shows Today/Overdue & Upcoming tasks for a rabbit
// ================================================================
class TasksCard extends StatefulWidget {
  final Rabbit rabbit;
  const TasksCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends State<TasksCard> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> todayTasks = [];
  List<Map<String, dynamic>> upcomingTasks = [];
  List<Map<String, dynamic>> completedTasks = [];
  bool _isLoading = true;
  String? _selectedFilterCategory;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      // Load both scheduled tasks and pipeline tasks for this rabbit
      final scheduledTasks = await _db.getScheduledTasksByRabbit(widget.rabbit.id);
      final pipelineTasks = await _db.getPipelineTasksForRabbit(widget.rabbit.id);

      // Merge both lists
      final allTasks = [...scheduledTasks, ...pipelineTasks];

      final now = DateTime.now();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final List<Map<String, dynamic>> today = [];
      final List<Map<String, dynamic>> upcoming = [];
      final List<Map<String, dynamic>> completed = [];

      for (final task in allTasks) {
        if (task['completedAt'] != null || task['completed'] == 1) {
          completed.add(task);
          continue;
        }

        final dueDate = DateTime.tryParse(task['dueDate'] ?? '');
        if (dueDate != null && dueDate.isBefore(todayEnd.add(const Duration(seconds: 1)))) {
          today.add(task);
        } else {
          upcoming.add(task);
        }
      }

      // Sort lists
      today.sort((a, b) {
        final aDate = DateTime.tryParse(a['dueDate'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['dueDate'] ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });
      upcoming.sort((a, b) {
        final aDate = DateTime.tryParse(a['dueDate'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['dueDate'] ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });
      completed.sort((a, b) {
        final aDate = DateTime.tryParse(a['completedAt'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['completedAt'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate); // Latest completed first
      });

      if (mounted) {
        setState(() {
          todayTasks = today;
          upcomingTasks = upcoming;
          completedTasks = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading tasks for rabbit: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kNeutral200),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep)),
      );
    }

    // Filter tasks if category is selected
    List<Map<String, dynamic>> todayToShow = todayTasks;
    List<Map<String, dynamic>> upcomingToShow = upcomingTasks;
    List<Map<String, dynamic>> completedToShow = completedTasks;

    if (_selectedFilterCategory != null) {
      final catFilter = _selectedFilterCategory!.toUpperCase();
      todayToShow = todayTasks.where((t) => (t['category'] ?? 'General').toString().toUpperCase().contains(catFilter)).toList();
      upcomingToShow = upcomingTasks.where((t) => (t['category'] ?? 'General').toString().toUpperCase().contains(catFilter)).toList();
      completedToShow = completedTasks.where((t) => (t['category'] ?? 'General').toString().toUpperCase().contains(catFilter)).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Text(
                  'TASKS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F4F56),
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  offset: const Offset(0, 40),
                  onSelected: (String category) {
                    setState(() {
                      _selectedFilterCategory = category == 'ALL' ? null : category;
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    final categories = ['ALL', 'BREEDING', 'HEALTH', 'OPERATIONS'];
                    return categories.map((cat) {
                      final isSelected = (_selectedFilterCategory == null && cat == 'ALL') ||
                          (_selectedFilterCategory == cat);
                      return PopupMenuItem<String>(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check : null, 
                              size: 16, 
                              color: const Color(0xFF8B5CF6)
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      PhosphorIcons.funnel(PhosphorIconsStyle.regular),
                      size: 16,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showNewScheduleDialog,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 18,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Task Sections
          _buildTaskHeader('TODAY & OVERDUE', todayToShow.length, isOverdue: true),
          if (todayToShow.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No tasks due today', style: TextStyle(fontSize: 13, color: kNeutral400)),
            )
          else
            ...todayToShow.asMap().entries.map((e) => _buildTaskItem(e.value, index: e.key)),

          const SizedBox(height: 4),
          _buildTaskHeader('UPCOMING', upcomingToShow.length, isOverdue: false),
          if (upcomingToShow.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No upcoming tasks', style: TextStyle(fontSize: 13, color: kNeutral400)),
            )
          else
            ...upcomingToShow.asMap().entries.map((e) => _buildTaskItem(e.value, index: e.key)),

          if (completedToShow.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildTaskHeader('COMPLETED', completedToShow.length, isOverdue: false),
            ...completedToShow.take(3).toList().asMap().entries.map((e) => _buildTaskItem(e.value, index: e.key, forcedCompleted: true)),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTaskHeader(String title, int count, {bool isOverdue = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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

  Widget _buildTaskItem(Map<String, dynamic> task, {int index = 0, bool forcedCompleted = false}) {
    final bool isCompleted = forcedCompleted || task['completedAt'] != null || task['completed'] == 1;
    final dueDate = DateTime.tryParse(task['dueDate'] ?? '');
    final now = DateTime.now();
    final bool isOverdue = dueDate != null && dueDate.isBefore(DateTime(now.year, now.month, now.day));
    final bool isToday = dueDate != null && dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
    
    String timeLabel;
    if (isOverdue) {
      final diff = now.difference(dueDate!).inDays;
      timeLabel = '$diff day${diff > 1 ? 's' : ''} overdue';
    } else if (isToday) {
      timeLabel = 'Today';
    } else if (dueDate != null) {
      final diff = dueDate.difference(now).inDays;
      timeLabel = '${DateFormat('MMM d').format(dueDate)} ($diff d)';
    } else {
      timeLabel = '';
    }

    final TextStyle timeLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: (isOverdue || isToday) ? FontWeight.w600 : FontWeight.w400,
      color: isOverdue 
          ? const Color(0xFFEF4444) 
          : isToday 
              ? const Color(0xFF10B981) 
              : const Color(0xFF6B7280),
    );

    final rowBg = index.isEven ? const Color(0xFFF2F2F7) : Colors.white;
    final bunnyName = widget.rabbit.name.isNotEmpty ? widget.rabbit.name.toUpperCase() : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTaskOptions(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Front small circle checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      if (isCompleted) {
                        await _uncompleteTask(task);
                      } else {
                        await _showTaskCostDialog(task);
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
                // Title & Bunny Name (NOT BOLD)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task['name'] ?? task['task'] ?? 'Task',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500, // NOT BOLD
                          color: isCompleted ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
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
                // Time label
                if (timeLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(timeLabel, style: timeLabelStyle),
                  ),
                const SizedBox(width: 4),
                // More options button (three dots)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showTaskOptions(task),
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

  // ---- Logic & Dialogs (Preserved from original but updated) ----

  Future<void> _uncompleteTask(Map<String, dynamic> task) async {
    final isPipeline = task['isPipelineTask'] == true;
    final taskId = task['id'];

    if (isPipeline) {
      if (taskId != null) {
        final db = await _db.database;
        await db.update(
          'tasks',
          {'completed': 0, 'completedAt': null},
          where: 'id = ?',
          whereArgs: [taskId.toString()],
        );
      }
    } else {
      if (taskId is int) {
        await _db.unmarkScheduledTaskCompleted(taskId);
      }
    }
    _loadTasks();
  }

  Future<void> _showTaskCostDialog(Map<String, dynamic> task) async {
    final taskTitle = task['title']?.toString() ?? task['name']?.toString() ?? 'Task';
    final taskCategory = task['category']?.toString() ?? 'Operations';
    final rabbitId = widget.rabbit.id;

    final costController = TextEditingController();
    bool shouldAddCost = false;

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Task Complete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                taskTitle,
                style: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: shouldAddCost,
                onChanged: (val) {
                  setDialogState(() {
                    shouldAddCost = val ?? false;
                  });
                },
                title: const Text('Add expense for this task?', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (shouldAddCost) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cost (\$)',
                    hintText: '0.00',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (shouldAddCost) {
                  final cost = double.tryParse(costController.text) ?? 0.0;
                  Navigator.pop(ctx, cost);
                } else {
                  Navigator.pop(ctx, 0.0);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _completeTaskWithOptionalCost(task, result > 0 ? result : null);
    }
  }

  Future<void> _completeTaskWithOptionalCost(Map<String, dynamic> task, double? cost) async {
    final isPipeline = task['isPipelineTask'] == true;
    final taskId = task['id'];
    final taskTitle = task['name'] ?? task['task'] ?? 'Task';
    final taskCategory = task['category'] ?? 'Operations';
    final rabbitId = widget.rabbit.id;

    if (isPipeline) {
      final String idStr = taskId.toString();
      if (cost != null && cost > 0) {
        await _db.completeTaskWithCost(idStr, cost, rabbitId, taskTitle: taskTitle, taskCategory: taskCategory);
      } else {
        await _db.completeTask(idStr);
      }
    } else {
      if (taskId is int) {
        if (cost != null && cost > 0) {
          await _db.markScheduledTaskCompletedWithCost(taskId, cost, taskTitle: taskTitle, taskCategory: taskCategory, rabbitId: rabbitId);
        } else {
          await _db.markScheduledTaskCompleted(taskId);
        }
      }
    }

    _loadTasks();
  }

  void _showNewScheduleDialog() async {
    String selectedCategory = 'Operations';
    String? selectedTask;
    String selectedFrequency = 'Select date';
    bool isCustomTask = false;
    DateTime? selectedCustomDate = DateTime.now();
    final TextEditingController customTaskController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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

            final isBreeding = selectedCategory == 'Breeding' || selectedCategory == 'Pregnancy';

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
            } else if (isBreeding) {
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
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle),
                              child: Icon(Icons.close, size: 20, color: kNeutral500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildDialogLabel('Category'),
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
                        _buildDialogLabel('Task'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: _inputBoxDecoration(),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: (selectedTask == '+ Custom...') ? null : selectedTask,
                              hint: const Text('Select a task...', style: TextStyle(fontSize: 14, color: kNeutral400)),
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: kNeutral500),
                              items: currentTaskOptions.map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: e == '+ Custom...' ? FontStyle.italic : FontStyle.normal,
                                    color: e == '+ Custom...' ? const Color(0xFF8B5CF6) : const Color(0xFF1E293B),
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
                              },
                            ),
                          ),
                        ),
                      ] else ...[
                        _buildDialogLabel('Custom Task Name'),
                        TextField(
                          controller: customTaskController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom task name...',
                            hintStyle: const TextStyle(fontSize: 14, color: kNeutral400),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kNeutral200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Frequency option is NOT shown for Breeding category!
                      if (!isBreeding) ...[
                        _buildDialogLabel('Frequency'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: _inputBoxDecoration(),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedFrequency,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: kNeutral500),
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
                                setDialogState(() => selectedFrequency = val!);
                                if (val != 'Daily') {
                                  pickDate();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Date selector: always shown for Breeding or when Frequency is not Daily
                      if (isBreeding || selectedFrequency != 'Daily') ...[
                        _buildDialogLabel(isBreeding ? 'Select a Date' : (selectedFrequency == 'Select date' ? 'Due Date' : 'Starting Date')),
                        InkWell(
                          onTap: pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: _inputBoxDecoration(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedCustomDate == null
                                      ? 'Choose date...'
                                      : FormatUtils.formatDate(selectedCustomDate!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selectedCustomDate == null ? kNeutral400 : const Color(0xFF1F2937),
                                  ),
                                ),
                                Icon(Icons.calendar_today, size: 18, color: kNeutral500),
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
                            String finalTaskName = isCustomTask ? customTaskController.text.trim() : (selectedTask ?? '');
                            if (finalTaskName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47)),
                              );
                              return;
                            }
                            final isDaily = !isBreeding && selectedFrequency == 'Daily';
                            final dueDate = isDaily ? DateTime.now() : (selectedCustomDate ?? DateTime.now());
                            final freqToSave = isBreeding ? 'Once' : (selectedFrequency == 'Select date' ? 'Once' : selectedFrequency);

                            try {
                              await _db.insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': freqToSave,
                                'linkType': 'rabbit',
                                'linkedEntities': [{'id': widget.rabbit.id, 'name': widget.rabbit.name, 'code': widget.rabbit.cage ?? 'No cage'}],
                                'dueDate': dueDate.toIso8601String(),
                              });
                              Navigator.pop(dialogContext);
                              _loadTasks();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Task Saved'), backgroundColor: Color(0xFF8B5CF6)),
                              );
                            } catch (e) {
                              print(e);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Save Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTaskOptions(Map<String, dynamic> task) {
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
                    const SnackBar(content: Text('System tasks cannot be edited directly.'), backgroundColor: Color(0xFF8B5CF6)),
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
                _loadTasks();
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

  void _showEditTaskDialog(Map<String, dynamic> task) async {
    final taskId = task['id'] as int?;
    if (taskId == null) return;

    String selectedCategory = task['category']?.toString() ?? 'Operations';
    String finalTaskName = task['name']?.toString() ?? task['task']?.toString() ?? '';
    String selectedFrequency = task['frequency']?.toString() ?? 'Weekly';
    final taskNameController = TextEditingController(text: finalTaskName);

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
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
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
                                  'Pregnancy',
                                  'Breeding',
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
                              final db = await _db.database;
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
                              _loadTasks();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task Updated'), backgroundColor: Color(0xFF8B5CF6)));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $e'), backgroundColor: const Color(0xFFD44C47)));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
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

  Widget _buildDialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
    );
  }

  BoxDecoration _inputBoxDecoration() {
    return BoxDecoration(
      border: Border.all(color: kNeutral200),
      borderRadius: BorderRadius.circular(12),
    );
  }
}

// Keeping ScheduleCard separate or removing if redundant. 
// For now, I'll keep it but it might need its own modernization if needed.
// The user asked for "Tasks", "Stats", "Records".

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedRectPainter({
    this.color = const Color(0xFFD1D5DB),
    this.strokeWidth = 1.5,
    this.gap = 3.0,
    this.radius = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double w = size.width;
    final double h = size.height;
    final double r = radius;

    // Straight sides
    _drawDashedLine(canvas, Offset(r, 0), Offset(w - r, 0), paint);
    _drawDashedLine(canvas, Offset(w, r), Offset(w, h - r), paint);
    _drawDashedLine(canvas, Offset(w - r, h), Offset(r, h), paint);
    _drawDashedLine(canvas, Offset(0, h - r), Offset(0, r), paint);

    // Diagonal corner connectors (approximate rounded corners)
    canvas.drawLine(Offset(0, r), Offset(r, 0), paint);
    canvas.drawLine(Offset(w - r, 0), Offset(w, r), paint);
    canvas.drawLine(Offset(w, h - r), Offset(w - r, h), paint);
    canvas.drawLine(Offset(r, h), Offset(0, h - r), paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final double distance = (end - start).distance;
    final double dashWidth = 3.5;
    final double dashGap = gap;
    
    double currentDistance = 0.0;
    while (currentDistance < distance) {
      final double nextDistance = currentDistance + dashWidth;
      final double endLerp = nextDistance > distance ? distance : nextDistance;
      
      final double startFraction = currentDistance / distance;
      final double endFraction = endLerp / distance;
      
      final Offset startPoint = Offset.lerp(start, end, startFraction)!;
      final Offset endPoint = Offset.lerp(start, end, endFraction)!;
      
      canvas.drawLine(startPoint, endPoint, paint);
      
      currentDistance += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth || oldDelegate.gap != gap || oldDelegate.radius != radius;
  }
}

