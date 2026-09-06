import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../constants/app_colors.dart';
import '../services/format_utils.dart';
import 'package:intl/intl.dart';
import '../screens/task_screen.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'TASKS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF374151),
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
                    final categories = ['ALL', 'BREEDING', 'HEALTH', 'MAINTENANCE', 'GENERAL', 'OPERATIONS'];
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

    String category = (task['category'] ?? 'General').toString().toUpperCase();
    
    final TextStyle categoryStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Color(0xFF8B5CF6),
      letterSpacing: 0.5,
    );

    final TextStyle timeLabelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: isOverdue 
          ? const Color(0xFFEF4444) 
          : isToday 
              ? const Color(0xFF10B981) 
              : const Color(0xFF6B7280),
    );

    final rowBg = index.isEven ? const Color(0xFFF2F2F7) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (isCompleted) {
                      await _uncompleteTask(task);
                    } else {
                      await _showTaskCostDialog(task);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: isCompleted
                        ? Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFFD6C3F9),
                            ),
                            child: const Icon(Icons.check, size: 14, color: Colors.white),
                          )
                        : (dueDate != null && !isToday && !isOverdue)
                            ? CustomPaint(
                                painter: DashedRectPainter(
                                  color: const Color(0xFFD1D5DB),
                                  strokeWidth: 2,
                                  gap: 2.5,
                                  radius: 6,
                                ),
                                child: const SizedBox(width: 22, height: 22),
                              )
                            : Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFD1D5DB),
                                    width: 2,
                                  ),
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['name'] ?? task['task'] ?? 'Task',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(category, style: categoryStyle),
                          if (timeLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(timeLabel, style: timeLabelStyle),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // More options button (three dots)
                const SizedBox(width: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showTaskOptions(task),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.more_horiz, size: 18, color: Color(0xFFD1D5DB)),
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
                borderRadius: BorderRadius.circular(12),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    DateTime? selectedCustomDate;
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
                              const DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF8B5CF6)))),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kNeutral200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
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
                            items: ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly', 'Once', 'Select Custom Date...']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: (val) => setDialogState(() => selectedFrequency = val!),
                          ),
                        ),
                      ),
                      if (selectedFrequency == 'Select Custom Date...') ...[
                        const SizedBox(height: 16),
                        _buildDialogLabel('Custom Due Date'),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedCustomDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)), // Enable past dates up to 10 years
                              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),   // Enable future dates up to 10 years
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedCustomDate = picked;
                              });
                            }
                          },
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
                                      : DateFormat('MMM d, yyyy').format(selectedCustomDate!),
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
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? '');
                            if (finalTaskName.isEmpty) return;
                            final isCustomDate = selectedFrequency == 'Select Custom Date...';
                            if (isCustomDate && selectedCustomDate == null) return;
                            try {
                              await _db.insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': isCustomDate ? 'Once' : selectedFrequency,
                                'linkType': 'rabbit',
                                'linkedEntities': [{'id': widget.rabbit.id, 'name': widget.rabbit.name, 'code': widget.rabbit.cage ?? 'No cage'}],
                                if (isCustomDate && selectedCustomDate != null)
                                  'dueDate': selectedCustomDate!.toIso8601String(),
                              });
                              Navigator.pop(dialogContext);
                              _loadTasks();
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

