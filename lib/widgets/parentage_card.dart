import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../screens/rabbit_detail_screen.dart';

class ParentageCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onUpdated;

  const ParentageCard({Key? key, required this.rabbit, this.onUpdated}) : super(key: key);

  @override
  State<ParentageCard> createState() => _ParentageCardState();
}

class _ParentageCardState extends State<ParentageCard> {
  Rabbit? _sireRabbit;
  Rabbit? _damRabbit;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  @override
  void didUpdateWidget(covariant ParentageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rabbit.sireId != widget.rabbit.sireId || oldWidget.rabbit.damId != widget.rabbit.damId) {
      _loadParents();
    }
  }

  Future<void> _loadParents({String? overrideSireId, String? overrideDamId}) async {
    final db = DatabaseService();
    final sireId = overrideSireId ?? widget.rabbit.sireId;
    final damId = overrideDamId ?? widget.rabbit.damId;

    Rabbit? sire;
    Rabbit? dam;

    // Load sire if sireId exists
    if (sireId != null && sireId.isNotEmpty) {
      sire = await db.getRabbit(sireId);
    }

    // Load dam if damId exists
    if (damId != null && damId.isNotEmpty) {
      dam = await db.getRabbit(damId);
    }

    if (mounted) {
      setState(() {
        _sireRabbit = sire;
        _damRabbit = dam;
        _loading = false;
      });
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
                  'PARENTAGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEditParentageDialog(context),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: _loading
                ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    children: [
                      Expanded(
                        child: _buildParentBox(
                          context,
                          'Sire',
                          _sireRabbit?.name ?? widget.rabbit.sireId ?? 'Unknown',
                          _sireRabbit?.id ?? widget.rabbit.sireId ?? '-',
                          true,
                          _sireRabbit,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildParentBox(
                          context,
                          'Dam',
                          _damRabbit?.name ?? widget.rabbit.damId ?? 'Unknown',
                          _damRabbit?.id ?? widget.rabbit.damId ?? '-',
                          false,
                          _damRabbit,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentBox(BuildContext context, String label, String name, String id, bool isMale, Rabbit? parentRabbit) {
    final bool parentExists = parentRabbit != null;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                ),
              ),
              SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  isMale ? Icons.male : Icons.female,
                  size: 20,
                  color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF37352F),
                      ),
                    ),
                    Text(
                      id,
                      style: TextStyle(fontSize: 11, color: Color(0xFF787774)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Only show "View Profile" link if parent exists in database
          if (parentExists)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RabbitDetailScreen(rabbit: parentRabbit),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, size: 12, color: Color(0xFF0F7B6C)),
                  SizedBox(width: 4),
                  Text(
                    'View Profile',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0F7B6C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Not in herd',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9B9A97),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  void _showEditParentageDialog(BuildContext context) {
    final db = DatabaseService();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<List<Rabbit>>>(
          future: Future.wait([
            db.getAllRabbits().then((all) => all.where((r) => r.type == RabbitType.buck && r.status != RabbitStatus.archived).toList()),
            db.getAllRabbits().then((all) => all.where((r) => r.type == RabbitType.doe && r.status != RabbitStatus.archived).toList()),
          ]),
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

            final bucks = snapshot.data![0];
            final does = snapshot.data![1];

            String? selectedSireId = widget.rabbit.sireId;
            String? selectedDamId = widget.rabbit.damId;

            return StatefulBuilder(
              builder: (ctx2, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF0F7B6C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.account_tree_outlined, color: Color(0xFF0F7B6C), size: 20),
                      ),
                      SizedBox(width: 12),
                      Text('Edit Parentage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sire dropdown
                      Text(
                        'SIRE (FATHER)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF787774), letterSpacing: 0.5),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: bucks.any((b) => b.id == selectedSireId) ? selectedSireId : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefixIcon: Icon(Icons.male, color: Color(0xFF2E7BB5), size: 20),
                        ),
                        hint: Text('Select Sire', style: TextStyle(fontSize: 14, color: Color(0xFF9B9A97))),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None', style: TextStyle(color: Color(0xFF9B9A97), fontStyle: FontStyle.italic)),
                          ),
                          ...bucks.map((buck) => DropdownMenuItem<String?>(
                                value: buck.id,
                                child: Text(
                                  '${buck.name.isNotEmpty ? buck.name : buck.id}  (${buck.id})',
                                  style: TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (val) => setDialogState(() => selectedSireId = val),
                      ),
                      SizedBox(height: 20),
                      // Dam dropdown
                      Text(
                        'DAM (MOTHER)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF787774), letterSpacing: 0.5),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: does.any((d) => d.id == selectedDamId) ? selectedDamId : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefixIcon: Icon(Icons.female, color: Color(0xFF9C6ADE), size: 20),
                        ),
                        hint: Text('Select Dam', style: TextStyle(fontSize: 14, color: Color(0xFF9B9A97))),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None', style: TextStyle(color: Color(0xFF9B9A97), fontStyle: FontStyle.italic)),
                          ),
                          ...does.map((doe) => DropdownMenuItem<String?>(
                                value: doe.id,
                                child: Text(
                                  '${doe.name.isNotEmpty ? doe.name : doe.id}  (${doe.id})',
                                  style: TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (val) => setDialogState(() => selectedDamId = val),
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
                        final updated = widget.rabbit.copyWith(
                          sireId: selectedSireId,
                          damId: selectedDamId,
                        );
                        await db.updateRabbit(updated);
                        Navigator.pop(dialogContext);
                        // Refresh parent data with the new IDs directly
                        setState(() {
                          _loading = true;
                        });
                        _loadParents(overrideSireId: selectedSireId, overrideDamId: selectedDamId);
                        widget.onUpdated?.call();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Parentage updated'),
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
}
