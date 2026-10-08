import 'package:flutter/material.dart';
import '../../models/barn.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../constants/app_colors.dart';

class MoveCageModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const MoveCageModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<MoveCageModal> createState() => _MoveCageModalState();
}

class _MoveCageModalState extends State<MoveCageModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _cageController = TextEditingController();
  String? _selectedLocation;
  bool _isSaving = false;
  bool _isLoading = true;

  List<Barn> _barns = [];
  Map<String, String> _rowToBarn = {};

  @override
  void initState() {
    super.initState();
    _cageController.text = widget.rabbit.cage ?? '';
    _loadBarns();
  }

  @override
  void dispose() {
    _cageController.dispose();
    super.dispose();
  }

  Future<void> _loadBarns() async {
    final barnsData = await _db.getAllBarns();
    final barns = barnsData.map((b) => Barn.fromMap(b)).toList();

    final rowToBarn = <String, String>{};
    for (var barn in barns) {
      for (var row in barn.rows) {
        rowToBarn[row.name] = barn.name;
      }
    }

    if (mounted) {
      setState(() {
        _barns = barns;
        _rowToBarn = rowToBarn;
        _selectedLocation = rowToBarn.containsKey(widget.rabbit.location) ? widget.rabbit.location : widget.rabbit.location;
        _isLoading = false;
      });
    }
  }

  String _formatRabbitName() {
    final prefix = (widget.rabbit.breederPrefix ?? '').trim();
    final name = widget.rabbit.name.trim();
    final ear = (widget.rabbit.earNumber?.trim().isNotEmpty == true
            ? widget.rabbit.earNumber!.trim()
            : widget.rabbit.id.trim())
        .toUpperCase();

    final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
    if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
      return '$namePart $ear';
    }
    return namePart;
  }

  @override
  Widget build(BuildContext context) {
    final isDoe = widget.rabbit.type == RabbitType.doe;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header banner (matches NEW TASK modal style)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: kLilacLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilac, width: 1)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3E6D).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Move Cage',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A3E6D),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatRabbitName(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.rabbit.location != null || widget.rabbit.cage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Current: ${widget.rabbit.location ?? 'N/A'} • ${widget.rabbit.cage ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF787774),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Modal body fields
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep)),
              ),
            )
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Dropdown field matching New Task InputDecorator
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Location / Barn',
                      labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                      floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kLilacLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLocation,
                        hint: const Text(
                          'Select Location',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: kNeutral400),
                        ),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
                        items: [
                          ..._buildLocationDropdownItems(),
                          const DropdownMenuItem<String>(
                            value: '__add_new__',
                            child: Text(
                              '+ Add New Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__add_new__') {
                            _showAddLocationDialog();
                          } else {
                            setState(() {
                              _selectedLocation = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cage / Hutch ID text field matching New Task modal
                  TextField(
                    controller: _cageController,
                    decoration: InputDecoration(
                      labelText: 'Cage / Hutch ID',
                      hintText: 'e.g., A-01, Row 1 Cage 3',
                      hintStyle: const TextStyle(color: kNeutral400, fontSize: 15, fontWeight: FontWeight.w400),
                      labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                      floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kLilacLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                  ),

                  const SizedBox(height: 24),

                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveCage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B6BA0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Move Cage',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildLocationDropdownItems() {
    final List<DropdownMenuItem<String>> items = [];
    int counter = 0;

    for (var barn in _barns) {
      for (var row in barn.rows) {
        final isAlt = counter % 2 == 1;
        counter++;
        items.add(
          DropdownMenuItem<String>(
            value: row.name,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isAlt ? const Color(0xFFF6F0FD) : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3A3A3C),
                    ),
                  ),
                  Text(
                    barn.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return items;
  }

  void _showAddLocationDialog() {
    String? selectedBarnId;
    final rowController = TextEditingController();
    final barnController = TextEditingController();
    bool isNewBarn = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4A3E6D))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Barn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56))),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kLilacLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedBarnId,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    hintText: 'Select barn',
                    hintStyle: TextStyle(fontSize: 14, color: kNeutral400),
                  ),
                  isExpanded: true,
                  items: [
                    ..._barns.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name),
                        )),
                    const DropdownMenuItem(
                      value: '__new_barn__',
                      child: Text('+ Create New Barn', style: TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w600)),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == '__new_barn__') {
                        isNewBarn = true;
                        selectedBarnId = null;
                      } else {
                        isNewBarn = false;
                        selectedBarnId = val;
                      }
                    });
                  },
                ),
              ),
              if (isNewBarn) ...[
                const SizedBox(height: 12),
                const Text('New Barn Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56))),
                const SizedBox(height: 6),
                TextField(
                  controller: barnController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g., Barn 3',
                    hintStyle: const TextStyle(color: kNeutral400, fontSize: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Row / Location Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56))),
              const SizedBox(height: 6),
              TextField(
                controller: rowController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Row 5',
                  hintStyle: const TextStyle(color: kNeutral400, fontSize: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
            ),
            ElevatedButton(
              onPressed: () async {
                final rowName = rowController.text.trim();
                if (rowName.isEmpty) return;

                if (isNewBarn) {
                  final barnName = barnController.text.trim();
                  if (barnName.isEmpty) return;
                  final newBarn = Barn(
                    id: 'barn_${DateTime.now().millisecondsSinceEpoch}',
                    name: barnName,
                    rows: [
                      BarnRow(name: rowName, cages: [])
                    ],
                  );
                  await _db.insertBarn(newBarn.toMap());
                } else if (selectedBarnId != null) {
                  final barn = _barns.firstWhere((b) => b.id == selectedBarnId);
                  final updatedRows = [
                    ...barn.rows,
                    BarnRow(name: rowName, cages: [])
                  ];
                  final updatedBarn = Barn(
                    id: barn.id,
                    name: barn.name,
                    rows: updatedRows,
                    notes: barn.notes,
                    createdAt: barn.createdAt,
                  );
                  await _db.updateBarn(updatedBarn.toMap());
                } else {
                  return;
                }

                Navigator.pop(ctx);
                await _loadBarns();
                setState(() => _selectedLocation = rowName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B6BA0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCage() async {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location'), backgroundColor: Color(0xFFD44C47)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cage = _cageController.text.trim();
      await _db.moveCage(widget.rabbit.id, _selectedLocation!, cage);

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved ${widget.rabbit.name} to $_selectedLocation${cage.isNotEmpty ? ' • $cage' : ''}'),
            backgroundColor: const Color(0xFF7B6BA0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD44C47)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
