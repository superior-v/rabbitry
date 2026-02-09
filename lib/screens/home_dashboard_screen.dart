import 'package:flutter/material.dart';
import 'herd_screen.dart';
import 'litters_screen.dart';
import 'finance_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../widgets/modals/log_weight_modal.dart';
import '../widgets/modals/confirm_pregnancy_modal.dart';
import '../widgets/modals/log_birth_modal.dart';
import '../widgets/modals/wean_litter_modal.dart';
import '../widgets/modals/move_cage_modal.dart';
import '../widgets/modals/archive_modal.dart';

class HomeDashboardScreen extends StatefulWidget {
  @override
  _HomeDashboardScreenState createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _selectedNavIndex = 0;

  // ✅ GlobalKey to access HomeTabContent state for refreshing tasks
  final GlobalKey<_HomeTabContentState> _homeTabKey = GlobalKey<_HomeTabContentState>();

  // ✅ Cache screens to prevent recreation
  late final List<Widget> _navScreens;

  @override
  void initState() {
    super.initState();
    _navScreens = [
      HomeTabContent(key: _homeTabKey),
      HerdScreen(),
      LittersScreen(),
      FinanceScreen(),
    ];
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _navScreens[_selectedNavIndex],
      floatingActionButton: _selectedNavIndex == 0
          ? FloatingActionButton(
              backgroundColor: Color(
                0xFF0F7B6C,
              ),
              elevation: 8,
              shape: CircleBorder(),
              child: Icon(
                Icons.add,
                size: 28,
                color: Colors.white,
              ),
              onPressed: () => _showFabModal(
                context,
              ),
            )
          : null,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 10,
            offset: Offset(
              0,
              -2,
            ),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(
          0xFF14B8A6,
        ),
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() => _selectedNavIndex = index);
          // ✅ Reload tasks when switching to Home tab
          if (index == 0) {
            _homeTabKey.currentState?._loadScheduledTasks();
          }
        },
        elevation: 0,
        backgroundColor: Colors.transparent,
        // ✅ FIXED: Only 4 items (removed Reports)
        items: [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(
                bottom: 4,
              ),
              child: Icon(
                PhosphorIcons.house(PhosphorIconsStyle.duotone),
              ),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(
                bottom: 4,
              ),
              child: Icon(
                Icons.pets,
              ),
            ),
            label: 'Herd',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(
                bottom: 4,
              ),
              child: Icon(
                PhosphorIcons.baby(PhosphorIconsStyle.duotone),
                size: 24,
              ),
            ),
            label: 'Litters',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(
                bottom: 4,
              ),
              child: Icon(
                PhosphorIcons.wallet(PhosphorIconsStyle.duotone),
              ),
            ),
            label: 'Finance',
          ),
          // ❌ REMOVED: Reports tab
        ],
      ),
    );
  }

  void _showFabModal(
    BuildContext context,
  ) {
    _showNewScheduleDialog(context);
  }

  void _showNewScheduleDialog(BuildContext context) {
    // State variables for the modal
    String selectedCategory = 'Operations';
    String? selectedTask;
    String selectedFrequency = 'Weekly';
    String selectedLinkType = 'unlinked'; // 'unlinked', 'rabbit', 'litter', 'kit'
    bool isCustomTask = false;
    TextEditingController customTaskController = TextEditingController();

    // Mock data for multi-select
    List<Map<String, String>> linkedEntities = [];
    final Map<String, List<Map<String, String>>> entityData = {
      'rabbit': [
        {
          'id': 'r1',
          'name': 'Luna',
          'code': 'D-101'
        },
        {
          'id': 'r2',
          'name': 'Thumper',
          'code': 'B-02'
        },
        {
          'id': 'r3',
          'name': 'Snowball',
          'code': 'D-112'
        },
        {
          'id': 'r4',
          'name': 'Ginger',
          'code': 'D-108'
        },
      ],
      'litter': [
        {
          'id': 'l1',
          'name': 'L-101',
          'desc': 'Luna x Thumper'
        },
        {
          'id': 'l2',
          'name': 'L-102',
          'desc': 'Ginger x Shadow'
        },
      ],
      'kit': [
        {
          'id': 'k1',
          'name': 'Kit #1',
          'desc': 'From L-101'
        },
        {
          'id': 'k2',
          'name': 'Kit #2',
          'desc': 'From L-101'
        },
      ]
    };

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Task Options Logic
            List<String> currentTaskOptions = [];
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

            // Helper to build a Radio Chip
            Widget buildRadioChip(String label, String value) {
              final bool isSelected = selectedLinkType == value;
              return GestureDetector(
                onTap: () {
                  setDialogState(() {
                    selectedLinkType = value;
                    linkedEntities.clear(); // Clear selections when type changes
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFE6FFFA) : Colors.white,
                    border: Border.all(color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: isSelected ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(0xFF0F7B6C), shape: BoxShape.circle))) : null,
                      ),
                      SizedBox(width: 8),
                      Text(label, style: TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.9),
                padding: EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Header ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Schedule',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F7FA),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // --- Category ---
                      _buildLabel('Category'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputDecoration(),
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
                                selectedTask = null; // Reset task on category change
                                isCustomTask = false;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // --- Task ---
                      _buildLabel('Task'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: isCustomTask ? 'custom' : selectedTask,
                            hint: Text('Select a task...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              ...currentTaskOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))),
                              DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF0F7B6C)))),
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
                      // Custom Task Input (Hidden by default)
                      if (isCustomTask) ...[
                        SizedBox(height: 8),
                        TextField(
                          controller: customTaskController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom task name...',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF0F7B6C))),
                          ),
                        ),
                      ],
                      SizedBox(height: 16),

                      // --- Frequency ---
                      _buildLabel('Frequency'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _inputDecoration(),
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
                      SizedBox(height: 16),

                      // --- Link To (Radio Chips) ---
                      _buildLabel('Link To'),
                      Text('Choose what this task applies to', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildRadioChip('Unlinked', 'unlinked'),
                          buildRadioChip('Rabbit', 'rabbit'),
                          buildRadioChip('Litter', 'litter'),
                          buildRadioChip('Kits (Mixed)', 'kit'),
                        ],
                      ),

                      // --- Dynamic Multi-Select for Linked Entities ---
                      if (selectedLinkType != 'unlinked') ...[
                        SizedBox(height: 16),
                        _buildLabel('Select ${selectedLinkType == 'rabbit' ? 'Rabbits' : selectedLinkType == 'litter' ? 'Litters' : 'Kits'}'),

                        // Fake Multi-select Dropdown
                        Container(
                          width: double.infinity,
                          decoration: _inputDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Selected Chips Area
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (linkedEntities.isEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4, left: 4, bottom: 4),
                                        child: Text('Select...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                                      ),
                                    ...linkedEntities.map((e) => Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFF5F7FA),
                                            border: Border.all(color: Color(0xFFE2E8F0)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(e['name']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                              SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () {
                                                  setDialogState(() {
                                                    linkedEntities.removeWhere((item) => item['id'] == e['id']);
                                                  });
                                                },
                                                child: Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                                              )
                                            ],
                                          ),
                                        ))
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: Color(0xFFE2E8F0)),

                              // Scrollable list of options
                              Container(
                                height: 150,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: (entityData[selectedLinkType] ?? []).map((entity) {
                                    final isSelected = linkedEntities.any((e) => e['id'] == entity['id']);
                                    return InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            linkedEntities.removeWhere((e) => e['id'] == entity['id']);
                                          } else {
                                            linkedEntities.add(entity);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        color: isSelected ? Color(0xFFF5F7FA) : Colors.transparent,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: isSelected ? Color(0xFF0F7B6C) : Colors.transparent,
                                                border: Border.all(color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF64748B), width: 1.5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: isSelected ? Icon(Icons.check, size: 14, color: Colors.white) : null,
                                            ),
                                            SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(entity['name']!, style: TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                                                if (entity.containsKey('code')) Text(entity['code']!, style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                if (entity.containsKey('desc')) Text(entity['desc']!, style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 24),

                      // --- Save Button ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Get final task name
                            String finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? 'Unknown Task');

                            if (finalTaskName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47)),
                              );
                              return;
                            }

                            // Save to database
                            try {
                              await DatabaseService().insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': selectedFrequency,
                                'linkType': selectedLinkType,
                                'linkedEntities': linkedEntities,
                              });

                              Navigator.pop(dialogContext);

                              // ✅ Refresh home tab tasks
                              _homeTabKey.currentState?._loadScheduledTasks();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Schedule Saved'), backgroundColor: Color(0xFF0F7B6C)),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error saving schedule: $e'), backgroundColor: Color(0xFFD44C47)),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0F7B6C),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),

                      // --- Cancel Button ---
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancel', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                        ),
                      )
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

  // Helper widgets for the modal styling
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
      ),
    );
  }

  BoxDecoration _inputDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(8),
    );
  }
  // Link option widget matching screenshot design
}

