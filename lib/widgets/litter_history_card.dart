import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';
import '../screens/litters_screen.dart';
import '../screens/home_dashboard_screen.dart' show HomeDashboardScreen;
import 'modals/wean_litter_modal.dart';
import 'modals/log_birth_modal.dart';

class LitterHistoryCard extends StatefulWidget {
  final Rabbit rabbit;
  const LitterHistoryCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<LitterHistoryCard> createState() => _LitterHistoryCardState();
}

class _LitterHistoryCardState extends State<LitterHistoryCard> {
  final DatabaseService _db = DatabaseService();
  List<Litter> _litters = [];
  List<Litter> _filteredLitters = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _expandedLitters = <String>{};

  // Theme Helpers
  Color get _primaryColor => widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;

  @override
  void initState() {
    super.initState();
    _loadLitterHistory();
  }

  Future<void> _loadLitterHistory() async {
    try {
      final littersData = await _db.getLittersByDoe(widget.rabbit.id);
      final db = await _db.database;
      final sireLitters = await db.query('litters',
          where: 'buckId = ?',
          whereArgs: [
            widget.rabbit.id
          ],
          orderBy: 'breedDate DESC');
      final allData = [
        ...littersData,
        ...sireLitters
      ];
      final seenIds = <String>{};
      final unique = allData.where((l) {
        final id = l['id'] as String?;
        if (id == null || seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();
      final litters = unique.map((data) => Litter.fromMap(data)).toList();
      litters.sort((a, b) => (b.kindleDate ?? b.breedDate).compareTo(a.kindleDate ?? a.breedDate));

      if (mounted) {
        setState(() {
          _litters = litters;
          _filteredLitters = litters;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterLitters(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredLitters = _litters;
      } else {
        _filteredLitters = _litters.where((l) => l.id.toLowerCase().contains(query.toLowerCase()) || (l.doeName ?? '').toLowerCase().contains(query.toLowerCase()) || (l.buckName ?? '').toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor));
    }

    int totalLitters = _litters.length;
    int totalKits = _litters.fold<int>(0, (sum, l) => sum + (l.totalKits ?? 0));
    int totalAlive = _litters.fold<int>(0, (sum, l) => sum + (l.aliveKits ?? 0));
    String survival = totalKits > 0 ? '${(totalAlive / totalKits * 100).round()}% survival' : '0% survival';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E3E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Light purple header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF6EEFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Text(
                  'LITTER HISTORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5A4D6E),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 2. Light purple summary pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$totalLitters litters • $totalKits kits lifetime • $survival',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF76668F),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 3. Compact space below summary pill
              if (_filteredLitters.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No litters found', style: TextStyle(color: kNeutral400)),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredLitters.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildLitterTile(_filteredLitters[index]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLitterTile(Litter litter) {
    final bool isDam = widget.rabbit.id == litter.doeId;
    final partner = isDam ? litter.buckName : litter.doeName;
    final partnerId = isDam ? litter.buckId : litter.doeId;
    final bornDateStr = DateFormat('MMM d \'yy').format(litter.kindleDate ?? litter.breedDate);
    final bredDateStr = DateFormat('MMM d \'yy').format(litter.breedDate);
    final isExpanded = _expandedLitters.contains(litter.id);

    String ageStr = 'Unknown';
    if (litter.kindleDate != null) {
      final ageDays = DateTime.now().difference(litter.kindleDate!).inDays;
      if (ageDays < 7) {
        ageStr = '$ageDays days';
      } else {
        final weeks = (ageDays / 7).floor();
        ageStr = '$weeks week${weeks > 1 ? 's' : ''}';
      }
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: isExpanded ? const Color(0xFFF7F3FB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isExpanded ? const Color(0xFFE2D6EE) : const Color(0xFFE4E4EA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: const Color(0xFF7D7D86),
          collapsedIconColor: const Color(0xFF7D7D86),
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedLitters.add(litter.id);
              } else {
                _expandedLitters.remove(litter.id);
              }
            });
          },
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showLitterActionsMenu(context, litter),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.more_horiz, size: 20, color: Color(0xFF9E9E9E)),
            ),
          ),
          title: Row(
            children: [
              Text(
                litter.status == 'Not Taken' ? 'MISSED LITTER' : litter.id,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: litter.status == 'Not Taken' ? const Color(0xFFC47070) : const Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: const Color(0xFF616161),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      litter.status == 'Not Taken'
                          ? 'Not Pregnant — archived'
                          : 'with $partner (${(partnerId.length > 4 ? partnerId.substring(0, 4) : partnerId).toUpperCase()})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: litter.status == 'Not Taken' ? const Color(0xFFC47070) : const Color(0xFF555555),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bred $bredDateStr',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      litter.status == 'Not Taken'
                          ? 'Not Taken'
                          : '${litter.totalKits} born • ${litter.aliveKits} alive • ${litter.status == 'Weaned' ? 'Weaned' : ageStr}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: litter.status == 'Not Taken' ? const Color(0xFFC47070) : const Color(0xFF424242),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Born $bornDateStr',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const SizedBox(height: 8),
            _buildFigmaField(litter, 'Patterns', 'patternsProduced', litter.patternsProduced),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildFigmaField(litter, 'Bucks', 'bucksProduced', litter.bucksProduced?.toString(), isNumber: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildFigmaField(litter, 'Does', 'doesProduced', litter.doesProduced?.toString(), isNumber: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildFigmaField(litter, 'Peanuts', 'peanutsProduced', litter.peanutsProduced?.toString(), isNumber: true)),
              ],
            ),
            const SizedBox(height: 10),
            _buildFigmaField(litter, 'Notes', 'notes', litter.notes),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternatingActionOption({
    required String label,
    required int index,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    final bool isOdd = index % 2 == 1;
    final Color bgColor = isOdd ? const Color(0xFFF4F0FA) : Colors.white;
    final Color textColor = isDangerous ? const Color(0xFFD94452) : const Color(0xFF463466);
    
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildLitterActionOption({
    required String label,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    final Color textColor = isDangerous ? const Color(0xFFD94452) : const Color(0xFF463466);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E0F2), width: 0.8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showLitterActionsMenu(BuildContext context, Litter litter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE5FA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Litter ${litter.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E), letterSpacing: -0.5)),
                        Text(litter.status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F0FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildLitterActionOption(
                        label: 'Edit Birth Info',
                        onTap: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => LogBirthModal(
                              doe: widget.rabbit,
                              existingLitter: litter,
                              onComplete: _loadLitterHistory,
                            ),
                          );
                        },
                      ),
                      _buildLitterActionOption(
                        label: 'Wean Litter',
                        onTap: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => WeanLitterModal(
                              doe: widget.rabbit,
                              onComplete: _loadLitterHistory,
                            ),
                          );
                        },
                      ),
                      _buildLitterActionOption(
                        label: 'Foster Kits',
                        onTap: () {
                          Navigator.pop(ctx);
                          _showFosterKitsModal(context, litter);
                        },
                      ),
                      _buildLitterActionOption(
                        label: 'Litter Died',
                        isDangerous: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showLitterDiedConfirm(context, litter);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLitterDiedConfirm(BuildContext context, Litter litter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Litter Died', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Mark all kits in this litter as dead? The doe will be set back to OPEN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleLitterDied(litter);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC47070),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLitterDied(Litter litter) async {
    try {
      final db = await _db.database;
      await db.update(
        'litters',
        {
          'currentAlive': 0,
          'status': 'archived',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [litter.id],
      );
      // Reset doe to open
      await db.update(
        'rabbits',
        {
          'status': 'RabbitStatus.open',
          'lastBreedDate': null,
          'lastBreedBuckId': null,
          'palpationDate': null,
          'dueDate': null,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [litter.doeId],
      );
      await _loadLitterHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Litter marked as died — doe reset to OPEN'),
            backgroundColor: Color(0xFFC47070),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showFosterKitsModal(BuildContext context, Litter sourceLitter) async {
    // Load all active litters except this one
    final allLitters = await _db.getLitters();
    final candidates = allLitters.where((l) =>
      l.id != sourceLitter.id &&
      l.status != 'archived' &&
      l.status != 'Not Taken' &&
      l.status != 'Weaned' &&
      ((l.aliveKits ?? 0) > 0 || (l.kits.where((k) => !k.isArchived).isNotEmpty))
    ).toList();

    final aliveKits = sourceLitter.kits.where((k) => !k.isArchived).toList();
    if (aliveKits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No alive kits to foster in this litter'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Litter? selectedTarget;
        final Set<String> selectedKitIds = {};

        return StatefulBuilder(builder: (ctx, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Foster Kits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('SELECT KITS TO FOSTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9E9E9E), letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      ...aliveKits.map((kit) => CheckboxListTile(
                        value: selectedKitIds.contains(kit.id),
                        onChanged: (v) => setModalState(() {
                          if (v == true) selectedKitIds.add(kit.id);
                          else selectedKitIds.remove(kit.id);
                        }),
                        title: Text(kit.color.isNotEmpty ? kit.color : 'Unknown color', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${kit.sex} • ${kit.weight.toStringAsFixed(1)} lbs'),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      )),
                      const SizedBox(height: 16),
                      const Text('FOSTER INTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9E9E9E), letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      if (candidates.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
                          child: const Text('No other active litters available to foster into.', style: TextStyle(color: Color(0xFF856404))),
                        )
                      else
                        ...candidates.map((targetLitter) => RadioListTile<Litter>(
                          value: targetLitter,
                          groupValue: selectedTarget,
                          onChanged: (v) => setModalState(() => selectedTarget = v),
                          title: Text(targetLitter.doeName.isNotEmpty ? targetLitter.doeName : targetLitter.dam, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Litter #${targetLitter.id.length > 6 ? targetLitter.id.substring(targetLitter.id.length - 4) : targetLitter.id} • ${targetLitter.aliveKits ?? targetLitter.kits.where((k) => !k.isArchived).length} kits'),
                          dense: true,
                        )),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (selectedKitIds.isNotEmpty && selectedTarget != null)
                          ? () async {
                              Navigator.pop(ctx);
                              await _handleFosterKits(sourceLitter, selectedTarget!, selectedKitIds.toList());
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B6BA0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        selectedKitIds.isEmpty ? 'Select Kits to Foster' : 'Foster ${selectedKitIds.length} Kit${selectedKitIds.length > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _handleFosterKits(Litter source, Litter target, List<String> kitIds) async {
    try {
      final db = await _db.database;
      final sourceDamName = source.doeName.isNotEmpty ? source.doeName : source.dam;

      // Mark moved kits with foster note
      final kitsToMove = source.kits.where((k) => kitIds.contains(k.id)).map((k) {
        final existingNote = k.details ?? '';
        final fosterNote = 'Fostered from $sourceDamName';
        final newDetails = existingNote.contains(fosterNote) ? existingNote : (existingNote.isEmpty ? fosterNote : '$existingNote • $fosterNote');
        return k.copyWith(status: 'Nursing', details: newDetails);
      }).toList();

      // Mark source kits as Fostered
      final updatedSourceKits = source.kits.map((k) {
        if (kitIds.contains(k.id)) {
          final targetDoeName = target.doeName.isNotEmpty ? target.doeName : target.dam;
          return k.copyWith(status: 'Fostered', details: 'Fostered to $targetDoeName');
        }
        return k;
      }).toList();

      // Add kits to target litter
      final targetKits = [...target.kits, ...kitsToMove];

      // Update source litter
      await db.update('litters', {
        'kits': jsonEncode(updatedSourceKits.map((k) => k.toMap()).toList()),
        'currentAlive': updatedSourceKits.where((k) => !k.isArchived && k.status != 'Fostered' && k.status != 'Dead' && k.status != 'Died').length,
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [source.id]);

      // Update target litter
      await db.update('litters', {
        'kits': jsonEncode(targetKits.map((k) => k.toMap()).toList()),
        'currentAlive': targetKits.where((k) => !k.isArchived && k.status != 'Fostered' && k.status != 'Dead' && k.status != 'Died').length,
        'updatedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [target.id]);

      // Check if source doe has any remaining nursing kits
      await _db.checkAndUpdateDoeStatusIfLitterEmpty(source.doeId);

      await _loadLitterHistory();
      if (mounted) {
        final targetDoeName = target.doeName.isNotEmpty ? target.doeName : target.dam;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${kitsToMove.length} kit${kitsToMove.length > 1 ? 's' : ''} fostered to $targetDoeName'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fostering kits: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildKitRow(Kit kit, int index) {

    final bool isDied = [
      'Dead',
      'Cull'
    ].contains(kit.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEEE6F5)),
        ),
        child: Row(
          children: [
            Icon(
              kit.sex == 'Male' ? PhosphorIconsFill.genderMale : (kit.sex == 'Female' ? PhosphorIconsFill.genderFemale : PhosphorIconsFill.question),
              size: 12,
              color: const Color(0xFF9F8BC0),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. ${kit.color.isNotEmpty ? kit.color : 'Unknown'}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4F4F57)),
                  ),
                  if (kit.details != null && kit.details!.contains('Fostered from'))
                    Text(
                      '(${RegExp(r'Fostered from [^\n•]+').firstMatch(kit.details!)?.group(0) ?? kit.details})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7B1FA2)),
                    ),
                ],
              ),
            ),
            Text(
              isDied ? 'Died day 2' : 'Alive',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDied ? const Color(0xFFE95462) : const Color(0xFF7F7F88),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.more_vert, size: 14, color: Color(0xFFB5B5BD)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8EE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A7A82),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4F4F57),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kNeutral200),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: kNeutral400),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral50, letterSpacing: 0.6)),
    );
  }

  Widget _buildFigmaField(Litter litter, String label, String field, String? initialValue, {bool isNumber = false}) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          // Re-calculate statistics and redraw when editing of a field is completed
          setState(() {});
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC7C7CC), width: 1.5),
        ),
        child: TextFormField(
          initialValue: initialValue ?? '',
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E2E35),
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9B9B9E),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (val) {
            dynamic finalVal = val;
            if (isNumber) {
              finalVal = int.tryParse(val);
            }
            // Update in-memory models to keep data synchronized
            final idx = _litters.indexWhere((l) => l.id == litter.id);
            if (idx != -1) {
              final updatedLitter = _updateLitterModelField(_litters[idx], field, finalVal);
              _litters[idx] = updatedLitter;
              final fIdx = _filteredLitters.indexWhere((l) => l.id == litter.id);
              if (fIdx != -1) {
                _filteredLitters[fIdx] = updatedLitter;
              }
            }
            _updateLitterField(litter.id, field, finalVal);
          },
        ),
      ),
    );
  }

  Litter _updateLitterModelField(Litter l, String field, dynamic val) {
    return l.copyWith(
      patternsProduced: field == 'patternsProduced' ? val as String? : l.patternsProduced,
      bucksProduced: field == 'bucksProduced' ? val as int? : l.bucksProduced,
      doesProduced: field == 'doesProduced' ? val as int? : l.doesProduced,
      peanutsProduced: field == 'peanutsProduced' ? val as int? : l.peanutsProduced,
      notes: field == 'notes' ? val as String? : l.notes,
    );
  }

  Future<void> _updateLitterField(String litterId, String field, dynamic value) async {
    try {
      final db = await _db.database;
      await db.update(
        'litters',
        {
          field: value,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [litterId],
      );
    } catch (e) {
      print('Error updating database field $field: $e');
    }
  }
}
