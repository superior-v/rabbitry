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
import '../screens/kit_detail_screen.dart';
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
      litters.sort((a, b) {
        final dateA = a.dob ?? a.kindleDate ?? a.breedDate;
        final dateB = b.dob ?? b.kindleDate ?? b.breedDate;
        return dateB.compareTo(dateA);
      });

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
              const SizedBox(height: 6),
              // 2. Light purple summary pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
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
              const SizedBox(height: 4),
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
    final String bredDateStr = DateFormat('MMM d, yyyy').format(litter.breedDate);
    final String bornDateStr = (litter.dob ?? litter.kindleDate) != null
        ? DateFormat('MMM d, yyyy').format(litter.dob ?? litter.kindleDate!)
        : '-';
    final isExpanded = _expandedLitters.contains(litter.id);
    final String lStatus = litter.status.toLowerCase().trim();
    final bool isMissedLitter = lStatus == 'not taken' || lStatus == 'missed' || lStatus == 'missed litter';

    String fullAgeStr = '';
    if (isMissedLitter) {
      fullAgeStr = '';
    } else if (lStatus == 'weaned') {
      if (litter.kindleDate != null || litter.dob != null) {
        fullAgeStr = 'Weaned • ${FormatUtils.formatAge(litter.kindleDate ?? litter.dob)}';
      } else {
        fullAgeStr = 'Weaned';
      }
    } else if (litter.kindleDate != null || litter.dob != null) {
      fullAgeStr = 'Age: ${FormatUtils.formatAge(litter.kindleDate ?? litter.dob)}';
    }

    return Container(
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Chevron expands/collapses, 3-dots opens menu
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedLitters.remove(litter.id);
                    } else {
                      _expandedLitters.add(litter.id);
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMissedLitter ? 'MISSED LITTER' : litter.id,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isMissedLitter ? const Color(0xFFC47070) : const Color(0xFF4F4F56),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: const Color(0xFF787880),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showLitterActionsMenu(context, litter),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Icon(Icons.more_horiz, size: 22, color: Color(0xFF787774)),
                ),
              ),
            ],
          ),

          // Subtitle / Dates Area: Tapping anywhere here opens 3-dots menu
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showLitterActionsMenu(context, litter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isMissedLitter
                            ? 'Not Pregnant — Missed Litter'
                            : '$partner (${(partnerId.length > 4 ? partnerId.substring(0, 4) : partnerId).toUpperCase()})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isMissedLitter ? const Color(0xFFC47070) : const Color(0xFF4F4F56),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bred $bredDateStr',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4F4F56),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isMissedLitter
                            ? 'Missed Litter'
                            : '${litter.totalKits ?? 0} Born • ${litter.aliveKits ?? 0} Alive',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isMissedLitter ? const Color(0xFFC47070) : const Color(0xFF4F4F56),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMissedLitter ? '' : 'Born $bornDateStr',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4F4F56),
                      ),
                    ),
                  ],
                ),
                if (fullAgeStr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    fullAgeStr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4F4F56),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Expandable children kits & notes matching Nursery page
          if (isExpanded) ...[
            const Divider(height: 20, color: Color(0xFFE5E5EA)),
            if (litter.kits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text(
                  isMissedLitter ? 'Missed breeding — no kits' : 'No kits recorded in this litter',
                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontStyle: FontStyle.italic),
                ),
              )
            else
              ...litter.kits.map((kit) => _buildKitRow(litter, kit)).toList(),
            const SizedBox(height: 8),
            _buildLitterNotesBox(litter),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildKitRow(Litter litter, Kit kit) {
    final String kStatus = kit.status.toLowerCase().trim();
    final bool isOutcome = [
      'sold',
      'butchered',
      'dead',
      'died',
      'deceased',
      'cull'
    ].contains(kStatus);

    final bool isFosteredIn = kit.id.startsWith('F-') ||
        kit.id.startsWith('foster_') ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered from'));

    String displayKitId;
    if (isFosteredIn) {
      final fosteredKitsInLitter = litter.kits.where((k) =>
        k.id.startsWith('F-') ||
        k.id.startsWith('foster_') ||
        (k.details != null && k.details!.toLowerCase().contains('fostered from'))
      ).toList();
      final fosterIndex = fosteredKitsInLitter.indexOf(kit) + 1;
      displayKitId = 'F-${fosterIndex > 0 ? fosterIndex : 1}';
    } else {
      final numericPart = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
      displayKitId = 'K-${numericPart.isEmpty ? (litter.kits.indexOf(kit) + 1) : numericPart}';
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KitDetailScreen(
              litter: litter,
              kit: kit,
              onUpdated: () => _loadLitterHistory(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF2F2F7))),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Index Pill (Purple matching Nursery)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              height: 24,
              constraints: const BoxConstraints(minWidth: 40),
              decoration: BoxDecoration(
                color: isFosteredIn
                    ? const Color(0xFF3A3A3C)
                    : (isOutcome ? const Color(0xFFF2F2F7) : const Color(0xFFF5F1FC)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFosteredIn
                      ? const Color(0xFF55555A)
                      : (isOutcome ? const Color(0xFFE5E5EA) : const Color(0xFFE8DFFA)),
                ),
              ),
              child: Center(
                child: Text(
                  displayKitId,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isFosteredIn
                        ? const Color(0xFFE2BFFB)
                        : (isOutcome ? const Color(0xFF8E8E93) : const Color(0xFF5A4880)),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        kit.color.isNotEmpty ? kit.color : 'Kit $displayKitId',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isOutcome ? const Color(0xFF8E8E93) : const Color(0xFF37352F),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        kit.sex == 'M' ? PhosphorIcons.genderMale(PhosphorIconsStyle.bold) : (kit.sex == 'F' ? PhosphorIcons.genderFemale(PhosphorIconsStyle.bold) : PhosphorIcons.genderIntersex(PhosphorIconsStyle.bold)),
                        size: 14,
                        color: kit.sex == 'M' ? const Color(0xFF5B8AD0) : (kit.sex == 'F' ? const Color(0xFFD4809A) : const Color(0xFF7B6BA0)),
                      ),
                    ],
                  ),
                  if (kit.weight > 0)
                    Text(
                      'Weight: ${FormatUtils.formatWeight(kit.weight)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFAEAEB2), fontWeight: FontWeight.w500),
                    ),
                  if (kit.details != null && kit.details!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      kit.details!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF7B6BA0), fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOutcome) ...[
              _buildOutcomeBadge(kit.status),
              const SizedBox(width: 6),
            ],
            const Icon(PhosphorIconsRegular.caretRight, size: 16, color: Color(0xFFE5E5EA)),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeBadge(String status) {
    final s = status.toLowerCase();
    if (s == 'sold') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(PhosphorIconsFill.tag, size: 10, color: Colors.white),
            SizedBox(width: 3),
            Text(
              'SOLD',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }
    if (s == 'dead' || s == 'died') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFE57373)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.close, size: 11, color: Color(0xFFD32F2F)),
            SizedBox(width: 3),
            Text(
              'Kit Died',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFFD32F2F),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }

  Widget _buildLitterNotesBox(Litter litter) {
    final hasNotes = litter.notes != null && litter.notes!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DFFA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B6BA0).withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notes_rounded, size: 16, color: Color(0xFF6B2D6D)),
              SizedBox(width: 6),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A3E6D),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasNotes ? litter.notes!.trim() : 'No notes recorded.',
            style: TextStyle(
              fontSize: 12.5,
              color: hasNotes ? const Color(0xFF333333) : const Color(0xFF8E8E93),
              height: 1.35,
              fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
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
                    Text('Litter ${litter.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF4F4F56), letterSpacing: -0.5)),
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
                            enableDrag: false,
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
        return k.copyWith(id: 'foster_${source.id}_${k.id}', status: 'Nursing', details: newDetails);
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
            color: Color(0xFF4F4F56),
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
