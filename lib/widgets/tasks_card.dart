import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
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

    final totalOpen = todayTasks.length + upcomingTasks.length;
    final overdueCount = todayTasks.where((t) {
      final d = DateTime.tryParse(t['dueDate'] ?? '');
      if (d == null) return false;
      final now = DateTime.now();
      return d.isBefore(DateTime(now.year, now.month, now.day));
    }).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.checkSquare, size: 18, color: kNeutral500),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'TASKS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kNeutral500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showNewScheduleDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kNeutral100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 14, color: kNeutral600),
                        const SizedBox(width: 4),
                        const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kNeutral600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Task Count Overview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$totalOpen',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'open tasks',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kNeutral500,
                    ),
                  ),
                ),
                if (overdueCount > 0) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text(
                            '$overdueCount overdue',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Task Sections
          _buildTaskHeader('TODAY & OVERDUE', todayTasks.length),
          ...todayTasks.map((t) => _buildTaskItem(t)),

          _buildTaskHeader('UPCOMING', upcomingTasks.length),
          ...upcomingTasks.map((t) => _buildTaskItem(t)),

          if (completedTasks.isNotEmpty) ...[
            _buildTaskHeader('COMPLETED', 0), // completed usually doesn't show badge in screens
            ...completedTasks.take(3).map((t) => _buildTaskItem(t, forcedCompleted: true)),
          ],

          // View All
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  // Navigate to all tasks or show more
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All Tasks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kNeutral400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: kNeutral400),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Stats Grid
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kNeutral100)),
              color: Color(0xFFFAFAFA),
            ),
            child: Row(
              children: [
                _buildBottomStatItem('${todayTasks.length}', 'OVERDUE'),
                _buildDivider(),
                _buildBottomStatItem('${upcomingTasks.length}', 'UPCOMING'),
                _buildDivider(),
                _buildBottomStatItem('${completedTasks.length}', 'COMPLETED'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: kNeutral400,
              letterSpacing: 0.8,
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, {bool forcedCompleted = false}) {
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

    String category = (task['category'] ?? 'General').toString().toUpperCase();
    Color categoryColor = kNeutral100;
    Color textColor = kNeutral600;

    if (category.contains('BREEDING')) {
      categoryColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFEF4444);
    } else if (category.contains('HEALTH')) {
      categoryColor = const Color(0xFFFFF7ED);
      textColor = const Color(0xFFF59E0B);
    } else if (category.contains('MAINT')) {
      categoryColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF3B82F6);
    }

    return InkWell(
      onTap: () => _showTaskOptions(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () async {
                if (isCompleted) {
                  await _uncompleteTask(task);
                } else {
                  await _showTaskCostDialog(task);
                }
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCompleted ? kPinkDeep : kNeutral300,
                    width: 2,
                  ),
                  color: isCompleted ? kPinkDeep : Colors.transparent,
                ),
                child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 14),
            // Title & Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['name'] ?? task['task'] ?? 'Task',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? kNeutral400 : const Color(0xFF1F2937),
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        (task['category'] ?? 'General').toString(),
                        style: TextStyle(fontSize: 12, color: kNeutral400),
                      ),
                      if (timeLabel.isNotEmpty) ...[
                        Text(' • ', style: TextStyle(color: kNeutral400)),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isOverdue ? const Color(0xFFEF4444) : isToday ? const Color(0xFFF59E0B) : kNeutral400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Badge
            if (!isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            // More
            const SizedBox(width: 12),
            Icon(Icons.more_horiz, size: 18, color: kNeutral300),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomStatItem(String val, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              val,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: kNeutral400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: kNeutral100);
  }

  // ---- Logic & Dialogs (Preserved from original but updated) ----

  Future<void> _uncompleteTask(Map<String, dynamic> task) async {
    final isPipeline = task['isPipelineTask'] == true;
    final taskId = task['id'];
    if (taskId != null) {
      if (isPipeline) {
        final db = await _db.database;
        await db.update(
          'tasks',
          {'completed': 0, 'completedAt': null},
          where: 'id = ?',
          whereArgs: [taskId.toString()],
        );
      } else {
        await _db.unmarkScheduledTaskCompleted(taskId);
      }
      _loadTasks();
    }
  }

  Future<void> _showTaskCostDialog(Map<String, dynamic> task) async {
    final costController = TextEditingController();
    final taskTitle = task['title']?.toString() ?? task['name']?.toString() ?? 'Task';
    final taskCategory = task['category']?.toString();
    final rabbitId = task['rabbitId']?.toString() ?? widget.rabbit.id;

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPinkDeep.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_outline, color: kPinkDeep, size: 20),
            ),
            const SizedBox(width: 14),
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
              style: TextStyle(fontSize: 14, color: kNeutral500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Any cost spent on this task?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: FormatUtils.currencySymbol,
                prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kPinkDeep, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: Text('No Cost', style: TextStyle(color: kNeutral500)),
          ),
          ElevatedButton(
            onPressed: () {
              final cost = double.tryParse(costController.text) ?? 0.0;
              Navigator.pop(ctx, cost);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPinkDeep,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final cost = result > 0 ? result : null;
    final isPipeline = task['isPipelineTask'] == true;

    if (isPipeline) {
      final taskId = task['id']?.toString();
      if (taskId != null) {
        if (cost != null) {
          await _db.completeTaskWithCost(taskId, cost, rabbitId, taskTitle: taskTitle, taskCategory: taskCategory);
        } else {
          await _db.completeTask(taskId);
        }
      }
    } else {
      final taskId = task['id'] as int?;
      if (taskId == null) return;
      if (cost != null) {
        await _db.markScheduledTaskCompletedWithCost(taskId, cost, taskTitle: taskTitle, taskCategory: taskCategory, rabbitId: rabbitId);
      } else {
        await _db.markScheduledTaskCompleted(taskId);
      }
    }

    _loadTasks();
  }

  void _showNewScheduleDialog() async {
    String selectedCategory = 'Operations';
    String? selectedTask;
    String selectedFrequency = 'Weekly';
    bool isCustomTask = false;
    final TextEditingController customTaskController = TextEditingController();

    List<Map<String, dynamic>> taskDirectoryItems = [];
    try {
      taskDirectoryItems = await _db.getAllTaskDirectoryItems();
    } catch (e) {
      print('Error loading task directory: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final directoryTasks = taskDirectoryItems
                .where((t) => (t['category'] as String).toLowerCase() == selectedCategory.toLowerCase())
                .map((t) => t['name'] as String)
                .toList();

            List<String> currentTaskOptions;
            if (directoryTasks.isNotEmpty) {
              currentTaskOptions = directoryTasks;
            } else {
              if (selectedCategory == 'Operations') {
                currentTaskOptions = ['Clean Trays', 'Top Off Feed', 'Check Water', 'Deep Clean'];
              } else if (selectedCategory == 'Health') {
                currentTaskOptions = ['Nail Trim', 'Health Check', 'Weighing', 'Ear Check'];
              } else if (selectedCategory == 'Butchering') {
                currentTaskOptions = ['Schedule Butcher', 'Prep Equipment', 'Process'];
              } else if (selectedCategory == 'Pregnancy') {
                currentTaskOptions = ['Palpation', 'Add Nest Box', 'Check for Kindle'];
              } else {
                currentTaskOptions = ['Inventory Check', 'General Maintenance'];
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: kNeutral500),
                            items: ['Operations', 'Health', 'Butchering', 'Pregnancy', 'Other']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedCategory = val!;
                                selectedTask = null;
                                isCustomTask = false;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDialogLabel('Task'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: isCustomTask ? 'custom' : selectedTask,
                            hint: const Text('Select a task...', style: TextStyle(fontSize: 14, color: kNeutral400)),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: kNeutral500),
                            items: [
                              ...currentTaskOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))),
                              const DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: kPinkDeep))),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == 'custom') {
                                  isCustomTask = true;
                                  selectedTask = null;
                                } else {
                                  isCustomTask = false;
                                  selectedTask = val;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      if (isCustomTask) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customTaskController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom task name...',
                            hintStyle: const TextStyle(fontSize: 14, color: kNeutral400),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kNeutral200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPinkDeep)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildDialogLabel('Frequency'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedFrequency,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: kNeutral500),
                            items: ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly', 'Once']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (val) => setDialogState(() => selectedFrequency = val!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? '');
                            if (finalTaskName.isEmpty) return;
                            try {
                              await _db.insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': selectedFrequency,
                                'linkType': 'rabbit',
                                'linkedEntities': [{'id': widget.rabbit.id, 'name': widget.rabbit.name, 'code': widget.rabbit.cage ?? 'No cage'}]
                              });
                              Navigator.pop(dialogContext);
                              _loadTasks();
                            } catch (e) {
                              print(e);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPinkDeep,
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4, width: 40,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: const Color(0xFFEF4444)),
              title: const Text('Delete Task', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
              onTap: () async {
                final isPipeline = task['isPipelineTask'] == true;
                if (isPipeline) {
                  await _db.deleteTask(task['id'].toString());
                } else {
                  await _db.deleteScheduledTask(task['id']);
                }
                Navigator.pop(context);
                _loadTasks();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
      borderRadius: BorderRadius.circular(8),
    );
  }
}

// Keeping ScheduleCard separate or removing if redundant. 
// For now, I'll keep it but it might need its own modernization if needed.
// The user asked for "Tasks", "Stats", "Records".
