import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/transaction.dart' as finance;
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';
import '../screens/litters_screen.dart';
import '../screens/rabbit_detail_screen.dart';
import '../screens/pedigree_screen.dart';
import 'certificate_card.dart';
import 'purple_dialog.dart';
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
  Map<String, Rabbit> _rabbitMap = {};
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
      final db = await _db.database;
      final rabbitsData = await db.query('rabbits');
      final rabbitMap = {for (var r in rabbitsData.map((d) => Rabbit.fromMap(d))) r.id: r};
      final littersData = await _db.getLittersByDoe(widget.rabbit.id);
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
          _rabbitMap = rabbitMap;
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
    int totalKits = _litters.fold<int>(0, (sum, l) {
      if (l.totalKits != null && l.totalKits! > 0) return sum + l.totalKits!;
      return sum + l.kits.length;
    });
    int totalAlive = _litters.fold<int>(0, (sum, l) {
      if (l.kits.isNotEmpty) {
        return sum + l.kits.where((k) {
          final st = k.status.trim().toLowerCase();
          return st != 'dead' && st != 'died' && st != 'culled' && st != 'cull' && st != 'deceased';
        }).length;
      }
      return sum + (l.aliveKits ?? l.totalKits ?? 0);
    });
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
    final String bredDateStr = DateFormat('MMM dd, yyyy').format(litter.breedDate);
    final String bornDateStr = (litter.dob ?? litter.kindleDate) != null
        ? DateFormat('MMM dd, yyyy').format(litter.dob ?? litter.kindleDate!)
        : '-';
    final String dueDateStr = (litter.dueDate ?? litter.dob ?? litter.kindleDate) != null
        ? DateFormat('MMM dd, yyyy').format(litter.dueDate ?? litter.dob ?? litter.kindleDate!)
        : '-';
    final isExpanded = _expandedLitters.contains(litter.id);
    final String lStatus = litter.status.toLowerCase().trim();

    final int born = (litter.totalKits != null && litter.totalKits! > 0)
        ? litter.totalKits!
        : (litter.kits.isNotEmpty ? litter.kits.length : 0);
    final int alive = litter.kits.isNotEmpty
        ? litter.kits.where((k) {
            final st = k.status.trim().toLowerCase();
            return st != 'dead' && st != 'died' && st != 'culled' && st != 'cull' && st != 'deceased';
          }).length
        : (litter.aliveKits ?? born);

    final bool isMissedLitter = litter.missedLitter == true ||
        lStatus == 'not taken' ||
        lStatus == 'missed' ||
        lStatus == 'missed litter' ||
        lStatus == 'missed_litter' ||
        (born == 0 && alive == 0 && litter.kits.isEmpty);

    final bool hasSoldKits = litter.kits.any((k) {
      final s = k.status.toLowerCase().trim();
      return s == 'sold' || s == 'archived' || s == 'weaned' || s == 'nursing' || s == 'growout' || s == '';
    });
    final bool allNonDeadKitsSold = litter.kits.isNotEmpty &&
        hasSoldKits &&
        litter.kits.every((k) {
          final s = k.status.toLowerCase().trim();
          return s != 'dead' && s != 'died' && s != 'deceased' && s != 'cull' && s != 'culled';
        });
    final bool isLitterSold = !isMissedLitter &&
        (lStatus == 'sold' || lStatus == 'history_only' || lStatus == 'deleted_archive' || lStatus == 'archived' || allNonDeadKitsSold);
    final bool allKitsDead = (litter.kits.isNotEmpty &&
            litter.kits.every((k) {
              final s = k.status.toLowerCase().trim();
              return s == 'dead' || s == 'died' || s == 'deceased';
            })) ||
        (litter.kits.isEmpty && born > 0 && (litter.deadKits ?? 0) >= born && (litter.aliveKits ?? 0) == 0);
    final bool isLitterDied = !isMissedLitter &&
        !isLitterSold &&
        (lStatus == 'died' || lStatus == 'dead' || allKitsDead);

    final partnerRabbit = _rabbitMap[partnerId];
    String partnerDisplay;
    if (partnerRabbit != null) {
      final prefix = (partnerRabbit.breederPrefix ?? '').trim();
      final name = partnerRabbit.name.trim();
      final ear = (partnerRabbit.earNumber?.trim().isNotEmpty == true
              ? partnerRabbit.earNumber!.trim()
              : partnerRabbit.id.trim())
          .toUpperCase();
      final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
      if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
        partnerDisplay = '$namePart $ear';
      } else {
        partnerDisplay = namePart.isNotEmpty ? namePart : 'Unknown';
      }
    } else {
      final rawName = (partner.isNotEmpty
              ? partner
              : (isDam ? litter.sire : litter.dam))
          .trim();
      final rawId = (partnerId ?? '').trim().toUpperCase();
      if (rawName.isNotEmpty && rawId.isNotEmpty && !rawName.toUpperCase().contains(rawId) && !FormatUtils.isSystemId(rawId)) {
        partnerDisplay = '$rawName $rawId';
      } else {
        partnerDisplay = rawName.isNotEmpty ? rawName : 'Unknown';
      }
    }

    String fullAgeStr = '';
    if (isMissedLitter) {
      fullAgeStr = '';
    } else if (isLitterSold) {
      fullAgeStr = 'Litter Sold • ${FormatUtils.formatAge(litter.kindleDate ?? litter.dob)}';
    } else if (isLitterDied) {
      fullAgeStr = 'Litter Died';
    } else {
      fullAgeStr = 'Age • ${FormatUtils.formatAge(litter.kindleDate ?? litter.dob)}';
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
                      isMissedLitter ? 'Missed Litter' : litter.id,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
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
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Partner name, Born/Alive, Age/Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partnerDisplay,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4F4F56),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isMissedLitter) ...[
                          const SizedBox(height: 3),
                          Text(
                            '$born Born • $alive Alive',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4F4F56),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right Column: Bred date, Born/Due date (Aligned vertically on the left edge)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bred $bredDateStr',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4F4F56),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isMissedLitter ? 'Due $dueDateStr' : 'Born $bornDateStr',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4F4F56),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
    final String rawStatus = kit.status.toLowerCase().trim();
    final String kStatus = (rawStatus == 'cull' || rawStatus == 'culled')
        ? 'cull'
        : ((rawStatus == 'dead' || rawStatus == 'died' || rawStatus == 'deceased')
            ? 'dead'
            : (rawStatus == 'butchered' ? 'butchered' : 'sold'));
    final bool isOutcome = (rawStatus == 'cull' ||
        rawStatus == 'culled' ||
        rawStatus == 'dead' ||
        rawStatus == 'died' ||
        rawStatus == 'deceased' ||
        rawStatus == 'butchered' ||
        rawStatus == 'sold');

    final bool isFosteredIn = kit.id.startsWith('F-') ||
        kit.id.startsWith('foster_') ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered from'));

    final String displayKitId = _getKitDisplayTag(litter, kit);

    return InkWell(
      onTap: () => _showKitActions(litter, kit),
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        kit.color.isNotEmpty ? kit.color : 'Kit $displayKitId',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isOutcome ? const Color(0xFF8E8E93) : const Color(0xFF37352F),
                        ),
                      ),
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
              _buildOutcomeBadge(kStatus),
              const SizedBox(width: 6),
            ],
            const Icon(PhosphorIconsRegular.caretRight, size: 16, color: Color(0xFFE5E5EA)),
          ],
        ),
      ),
    );
  }

  String _getKitDisplayTag(Litter litter, Kit kit) {
    final bool isFosteredIn = kit.id.startsWith('F-') ||
        kit.id.startsWith('foster_') ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered from'));
    if (isFosteredIn) {
      final fosteredKits = litter.kits.where((k) =>
        k.id.startsWith('F-') ||
        k.id.startsWith('foster_') ||
        (k.details != null && k.details!.toLowerCase().contains('fostered from'))
      ).toList();
      final idx = fosteredKits.indexOf(kit) + 1;
      return 'F-${idx > 0 ? idx : 1}';
    } else {
      final numericPart = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
      final idx = (numericPart.isNotEmpty && numericPart.length <= 4)
          ? numericPart
          : (litter.kits.indexOf(kit) + 1).toString();
      return 'K-$idx';
    }
  }

  void _showKitActions(Litter litter, Kit kit) {
    final DateTime? kitDob = litter.dob ?? litter.kindleDate;
    final int kitAgeDays = kitDob != null
        ? DateTime.now().difference(kitDob).inDays
        : litter.ageDays;
    final int weanDays = SettingsService.instance.weanAge * 7;
    final bool isWeanAgeReached = kitAgeDays >= weanDays;

    final String kStatus = kit.status.toLowerCase().trim();
    final String lStatus = litter.status.toLowerCase().trim();

    String kitStage = 'nursing';
    if (kStatus == 'quarantine' || (kStatus.isEmpty && lStatus == 'quarantine')) {
      kitStage = 'quarantine';
    } else if (kStatus == 'growout' || kStatus == 'grow out' || kStatus == 'grow-out' || (kStatus.isEmpty && (lStatus == 'growout' || lStatus == 'grow out' || lStatus == 'grow-out'))) {
      kitStage = 'growout';
    } else if (kStatus == 'weaned' || (kStatus.isEmpty && (lStatus == 'weaned' || (litter.weanDate != null && DateTime.now().isAfter(litter.weanDate!)) || isWeanAgeReached))) {
      kitStage = 'weaned';
    } else if (kStatus == 'sold' || kStatus == 'dead' || kStatus == 'died') {
      if (lStatus == 'quarantine') {
        kitStage = 'quarantine';
      } else if (lStatus == 'growout' || lStatus == 'grow out' || lStatus == 'grow-out') {
        kitStage = 'growout';
      } else if (lStatus == 'weaned' || isWeanAgeReached) {
        kitStage = 'weaned';
      } else {
        kitStage = 'nursing';
      }
    } else {
      kitStage = 'nursing';
    }

    final bool isFosteredIn = kit.id.startsWith('F-') ||
        kit.id.startsWith('foster_') ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered from'));
    final bool isFosteredOut = kit.status.toLowerCase() == 'fostered' ||
        (kit.details != null && kit.details!.toLowerCase().contains('fostered to'));
    final bool isFostered = isFosteredIn || isFosteredOut;

    final bool isSold = kStatus == 'sold';
    final bool isDeadOrCulled = kStatus == 'dead' ||
        kStatus == 'died' ||
        kStatus == 'deceased' ||
        kStatus == 'cull' ||
        kStatus == 'culled';

    final String kitTag = _getKitDisplayTag(litter, kit);
    final List<Widget> actions = [];

    if (isSold) {
      // 0. View Kit Profile
      actions.add(_buildCompactActionTile(
        label: 'View Kit Profile',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _openKitProfile(litter, kit);
        },
      ));

      // 1. Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // 2. Cancel Sale
      actions.add(_buildCompactActionTile(
        label: 'Cancel Sale',
        color: const Color(0xFF7B6BA0),
        onTap: () {
          Navigator.pop(context);
          _cancelKitSale(litter, kit);
        },
      ));

      // 3. Birth Certificate
      actions.add(_buildCompactActionTile(
        label: 'Birth Certificate',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitBirthCertificate(litter, kit);
        },
      ));

      // 4. Pedigree
      actions.add(_buildCompactActionTile(
        label: 'Pedigree',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitPedigree(litter, kit);
        },
      ));
    } else if (isDeadOrCulled) {
      // 0. View Kit Profile
      actions.add(_buildCompactActionTile(
        label: 'View Kit Profile',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _openKitProfile(litter, kit);
        },
      ));

      // 1. Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // 2. Cancel Death
      actions.add(_buildCompactActionTile(
        label: 'Cancel Death',
        color: const Color(0xFF2E7B32),
        textColor: const Color(0xFF2E7B32),
        onTap: () {
          Navigator.pop(context);
          _showReverseKitDiedDialog(litter, kit);
        },
      ));
    } else if (kitStage == 'nursing') {
      // 1. Nursing
      // - View Kit Profile
      actions.add(_buildCompactActionTile(
        label: 'View Kit Profile',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _openKitProfile(litter, kit);
        },
      ));

      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Foster Kit
      if (isFostered) {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Foster',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelFosterKit(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Foster Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showFosterKitDialog(litter, kit);
          },
        ));
      }

      // - Sell Kit / Cancel Sale
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Weaned
      actions.add(_buildCompactActionTile(
        label: 'Move to Weaned',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Weaned');
        },
      ));

      // - Move to Grow out
      actions.add(_buildCompactActionTile(
        label: 'Move to Grow out',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'GrowOut');
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Quarantine
      actions.add(_buildCompactActionTile(
        label: 'Quarantine',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Quarantine');
        },
      ));

      // - Delete Kit
      actions.add(_buildCompactActionTile(
        label: 'Delete Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _showDeleteKitConfirm(litter, kit);
        },
      ));

      // - Cull Kit
      actions.add(_buildCompactActionTile(
        label: 'Cull Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _markKitAsCulled(litter, kit);
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died' || kit.status.toLowerCase() == 'cull' || kit.status.toLowerCase() == 'culled') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    } else if (kitStage == 'weaned') {
      // 2. Weaned
      // - View Kit Profile
      actions.add(_buildCompactActionTile(
        label: 'View Kit Profile',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _openKitProfile(litter, kit);
        },
      ));

      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Sell Kit
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Nursing
      actions.add(_buildCompactActionTile(
        label: 'Move to Nursing',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Nursing');
        },
      ));

      // - Move to Grow out
      actions.add(_buildCompactActionTile(
        label: 'Move to Grow out',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'GrowOut');
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Birth Certificate
      actions.add(_buildCompactActionTile(
        label: 'Birth Certificate',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitBirthCertificate(litter, kit);
        },
      ));

      // - Pedigree
      actions.add(_buildCompactActionTile(
        label: 'Pedigree',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitPedigree(litter, kit);
        },
      ));

      // - Quarantine
      actions.add(_buildCompactActionTile(
        label: 'Quarantine',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Quarantine');
        },
      ));

      // - Delete Kit
      actions.add(_buildCompactActionTile(
        label: 'Delete Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _showDeleteKitConfirm(litter, kit);
        },
      ));

      // - Cull Kit
      actions.add(_buildCompactActionTile(
        label: 'Cull Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _markKitAsCulled(litter, kit);
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died' || kit.status.toLowerCase() == 'cull' || kit.status.toLowerCase() == 'culled') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    } else if (kitStage == 'growout') {
      // 3. Grow-Out
      // - View Kit Profile
      actions.add(_buildCompactActionTile(
        label: 'View Kit Profile',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _openKitProfile(litter, kit);
        },
      ));

      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Sell Kit
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Nursing
      actions.add(_buildCompactActionTile(
        label: 'Move to Nursing',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Nursing');
        },
      ));

      // - Move to Weaned
      actions.add(_buildCompactActionTile(
        label: 'Move to Weaned',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Weaned');
        },
      ));

      // - Move to Herd (Under 6 months status Inactive or growout in Herd)
      actions.add(_buildCompactActionTile(
        label: 'Move to Herd',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          final bool isUnder6Months = kitAgeDays < 180;
          _promoteKitToMature(litter, kit, isGrowOut: isUnder6Months);
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Birth Certificate
      actions.add(_buildCompactActionTile(
        label: 'Birth Certificate',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitBirthCertificate(litter, kit);
        },
      ));

      // - Pedigree
      actions.add(_buildCompactActionTile(
        label: 'Pedigree',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitPedigree(litter, kit);
        },
      ));

      // - Quarantine
      actions.add(_buildCompactActionTile(
        label: 'Quarantine',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Quarantine');
        },
      ));

      // - Delete Kit
      actions.add(_buildCompactActionTile(
        label: 'Delete Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _showDeleteKitConfirm(litter, kit);
        },
      ));

      // - Cull Kit
      actions.add(_buildCompactActionTile(
        label: 'Cull Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _markKitAsCulled(litter, kit);
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died' || kit.status.toLowerCase() == 'cull' || kit.status.toLowerCase() == 'culled') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    } else if (kitStage == 'quarantine') {
      // 4. Quarantine
      // - View Kit Profile
      actions.add(_buildCompactActionTile(
        label: 'View Kit Profile',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _openKitProfile(litter, kit);
        },
      ));

      // - Edit Kit info
      actions.add(_buildCompactActionTile(
        label: 'Edit Kit info',
        color: kLilacDeep,
        onTap: () {
          Navigator.pop(context);
          _showEditKitDetails(litter, kit);
        },
      ));

      // - Sell Kit
      if (kit.status.toLowerCase() == 'sold') {
        actions.add(_buildCompactActionTile(
          label: 'Cancel Sale',
          color: const Color(0xFF7B6BA0),
          onTap: () {
            Navigator.pop(context);
            _cancelKitSale(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Sell Kit',
          color: kNeutral700,
          onTap: () {
            Navigator.pop(context);
            _showSellKitDialog(litter, kit);
          },
        ));
      }

      // - Move to Nursing
      actions.add(_buildCompactActionTile(
        label: 'Move to Nursing',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Nursing');
        },
      ));

      // - Move to Weaned
      actions.add(_buildCompactActionTile(
        label: 'Move to Weaned',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'Weaned');
        },
      ));

      // - Move to Grow out
      actions.add(_buildCompactActionTile(
        label: 'Move to Grow out',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _moveKitToStage(litter, kit, 'GrowOut');
        },
      ));

      // - Record Health
      actions.add(_buildCompactActionTile(
        label: 'Record Health',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitHealthRecord(litter, kit);
        },
      ));

      // - Log Weight
      actions.add(_buildCompactActionTile(
        label: 'Log Weight',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _logKitWeight(litter, kit);
        },
      ));

      // - Birth Certificate
      actions.add(_buildCompactActionTile(
        label: 'Birth Certificate',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitBirthCertificate(litter, kit);
        },
      ));

      // - Pedigree
      actions.add(_buildCompactActionTile(
        label: 'Pedigree',
        color: kNeutral700,
        onTap: () {
          Navigator.pop(context);
          _showKitPedigree(litter, kit);
        },
      ));

      // - Delete Kit
      actions.add(_buildCompactActionTile(
        label: 'Delete Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _showDeleteKitConfirm(litter, kit);
        },
      ));

      // - Cull Kit
      actions.add(_buildCompactActionTile(
        label: 'Cull Kit',
        color: const Color(0xFFD44C47),
        textColor: const Color(0xFFD44C47),
        onTap: () {
          Navigator.pop(context);
          _markKitAsCulled(litter, kit);
        },
      ));

      // - Kit Died in RED / Bring Back to Life
      if (kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died' || kit.status.toLowerCase() == 'cull' || kit.status.toLowerCase() == 'culled') {
        actions.add(_buildCompactActionTile(
          label: 'Bring Back to Life',
          color: const Color(0xFF2E7B32),
          textColor: const Color(0xFF2E7B32),
          onTap: () {
            Navigator.pop(context);
            _showReverseKitDiedDialog(litter, kit);
          },
        ));
      } else {
        actions.add(_buildCompactActionTile(
          label: 'Kit Died',
          color: const Color(0xFFD44C47),
          textColor: const Color(0xFFD44C47),
          onTap: () {
            Navigator.pop(context);
            _markKitAsDied(litter, kit);
          },
        ));
      }
    }

    String displayStageName = kitStage;
    if (isSold) {
      displayStageName = 'Sold';
    } else if (isDeadOrCulled) {
      displayStageName = kStatus == 'cull' || kStatus == 'culled' ? 'Culled' : 'Dead';
    } else {
      displayStageName = kitStage.isNotEmpty
          ? (kitStage == 'growout' ? 'Grow out' : (kitStage[0].toUpperCase() + kitStage.substring(1)))
          : 'Nursing';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kit $kitTag',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C2C2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayStageName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF2C2C2E), size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE6F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 3.4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactActionTile({
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final effectiveTextColor = textColor ?? const Color(0xFF2C2C2E);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: effectiveTextColor),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _openKitProfile(Litter litter, Kit kit) {
    final String rabbitName = (kit.name != null && kit.name!.trim().isNotEmpty)
        ? kit.name!.trim()
        : (kit.id.startsWith('K-') || kit.id.startsWith('F-') ? 'Kit ${kit.id}' : kit.id);

    final kitRabbit = Rabbit(
      id: kit.id,
      name: rabbitName,
      breed: litter.breed,
      type: kit.sex == 'M' ? RabbitType.buck : RabbitType.doe,
      color: kit.color,
      dateOfBirth: litter.dob ?? litter.kindleDate,
      weight: kit.weight > 0 ? kit.weight : null,
      sireId: litter.buckId,
      damId: litter.doeId,
      status: (kit.status.toLowerCase() == 'sold' ||
              kit.status.toLowerCase() == 'dead' ||
              kit.status.toLowerCase() == 'died' ||
              kit.status.toLowerCase() == 'culled')
          ? RabbitStatus.archived
          : RabbitStatus.active,
      archiveReason: kit.status.toLowerCase() == 'sold'
          ? ArchiveReason.sold
          : (kit.status.toLowerCase() == 'culled'
              ? ArchiveReason.cull
              : ((kit.status.toLowerCase() == 'dead' || kit.status.toLowerCase() == 'died')
                  ? ArchiveReason.dead
                  : null)),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RabbitDetailScreen(
          rabbit: kitRabbit,
        ),
      ),
    );
  }

  void _showEditKitDetails(Litter litter, Kit kit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditKitDetailsScreen(
          litter: litter,
          kit: kit,
          onSaved: () => _loadLitterHistory(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _showKitBirthCertificate(Litter litter, Kit kit) {
    final String rabbitName = (kit.name != null && kit.name!.trim().isNotEmpty)
        ? kit.name!.trim()
        : (kit.id.startsWith('K-') || kit.id.startsWith('F-') ? 'Kit ${kit.id}' : kit.id);

    final kitRabbit = Rabbit(
      id: kit.id,
      name: rabbitName,
      breed: litter.breed,
      type: kit.sex == 'M' ? RabbitType.buck : RabbitType.doe,
      color: kit.color,
      dateOfBirth: litter.dob ?? litter.kindleDate,
      weight: kit.weight > 0 ? kit.weight : null,
      sireId: litter.buckId,
      damId: litter.doeId,
      status: RabbitStatus.open,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Birth Certificate Preview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2C2C2E)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CertificateCard(rabbit: kitRabbit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKitPedigree(Litter litter, Kit kit) {
    final String rabbitName = (kit.name != null && kit.name!.trim().isNotEmpty)
        ? kit.name!.trim()
        : (kit.id.startsWith('K-') || kit.id.startsWith('F-') ? 'Kit ${kit.id}' : kit.id);

    final kitRabbit = Rabbit(
      id: kit.id,
      name: rabbitName,
      breed: litter.breed,
      type: kit.sex == 'M' ? RabbitType.buck : RabbitType.doe,
      color: kit.color,
      dateOfBirth: litter.dob ?? litter.kindleDate,
      weight: kit.weight > 0 ? kit.weight : null,
      sireId: litter.buckId,
      damId: litter.doeId,
      status: RabbitStatus.open,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PedigreeScreen(
          rabbitId: kitRabbit.id,
          initialRabbit: kitRabbit,
        ),
      ),
    );
  }

  void _logKitWeight(Litter litter, Kit kit) {
    int initialLbs = 0;
    double initialOz = 0;
    if (kit.weight > 0) {
      initialLbs = kit.weight.floor();
      initialOz = (kit.weight - initialLbs) * 16.0;
    }
    final TextEditingController lbsController = TextEditingController(
      text: initialLbs > 0 ? initialLbs.toString() : '',
    );
    final TextEditingController ozController = TextEditingController(
      text: initialOz > 0.01 ? initialOz.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : '',
    );
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6BEFE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Log Weight - ${_getKitDisplayTag(litter, kit)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C2C2E),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 22, color: Color(0xFF2C2C2E)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATE OF ENTRY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF7B6BA0),
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Color(0xFF2C2C2E),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC7C7CC)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              FormatUtils.formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2C2C2E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: Color(0xFF7B6BA0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'WEIGHT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lbsController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixText: 'lbs',
                              suffixStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8E8E93),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF7B6BA0),
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: ozController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixText: 'oz',
                              suffixStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8E8E93),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF7B6BA0),
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                final double lbsVal = double.tryParse(lbsController.text.trim()) ?? 0.0;
                                final double ozVal = double.tryParse(ozController.text.trim()) ?? 0.0;
                                final double weightVal = lbsVal + (ozVal / 16.0);

                                final litterIndex = _litters.indexWhere((l) => l.id == litter.id);
                                if (litterIndex != -1) {
                                  final currentLitter = _litters[litterIndex];
                                  final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
                                  bool updated = false;
                                  final updatedKits = currentLitter.kits.map((k) {
                                    final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
                                    final bool isExactId = k.id == kit.id;
                                    final bool isNumericMatch = (k.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(k.id)) &&
                                        (kit.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(kit.id)) &&
                                        kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
                                    if ((isExactId || isNumericMatch) && !updated) {
                                      updated = true;
                                      return k.copyWith(weight: weightVal);
                                    }
                                    return k;
                                  }).toList();

                                  final updatedLitter = currentLitter.copyWith(kits: updatedKits);
                                  await _db.updateLitter(updatedLitter);
                                  await _loadLitterHistory();
                                }

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Weight updated'),
                                      backgroundColor: Color(0xFF7B6BA0),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6BEFE),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2C2C2E),
                                ),
                              )
                            : const Text(
                                'Save Weight',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C2C2E),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKitHealthRecord(Litter litter, Kit kit) {
    DateTime selectedDate = DateTime.now();
    String selectedType = 'treatment';
    final conditionController = TextEditingController();
    final notesController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6BEFE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Record Health',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C2C2E),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 22, color: Color(0xFF2C2C2E)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATE OF ENTRY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF7B6BA0),
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Color(0xFF2C2C2E),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC7C7CC)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              FormatUtils.formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2C2C2E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: Color(0xFF7B6BA0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'TYPE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'treatment', child: Text('Treatment')),
                        DropdownMenuItem(value: 'vaccination', child: Text('Vaccination')),
                        DropdownMenuItem(value: 'deworm', child: Text('Deworm')),
                        DropdownMenuItem(value: 'checkup', child: Text('Check-up')),
                        DropdownMenuItem(value: 'injury', child: Text('Injury')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CONDITION / DIAGNOSIS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: conditionController,
                      decoration: InputDecoration(
                        hintText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFC7C7CC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF7B6BA0),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                await _db.insertHealthRecord({
                                  'id': 'HLTH-${DateTime.now().millisecondsSinceEpoch}',
                                  'rabbitId': kit.id,
                                  'type': selectedType,
                                  'condition': conditionController.text.trim(),
                                  'notes': notesController.text.trim(),
                                  'date': selectedDate.toIso8601String(),
                                  'createdAt': DateTime.now().toIso8601String(),
                                });

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Health record saved'),
                                      backgroundColor: Color(0xFF7B6BA0),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6BEFE),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2C2C2E),
                                ),
                              )
                            : const Text(
                                'Save Record',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C2C2E),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSellKitDialog(Litter litter, Kit kit) {
    final TextEditingController priceController = TextEditingController();
    final TextEditingController buyerController = TextEditingController();
    DateTime soldDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6BEFE),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sell Kit',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C2C2E),
                          letterSpacing: 0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Color(0xFF2C2C2E), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F2FA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE8DFFA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kit ${_getKitDisplayTag(litter, kit)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A3E6D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${kit.sex == 'M' ? 'Buck' : 'Doe'} • ${kit.color} • ${kit.weight} ${FormatUtils.weightUnit}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF787774),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'DATE SOLD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F4F56),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: soldDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF7B6BA0),
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Color(0xFF2C2C2E),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() => soldDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFC7C7CC), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  FormatUtils.formatDate(soldDate),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF2C2C2E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 20,
                                  color: Color(0xFF7B6BA0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'SALE PRICE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F4F56),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: '${FormatUtils.currencySymbol} ',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFC7C7CC), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF7B6BA0),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'BUYER NAME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F4F56),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _db.getContacts(),
                          builder: (context, snapshot) {
                            final contacts = snapshot.data ?? [];
                            return Autocomplete<String>(
                              initialValue: TextEditingValue(text: buyerController.text),
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<String>.empty();
                                }
                                return contacts
                                    .map((c) => c['name'] as String)
                                    .where((name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                              },
                              onSelected: (String selection) {
                                buyerController.text = selection;
                              },
                              fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                                fieldController.addListener(() {
                                  buyerController.text = fieldController.text;
                                });
                                return TextField(
                                  controller: fieldController,
                                  focusNode: focusNode,
                                  onSubmitted: (value) => onFieldSubmitted(),
                                  decoration: InputDecoration(
                                    hintText: 'Select or enter buyer',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFC7C7CC), width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF7B6BA0),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);

                        final litterIndex = _litters.indexWhere((l) => l.id == litter.id);
                        if (litterIndex != -1) {
                          final currentLitter = _litters[litterIndex];
                          final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
                          bool updated = false;
                          final updatedKits = currentLitter.kits.map((k) {
                            final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
                            final bool isExactId = k.id == kit.id;
                            final bool isNumericMatch = (k.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(k.id)) &&
                                (kit.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(kit.id)) &&
                                kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
                            if ((isExactId || isNumericMatch) && !updated) {
                              updated = true;
                              return k.copyWith(
                                status: 'Sold',
                                details: buyerController.text.isNotEmpty ? 'Sold to ${buyerController.text}' : 'Sold',
                                price: double.tryParse(priceController.text),
                              );
                            }
                            return k;
                          }).toList();

                          final updatedLitter = currentLitter.copyWith(kits: updatedKits);
                          await _db.updateLitter(updatedLitter);

                          final double? salePrice = double.tryParse(priceController.text.trim());
                          if (salePrice != null && salePrice > 0) {
                            final transaction = finance.Transaction(
                              id: 'TX-${DateTime.now().millisecondsSinceEpoch}',
                              type: finance.TransactionType.income,
                              category: finance.TransactionCategory.soldKit,
                              amount: salePrice,
                              date: soldDate,
                              notes: 'Sale of Kit ${_getKitDisplayTag(litter, kit)} (Litter ${litter.id})${buyerController.text.isNotEmpty ? ' to ' + buyerController.text.trim() : ''}',
                              rabbitId: kit.id,
                              litterId: litter.id,
                            );
                            await _db.insertTransaction(transaction);
                          }

                          await _loadLitterHistory();
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kit marked as sold'),
                              backgroundColor: Color(0xFF6B2D6D),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE6BEFE),
                        foregroundColor: const Color(0xFF2C2C2E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Record Sale',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cancelKitSale(Litter litter, Kit kit) async {
    final kitTag = _getKitDisplayTag(litter, kit);
    final confirmed = await showBrightPurpleDialog<bool>(
      context: context,
      title: 'Cancel Sale',
      content: 'Are you sure, you want to cancel the sale for Kit $kitTag?',
      cancelText: 'Cancel',
      confirmText: 'OK',
    );

    if (confirmed != true) return;

    try {
      final litterIndex = _litters.indexWhere((l) => l.id == litter.id);
      if (litterIndex != -1) {
        final currentLitter = _litters[litterIndex];
        final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
        final int weanDays = SettingsService.instance.weanAge * 7;
        final DateTime? kitDob = currentLitter.dob ?? currentLitter.kindleDate;
        final int kitAgeDays = kitDob != null ? DateTime.now().difference(kitDob).inDays : currentLitter.ageDays;
        final bool isWeanAgeReached = kitAgeDays >= weanDays;
        final String restoredStatus = isWeanAgeReached ? 'Weaned' : 'Nursing';

        bool updated = false;
        final updatedKits = currentLitter.kits.map((k) {
          final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
          final bool isExactId = k.id == kit.id;
          final bool isNumericMatch = (k.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(k.id)) &&
              (kit.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(kit.id)) &&
              kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
          if ((isExactId || isNumericMatch) && !updated) {
            updated = true;
            return k.copyWith(status: restoredStatus, details: null);
          }
          return k;
        }).toList();

        final updatedLitter = currentLitter.copyWith(kits: updatedKits);
        await _db.updateLitter(updatedLitter);

        final db = await _db.database;
        await db.delete(
          'transactions',
          where: 'rabbitId = ? AND category = ?',
          whereArgs: [kit.id, 'Sales'],
        );

        await _loadLitterHistory();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale cancelled for Kit $kitTag'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _moveKitToStage(Litter litter, Kit kit, String targetStage) async {
    try {
      final index = _litters.indexWhere((l) => l.id == litter.id);
      if (index == -1) return;

      final currentLitter = _litters[index];
      final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
      bool updated = false;
      final updatedKits = currentLitter.kits.map((k) {
        final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
        final bool isExactId = k.id == kit.id;
        final bool isNumericMatch = (k.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(k.id)) &&
            (kit.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(kit.id)) &&
            kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
        if ((isExactId || isNumericMatch) && !updated) {
          updated = true;
          return k.copyWith(status: targetStage == 'Archived' ? 'Sold' : targetStage);
        }
        return k;
      }).toList();

      final allKitsInTargetOrOutcome = updatedKits.every((k) =>
          k.status.toLowerCase() == targetStage.toLowerCase() ||
          k.status.toLowerCase() == 'sold' ||
          k.status.toLowerCase() == 'dead' ||
          k.status.toLowerCase() == 'died' ||
          k.status.toLowerCase() == 'butchered' ||
          k.status.toLowerCase() == 'cull' ||
          k.status.toLowerCase() == 'culled');

      final bool hasAnyNursing = updatedKits.any((k) {
        final s = k.status.toLowerCase().trim();
        return s == 'nursing' || s == 'fostered';
      });

      final int weanDays = SettingsService.instance.weanAge * 7;
      final DateTime? updatedWeanDate = targetStage == 'Weaned'
          ? (_litters[index].weanDate ?? DateTime.now())
          : (targetStage == 'Nursing' ? DateTime.now().add(Duration(days: weanDays)) : _litters[index].weanDate);

      final updatedLitter = _litters[index].copyWith(
        kits: updatedKits,
        status: allKitsInTargetOrOutcome
            ? targetStage
            : (hasAnyNursing ? 'Nursing' : targetStage),
        weanDate: updatedWeanDate,
      );

      await _db.updateLitter(updatedLitter);
      await _loadLitterHistory();

      if (mounted) {
        final displayStage = targetStage == 'GrowOut' ? 'Grow out' : targetStage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kit ${_getKitDisplayTag(litter, kit)} moved to $displayStage'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _promoteKitToMature(Litter litter, Kit kit, {bool isGrowOut = false}) async {
    final String rabbitName = (kit.name != null && kit.name!.trim().isNotEmpty)
        ? kit.name!.trim()
        : (kit.id.startsWith('K-') || kit.id.startsWith('F-') ? 'Kit ${kit.id}' : kit.id);

    final RabbitStatus newStatus = isGrowOut ? RabbitStatus.inactive : RabbitStatus.active;
    final matureRabbit = Rabbit(
      id: kit.id,
      name: rabbitName,
      breed: litter.breed,
      type: kit.sex == 'M' ? RabbitType.buck : RabbitType.doe,
      color: kit.color,
      dateOfBirth: litter.dob ?? litter.kindleDate,
      weight: kit.weight > 0 ? kit.weight : null,
      sireId: litter.buckId,
      damId: litter.doeId,
      status: newStatus,
      cage: isGrowOut ? 'Grow-Out' : null,
    );

    try {
      await _db.insertRabbit(matureRabbit);

      final litterIndex = _litters.indexWhere((l) => l.id == litter.id);
      if (litterIndex != -1) {
        final currentLitter = _litters[litterIndex];
        final updatedKits = currentLitter.kits.where((k) => k.id != kit.id).toList();
        final updatedLitter = currentLitter.copyWith(kits: updatedKits);
        await _db.updateLitter(updatedLitter);
        await _loadLitterHistory();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${matureRabbit.name} moved to Herd (${isGrowOut ? "Inactive / Grow-Out" : "Active"})'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error promoting kit: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFosterKitDialog(Litter litter, Kit kit) {
    String? selectedLitterId;
    final fosterLitters = _litters.where((l) =>
      l.id != litter.id &&
      l.doeId != litter.doeId &&
      l.status.toLowerCase() == 'nursing' &&
      l.status.toLowerCase() != 'archived' &&
      l.status.toLowerCase() != 'weaned'
    ).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Foster Kit', style: TextStyle(fontWeight: FontWeight.w700)),
          content: fosterLitters.isEmpty
              ? const Text('No active nursing litters found to foster with.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a nursing foster mother:'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedLitterId,
                      items: fosterLitters
                          .map((l) {
                            final fosterDoeName = l.doeName.isNotEmpty ? l.doeName : l.dam;
                            final shortLitterId = l.id.length > 6 ? l.id.substring(l.id.length - 4) : l.id;
                            final nursingKitsCount = l.kits.where((k) => k.status.toLowerCase() == 'nursing' || (!k.isArchived && k.status != 'Dead' && k.status != 'Died')).length;
                            return DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                '$fosterDoeName (Litter #$shortLitterId • $nursingKitsCount nursing kits)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedLitterId = val),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Note: This will transfer the kit to the surrogate doe with a note indicating its birth dam.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                    ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
            ),
            if (fosterLitters.isNotEmpty)
              ElevatedButton(
                onPressed: selectedLitterId == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        final target = fosterLitters.firstWhere((l) => l.id == selectedLitterId);
                        await _handleFosterKitSingle(litter, target, kit);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6BA0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFosterKitSingle(Litter source, Litter target, Kit kit) async {
    try {
      final sourceDamName = source.doeName.isNotEmpty ? source.doeName : source.dam;
      final targetDoeName = target.doeName.isNotEmpty ? target.doeName : target.dam;

      final updatedSourceKits = source.kits.map((k) {
        if (k.id == kit.id) {
          return k.copyWith(status: 'Fostered', details: 'Fostered to $targetDoeName');
        }
        return k;
      }).toList();

      final fosteredKit = kit.copyWith(
        id: 'foster_${source.id}_${kit.id}',
        status: 'Nursing',
        details: 'Fostered from $sourceDamName',
      );

      final updatedTargetKits = [...target.kits, fosteredKit];

      final sourceAliveCount = updatedSourceKits.where((k) {
        final s = k.status.toLowerCase().trim();
        return !k.isArchived && s != 'dead' && s != 'died' && s != 'deceased' && s != 'cull' && s != 'culled' && s != 'sold' && s != 'butchered';
      }).length;

      await _db.updateLitter(source.copyWith(kits: updatedSourceKits, aliveKits: sourceAliveCount));
      await _db.updateLitter(target.copyWith(kits: updatedTargetKits));
      await _loadLitterHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kit fostered to $targetDoeName'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fostering kit: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelFosterKit(Litter litter, Kit kit) async {
    try {
      final index = _litters.indexWhere((l) => l.id == litter.id);
      if (index == -1) return;

      final currentLitter = _litters[index];
      final updatedKits = currentLitter.kits.map((k) {
        if (k.id == kit.id) {
          return k.copyWith(status: 'Nursing', details: null);
        }
        return k;
      }).toList();

      await _db.updateLitter(currentLitter.copyWith(kits: updatedKits));
      await _loadLitterHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foster cancelled'),
            backgroundColor: Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteKitConfirm(Litter litter, Kit kit) async {
    final kitTag = _getKitDisplayTag(litter, kit);
    final confirmed = await showBrightPurpleDialog<bool>(
      context: context,
      title: 'Delete Kit',
      content:
          'Are you sure you want to delete kit $kitTag? This will permanently remove this kit from Litter ${litter.id}.',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      await _deleteKit(litter, kit);
    }
  }

  Future<void> _deleteKit(Litter litter, Kit kit) async {
    try {
      final kitTag = _getKitDisplayTag(litter, kit);
      final currentKits = litter.kits;
      final targetId = kit.id.trim().toLowerCase();
      final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
      bool deleted = false;
      final updatedKits = <Kit>[];
      for (final k in currentKits) {
        final kId = k.id.trim().toLowerCase();
        final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
        final bool isExactId = kId == targetId;
        final bool isNumericMatch = (kId.startsWith('k-') || RegExp(r'^\d+$').hasMatch(kId)) &&
            (targetId.startsWith('k-') || RegExp(r'^\d+$').hasMatch(targetId)) &&
            kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
        if ((isExactId || isNumericMatch) && !deleted) {
          deleted = true;
          continue;
        }
        updatedKits.add(k);
      }
      final int currentTotal = litter.totalKits ?? currentKits.length;
      final int newTotal = currentTotal > 0 ? currentTotal - 1 : 0;
      final int newAlive = updatedKits.where((k) {
        final s = k.status.toLowerCase().trim();
        return !k.isArchived &&
            s != 'dead' &&
            s != 'died' &&
            s != 'deceased' &&
            s != 'sold' &&
            s != 'butchered' &&
            s != 'cull' &&
            s != 'culled' &&
            s != 'fostered';
      }).length;

      final updatedLitter = litter.copyWith(
        kits: updatedKits,
        totalKits: newTotal,
        aliveKits: newAlive,
      );

      await _db.updateLitter(updatedLitter);
      await _loadLitterHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kit $kitTag deleted'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _markKitAsCulled(Litter litter, Kit kit) {
    final TextEditingController reasonController = TextEditingController();
    final kitTag = _getKitDisplayTag(litter, kit);

    showDialog(
      context: context,
      builder: (context) => BrightPurpleDialog(
        title: 'Cull Kit',
        textAlign: TextAlign.start,
        contentWidget: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to mark Kit $kitTag as culled?',
              style: const TextStyle(fontSize: 15, color: Color(0xFF3A3A3C), height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason for culling (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kLilacLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kLilacDeep, width: 1.8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        cancelText: 'Cancel',
        confirmText: 'Confirm',
        isDestructive: true,
        onConfirm: () async {
          Navigator.pop(context);

          final litterIndex = _litters.indexWhere((l) => l.id == litter.id);
          if (litterIndex != -1) {
            final currentLitter = _litters[litterIndex];
            final targetId = kit.id.trim().toLowerCase();
            final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
            bool updated = false;
            final updatedKits = currentLitter.kits.map((k) {
              final kId = k.id.trim().toLowerCase();
              final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
              final bool isExactId = kId == targetId;
              final bool isNumericMatch = (kId.startsWith('k-') || RegExp(r'^\d+$').hasMatch(kId)) &&
                  (targetId.startsWith('k-') || RegExp(r'^\d+$').hasMatch(targetId)) &&
                  kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
              if ((isExactId || isNumericMatch) && !updated) {
                updated = true;
                return k.copyWith(
                  status: 'Cull',
                  details: reasonController.text.isNotEmpty ? reasonController.text : 'Culled',
                );
              }
              return k;
            }).toList();

            final int newAlive = updatedKits.where((k) {
              final s = k.status.toLowerCase().trim();
              return !k.isArchived &&
                  s != 'dead' &&
                  s != 'died' &&
                  s != 'deceased' &&
                  s != 'sold' &&
                  s != 'butchered' &&
                  s != 'cull' &&
                  s != 'culled' &&
                  s != 'fostered';
            }).length;

            final int deadCount = updatedKits.where((k) {
              final s = k.status.toLowerCase().trim();
              return s == 'dead' || s == 'died' || s == 'deceased' || s == 'cull' || s == 'culled';
            }).length;

            final updatedLitter = currentLitter.copyWith(
              kits: updatedKits,
              aliveKits: newAlive,
              deadKits: deadCount,
            );

            await _db.updateLitter(updatedLitter);
            await _loadLitterHistory();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kit $kitTag marked as culled'),
                backgroundColor: const Color(0xFF7B6BA0),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _markKitAsDied(Litter litter, Kit kit) {
    final TextEditingController reasonController = TextEditingController();
    final kitTag = _getKitDisplayTag(litter, kit);

    showDialog(
      context: context,
      builder: (context) => BrightPurpleDialog(
        title: 'Mark as Died',
        textAlign: TextAlign.start,
        contentWidget: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record cause of death for Kit $kitTag (optional):',
              style: const TextStyle(fontSize: 15, color: Color(0xFF3A3A3C), height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g., Runt, illness',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kLilacLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kLilacDeep, width: 1.8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        cancelText: 'Cancel',
        confirmText: 'Confirm',
        isDestructive: true,
        onConfirm: () async {
          Navigator.pop(context);

          final litterIndex = _litters.indexWhere((l) => l.id == litter.id);
          if (litterIndex != -1) {
            final currentLitter = _litters[litterIndex];
            final targetId = kit.id.trim().toLowerCase();
            final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
            bool updated = false;
            final updatedKits = currentLitter.kits.map((k) {
              final kId = k.id.trim().toLowerCase();
              final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
              final bool isExactId = kId == targetId;
              final bool isNumericMatch = (kId.startsWith('k-') || RegExp(r'^\d+$').hasMatch(kId)) &&
                  (targetId.startsWith('k-') || RegExp(r'^\d+$').hasMatch(targetId)) &&
                  kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
              if ((isExactId || isNumericMatch) && !updated) {
                updated = true;
                return k.copyWith(
                  status: 'Dead',
                  details: reasonController.text.isNotEmpty ? reasonController.text : 'Deceased',
                );
              }
              return k;
            }).toList();

            final int newAlive = updatedKits.where((k) {
              final s = k.status.toLowerCase().trim();
              return !k.isArchived &&
                  s != 'dead' &&
                  s != 'died' &&
                  s != 'deceased' &&
                  s != 'sold' &&
                  s != 'butchered' &&
                  s != 'cull' &&
                  s != 'culled' &&
                  s != 'fostered';
            }).length;

            final int deadCount = updatedKits.where((k) {
              final s = k.status.toLowerCase().trim();
              return s == 'dead' || s == 'died' || s == 'deceased' || s == 'cull' || s == 'culled';
            }).length;

            final updatedLitter = currentLitter.copyWith(
              kits: updatedKits,
              aliveKits: newAlive,
              deadKits: deadCount,
            );

            await _db.updateLitter(updatedLitter);
            await _loadLitterHistory();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kit $kitTag marked as died'),
                backgroundColor: const Color(0xFF7B6BA0),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _showReverseKitDiedDialog(Litter litter, Kit kit) async {
    final kitTag = _getKitDisplayTag(litter, kit);
    final confirmed = await showBrightPurpleDialog<bool>(
      context: context,
      title: 'Bring Back to Life',
      content: 'Do you want to restore Kit $kitTag back to life?',
      cancelText: 'Cancel',
      confirmText: 'Restore',
    );

    if (confirmed != true) return;

    try {
      final litterIndex = _litters.indexWhere((l) => l.id == litter.id);
      if (litterIndex != -1) {
        final currentLitter = _litters[litterIndex];
        final targetNum = kit.id.replaceAll(RegExp(r'[^0-9]'), '');
        final int weanDays = SettingsService.instance.weanAge * 7;
        final DateTime? kitDob = currentLitter.dob ?? currentLitter.kindleDate;
        final int kitAgeDays = kitDob != null ? DateTime.now().difference(kitDob).inDays : currentLitter.ageDays;
        final bool isWeanAgeReached = kitAgeDays >= weanDays;
        final String restoredStatus = isWeanAgeReached ? 'Weaned' : 'Nursing';

        bool updated = false;
        final updatedKits = currentLitter.kits.map((k) {
          final kNum = k.id.replaceAll(RegExp(r'[^0-9]'), '');
          final bool isExactId = k.id == kit.id;
          final bool isNumericMatch = (k.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(k.id)) &&
              (kit.id.startsWith('K-') || RegExp(r'^\d+$').hasMatch(kit.id)) &&
              kNum.isNotEmpty && targetNum.isNotEmpty && kNum == targetNum;
          if ((isExactId || isNumericMatch) && !updated) {
            updated = true;
            return k.copyWith(status: restoredStatus, details: null);
          }
          return k;
        }).toList();

        final int newAlive = updatedKits.where((k) {
          final s = k.status.toLowerCase().trim();
          return !k.isArchived &&
              s != 'dead' &&
              s != 'died' &&
              s != 'deceased' &&
              s != 'sold' &&
              s != 'butchered' &&
              s != 'cull' &&
              s != 'culled' &&
              s != 'fostered';
        }).length;

        final int deadCount = updatedKits.where((k) {
          final s = k.status.toLowerCase().trim();
          return s == 'dead' || s == 'died' || s == 'deceased' || s == 'cull' || s == 'culled';
        }).length;

        final updatedLitter = currentLitter.copyWith(
          kits: updatedKits,
          aliveKits: newAlive,
          deadKits: deadCount,
        );

        await _db.updateLitter(updatedLitter);
        await _loadLitterHistory();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kit $kitTag restored to life'),
            backgroundColor: const Color(0xFF2E7B32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildOutcomeBadge(String status) {
    final s = status.toLowerCase();
    if (s == 'sold') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
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
    if (s == 'cull' || s == 'culled') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F), // Solid red box matching SOLD
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.close, size: 10, color: Colors.white),
            SizedBox(width: 3),
            Text(
              'CULL',
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
    if (s == 'dead' || s == 'died' || s == 'deceased') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F), // Solid red box matching SOLD
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.close, size: 10, color: Colors.white),
            SizedBox(width: 3),
            Text(
              'DIED',
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
    if (!hasNotes) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DFFA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B6BA0).withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A3E6D),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            litter.notes!.trim(),
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF333333),
              height: 1.3,
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
                        onTap: () async {
                          Navigator.pop(ctx);
                          final doe = await _db.getRabbit(litter.doeId);
                          if (mounted) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              enableDrag: false,
                              backgroundColor: Colors.transparent,
                              builder: (_) => LogBirthModal(
                                doe: doe ?? widget.rabbit,
                                existingLitter: litter,
                                onComplete: _loadLitterHistory,
                              ),
                            );
                          }
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
