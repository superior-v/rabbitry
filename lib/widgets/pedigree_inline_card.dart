import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';

class PedigreeInlineCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onUpdated;

  const PedigreeInlineCard({Key? key, required this.rabbit, this.onUpdated}) : super(key: key);

  @override
  State<PedigreeInlineCard> createState() => _PedigreeInlineCardState();
}

class _PedigreeInlineCardState extends State<PedigreeInlineCard> {
  final DatabaseService _db = DatabaseService();
  int selectedGenerations = 3;

  // Pedigree data
  Rabbit? _sire;
  Rabbit? _dam;
  Rabbit? _siresSire;
  Rabbit? _siresDam;
  Rabbit? _damsSire;
  Rabbit? _damsDam;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPedigree();
  }

  @override
  void didUpdateWidget(covariant PedigreeInlineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rabbit.sireId != widget.rabbit.sireId || oldWidget.rabbit.damId != widget.rabbit.damId) {
      _loadPedigree();
    }
  }

  Future<void> _loadPedigree() async {
    try {
      // Load parents
      if (widget.rabbit.sireId != null && widget.rabbit.sireId!.isNotEmpty) {
        _sire = await _db.getRabbit(widget.rabbit.sireId!);
      }
      if (widget.rabbit.damId != null && widget.rabbit.damId!.isNotEmpty) {
        _dam = await _db.getRabbit(widget.rabbit.damId!);
      }

      // Load grandparents
      if (_sire != null) {
        if (_sire!.sireId != null && _sire!.sireId!.isNotEmpty) {
          _siresSire = await _db.getRabbit(_sire!.sireId!);
        }
        if (_sire!.damId != null && _sire!.damId!.isNotEmpty) {
          _siresDam = await _db.getRabbit(_sire!.damId!);
        }
      }
      if (_dam != null) {
        if (_dam!.sireId != null && _dam!.sireId!.isNotEmpty) {
          _damsSire = await _db.getRabbit(_dam!.sireId!);
        }
        if (_dam!.damId != null && _dam!.damId!.isNotEmpty) {
          _damsDam = await _db.getRabbit(_dam!.damId!);
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading pedigree: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PEDIGREE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showFullPedigree(context),
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 14, color: Color(0xFF787774)),
                          SizedBox(width: 4),
                          Text(
                            'Export',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF787774),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown for generations
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: selectedGenerations,
                    underline: SizedBox(),
                    isDense: true,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: 3, child: Text('3 Generations')),
                      DropdownMenuItem(value: 4, child: Text('4 Generations')),
                      DropdownMenuItem(value: 5, child: Text('5 Generations')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedGenerations = value ?? 3;
                      });
                    },
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF37352F),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // SUBJECT Section
                Text(
                  'SUBJECT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                _buildSubjectCard(
                  widget.rabbit.name,
                  widget.rabbit.id,
                  widget.rabbit.breed,
                  widget.rabbit.color ?? 'Unknown',
                ),

                SizedBox(height: 24),

                // PARENTS Section
                Text(
                  'PARENTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildParentCard(
                        _sire?.name ?? 'Unknown Sire',
                        _sire?.id ?? '--',
                        _sire?.breed ?? widget.rabbit.breed,
                        true,
                        onTap: () => _showEditPedigreeEntryDialog(
                          label: 'Edit Sire',
                          targetRabbit: widget.rabbit,
                          isMale: true,
                          currentId: widget.rabbit.sireId,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildParentCard(
                        _dam?.name ?? 'Unknown Dam',
                        _dam?.id ?? '--',
                        _dam?.breed ?? widget.rabbit.breed,
                        false,
                        onTap: () => _showEditPedigreeEntryDialog(
                          label: 'Edit Dam',
                          targetRabbit: widget.rabbit,
                          isMale: false,
                          currentId: widget.rabbit.damId,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // GRANDPARENTS Section
                Text(
                  'GRANDPARENTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 12),

                // Parent labels
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sire\'s parents',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9B9A97),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dam\'s parents',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9B9A97),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // First row of grandparents
                Row(
                  children: [
                    Expanded(
                      child: _buildGrandparentCard(
                        _siresSire?.name ?? 'Unknown',
                        _siresSire?.id ?? '--',
                        true,
                        onTap: _sire != null
                            ? () => _showEditPedigreeEntryDialog(
                                  label: 'Edit Sire\'s Sire',
                                  targetRabbit: _sire!,
                                  isMale: true,
                                  currentId: _sire!.sireId,
                                )
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildGrandparentCard(
                        _damsSire?.name ?? 'Unknown',
                        _damsSire?.id ?? '--',
                        true,
                        onTap: _dam != null
                            ? () => _showEditPedigreeEntryDialog(
                                  label: 'Edit Dam\'s Sire',
                                  targetRabbit: _dam!,
                                  isMale: true,
                                  currentId: _dam!.sireId,
                                )
                            : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Second row of grandparents
                Row(
                  children: [
                    Expanded(
                      child: _buildGrandparentCard(
                        _siresDam?.name ?? 'Unknown',
                        _siresDam?.id ?? '--',
                        false,
                        onTap: _sire != null
                            ? () => _showEditPedigreeEntryDialog(
                                  label: 'Edit Sire\'s Dam',
                                  targetRabbit: _sire!,
                                  isMale: false,
                                  currentId: _sire!.damId,
                                )
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildGrandparentCard(
                        _damsDam?.name ?? 'Unknown',
                        _damsDam?.id ?? '--',
                        false,
                        onTap: _dam != null
                            ? () => _showEditPedigreeEntryDialog(
                                  label: 'Edit Dam\'s Dam',
                                  targetRabbit: _dam!,
                                  isMale: false,
                                  currentId: _dam!.damId,
                                )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(String name, String id, String breed, String color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFF0F7B6C), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF37352F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            id,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF787774),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '$breed • $color',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9B9A97),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentCard(String name, String id, String breed, bool isMale, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF37352F),
                    ),
                  ),
                ),
                if (onTap != null) Icon(Icons.edit, size: 14, color: Color(0xFF9B9A97)),
              ],
            ),
            SizedBox(height: 4),
            Text(
              id,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF787774),
              ),
            ),
            SizedBox(height: 4),
            Text(
              breed,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9B9A97),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrandparentCard(String name, String id, bool isMale, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isMale ? Color(0xFF2E7BB5).withOpacity(0.3) : Color(0xFF9C6ADE).withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF37352F),
                    ),
                  ),
                ),
                if (onTap != null) Icon(Icons.edit, size: 12, color: Color(0xFF9B9A97)),
              ],
            ),
            SizedBox(height: 4),
            Text(
              id,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF787774),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to edit one pedigree relationship.
  /// [label] – display title (e.g. "Edit Sire")
  /// [targetRabbit] – the rabbit whose parent we are changing
  /// [isMale] – true = selecting a buck (sire), false = selecting a doe (dam)
  /// [currentId] – currently assigned parent id (for pre-selection)
  void _showEditPedigreeEntryDialog({
    required String label,
    required Rabbit targetRabbit,
    required bool isMale,
    String? currentId,
  }) {
    final db = DatabaseService();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<Rabbit>>(
          future: db.getAllRabbits().then((all) => all.where((r) => (isMale ? r.type == RabbitType.buck : r.type == RabbitType.doe) && r.status != RabbitStatus.archived && r.id != targetRabbit.id).toList()),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF0F7B6C), strokeWidth: 2)),
                ),
              );
            }

            final rabbits = snapshot.data!;
            String? selectedId = currentId;

            return StatefulBuilder(
              builder: (ctx2, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE)).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isMale ? Icons.male : Icons.female,
                          color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editing for ${targetRabbit.name.isNotEmpty ? targetRabbit.name : targetRabbit.id}',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9B9A97)),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: rabbits.any((r) => r.id == selectedId) ? selectedId : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefixIcon: Icon(
                            isMale ? Icons.male : Icons.female,
                            color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                            size: 20,
                          ),
                        ),
                        hint: Text(
                          isMale ? 'Select Sire' : 'Select Dam',
                          style: TextStyle(fontSize: 14, color: Color(0xFF9B9A97)),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None', style: TextStyle(color: Color(0xFF9B9A97), fontStyle: FontStyle.italic)),
                          ),
                          ...rabbits.map((r) => DropdownMenuItem<String?>(
                                value: r.id,
                                child: Text(
                                  '${r.name.isNotEmpty ? r.name : r.id}  (${r.id})',
                                  style: TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (val) => setDialogState(() => selectedId = val),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final updated = isMale ? targetRabbit.copyWith(sireId: selectedId) : targetRabbit.copyWith(damId: selectedId);
                        await db.updateRabbit(updated);
                        Navigator.pop(dialogContext);
                        // Reload pedigree tree
                        setState(() => _isLoading = true);
                        await _loadPedigree();
                        widget.onUpdated?.call();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pedigree updated'),
                              backgroundColor: Color(0xFF0F7B6C),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0F7B6C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showFullPedigree(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.rabbit.name} Pedigree',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$selectedGenerations Generations',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF787774),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.print),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Preparing pedigree for printing...'),
                          backgroundColor: Color(0xFF0F7B6C),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.share),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sharing pedigree...'),
                          backgroundColor: Color(0xFF0F7B6C),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full pedigree view with same layout
                    Text(
                      'SUBJECT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildSubjectCard(
                      widget.rabbit.name,
                      widget.rabbit.id,
                      widget.rabbit.breed,
                      widget.rabbit.color ?? 'Unknown',
                    ),
                    SizedBox(height: 24),

                    Text(
                      'PARENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _buildParentCard(
                          _sire?.name ?? 'Unknown Sire',
                          _sire?.id ?? '--',
                          _sire?.breed ?? widget.rabbit.breed,
                          true,
                          onTap: () {
                            Navigator.pop(context);
                            _showEditPedigreeEntryDialog(label: 'Edit Sire', targetRabbit: widget.rabbit, isMale: true, currentId: widget.rabbit.sireId);
                          },
                        )),
                        SizedBox(width: 12),
                        Expanded(
                            child: _buildParentCard(
                          _dam?.name ?? 'Unknown Dam',
                          _dam?.id ?? '--',
                          _dam?.breed ?? widget.rabbit.breed,
                          false,
                          onTap: () {
                            Navigator.pop(context);
                            _showEditPedigreeEntryDialog(label: 'Edit Dam', targetRabbit: widget.rabbit, isMale: false, currentId: widget.rabbit.damId);
                          },
                        )),
                      ],
                    ),
                    SizedBox(height: 24),

                    Text(
                      'GRANDPARENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sire\'s parents',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dam\'s parents',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _buildGrandparentCard(
                          _siresSire?.name ?? 'Unknown',
                          _siresSire?.id ?? '--',
                          true,
                          onTap: _sire != null
                              ? () {
                                  Navigator.pop(context);
                                  _showEditPedigreeEntryDialog(label: 'Edit Sire\'s Sire', targetRabbit: _sire!, isMale: true, currentId: _sire!.sireId);
                                }
                              : null,
                        )),
                        SizedBox(width: 12),
                        Expanded(
                            child: _buildGrandparentCard(
                          _damsSire?.name ?? 'Unknown',
                          _damsSire?.id ?? '--',
                          true,
                          onTap: _dam != null
                              ? () {
                                  Navigator.pop(context);
                                  _showEditPedigreeEntryDialog(label: 'Edit Dam\'s Sire', targetRabbit: _dam!, isMale: true, currentId: _dam!.sireId);
                                }
                              : null,
                        )),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _buildGrandparentCard(
                          _siresDam?.name ?? 'Unknown',
                          _siresDam?.id ?? '--',
                          false,
                          onTap: _sire != null
                              ? () {
                                  Navigator.pop(context);
                                  _showEditPedigreeEntryDialog(label: 'Edit Sire\'s Dam', targetRabbit: _sire!, isMale: false, currentId: _sire!.damId);
                                }
                              : null,
                        )),
                        SizedBox(width: 12),
                        Expanded(
                            child: _buildGrandparentCard(
                          _damsDam?.name ?? 'Unknown',
                          _damsDam?.id ?? '--',
                          false,
                          onTap: _dam != null
                              ? () {
                                  Navigator.pop(context);
                                  _showEditPedigreeEntryDialog(label: 'Edit Dam\'s Dam', targetRabbit: _dam!, isMale: false, currentId: _dam!.damId);
                                }
                              : null,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
