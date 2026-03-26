import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

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
      final allTasks = [
        ...scheduledTasks,
        ...pipelineTasks
      ];

      final now = DateTime.now();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final List<Map<String, dynamic>> today = [];
      final List<Map<String, dynamic>> upcoming = [];

      for (final task in allTasks) {
        final dueDate = DateTime.tryParse(task['dueDate'] ?? '');
        if (dueDate != null && dueDate.isBefore(todayEnd.add(Duration(seconds: 1)))) {
          today.add(task);
        } else {
          upcoming.add(task);
        }
      }

      // Sort each list by due date
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

      if (mounted) {
        setState(() {
          todayTasks = today;
          upcomingTasks = upcoming;
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TASKS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showNewScheduleDialog,
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text(
                        'ADD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                ),
              ),
            )
          else
            _buildTasksContent(),

          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTasksContent() {
    final bool hasNoTasks = todayTasks.isEmpty && upcomingTasks.isEmpty;

    if (hasNoTasks) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(PhosphorIconsRegular.clipboardText, size: 40, color: Color(0xFFD1D5DB)),
              SizedBox(height: 12),
              Text(
                'No tasks for ${widget.rabbit.name}',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                'Tap + ADD to create a new task',
                style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todayTasks.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'TODAY & OVERDUE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...todayTasks.map((task) => _buildTaskItem(task)).toList(),
        ],
        if (upcomingTasks.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'UPCOMING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...upcomingTasks.map((task) => _buildTaskItem(task)).toList(),
        ],
      ],
    );
  }

  /// Show cost dialog when completing a task
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
                color: Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle_outline, color: Color(0xFF6366F1), size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
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
              style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            SizedBox(height: 16),
            Text(
              'Any cost spent on this task?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            TextField(
              controller: costController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '\u20b9',
                prefixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: Text('No Cost', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () {
              final cost = double.tryParse(costController.text) ?? 0.0;
              Navigator.pop(ctx, cost);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );

    // If dialog was dismissed (back button / outside tap), don't complete
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

  Widget _buildTaskItem(Map<String, dynamic> task) {
    String? category = task['category'];
    final dueDate = DateTime.tryParse(task['dueDate'] ?? '');
    final now = DateTime.now();
    final bool isOverdue = dueDate != null && dueDate.isBefore(DateTime(now.year, now.month, now.day));
    final bool isToday = dueDate != null && dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
    final bool isCompleted = task['completedAt'] != null;

    String timeLabel;
    if (isOverdue) {
      final diff = now.difference(dueDate!).inDays;
      timeLabel = 'Overdue by $diff day${diff > 1 ? 's' : ''}';
    } else if (isToday) {
      timeLabel = 'Today';
    } else if (dueDate != null) {
      timeLabel = '${dueDate.month}/${dueDate.day}/${dueDate.year}';
    } else {
      timeLabel = 'No date';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Complete button
          GestureDetector(
            onTap: () async {
              final isPipeline = task['isPipelineTask'] == true;
              final taskId = task['id'];
              if (taskId != null) {
                if (isCompleted) {
                  // Uncheck — clear completedAt
                  if (isPipeline) {
                    final db = await _db.database;
                    await db.update(
                        'tasks',
                        {
                          'completed': 0,
                          'completedAt': null
                        },
                        where: 'id = ?',
                        whereArgs: [
                          taskId.toString()
                        ]);
                  } else {
                    await _db.unmarkScheduledTaskCompleted(taskId);
                  }
                  _loadTasks();
                } else {
                  // Check — show cost dialog then complete
                  await _showTaskCostDialog(task);
                }
              }
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Color(0xFF6366F1) : Colors.white,
                border: Border.all(color: isCompleted ? Color(0xFF6366F1) : Color(0xFFD1D5DB), width: 2),
              ),
              child: isCompleted ? Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['name'] ?? task['task'] ?? 'Task',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Color(0xFF9CA3AF) : Color(0xFF1F2937),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      if (category != null) ...[
                        TextSpan(
                          text: category,
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w400),
                        ),
                        TextSpan(
                          text: ' • ',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                      TextSpan(
                        text: timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue
                              ? Color(0xFFEF4444)
                              : isToday
                                  ? Color(0xFFF59E0B)
                                  : Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: ' • ${task['frequency'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: Color(0xFF9CA3AF), size: 18),
            onPressed: () => _showTaskOptions(task),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ---- Dialogs ----

  void _showNewScheduleDialog() async {
    String selectedCategory = 'Operations';
    String? selectedTask;
    String selectedFrequency = 'Weekly';
    bool isCustomTask = false;
    TextEditingController customTaskController = TextEditingController();

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
            List<String> directoryTasks = taskDirectoryItems.where((t) => (t['category'] as String).toLowerCase() == selectedCategory.toLowerCase()).map((t) => t['name'] as String).toList();

            List<String> currentTaskOptions;
            if (directoryTasks.isNotEmpty) {
              currentTaskOptions = directoryTasks;
            } else {
              if (selectedCategory == 'Operations')
                currentTaskOptions = [
                  'Clean Trays',
                  'Top Off Feed',
                  'Check Water',
                  'Deep Clean'
                ];
              else if (selectedCategory == 'Health')
                currentTaskOptions = [
                  'Nail Trim',
                  'Health Check',
                  'Weighing',
                  'Ear Check'
                ];
              else if (selectedCategory == 'Butchering')
                currentTaskOptions = [
                  'Schedule Butcher',
                  'Prep Equipment',
                  'Process'
                ];
              else if (selectedCategory == 'Pregnancy')
                currentTaskOptions = [
                  'Palpation',
                  'Add Nest Box',
                  'Check for Kindle'
                ];
              else
                currentTaskOptions = [
                  'Inventory Check',
                  'General Maintenance'
                ];
            }

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('New Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle),
                              child: Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Linked rabbit banner
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0ECFE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF6366F1).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIconsRegular.link, size: 16, color: Color(0xFF6366F1)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Linked to ${widget.rabbit.name}',
                                style: TextStyle(fontSize: 13, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      // Category
                      _buildDialogLabel('Category'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              'Operations',
                              'Health',
                              'Butchering',
                              'Pregnancy',
                              'Other'
                            ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))).toList(),
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
                      SizedBox(height: 16),
                      // Task
                      _buildDialogLabel('Task'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: isCustomTask ? 'custom' : selectedTask,
                            hint: Text('Select a task...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              ...currentTaskOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))),
                              DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF6366F1)))),
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
                        SizedBox(height: 8),
                        TextField(
                          controller: customTaskController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom task name...',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF6366F1))),
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      // Frequency
                      _buildDialogLabel('Frequency'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedFrequency,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              'Daily',
                              'Weekly',
                              'Bi-Weekly',
                              'Monthly',
                              'Once'
                            ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) => setDialogState(() => selectedFrequency = val!),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      // Save
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? '');
                            if (finalTaskName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47)));
                              return;
                            }
                            try {
                              await _db.insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': selectedFrequency,
                                'linkType': 'rabbit',
                                'linkedEntities': [
                                  {
                                    'id': widget.rabbit.id,
                                    'name': widget.rabbit.name,
                                    'code': widget.rabbit.cage ?? widget.rabbit.location ?? 'No cage',
                                  }
                                ],
                              });
                              Navigator.pop(dialogContext);
                              _loadTasks();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Schedule saved for ${widget.rabbit.name}'),
                                backgroundColor: Color(0xFF6366F1),
                                behavior: SnackBarBehavior.floating,
                              ));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving schedule: $e'), backgroundColor: Color(0xFFD44C47)));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancel', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              margin: EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                task['completedAt'] != null ? Icons.undo : Icons.check_circle,
                color: task['completedAt'] != null ? Color(0xFF64748B) : Color(0xFF10B981),
              ),
              title: Text(
                task['completedAt'] != null ? 'Mark Undone' : 'Mark Done',
                style: TextStyle(fontSize: 15),
              ),
              onTap: () async {
                Navigator.pop(context);
                final isPipeline = task['isPipelineTask'] == true;
                final taskId = task['id'];
                if (taskId != null) {
                  if (task['completedAt'] != null) {
                    // Uncomplete
                    if (isPipeline) {
                      final db = await _db.database;
                      await db.update(
                          'tasks',
                          {
                            'completed': 0,
                            'completedAt': null
                          },
                          where: 'id = ?',
                          whereArgs: [
                            taskId.toString()
                          ]);
                    } else {
                      await _db.unmarkScheduledTaskCompleted(taskId);
                    }
                  } else {
                    // Complete
                    if (isPipeline) {
                      await _db.completeTask(taskId.toString());
                    } else {
                      await _db.markScheduledTaskCompleted(taskId);
                    }
                  }
                  _loadTasks();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(task['completedAt'] != null ? 'Task unmarked' : 'Task completed'),
                    backgroundColor: Color(0xFF6366F1),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Color(0xFFEF4444)),
              title: Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                _deleteTask(task);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _deleteTask(Map<String, dynamic> task) {
    final taskId = task['id'];
    if (taskId == null) return;
    final isPipeline = task['isPipelineTask'] == true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Task', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${task['name'] ?? task['task']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (isPipeline) {
                await _db.deleteTask(taskId.toString());
              } else {
                await _db.deleteScheduledTask(taskId);
              }
              Navigator.pop(context);
              _loadTasks();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Task deleted'),
                backgroundColor: Color(0xFF6366F1),
                behavior: SnackBarBehavior.floating,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getNextDueDate(String frequency) {
    final now = DateTime.now();
    DateTime next;
    switch (frequency) {
      case 'Daily':
        next = now.add(Duration(days: 1));
        break;
      case 'Weekly':
        next = now.add(Duration(days: 7));
        break;
      case 'Bi-Weekly':
        next = now.add(Duration(days: 14));
        break;
      case 'Monthly':
        next = DateTime(now.year, now.month + 1, now.day);
        break;
      default:
        next = now.add(Duration(days: 7));
    }
    return next.toIso8601String();
  }

  Widget _buildDialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
    );
  }

  BoxDecoration _inputBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(8),
    );
  }
}

