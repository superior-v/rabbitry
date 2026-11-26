import '../purple_dialog.dart';
import 'package:flutter/material.dart';
import '../../services/appearance_service.dart';
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
  String? _selectedCage;
  bool _isSaving = false;
  bool _isLoading = true;

  List<Barn> _barns = [];
  Map<String, String> _rowToBarn = {};

  @override
  void initState() {
    super.initState();
    _selectedCage = (widget.rabbit.cage ?? '').isEmpty ? null : widget.rabbit.cage;
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
        final loc = widget.rabbit.location;
        _selectedLocation = (loc == null || loc.isEmpty) ? null : (rowToBarn[loc] ?? loc);
        _isLoading = false;
      });
    }
  }

  Widget _buildRabbitHeaderName(Rabbit rabbit, {double fontSize = 14}) {
    final isDoe = rabbit.type == RabbitType.doe;
    final isArchived = rabbit.status == RabbitStatus.archived;
    final nameColor = isDoe
        ? (isArchived ? appColor(0xFFF48FB1) : appColor(0xFFE04F9F))
        : (isArchived ? appColor(0xFF80BFFF) : appColor(0xFF2196F3));
    final prefix = (rabbit.breederPrefix ?? '').trim();
    final name = rabbit.name.trim();
    final ear = (rabbit.earNumber?.trim().isNotEmpty == true
            ? rabbit.earNumber!.trim()
            : (rabbit.id.length >= 6 ? rabbit.id.substring(0, 6) : rabbit.id).trim())
        .toUpperCase();

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: '$prefix ',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: appColor(0xFF787774),
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: nameColor,
            ),
          ),
          if (ear.isNotEmpty && !name.toUpperCase().endsWith(ear))
            TextSpan(
              text: ' $ear',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: appColor(0xFF787774),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kAppCardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header banner (matches NEW TASK modal style)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
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
                      color: appSurface(0xFF4A3E6D).withValues(alpha: 0.3),
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
                          Text(
                            'Move Cage',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: appColor(0xFF4A3E6D),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _buildRabbitHeaderName(widget.rabbit, fontSize: 14),
                          if (widget.rabbit.location != null || widget.rabbit.cage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Current: ${widget.rabbit.location ?? 'N/A'} • ${widget.rabbit.cage ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: appColor(0xFF787774),
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
                          color: kAppCardWhite.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: appColor(0xFF4A3E6D), size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Modal body fields
          if (_isLoading)
            Padding(
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
                  _buildPickerField(
                    label: 'Location',
                    hint: 'Select Location',
                    value: _selectedLocation,
                    options: _locationOptions(),
                    onChanged: (val) => setState(() {
                      _selectedLocation = val;
                      _selectedCage = null;
                    }),
                  ),

                  const SizedBox(height: 16),

                  _buildPickerField(
                    label: 'Cage',
                    hint: _selectedLocation == null
                        ? 'Select Location first'
                        : (_cageOptions().isEmpty ? 'No cages in this location' : 'Select Cage'),
                    value: _selectedCage,
                    options: _cageOptions(),
                    onChanged: (val) => setState(() => _selectedCage = val),
                  ),

                  const SizedBox(height: 24),

                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveCage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appSurface(0xFFE6BEFE),
                        foregroundColor: appColor(0xFF4A3E6D),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(appColor(0xFF4A3E6D)),
                              ),
                            )
                          : Text(
                              'Move',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: appColor(0xFF4A3E6D),
                              ),
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

  List<String> _locationOptions() {
    final names = _barns.map((b) => b.name).toList();
    if (_selectedLocation != null && !names.contains(_selectedLocation)) {
      names.add(_selectedLocation!);
    }
    return names;
  }

  List<String> _cageOptions() {
    final cages = <String>[];
    if (_selectedLocation != null) {
      for (final barn in _barns.where((b) => b.name == _selectedLocation)) {
        for (final row in barn.rows) {
          cages.addAll(row.cages);
        }
      }
    }
    if (_selectedCage != null && !cages.contains(_selectedCage)) {
      cages.add(_selectedCage!);
    }
    return cages;
  }

  Widget _buildPickerField({
    required String label,
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: appColor(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
        floatingLabelStyle: TextStyle(color: appColor(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kLilacLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appSurface(0xFF7B6BA0), width: 1.5),
        ),
        filled: true,
        fillColor: kAppCardWhite,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey('$label-$value-${options.length}'),
          value: options.contains(value) ? value : null,
          hint: Text(hint, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: kNeutral400)),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: appColor(0xFF4A3E6D)),
          menuMaxHeight: 320,
          items: options
              .asMap()
              .entries
              .map((e) => DropdownMenuItem<String>(
                    value: e.value,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: e.key % 2 == 1 ? appSurface(0xFFF6F0FD) : kAppCardWhite,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: appColor(0xFF3A3A3C)),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
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
                color: isAlt ? appSurface(0xFFF6F0FD) : kAppCardWhite,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: appColor(0xFF3A3A3C),
                    ),
                  ),
                  Text(
                    barn.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: appColor(0xFF8E8E93),
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
          backgroundColor: kAppCardWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add New Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: appColor(0xFF4A3E6D))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Barn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appColor(0xFF4F4F56))),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kLilacLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedBarnId,
                  decoration: InputDecoration(
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
                    DropdownMenuItem(
                      value: '__new_barn__',
                      child: Text('+ Create New Barn', style: TextStyle(color: appColor(0xFF7B6BA0), fontWeight: FontWeight.w600)),
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
                Text('New Barn Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appColor(0xFF4F4F56))),
                const SizedBox(height: 6),
                TextField(
                  controller: barnController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g., Barn 3',
                    hintStyle: TextStyle(color: kNeutral400, fontSize: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLilacLight)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: appSurface(0xFF7B6BA0), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Row / Location Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appColor(0xFF4F4F56))),
              const SizedBox(height: 6),
              TextField(
                controller: rowController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Row 5',
                  hintStyle: TextStyle(color: kNeutral400, fontSize: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLilacLight)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: appSurface(0xFF7B6BA0), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: appColor(0xFF787774))),
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
                backgroundColor: appSurface(0xFF7B6BA0),
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
        SnackBar(content: Text('Please select a location'), backgroundColor: appSurface(0xFFD44C47)),
      );
      return;
    }

    if (_selectedCage == null || _selectedCage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a cage'), backgroundColor: appSurface(0xFFD44C47)),
      );
      return;
    }

    // Same Location + Cage cannot hold two bunnies
    final all = await _db.getAllRabbits();
    for (final r in all) {
      if (r.id == widget.rabbit.id || r.type == RabbitType.pedigree) continue;
      if (r.isArchived || r.status == RabbitStatus.archived) continue;
      if ((r.location ?? '') == _selectedLocation && (r.cage ?? '') == _selectedCage) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => BrightPurpleDialog(
            title: 'Cage already in use',
            content: '$_selectedLocation cage $_selectedCage is already assigned to ${r.name}.\n\nPlease choose a different cage.',
            confirmText: 'OK',
            onConfirm: () => Navigator.pop(ctx),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final cage = _selectedCage!;
      await _db.moveCage(widget.rabbit.id, _selectedLocation!, cage);

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved ${widget.rabbit.name} to $_selectedLocation${cage.isNotEmpty ? ' • $cage' : ''}'),
            backgroundColor: appSurface(0xFF7B6BA0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: appSurface(0xFFD44C47)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}