// Home Tab Content
class HomeTabContent extends StatefulWidget {
  const HomeTabContent({Key? key}) : super(key: key);

  @override
  _HomeTabContentState createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  final DatabaseService _db = DatabaseService();
  String _selectedCategory = 'All';
  String _breedFilter = 'All';
  String _searchQuery = ''; // ✅ Search query
  Set<String> _completedTasks = {};
  Set<String> _expandedGroups = {};

  // ✅ Database scheduled tasks
  List<Map<String, dynamic>> _todayTasks = [];
  List<Map<String, dynamic>> _upcomingTasks = [];

  @override
  void initState() {
    super.initState();
    _loadScheduledTasks();
  }

  /// Load scheduled tasks from database
  Future<void> _loadScheduledTasks() async {
    print('🔄 Loading scheduled tasks from database...');
    final today = await _db.getTasksDueToday();
    final upcoming = await _db.getUpcomingScheduledTasks();
    print('✅ Loaded ${today.length} today tasks, ${upcoming.length} upcoming tasks');
    if (mounted) {
      setState(() {
        _todayTasks = today;
        _upcomingTasks = upcoming;
      });
    }
  }

  /// Handle task tap - show appropriate modal based on taskType
  Future<void> _handleTaskTap(String? taskType, String? rabbitId, String title) async {
    if (taskType == null) return;

    Rabbit? rabbit;
    if (rabbitId != null) {
      rabbit = await _db.getRabbit(rabbitId);
      if (rabbit == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rabbit not found'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    switch (taskType) {
      case 'weight':
        if (rabbit != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => LogWeightModal(
              rabbit: rabbit!,
              onComplete: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
          );
        }
        break;

      case 'palpation':
        if (rabbit != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ConfirmPregnancyModal(
              doe: rabbit!,
              onComplete: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
          );
        }
        break;

      case 'nesting':
        if (rabbit != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => MoveCageModal(
              rabbit: rabbit!,
              onComplete: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
          );
        }
        break;

      case 'kindle':
      case 'birth':
        if (rabbit != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => LogBirthModal(
              doe: rabbit!,
              onComplete: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
          );
        }
        break;

      case 'wean':
        if (rabbit != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => WeanLitterModal(
              doe: rabbit!,
              onComplete: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
          );
        }
        break;

      case 'butcher':
        if (rabbit != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ArchiveModal(
              rabbit: rabbit!,
              onComplete: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
          );
        }
        break;

      case 'operations':
        // Show cost popup
        _showOperationsCostDialog(title);
        break;

      default:
        // For unknown task types, just mark as complete
        break;
    }
  }

  /// Show operations cost dialog
  void _showOperationsCostDialog(String taskTitle) {
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Cost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              taskTitle,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF787774),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: costController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cost incurred',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Skip', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              final cost = double.tryParse(costController.text);
              if (cost != null && cost > 0) {
                // Log expense transaction
                // TODO: Add transaction logging
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Task completed'),
                  backgroundColor: Color(0xFF0F7B6C),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0F7B6C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ Keep this
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white, // ✅ ADD THIS to prevent Material 3 tint
        leading: Padding(
          padding: EdgeInsets.all(14),
          child: Icon(
            Icons.pets,
            color: Color(0xFF0F7B6C),
            size: 28,
          ),
        ),
        title: Text(
          'My Rabbitry',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // ✅ ADD THIS: Profile Dropdown Menu
          PopupMenuButton<String>(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFF0F7B6C).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Color(0xFF0F7B6C),
                size: 20,
              ),
            ),
            offset: Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'reports') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ReportsScreen()),
                );
                // ✅ Reload scheduled tasks after returning
                await _loadScheduledTasks();
              } else if (value == 'settings') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
                // ✅ Reload scheduled tasks after returning from Settings
                await _loadScheduledTasks();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, color: Color(0xFF0F7B6C), size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Color(0xFF64748B), size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Stack(
              children: [
                Icon(
                  Icons.tune,
                  color: Colors.black87,
                ),
                if (_breedFilter != 'All')
                  Positioned(
                    top: 0,
                    right: 0,
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
            onPressed: () => _showFilterModal(),
          ),
          IconButton(
            icon: Stack(
              children: [
                Icon(
                  Icons.search,
                  color: Colors.black87,
                ),
                if (_searchQuery.isNotEmpty)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(0xFF0F7B6C),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showSearchModal(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(),
          _buildCategoryTabs(),
          Expanded(
            child: _buildTaskList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatBox(
              'Tasks Due',
              '14',
              Color(
                0xFF0F7B6C,
              ),
            ),
            SizedBox(
              width: 12,
            ),
            _buildStatBox(
              'Active Litters',
              '5',
              Colors.black87,
            ),
            SizedBox(
              width: 12,
            ),
            _buildStatBox(
              'Breeders',
              '22',
              Colors.black87,
            ),
            SizedBox(
              width: 12,
            ),
            _buildStatBox(
              'Grow-outs',
              '38',
              Colors.black87,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(
    String label,
    String value,
    Color valueColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Color(
            0xFFE9E9E7,
          ),
        ),
        borderRadius: BorderRadius.circular(
          8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: Color(
                0xFF787774,
              ),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(
            height: 4,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(
              0xFFF1F1EF,
            ),
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
        ),
        child: Row(
          children: [
            _buildTab(
              'All',
            ),
            SizedBox(
              width: 8,
            ),
            _buildTab(
              'Reproduction',
            ),
            SizedBox(
              width: 8,
            ),
            _buildTab(
              'Health',
            ),
            SizedBox(
              width: 8,
            ),
            _buildTab(
              'Operations',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    String label,
  ) {
    final isActive = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(
        () => _selectedCategory = label,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Color(
                  0xFFE8F5F3,
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            6,
          ),
          border: Border.all(
            color: isActive
                ? Color(
                    0xFF0F7B6C,
                  ).withOpacity(
                    0.1,
                  )
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
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
    );
  }

  Widget _buildTaskList() {
    return ListView(
      padding: EdgeInsets.all(
        16,
      ),
      children: [
        // TODAY & OVERDUE Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TODAY & OVERDUE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(
                  0xFF787774,
                ),
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Color(
                  0xFFF7F7F5,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                _getFilteredTodayTasksCount().toString(),
                style: TextStyle(
                  fontSize: 11,
                  color: Color(
                    0xFF787774,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 12,
        ),

        // TODAY & OVERDUE Tasks
        ..._getFilteredTodayTasks(),

        // Show empty state if no tasks
        if (_getFilteredTodayTasks().isEmpty)
          _buildEmptyState(
            'No tasks match your filter',
          ),

        SizedBox(
          height: 32,
        ),

        // UPCOMING Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UPCOMING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(
                  0xFF787774,
                ),
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Color(
                  0xFFF7F7F5,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
              child: Text(
                _getFilteredUpcomingTasksCount().toString(),
                style: TextStyle(
                  fontSize: 11,
                  color: Color(
                    0xFF787774,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 12,
        ),

        // UPCOMING Tasks
        ..._getFilteredUpcomingTasks(),

        // Show empty state if no upcoming tasks
        if (_getFilteredUpcomingTasks().isEmpty)
          _buildEmptyState(
            'No upcoming tasks match your filter',
          ),

        SizedBox(
          height: 100,
        ),
      ],
    );
  }

  // Helper method to get filtered TODAY tasks
  List<Widget> _getFilteredTodayTasks() {
    List<Widget> tasks = [];

    // Palpation Checks Group (Rex breed) - Category: Mating → Reproduction
    if (_shouldShowCategory('Mating')) {
      List<Map<String, String>> palpationTasks = [
        {
          'name': 'Luna',
          'breed': 'Rex',
          'location': 'Cage 12'
        },
        {
          'name': 'Star',
          'breed': 'Rex',
          'location': 'Cage 14'
        },
        {
          'name': 'Ginger',
          'breed': 'NZ White',
          'location': 'Cage 15'
        },
      ];

      List<Map<String, String>> filteredPalpation = palpationTasks.where((task) => _shouldShowBreed(task['breed']) && _matchesSearch('Palpation Checks ${task['name']}', task['breed'], task['location'])).toList();

      if (filteredPalpation.isNotEmpty) {
        tasks.add(
          _buildGroupTask(
            title: 'Palpation Checks',
            count: filteredPalpation.length,
            category: 'Mating',
            categoryColor: Color(0xFFF6F0FF),
            categoryTextColor: Color(0xFF6931B6),
            icon: Icons.favorite_outline,
            date: 'Today',
            isOverdue: false,
            subTasks: filteredPalpation,
            taskType: 'palpation',
          ),
        );
        tasks.add(SizedBox(height: 12));
      }
    }

    // Check Sore Hocks (Silver Fox) - Category: Medical → Health
    if (_shouldShowCategory('Medical') && _shouldShowBreed('Silver Fox') && _matchesSearch('Check Sore Hocks: Buck #42', 'Silver Fox', 'Cage 02')) {
      tasks.add(
        _buildSingleTask(
          title: 'Check Sore Hocks: Buck #42',
          category: 'Medical',
          categoryColor: Color(0xFFFFEBEB),
          categoryTextColor: Color(0xFFBF360C),
          icon: Icons.medical_services_outlined,
          breed: 'Silver Fox',
          location: 'Cage 02',
          date: 'Today',
          isOverdue: false,
          taskType: 'operations',
        ),
      );
      tasks.add(SizedBox(height: 12));
    }

    // Sanitize Row A (no breed) - Category: Housing → Operations
    if (_shouldShowCategory('Housing') && _breedFilter == 'All' && _matchesSearch('Sanitize: Row A Trays', null, 'Row A')) {
      tasks.add(
        _buildSingleTask(
          title: 'Sanitize: Row A Trays',
          category: 'Housing',
          categoryColor: Color(
            0xFFE3F2FD,
          ),
          categoryTextColor: Color(
            0xFF0D47A1,
          ),
          icon: Icons.cleaning_services_outlined,
          breed: null,
          location: 'Row A',
          date: 'Today',
          isOverdue: false,
          taskType: 'operations',
        ),
      );
      tasks.add(
        SizedBox(
          height: 12,
        ),
      );
    }

    // L-202 Weights (Rex) - Category: Weight → Health
    if (_shouldShowCategory('Weight')) {
      List<Map<String, String>> weightTasks = [
        {
          'name': 'Kit #1 (Black)',
          'breed': 'Rex',
          'location': 'Cage 20'
        },
        {
          'name': 'Kit #2 (Broken)',
          'breed': 'Rex',
          'location': 'Cage 20'
        },
        {
          'name': 'Kit #3 (Castor)',
          'breed': 'Rex',
          'location': 'Cage 20'
        },
      ];

      List<Map<String, String>> filteredWeights = weightTasks.where((task) => _shouldShowBreed(task['breed']) && _matchesSearch('L-202 Weights ${task['name']}', task['breed'], task['location'])).toList();

      if (filteredWeights.isNotEmpty) {
        tasks.add(
          _buildGroupTask(
            title: 'L-202 Weights',
            count: filteredWeights.length,
            category: 'Weight',
            categoryColor: Color(0xFFFFEBEB),
            categoryTextColor: Color(0xFFBF360C),
            icon: Icons.monitor_weight_outlined,
            date: 'Today',
            isOverdue: false,
            subTasks: filteredWeights,
            taskType: 'weight',
          ),
        );
        tasks.add(SizedBox(height: 12));
      }
    }

    // ✅ Add scheduled tasks from database (Today/Overdue)
    for (var task in _todayTasks) {
      final taskName = task['name'] ?? task['task'] ?? 'Task';
      final taskCategory = task['category'] ?? 'Operations';
      final taskLocation = task['linkType'] == 'unlinked' ? 'Unlinked' : '${task['linkType']}';

      // Apply all filters
      if (!_shouldShowCategory(taskCategory)) continue;
      if (!_matchesSearch(taskName, null, taskLocation)) continue;

      tasks.add(
        _buildSingleTask(
          title: taskName,
          category: taskCategory,
          categoryColor: _getCategoryColor(task['category']),
          categoryTextColor: _getCategoryTextColor(task['category']),
          icon: _getCategoryIcon(task['category']),
          breed: null, // Scheduled tasks don't have breed
          location: taskLocation,
          date: 'Today',
          isOverdue: _isTaskOverdue(task['dueDate']),
          taskType: 'scheduled',
        ),
      );
      tasks.add(SizedBox(height: 12));
    }

    // Remove last spacing if tasks exist
    if (tasks.isNotEmpty && tasks.last is SizedBox) {
      tasks.removeLast();
    }

    return tasks;
  }

  List<Widget> _getFilteredUpcomingTasks() {
    List<Widget> tasks = [];

    // Nest Box Prep (NZ White) - Category: Kindling → Reproduction
    if (_shouldShowCategory('Kindling') && _shouldShowBreed('NZ White') && _matchesSearch('Nest Box Prep: Bella', 'NZ White', 'Row A')) {
      tasks.add(
        _buildSingleTask(
          title: 'Nest Box Prep: Bella',
          category: 'Kindling',
          categoryColor: Color(0xFFF6F0FF),
          categoryTextColor: Color(0xFF6931B6),
          icon: Icons.child_care_outlined,
          breed: 'NZ White',
          location: 'Row A',
          date: 'Jan 23',
          isOverdue: false,
          taskType: 'nesting',
        ),
      );
      tasks.add(SizedBox(height: 12));
    }

    // Wean Litter (Mix) - Category: Weaning → Reproduction
    if (_shouldShowCategory('Weaning') && _shouldShowBreed('Mix') && _matchesSearch('Wean Litter: L-204', 'Mix', 'Cage 05')) {
      tasks.add(
        _buildSingleTask(
          title: 'Wean Litter: L-204',
          category: 'Weaning',
          categoryColor: Color(0xFFF6F0FF),
          categoryTextColor: Color(0xFF6931B6),
          icon: Icons.group_outlined,
          breed: 'Mix',
          location: 'Cage 05',
          date: 'Jan 25',
          isOverdue: false,
          taskType: 'wean',
        ),
      );
      tasks.add(SizedBox(height: 12));
    }

    // Deworming (Dutch) - Category: Medical → Health
    if (_shouldShowCategory('Medical') && _shouldShowBreed('Dutch') && _matchesSearch('Mass Deworming', 'Dutch', 'Whole Herd')) {
      tasks.add(
        _buildSingleTask(
          title: 'Mass Deworming',
          category: 'Medical',
          categoryColor: Color(0xFFFFEBEB),
          categoryTextColor: Color(0xFFBF360C),
          icon: Icons.medical_services_outlined,
          breed: 'Dutch',
          location: 'Whole Herd',
          date: 'Jan 27',
          isOverdue: false,
          taskType: 'operations',
        ),
      );
      tasks.add(SizedBox(height: 12));
    }

    // ✅ Add scheduled tasks from database (Upcoming)
    for (var task in _upcomingTasks) {
      final taskName = task['name'] ?? task['task'] ?? 'Task';
      final taskCategory = task['category'] ?? 'Operations';
      final taskLocation = task['linkType'] == 'unlinked' ? 'Unlinked' : '${task['linkType']}';

      // Apply all filters
      if (!_shouldShowCategory(taskCategory)) continue;
      if (!_matchesSearch(taskName, null, taskLocation)) continue;

      final dueDate = DateTime.tryParse(task['dueDate'] ?? '');
      final dateStr = dueDate != null ? _formatDueDate(dueDate) : 'Upcoming';

      tasks.add(
        _buildSingleTask(
          title: taskName,
          category: taskCategory,
          categoryColor: _getCategoryColor(task['category']),
          categoryTextColor: _getCategoryTextColor(task['category']),
          icon: _getCategoryIcon(task['category']),
          breed: null,
          location: task['linkType'] == 'unlinked' ? 'Unlinked' : '${task['linkType']}',
          date: dateStr,
          isOverdue: false,
          taskType: 'scheduled',
        ),
      );
      tasks.add(SizedBox(height: 12));
    }

    // Remove last spacing if tasks exist
    if (tasks.isNotEmpty && tasks.last is SizedBox) {
      tasks.removeLast();
    }

    return tasks;
  }

  // ✅ Helper: Format due date for display
  String _formatDueDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}';
  }

  // ✅ Helper: Check if task is overdue
  bool _isTaskOverdue(String? dueDateStr) {
    if (dueDateStr == null) return false;
    final dueDate = DateTime.tryParse(dueDateStr);
    if (dueDate == null) return false;
    return dueDate.isBefore(DateTime.now());
  }

  // ✅ Helper: Get category color
  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Health':
        return Color(0xFFFFEBEB);
      case 'Operations':
        return Color(0xFFE8F5E9);
      case 'Butchering':
        return Color(0xFFFFF3E0);
      case 'Pregnancy':
        return Color(0xFFF6F0FF);
      case 'Reproduction':
        return Color(0xFFFCE4EC);
      default:
        return Color(0xFFF5F5F5);
    }
  }

  // ✅ Helper: Get category text color
  Color _getCategoryTextColor(String? category) {
    switch (category) {
      case 'Health':
        return Color(0xFFBF360C);
      case 'Operations':
        return Color(0xFF2E7D32);
      case 'Butchering':
        return Color(0xFFE65100);
      case 'Pregnancy':
        return Color(0xFF6931B6);
      case 'Reproduction':
        return Color(0xFFC2185B);
      default:
        return Color(0xFF616161);
    }
  }

  // ✅ Helper: Get category icon
  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Health':
        return Icons.medical_services_outlined;
      case 'Operations':
        return Icons.build_outlined;
      case 'Butchering':
        return Icons.content_cut_outlined;
      case 'Pregnancy':
        return Icons.child_care_outlined;
      case 'Reproduction':
        return Icons.favorite_outline;
      default:
        return Icons.task_alt_outlined;
    }
  }

  // Helper method to check if breed should be shown
  bool _shouldShowBreed(
    String? breed,
  ) {
    if (_breedFilter == 'All') return true;
    if (breed == null) return false;
    return breed == _breedFilter;
  }

  // Helper to get count of filtered today tasks
  int _getFilteredTodayTasksCount() {
    int count = 0;

    // Palpation - Category: Mating → Reproduction
    if (_shouldShowCategory('Mating')) {
      List<Map<String, String>> palpationTasks = [
        {
          'name': 'Luna',
          'breed': 'Rex',
          'location': 'Cage 12'
        },
        {
          'name': 'Star',
          'breed': 'Rex',
          'location': 'Cage 14'
        },
        {
          'name': 'Ginger',
          'breed': 'NZ White',
          'location': 'Cage 15'
        },
      ];
      count += palpationTasks.where((task) => _shouldShowBreed(task['breed']) && _matchesSearch('Palpation Checks ${task['name']}', task['breed'], task['location'])).length;
    }

    // Sore hocks - Category: Medical → Health
    if (_shouldShowCategory('Medical') && _shouldShowBreed('Silver Fox') && _matchesSearch('Check Sore Hocks: Buck #42', 'Silver Fox', 'Cage 02')) {
      count++;
    }

    // Sanitize - Category: Housing → Operations
    if (_shouldShowCategory('Housing') && _breedFilter == 'All' && _matchesSearch('Sanitize: Row A Trays', null, 'Row A')) {
      count++;
    }

    // Weights - Category: Weight → Health
    if (_shouldShowCategory('Weight')) {
      List<Map<String, String>> weightTasks = [
        {
          'name': 'Kit #1 (Black)',
          'breed': 'Rex',
          'location': 'Cage 20'
        },
        {
          'name': 'Kit #2 (Broken)',
          'breed': 'Rex',
          'location': 'Cage 20'
        },
        {
          'name': 'Kit #3 (Castor)',
          'breed': 'Rex',
          'location': 'Cage 20'
        },
      ];
      count += weightTasks.where((task) => _shouldShowBreed(task['breed']) && _matchesSearch('L-202 Weights ${task['name']}', task['breed'], task['location'])).length;
    }

    // Database tasks
    for (var task in _todayTasks) {
      final taskName = task['name'] ?? task['task'] ?? 'Task';
      final taskCategory = task['category'] ?? 'Operations';
      final taskLocation = task['linkType'] == 'unlinked' ? 'Unlinked' : '${task['linkType']}';

      if (_shouldShowCategory(taskCategory) && _matchesSearch(taskName, null, taskLocation)) {
        count++;
      }
    }

    return count;
  }

  // Helper to get count of filtered upcoming tasks
  int _getFilteredUpcomingTasksCount() {
    int count = 0;

    // Nest Box - Category: Kindling → Reproduction
    if (_shouldShowCategory('Kindling') && _shouldShowBreed('NZ White') && _matchesSearch('Nest Box Prep: Bella', 'NZ White', 'Row A')) {
      count++;
    }

    // Wean - Category: Weaning → Reproduction
    if (_shouldShowCategory('Weaning') && _shouldShowBreed('Mix') && _matchesSearch('Wean Litter: L-204', 'Mix', 'Cage 05')) {
      count++;
    }

    // Deworming - Category: Medical → Health
    if (_shouldShowCategory('Medical') && _shouldShowBreed('Dutch') && _matchesSearch('Mass Deworming', 'Dutch', 'Whole Herd')) {
      count++;
    }

    // Database tasks
    for (var task in _upcomingTasks) {
      final taskName = task['name'] ?? task['task'] ?? 'Task';
      final taskCategory = task['category'] ?? 'Operations';
      final taskLocation = task['linkType'] == 'unlinked' ? 'Unlinked' : '${task['linkType']}';

      if (_shouldShowCategory(taskCategory) && _matchesSearch(taskName, null, taskLocation)) {
        count++;
      }
    }

    return count;
  }

  // Empty state widget
  Widget _buildEmptyState(
    String message,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 40,
      ),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off,
            size: 48,
            color: Color(
              0xFFE9E9E7,
            ),
          ),
          SizedBox(
            height: 12,
          ),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Color(
                0xFF9B9A97,
              ),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _breedFilter = 'All';
                _searchQuery = '';
                _selectedCategory = 'All';
              });
            },
            child: Text(
              'Clear All Filters',
              style: TextStyle(
                color: Color(
                  0xFF0F7B6C,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
  }) {
    final taskId = '$title-$location'; // Unique ID for each task
    final isCompleted = _completedTasks.contains(
      taskId,
    );

    return GestureDetector(
      onTap: () => _handleTaskTap(taskType, rabbitId, title),
      child: Container(
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
            // Interactive Checkbox - UPDATED
            GestureDetector(
              onTap: () {
                setState(
                  () {
                    if (isCompleted) {
                      _completedTasks.remove(
                        taskId,
                      );
                    } else {
                      _completedTasks.add(
                        taskId,
                      );
                    }
                  },
                );
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Color(
                          0xFF0F7B6C,
                        )
                      : Colors.transparent,
                  border: Border.all(
                    color: isCompleted
                        ? Color(
                            0xFF0F7B6C,
                          )
                        : Color(
                            0xFFE9E9E7,
                          ),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(
                    6,
                  ),
                ),
                child: isCompleted
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            SizedBox(
              width: 16,
            ),

            // Content - Add strikethrough when completed
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? Color(
                                    0xFF9B9A97,
                                  )
                                : Colors.black87,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue
                              ? Color(
                                  0xFFD44C47,
                                )
                              : Color(
                                  0xFF787774,
                                ),
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 6,
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(
                            4,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 12,
                              color: categoryTextColor,
                            ),
                            SizedBox(
                              width: 4,
                            ),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: categoryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (breed != null) ...[
                        SizedBox(
                          width: 6,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Color(
                              0xFFEEEEEE,
                            ),
                            borderRadius: BorderRadius.circular(
                              4,
                            ),
                          ),
                          child: Text(
                            breed,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(
                                0xFF666666,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(
                        width: 6,
                      ),
                      Text(
                        '• $location',
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

            // Action Icons
            SizedBox(
              width: 12,
            ),
            Icon(
              Icons.block,
              size: 20,
              color: Color(
                0xFF9B9A97,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTask({
    required String title,
    required int count,
    required String category,
    required Color categoryColor,
    required Color categoryTextColor,
    required IconData icon,
    required String date,
    required bool isOverdue,
    required List<Map<String, String>> subTasks,
    String? taskType,
  }) {
    // Filter subtasks based on breed
    final filteredSubTasks = subTasks.where(
      (
        task,
      ) {
        if (_breedFilter == 'All') return true;
        return task['breed'] == _breedFilter;
      },
    ).toList();

    // Don't show group if no tasks match filter
    if (filteredSubTasks.isEmpty) return SizedBox.shrink();

    final groupId = '$title-group';
    final isGroupCompleted = _completedTasks.contains(
      groupId,
    );
    final isExpanded = _expandedGroups.contains(
      groupId,
    );
    final actualCount = filteredSubTasks.length; // Use filtered count

    return Container(
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
          // Main Group Header
          InkWell(
            onTap: () {
              setState(
                () {
                  if (isExpanded) {
                    _expandedGroups.remove(
                      groupId,
                    );
                  } else {
                    _expandedGroups.add(
                      groupId,
                    );
                  }
                },
              );
            },
            child: Padding(
              padding: EdgeInsets.all(
                14,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(
                        () {
                          if (isGroupCompleted) {
                            _completedTasks.remove(
                              groupId,
                            );
                            for (var task in filteredSubTasks) {
                              _completedTasks.remove(
                                '${task['name']}-${task['location']}',
                              );
                            }
                          } else {
                            _completedTasks.add(
                              groupId,
                            );
                            for (var task in filteredSubTasks) {
                              _completedTasks.add(
                                '${task['name']}-${task['location']}',
                              );
                            }
                          }
                        },
                      );
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isGroupCompleted
                            ? Color(
                                0xFF0F7B6C,
                              )
                            : Colors.transparent,
                        border: Border.all(
                          color: isGroupCompleted
                              ? Color(
                                  0xFF0F7B6C,
                                )
                              : Color(
                                  0xFFE9E9E7,
                                ),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(
                          6,
                        ),
                      ),
                      child: isGroupCompleted
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
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
                            Expanded(
                              child: Text(
                                '$title ($actualCount)', // Show filtered count
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isGroupCompleted
                                      ? Color(
                                          0xFF9B9A97,
                                        )
                                      : Colors.black87,
                                  decoration: isGroupCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue
                                    ? Color(
                                        0xFFD44C47,
                                      )
                                    : Color(
                                        0xFF787774,
                                      ),
                                fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 6,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor,
                            borderRadius: BorderRadius.circular(
                              4,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 12,
                                color: categoryTextColor,
                              ),
                              SizedBox(
                                width: 4,
                              ),
                              Text(
                                category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: categoryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 12,
                  ),
                  Icon(
                    Icons.block,
                    size: 20,
                    color: Color(
                      0xFF9B9A97,
                    ),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: Duration(
                      milliseconds: 200,
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 24,
                      color: Color(
                        0xFF9B9A97,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subtasks - use filteredSubTasks
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: Container(
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
                children: filteredSubTasks.map(
                  (
                    task,
                  ) {
                    final subTaskId = '${task['name']}-${task['location']}';
                    final isSubCompleted = _completedTasks.contains(
                      subTaskId,
                    );

                    return GestureDetector(
                      onTap: () => _handleTaskTap(taskType, task['rabbitId'], task['name'] ?? ''),
                      child: Container(
                        padding: EdgeInsets.all(
                          10,
                        ),
                        decoration: BoxDecoration(
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
                            SizedBox(
                              width: 38,
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(
                                  () {
                                    if (isSubCompleted) {
                                      _completedTasks.remove(
                                        subTaskId,
                                      );
                                      _completedTasks.remove(
                                        groupId,
                                      );
                                    } else {
                                      _completedTasks.add(
                                        subTaskId,
                                      );
                                      bool allCompleted = filteredSubTasks.every(
                                        (
                                          t,
                                        ) =>
                                            _completedTasks.contains(
                                          '${t['name']}-${t['location']}',
                                        ),
                                      );
                                      if (allCompleted) {
                                        _completedTasks.add(
                                          groupId,
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isSubCompleted
                                      ? Color(
                                          0xFF0F7B6C,
                                        )
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSubCompleted
                                        ? Color(
                                            0xFF0F7B6C,
                                          )
                                        : Color(
                                            0xFFE9E9E7,
                                          ),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    4,
                                  ),
                                ),
                                child: isSubCompleted
                                    ? Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.white,
                                      )
                                    : null,
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
                                        task['name']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isSubCompleted
                                              ? Color(
                                                  0xFF9B9A97,
                                                )
                                              : Colors.black87,
                                          decoration: isSubCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 6,
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(
                                            0xFFEEEEEE,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          task['breed']!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(
                                              0xFF666666,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 2,
                                  ),
                                  Text(
                                    task['location']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(
                                        0xFF787774,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.block,
                              size: 18,
                              color: Color(
                                0xFF9B9A97,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(
              milliseconds: 200,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Search modal
  void _showSearchModal() {
    final searchController = TextEditingController(text: _searchQuery);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search Tasks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by task name, breed, location...',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF787774)),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Color(0xFF787774)),
                          onPressed: () {
                            searchController.clear();
                            setState(() => _searchQuery = '');
                            Navigator.pop(context);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (value) {
                  setState(() => _searchQuery = value.trim());
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() => _searchQuery = '');
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF787774),
                        side: BorderSide(color: Color(0xFFE2E8F0)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Clear'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _searchQuery = searchController.text.trim());
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0F7B6C),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Search'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Helper: Map task category to tab category
  bool _shouldShowCategory(String? taskCategory) {
    if (_selectedCategory == 'All') return true;
    if (taskCategory == null) return _selectedCategory == 'All';

    // Map task categories to tab categories
    switch (_selectedCategory) {
      case 'Reproduction':
        return [
          'Mating',
          'Kindling',
          'Weaning',
          'Pregnancy',
          'Reproduction'
        ].contains(taskCategory);
      case 'Health':
        return [
          'Medical',
          'Health',
          'Weight'
        ].contains(taskCategory);
      case 'Operations':
        return [
          'Housing',
          'Operations',
          'Butchering'
        ].contains(taskCategory);
      default:
        return taskCategory == _selectedCategory;
    }
  }

  // ✅ Helper: Check if task matches search query
  bool _matchesSearch(String title, String? breed, String? location) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return title.toLowerCase().contains(query) || (breed?.toLowerCase().contains(query) ?? false) || (location?.toLowerCase().contains(query) ?? false);
  }

  void _showFilterModal() {
    showDialog(
      context: context,
      builder: (
        context,
      ) =>
          Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: 32,
          ),
          padding: EdgeInsets.all(
            20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              16,
            ),
          ),
          child: Material(
            // ← ADD THIS WRAPPER
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Breed',
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
                SizedBox(
                  height: 16,
                ),
                ...[
                  'All',
                  'Rex',
                  'NZ White',
                  'Dutch',
                  'Silver Fox',
                  'Mix',
                ].map(
                  (
                    breed,
                  ) {
                    final isSelected = _breedFilter == breed;
                    return InkWell(
                      onTap: () {
                        setState(
                          () => _breedFilter = breed,
                        );
                        Navigator.pop(
                          context,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        margin: EdgeInsets.only(
                          bottom: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(
                                  0xFFE8F5F3,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            8,
                          ),
                          border: isSelected
                              ? Border.all(
                                  color: Color(
                                    0xFF0F7B6C,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              breed,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected
                                    ? Color(
                                        0xFF0F7B6C,
                                      )
                                    : Colors.black87,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check,
                                color: Color(
                                  0xFF0F7B6C,
                                ),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Placeholder Screen for other tabs
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(
              height: 16,
            ),
            Text(
              '$title Coming Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(
              height: 8,
            ),
            Text(
              'This feature is under development',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