// ================================================================
//  SCHEDULE CARD — shows Recurring Schedules for a rabbit
// ================================================================
class ScheduleCard extends StatefulWidget {
  final Rabbit rabbit;
  const ScheduleCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> recurringSchedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final allTasks = await _db.getScheduledTasksByRabbit(widget.rabbit.id);
      final recurring = allTasks.where((t) => (t['frequency'] ?? 'Once') != 'Once' && (t['frequency'] ?? 'One-time') != 'One-time').toList();

      if (mounted) {
        setState(() {
          recurringSchedules = recurring;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading schedules for rabbit: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'SCHEDULE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showNewScheduleDialog,
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text(
                        'ADD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                ),
              ),
            )
          else
            _buildScheduleContent(),

          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScheduleContent() {
    if (recurringSchedules.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(PhosphorIconsBold.clipboardText, size: 40, color: Color(0xFFD1D5DB)),
              SizedBox(height: 12),
              Text(
                'No recurring schedules',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                'Tap + ADD to create a recurring schedule',
                style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Icon(PhosphorIconsBold.clipboardText, color: Color(0xFF6366F1), size: 24),
              SizedBox(width: 10),
              Text(
                'Recurring Schedules',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Color(0xFFE2E8F0)),
        ...recurringSchedules.map((s) => _buildScheduleItem(s)).toList(),
      ],
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> schedule) {
    final frequency = schedule['frequency'] ?? 'Weekly';
    final category = schedule['category'] ?? '';
    final dueDate = DateTime.tryParse(schedule['dueDate'] ?? '');
    final dueDateStr = dueDate != null ? '${dueDate.month}/${dueDate.day}/${dueDate.year}' : '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule['name'] ?? schedule['task'] ?? 'Task',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$frequency${category.isNotEmpty ? ' • $category' : ''}${dueDateStr.isNotEmpty ? ' • Next: $dueDateStr' : ''}',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIconsRegular.trash, color: Color(0xFF94A3B8), size: 20),
            onPressed: () => _deleteSchedule(schedule),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _deleteSchedule(Map<String, dynamic> schedule) {
    final taskId = schedule['id'];
    if (taskId == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this recurring schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              await _db.deleteScheduledTask(taskId);
              Navigator.pop(context);
              _loadSchedules();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Schedule deleted'),
                backgroundColor: Color(0xFF6366F1),
                behavior: SnackBarBehavior.floating,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNewScheduleDialog() async {
    String selectedCategory = 'Operations';
    String? selectedTask;
    String selectedFrequency = 'Weekly';
    bool isCustomTask = false;
    TextEditingController customTaskController = TextEditingController();

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
            List<String> directoryTasks = taskDirectoryItems.where((t) => (t['category'] as String).toLowerCase() == selectedCategory.toLowerCase()).map((t) => t['name'] as String).toList();

            List<String> currentTaskOptions;
            if (directoryTasks.isNotEmpty) {
              currentTaskOptions = directoryTasks;
            } else {
              if (selectedCategory == 'Operations')
                currentTaskOptions = [
                  'Clean Trays',
                  'Top Off Feed',
                  'Check Water',
                  'Deep Clean'
                ];
              else if (selectedCategory == 'Health')
                currentTaskOptions = [
                  'Nail Trim',
                  'Health Check',
                  'Weighing',
                  'Ear Check'
                ];
              else if (selectedCategory == 'Butchering')
                currentTaskOptions = [
                  'Schedule Butcher',
                  'Prep Equipment',
                  'Process'
                ];
              else if (selectedCategory == 'Pregnancy')
                currentTaskOptions = [
                  'Palpation',
                  'Add Nest Box',
                  'Check for Kindle'
                ];
              else
                currentTaskOptions = [
                  'Inventory Check',
                  'General Maintenance'
                ];
            }

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('New Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Color(0xFFF5F7FA), shape: BoxShape.circle),
                              child: Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Color(0xFFF0ECFE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF6366F1).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIconsRegular.link, size: 16, color: Color(0xFF6366F1)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Linked to ${widget.rabbit.name}',
                                style: TextStyle(fontSize: 13, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildDialogLabel('Category'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              'Operations',
                              'Health',
                              if (SettingsService.instance.meatProductionEnabled) 'Butchering',
                              'Pregnancy',
                              'Other'
                            ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))).toList(),
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
                      SizedBox(height: 16),
                      _buildDialogLabel('Task'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: isCustomTask ? 'custom' : selectedTask,
                            hint: Text('Select a task...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              ...currentTaskOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))),
                              DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF6366F1)))),
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
                        SizedBox(height: 8),
                        TextField(
                          controller: customTaskController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom task name...',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF6366F1))),
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      _buildDialogLabel('Frequency'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputBoxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedFrequency,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              'Daily',
                              'Weekly',
                              'Bi-Weekly',
                              'Monthly',
                              'Once'
                            ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) => setDialogState(() => selectedFrequency = val!),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? '');
                            if (finalTaskName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47)));
                              return;
                            }
                            try {
                              await _db.insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': selectedFrequency,
                                'linkType': 'rabbit',
                                'linkedEntities': [
                                  {
                                    'id': widget.rabbit.id,
                                    'name': widget.rabbit.name,
                                    'code': widget.rabbit.cage ?? widget.rabbit.location ?? 'No cage',
                                  }
                                ],
                              });
                              Navigator.pop(dialogContext);
                              _loadSchedules();
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Schedule saved for ${widget.rabbit.name}'),
                                backgroundColor: Color(0xFF6366F1),
                                behavior: SnackBarBehavior.floating,
                              ));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving schedule: $e'), backgroundColor: Color(0xFFD44C47)));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancel', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
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

  Widget _buildDialogLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
    );
  }

  BoxDecoration _inputBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(8),
    );
  }
}
