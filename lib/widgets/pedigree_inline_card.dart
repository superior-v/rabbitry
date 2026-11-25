import 'package:flutter/material.dart';
import '../services/appearance_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';
import 'pedigree_layout.dart';
import 'pedigree_preview_modal.dart';

bool isPedigreeAncestorRecorded(Rabbit? r) {
  if (r == null) return false;
  final name = r.name.trim();
  final ear = (r.earNumber ?? '').trim();
  return name.isNotEmpty || ear.isNotEmpty;
}

Future<Rabbit> savePedigreeSlotOnPath({
  required DatabaseService db,
  required Rabbit baseRabbit,
  required List<String> path,
  required Rabbit? selectedRabbit,
}) async {
  Rabbit root = (await db.getRabbit(baseRabbit.id)) ?? baseRabbit;
  if (await db.getRabbit(root.id) == null) {
    await db.insertRabbit(root);
  }

  Rabbit node = root;
  for (int i = 0; i < path.length - 1; i++) {
    final step = path[i];
    final childId = step == 'sire' ? node.sireId : node.damId;
    Rabbit? child = (childId != null && childId.isNotEmpty)
        ? await db.getRabbit(childId)
        : null;
    if (child == null) {
      child = Rabbit(
        id: 'PED-${DateTime.now().microsecondsSinceEpoch}_$i',
        name: '',
        type: step == 'sire' ? RabbitType.buck : RabbitType.doe,
        status: RabbitStatus.archived,
        breed: root.breed,
      );
      await db.insertRabbit(child);
      if (step == 'sire') {
        node.sireId = child.id;
      } else {
        node.damId = child.id;
      }
      await db.updateRabbit(node);
      if (i == 0) root = node;
    }
    node = child;
  }

  final lastStep = path.last;
  final oldSlotId = lastStep == 'sire' ? node.sireId : node.damId;
  final Rabbit? oldSlotRabbit = (oldSlotId != null && oldSlotId.isNotEmpty)
      ? await db.getRabbit(oldSlotId)
      : null;

  if (selectedRabbit != null &&
      oldSlotRabbit != null &&
      selectedRabbit.id != oldSlotRabbit.id) {
    bool needUpdateSelected = false;
    if ((selectedRabbit.sireId == null || selectedRabbit.sireId!.isEmpty) &&
        oldSlotRabbit.sireId != null &&
        oldSlotRabbit.sireId!.isNotEmpty) {
      selectedRabbit.sireId = oldSlotRabbit.sireId;
      needUpdateSelected = true;
    }
    if ((selectedRabbit.damId == null || selectedRabbit.damId!.isEmpty) &&
        oldSlotRabbit.damId != null &&
        oldSlotRabbit.damId!.isNotEmpty) {
      selectedRabbit.damId = oldSlotRabbit.damId;
      needUpdateSelected = true;
    }
    if (needUpdateSelected) {
      await db.updateRabbit(selectedRabbit);
    }
  }

  if (lastStep == 'sire') {
    node.sireId = selectedRabbit?.id;
  } else {
    node.damId = selectedRabbit?.id;
  }
  await db.updateRabbit(node);
  if (path.length == 1) {
    root = node;
  }
  return (await db.getRabbit(root.id)) ?? root;
}

class PedigreeThreeColumnTree extends StatelessWidget {
  final int generations;
  final Rabbit? sire;
  final Rabbit? dam;
  final Rabbit? ss;
  final Rabbit? sd;
  final Rabbit? ds;
  final Rabbit? dd;
  final Rabbit? sss;
  final Rabbit? ssd;
  final Rabbit? sds;
  final Rabbit? sdd;
  final Rabbit? dss;
  final Rabbit? dsd;
  final Rabbit? dds;
  final Rabbit? ddd;
  final void Function(List<String> path, String label, RabbitType type, Rabbit? current) onTapSlot;

  const PedigreeThreeColumnTree({
    super.key,
    this.generations = 4,
    required this.sire,
    required this.dam,
    required this.ss,
    required this.sd,
    required this.ds,
    required this.dd,
    required this.sss,
    required this.ssd,
    required this.sds,
    required this.sdd,
    required this.dss,
    required this.dsd,
    required this.dds,
    required this.ddd,
    required this.onTapSlot,
  });

  int get _recordedCount {
    final all = <Rabbit?>[
      sire,
      dam,
      ss,
      sd,
      ds,
      dd,
      sss,
      ssd,
      sds,
      sdd,
      dss,
      dsd,
      dds,
      ddd,
    ];
    return all.where(isPedigreeAncestorRecorded).length;
  }

  @override
  Widget build(BuildContext context) {
    const double boxHeight = 46.0;
    const double gap = 6.0;
    const double pairHeight = boxHeight * 2 + gap; // 98.0
    const double halfHeight = boxHeight * 4 + gap * 3; // 202.0
    const double colGap = 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_recordedCount of 14 ancestors recorded',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: appColor(0xFF4F4F56, 0xFFB4B9C8),
          ),
        ),
        const SizedBox(height: 12),
        // Column headers
        Row(
          children: [
            Expanded(
              flex: 10,
              child: Text(
                'Parents',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: appColor(0xFF6B7280, 0xFF9EA6B8),
                ),
              ),
            ),
            if (generations >= 3) ...[
              const SizedBox(width: colGap),
              Expanded(
                flex: 10,
                child: Text(
                  'Grandparents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: appColor(0xFF6B7280, 0xFF9EA6B8),
                  ),
                ),
              ),
            ],
            if (generations >= 4) ...[
              const SizedBox(width: colGap),
              Expanded(
                flex: 11,
                child: Text(
                  'Great GrandParents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: appColor(0xFF6B7280, 0xFF9EA6B8),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // TOP HALF: Paternal (Sire) Branch
        SizedBox(
          height: halfHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Parents Column: Sire
              Expanded(
                flex: 10,
                child: Center(
                  child: _buildAncestorBox(
                    rabbit: sire,
                    isMale: true,
                    height: boxHeight,
                    onTap: () => onTapSlot(['sire'], 'Sire', RabbitType.buck, sire),
                  ),
                ),
              ),
              if (generations >= 3) ...[
                const SizedBox(width: colGap),
                // Grandparents Column: Sire's Sire & Sire's Dam
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      SizedBox(
                        height: pairHeight,
                        child: Center(
                          child: _buildAncestorBox(
                            rabbit: ss,
                            isMale: true,
                            height: boxHeight,
                            onTap: () => onTapSlot(['sire', 'sire'], "Sire's Sire", RabbitType.buck, ss),
                          ),
                        ),
                      ),
                      const SizedBox(height: gap),
                      SizedBox(
                        height: pairHeight,
                        child: Center(
                          child: _buildAncestorBox(
                            rabbit: sd,
                            isMale: false,
                            height: boxHeight,
                            onTap: () => onTapSlot(['sire', 'dam'], "Sire's Dam", RabbitType.doe, sd),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (generations >= 4) ...[
                const SizedBox(width: colGap),
                // Great GrandParents Column: Paternal 4
                Expanded(
                  flex: 11,
                  child: Column(
                    children: [
                      _buildAncestorBox(
                        rabbit: sss,
                        isMale: true,
                        height: boxHeight,
                        onTap: () => onTapSlot(['sire', 'sire', 'sire'], "Sire's Paternal G.Sire", RabbitType.buck, sss),
                      ),
                      const SizedBox(height: gap),
                      _buildAncestorBox(
                        rabbit: ssd,
                        isMale: false,
                        height: boxHeight,
                        onTap: () => onTapSlot(['sire', 'sire', 'dam'], "Sire's Paternal G.Dam", RabbitType.doe, ssd),
                      ),
                      const SizedBox(height: gap),
                      _buildAncestorBox(
                        rabbit: sds,
                        isMale: true,
                        height: boxHeight,
                        onTap: () => onTapSlot(['sire', 'dam', 'sire'], "Sire's Maternal G.Sire", RabbitType.buck, sds),
                      ),
                      const SizedBox(height: gap),
                      _buildAncestorBox(
                        rabbit: sdd,
                        isMale: false,
                        height: boxHeight,
                        onTap: () => onTapSlot(['sire', 'dam', 'dam'], "Sire's Maternal G.Dam", RabbitType.doe, sdd),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // BOTTOM HALF: Maternal (Dam) Branch
        SizedBox(
          height: halfHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Parents Column: Dam
              Expanded(
                flex: 10,
                child: Center(
                  child: _buildAncestorBox(
                    rabbit: dam,
                    isMale: false,
                    height: boxHeight,
                    onTap: () => onTapSlot(['dam'], 'Dam', RabbitType.doe, dam),
                  ),
                ),
              ),
              if (generations >= 3) ...[
                const SizedBox(width: colGap),
                // Grandparents Column: Dam's Sire & Dam's Dam
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      SizedBox(
                        height: pairHeight,
                        child: Center(
                          child: _buildAncestorBox(
                            rabbit: ds,
                            isMale: true,
                            height: boxHeight,
                            onTap: () => onTapSlot(['dam', 'sire'], "Dam's Sire", RabbitType.buck, ds),
                          ),
                        ),
                      ),
                      const SizedBox(height: gap),
                      SizedBox(
                        height: pairHeight,
                        child: Center(
                          child: _buildAncestorBox(
                            rabbit: dd,
                            isMale: false,
                            height: boxHeight,
                            onTap: () => onTapSlot(['dam', 'dam'], "Dam's Dam", RabbitType.doe, dd),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (generations >= 4) ...[
                const SizedBox(width: colGap),
                // Great GrandParents Column: Maternal 4
                Expanded(
                  flex: 11,
                  child: Column(
                    children: [
                      _buildAncestorBox(
                        rabbit: dss,
                        isMale: true,
                        height: boxHeight,
                        onTap: () => onTapSlot(['dam', 'sire', 'sire'], "Dam's Paternal G.Sire", RabbitType.buck, dss),
                      ),
                      const SizedBox(height: gap),
                      _buildAncestorBox(
                        rabbit: dsd,
                        isMale: false,
                        height: boxHeight,
                        onTap: () => onTapSlot(['dam', 'sire', 'dam'], "Dam's Paternal G.Dam", RabbitType.doe, dsd),
                      ),
                      const SizedBox(height: gap),
                      _buildAncestorBox(
                        rabbit: dds,
                        isMale: true,
                        height: boxHeight,
                        onTap: () => onTapSlot(['dam', 'dam', 'sire'], "Dam's Maternal G.Sire", RabbitType.buck, dds),
                      ),
                      const SizedBox(height: gap),
                      _buildAncestorBox(
                        rabbit: ddd,
                        isMale: false,
                        height: boxHeight,
                        onTap: () => onTapSlot(['dam', 'dam', 'dam'], "Dam's Maternal G.Dam", RabbitType.doe, ddd),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAncestorBox({
    required Rabbit? rabbit,
    required bool isMale,
    required double height,
    required VoidCallback onTap,
  }) {
    final bool recorded = isPedigreeAncestorRecorded(rabbit);
    final Color bgColor = isMale
        ? appSurface(0xFFEAF4FF, 0xFF202830)
        : appSurface(0xFFFFEEF6, 0xFF292029);
    final Color borderColor = isMale
        ? appSurface(0xFF7CBDF5, 0xFF334456)
        : appSurface(0xFFF49AC6, 0xFF4C3344);
    final Color accentColor = isMale
        ? appColor(0xFF3B96E8, 0xFF7CC4FA)
        : appColor(0xFFE85C9E, 0xFFF49AC6);

    String primaryLine = '-';
    String secondaryLine = '';

    if (recorded && rabbit != null) {
      final prefix = (rabbit.breederPrefix ?? '').trim();
      final name = rabbit.name.trim();
      final fullName = prefix.isNotEmpty && name.isNotEmpty
          ? '$prefix $name'
          : (name.isNotEmpty ? name : prefix);
      final ear = (rabbit.earNumber ?? '').trim();

      if (ear.isNotEmpty && fullName.isNotEmpty) {
        primaryLine = '$ear · $fullName';
      } else if (fullName.isNotEmpty) {
        primaryLine = fullName;
      } else if (ear.isNotEmpty) {
        primaryLine = ear;
      }

      if (rabbit.dateOfBirth != null) {
        secondaryLine = DateFormat('MMM d, yyyy').format(rabbit.dateOfBirth!);
      } else if ((rabbit.color ?? '').trim().isNotEmpty) {
        secondaryLine = rabbit.color!.trim();
      } else if (rabbit.breed.trim().isNotEmpty) {
        secondaryLine = rabbit.breed.trim();
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3.5,
              color: accentColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryLine,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: recorded
                            ? appColor(0xFF1F2937, 0xFFF1F5F9)
                            : (isMale
                                ? appColor(0xFF5A8BB8, 0xFF8CA8C4)
                                : appColor(0xFFB86B90, 0xFFC48AA8)),
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondaryLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondaryLine,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: appColor(0xFF55555C, 0xFF9EA6B8),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class PedigreeInlineCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onUpdated;
  const PedigreeInlineCard({super.key, required this.rabbit, this.onUpdated});

  @override
  State<PedigreeInlineCard> createState() => _PedigreeInlineCardState();
}

class _PedigreeInlineCardState extends State<PedigreeInlineCard> {
  final DatabaseService _db = DatabaseService();
  int selectedGenerations = 4;
  PedigreeOrientation _orientation = PedigreeOrientation.landscape;
  bool _isLoading = true;
  Rabbit? _sire; 
  Rabbit? _dam;
  Rabbit? _ss, _sd, _ds, _dd;
  Rabbit? _sss, _ssd, _sds, _sdd, _dss, _dsd, _dds, _ddd;

  @override
  void initState() {
    super.initState();
    _loadPedigree();
  }

  Future<void> _loadPedigree() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      final tree = await _db.buildPedigreeTree(widget.rabbit.id, maxGenerations: selectedGenerations, initialRabbit: widget.rabbit);
      
      Rabbit? sire, dam, ss, sd, ds, dd;
      Rabbit? sss, ssd, sds, sdd, dss, dsd, dds, ddd;

      if (tree.sire != null) sire = await _db.getRabbit(tree.sire!.id);
      if (tree.dam != null) dam = await _db.getRabbit(tree.dam!.id);
      
      // 3 generations loads grandparents (ss, sd, ds, dd)
      if (selectedGenerations >= 3) {
        if (tree.sire?.sire != null) ss = await _db.getRabbit(tree.sire!.sire!.id);
        if (tree.sire?.dam != null) sd = await _db.getRabbit(tree.sire!.dam!.id);
        if (tree.dam?.sire != null) ds = await _db.getRabbit(tree.dam!.sire!.id);
        if (tree.dam?.dam != null) dd = await _db.getRabbit(tree.dam!.dam!.id);
      }

      // 4 generations loads great grandparents
      if (selectedGenerations >= 4) {
        if (tree.sire?.sire?.sire != null) sss = await _db.getRabbit(tree.sire!.sire!.sire!.id);
        if (tree.sire?.sire?.dam != null) ssd = await _db.getRabbit(tree.sire!.sire!.dam!.id);
        if (tree.sire?.dam?.sire != null) sds = await _db.getRabbit(tree.sire!.dam!.sire!.id);
        if (tree.sire?.dam?.dam != null) sdd = await _db.getRabbit(tree.sire!.dam!.dam!.id);
        if (tree.dam?.sire?.sire != null) dss = await _db.getRabbit(tree.dam!.sire!.sire!.id);
        if (tree.dam?.sire?.dam != null) dsd = await _db.getRabbit(tree.dam!.sire!.dam!.id);
        if (tree.dam?.dam?.sire != null) dds = await _db.getRabbit(tree.dam!.dam!.sire!.id);
        if (tree.dam?.dam?.dam != null) ddd = await _db.getRabbit(tree.dam!.dam!.dam!.id);
      }
      
      if (mounted) {
        setState(() {
          _sire = sire; _dam = dam;
          _ss = ss; _sd = sd; _ds = ds; _dd = dd;
          _sss = sss; _ssd = ssd; _sds = sds; _sdd = sdd;
          _dss = dss; _dsd = dsd; _dds = dds; _ddd = ddd;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPedigree() async {
    try {
      final data = await PedigreeData.fromRabbit(
        widget.rabbit,
        db: _db,
        orientation: _orientation,
      );
      if (mounted) {
        PedigreePreviewSheet.show(
          context,
          data,
          onOrientationChanged: (opt) => setState(() => _orientation = opt),
        );
      }
    } catch (e) {
      debugPrint('Error preparing pedigree export: $e');
    }
  }

  Widget _buildOrientationToggle(String label, PedigreeOrientation opt) {
    final isSelected = _orientation == opt;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _orientation = opt),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? kAppCardWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? appColor(0xFF5C4A70) : appColor(0xFF6B7280),
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep));
    }

    return Container(
      decoration: BoxDecoration(
        color: kAppCardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  'PEDIGREE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: appColor(0xFF4F4F56),
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<int>(
                  offset: const Offset(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    setState(() {
                      selectedGenerations = val;
                      _loadPedigree();
                    });
                  },
                  itemBuilder: (context) => [2, 3, 4].map((g) => PopupMenuItem(
                    value: g,
                    child: Text('$g Generations', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  )).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kNeutral100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Text('$selectedGenerations Generations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: appColor(0xFF374151))),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: kNeutral500),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _exportPedigree,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(100)),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.downloadSimple(), size: 14, color: kNeutral600),
                        const SizedBox(width: 6),
                        Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: kNeutral100),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PedigreeThreeColumnTree(
                  generations: selectedGenerations,
                  sire: _sire,
                  dam: _dam,
                  ss: _ss,
                  sd: _sd,
                  ds: _ds,
                  dd: _dd,
                  sss: _sss,
                  ssd: _ssd,
                  sds: _sds,
                  sdd: _sdd,
                  dss: _dss,
                  dsd: _dsd,
                  dds: _dds,
                  ddd: _ddd,
                  onTapSlot: _editSlotOnPath,
                ),

                const SizedBox(height: 20),
                // 2 Options / Toggle Buttons: Landscape & Portrait
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: appSurface(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: appSurface(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildOrientationToggle('Landscape', PedigreeOrientation.landscape),
                      _buildOrientationToggle('Portrait', PedigreeOrientation.portrait),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Preview Pedigree Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _exportPedigree,
                    icon: Icon(
                      PhosphorIcons.treeStructure(PhosphorIconsStyle.duotone),
                      size: 18,
                      color: appColor(0xFF5C4A70),
                    ),
                    label: Text(
                      'Preview Pedigree',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: appColor(0xFF5C4A70),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appSurface(0xFFD4B3EE),
                      foregroundColor: appColor(0xFF5C4A70),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Future<void> _editSlotOnPath(
    List<String> path,
    String label,
    RabbitType gender,
    Rabbit? currentSlotRabbit,
  ) async {
    final Rabbit? existingRecorded =
        isPedigreeAncestorRecorded(currentSlotRabbit) ? currentSlotRabbit : null;
    final suggestedPrefix = existingRecorded == null
        ? await pedigreeSuggestedPrefix(_db, widget.rabbit, path)
        : null;
    _showParentPickerDialog(
      label,
      gender,
      (selectedRabbit) async {
        await savePedigreeSlotOnPath(
          db: _db,
          baseRabbit: widget.rabbit,
          path: path,
          selectedRabbit: selectedRabbit,
        );
        await _loadPedigree();
        if (widget.onUpdated != null) widget.onUpdated!();
      },
      currentRabbit: existingRecorded,
      suggestedPrefix: suggestedPrefix,
    );
  }

  Widget _buildSubjectCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kHeaderPink,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appSurface(0xFFF7B4DE), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUBJECT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: appColor(0xFF55555C),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                if ((widget.rabbit.breederPrefix ?? '').isNotEmpty)
                  TextSpan(
                    text: '${widget.rabbit.breederPrefix} ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: appColor(0xFF2C2C2E),
                    ),
                  ),
                TextSpan(
                  text: widget.rabbit.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: appColor(0xFF2C2C2E),
                  ),
                ),
              ],
            ),
          ),
          if (widget.rabbit.breed.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              widget.rabbit.breed,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: appColor(0xFF55555C),
              ),
            ),
          ],
          if ((widget.rabbit.earNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Ear #: ${widget.rabbit.earNumber}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: appColor(0xFF8E8E93),
              ),
            ),
          ] else if (widget.rabbit.id.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'ID: ${widget.rabbit.id}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: appColor(0xFF8E8E93),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParentCard({
    required String label,
    required Rabbit? rabbit,
    required bool isMale,
    required VoidCallback onTap,
  }) {
    final Gradient cardGradient = isMale
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [appSurface(0xFF86DAFF), appSurface(0xFFF0F9FF)],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [appSurface(0xFFFFBCE7), appSurface(0xFFFFF0F9)],
          );

    final bool hasDetails = rabbit != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMale ? appSurface(0xFFBFE0F7) : appSurface(0xFFF7B4DE),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: appColor(0xFF55555C),
                    letterSpacing: 1.4,
                  ),
                ),
                Icon(
                  hasDetails ? Icons.edit : Icons.add_circle_outline,
                  size: 14,
                  color: appColor(0xFF55555C).withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasDetails) ...[
              Text(
                isMale ? 'Add Sire' : 'Add Dam',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appColor(0xFF55555C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to select',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: appColor(0xFF8E8E93),
                ),
              ),
            ] else ...[
              RichText(
                text: TextSpan(
                  children: [
                    if ((rabbit.breederPrefix ?? '').isNotEmpty)
                      TextSpan(
                        text: '${rabbit.breederPrefix} ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: appColor(0xFF2C2C2E),
                        ),
                      ),
                    TextSpan(
                      text: rabbit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: appColor(0xFF2C2C2E),
                      ),
                    ),
                  ],
                ),
              ),
              if (rabbit.breed.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  rabbit.breed,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: appColor(0xFF55555C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if ((rabbit.earNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Ear #: ${rabbit.earNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: appColor(0xFF8E8E93),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (rabbit.id.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'ID: ${rabbit.id}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: appColor(0xFF8E8E93),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAncestorCol(Rabbit? parent, String label, Rabbit? sire, Rabbit? dam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubLabel(label),
        _buildBaseCard(
          name: sire?.name ?? 'Sire',
          id: sire?.id ?? '--',
          borderColor: kBlueDeep,
          isSmall: true,
          onTap: () => _updateGrandparent(parent, RabbitType.buck, label.contains('Sire') ? 'Sire\'s Paternal Sire' : 'Dam\'s Paternal Sire', sire),
        ),
        const SizedBox(height: 6),
        _buildBaseCard(
          name: dam?.name ?? 'Dam',
          id: dam?.id ?? '--',
          borderColor: kPinkDeep,
          isSmall: true,
          onTap: () => _updateGrandparent(parent, RabbitType.doe, label.contains('Sire') ? 'Sire\'s Paternal Dam' : 'Dam\'s Paternal Dam', dam),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: appColor(0xFF4F4F56), letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: appColor(0xFF55555C), letterSpacing: 0.3),
      ),
    );
  }

  Future<void> _updateParent(RabbitType gender, bool isPrimary) async {
    final label = gender == RabbitType.buck ? 'Sire' : 'Dam';
    Rabbit? current = gender == RabbitType.buck ? _sire : _dam;
    if (current == null) {
      final parentId = gender == RabbitType.buck ? widget.rabbit.sireId : widget.rabbit.damId;
      if (parentId != null && parentId.isNotEmpty) {
        current = await _db.getRabbit(parentId);
      }
    }
    _showParentPickerDialog(label, gender, (selectedRabbit) async {
      final updated = widget.rabbit;
      if (gender == RabbitType.buck) {
        updated.sireId = selectedRabbit?.id;
      } else {
        updated.damId = selectedRabbit?.id;
      }
      await _db.updateRabbit(updated);
      _loadPedigree();
      if (widget.onUpdated != null) widget.onUpdated!();
    }, currentRabbit: current);
  }

  Future<void> _updateGrandparent(Rabbit? parent, RabbitType gender, String label, [Rabbit? currentGrandparent]) async {
    if (parent == null) {
      _showError('Please add the ${label.contains("Sire's") ? "Sire" : "Dam"} first.');
      return;
    }

    Rabbit? existing = currentGrandparent;
    if (existing == null) {
      final id = gender == RabbitType.buck ? parent.sireId : parent.damId;
      if (id != null && id.isNotEmpty) {
        existing = await _db.getRabbit(id);
      }
    }

    _showParentPickerDialog(label, gender, (selectedRabbit) async {
      final updatedParent = parent;
      if (gender == RabbitType.buck) {
        updatedParent.sireId = selectedRabbit?.id;
      } else {
        updatedParent.damId = selectedRabbit?.id;
      }
      await _db.updateRabbit(updatedParent);
      _loadPedigree();
    }, currentRabbit: existing);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kPinkDeep),
    );
  }

  void _showParentPickerDialog(String label, RabbitType type, Function(Rabbit?) onSelect, {Rabbit? currentRabbit, String? suggestedPrefix}) async {
    final options = await _db.getRabbitsByType(type);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PedigreeEntryModal(
        label: label,
        type: type,
        options: options,
        onSelect: onSelect,
        db: _db,
        breed: widget.rabbit.breed,
        currentRabbit: currentRabbit,
        suggestedPrefix: suggestedPrefix,
      ),
    );
  }

  Widget _buildBaseCard({
    required String name,
    required String id,
    String? breed,
    Color? color,
    required Color borderColor,
    bool isFullBorder = false,
    bool isSmall = false,
    VoidCallback? onTap,
    bool showEditIcon = true,
  }) {
    final isPlaceholder = name.contains('Sire') || name.contains('Dam') || id.contains('Add');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmall ? 10 : 12),
        decoration: BoxDecoration(
          color: color ?? (isPlaceholder ? kNeutral50.withValues(alpha: 0.5) : appSurface(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(12),
          border: isFullBorder
              ? Border.all(color: borderColor, width: 1.5)
              : Border(left: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
             if (!isPlaceholder) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
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
                    fontSize: isSmall ? 12 : 14,
                    fontWeight: FontWeight.w800,
                    color: isPlaceholder ? appColor(0xFF787880) : appColor(0xFF2C2C2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isPlaceholder && showEditIcon) Icon(Icons.edit, size: 10, color: appColor(0xFF787880).withValues(alpha: 0.6)),
            ],
          ),
          Text(
            id,
            style: TextStyle(
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: isPlaceholder ? appColor(0xFFAEAEB2) : appColor(0xFF55555C),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (breed != null && !isSmall) ...[
            const SizedBox(height: 2),
            Text(
              breed,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: appColor(0xFF55555C)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          ],
        ),
      ),
    );
  }
}

/// Finds the prefix to pre-fill for a new ancestor at [path]: the prefix of its
/// nearest ancestor on that path (e.g. "Sire's Sire" -> the Sire's prefix).
/// Returns null for direct parents (path length 1) or when none is found.
Future<String?> pedigreeSuggestedPrefix(
  DatabaseService db,
  Rabbit base,
  List<String> path,
) async {
  String? found;
  Rabbit? cur = base;
  for (final step in path.take(path.length - 1)) {
    final id = step == 'sire' ? cur?.sireId : cur?.damId;
    if (id == null || id.isEmpty) break;
    cur = await db.getRabbit(id);
    if (cur == null) break;
    final p = (cur.breederPrefix ?? '').trim();
    if (p.isNotEmpty) found = p;
  }
  return found?.toUpperCase();
}

class PedigreeEntryModal extends StatefulWidget {
  final String? suggestedPrefix;
  final String label;
  final RabbitType type;
  final List<Rabbit> options;
  final Function(Rabbit?) onSelect;
  final DatabaseService db;
  final String? breed;
  final Rabbit? currentRabbit;

  const PedigreeEntryModal({
    super.key,
    required this.label,
    required this.type,
    required this.options,
    required this.onSelect,
    required this.db,
    this.breed,
    this.currentRabbit,
    this.suggestedPrefix,
  });

  @override
  State<PedigreeEntryModal> createState() => _PedigreeEntryModalState();
}

class _PedigreeEntryModalState extends State<PedigreeEntryModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Search Controller for Herd Tab
  final _herdSearchController = TextEditingController();
  String _herdSearchQuery = '';

  // Manual Entry Controllers
  final _prefixController = TextEditingController();
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _lbsController = TextEditingController();
  final _ozController = TextEditingController();
  final _idController = TextEditingController();
  final _regController = TextEditingController();
  final _gcController = TextEditingController();
  final _legsController = TextEditingController();
  final _winningsController = TextEditingController();
  final _breedController = TextEditingController();
  final _champController = TextEditingController();
  final _genotypeController = TextEditingController();
  
  DateTime? _dateOfBirth;
  DateTime? _acquiredDate;
  bool _isBroken = false;

  // Auto-filled prefix shown in light grey until accepted or replaced.
  final _nameFocus = FocusNode();
  bool _prefixIsSuggestion = false;

  void _onNameFocus() {
    if (_nameFocus.hasFocus && _prefixIsSuggestion) {
      setState(() => _prefixIsSuggestion = false); // accepted
    }
  }

  void _onPrefixTap() {
    if (_prefixIsSuggestion) {
      setState(() {
        _prefixIsSuggestion = false;
        _prefixController.clear(); // wrong prefix: start fresh
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onNameFocus);
    final bool hasExisting = widget.currentRabbit != null;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: hasExisting ? 1 : 0,
    );

    if (hasExisting) {
      final r = widget.currentRabbit!;
      _prefixController.text = (r.breederPrefix ?? '').toUpperCase();
      _nameController.text = r.name;
      _breedController.text = r.breed;
      _colorController.text = r.color ?? '';
      if (r.weight != null && r.weight! > 0) {
        final totalOz = (r.weight! * 16.0).round();
        final lbs = totalOz ~/ 16;
        final oz = totalOz % 16;
        if (lbs > 0) _lbsController.text = lbs.toString();
        if (oz > 0) _ozController.text = oz.toString();
      }
      _idController.text = (r.earNumber ?? '').isNotEmpty ? r.earNumber! : (r.id.startsWith('PED-') ? '' : r.id);
      _dateOfBirth = r.dateOfBirth;
      _acquiredDate = r.acquiredDate;
      if ((r.grandChampionLegs ?? 0) > 0) {
        _legsController.text = r.grandChampionLegs.toString();
      }
      _regController.text = r.registrationNumber ?? '';
      _gcController.text = r.grandChampionNumber ?? '';
      _winningsController.text = r.winnings ?? '';
      _genotypeController.text = r.genetics ?? '';
      _isBroken = r.broken ?? false;
    } else {
      if ((widget.breed ?? '').isNotEmpty) {
        _breedController.text = widget.breed!;
      }
      if ((widget.suggestedPrefix ?? '').isNotEmpty) {
        _prefixController.text = widget.suggestedPrefix!;
        _prefixIsSuggestion = true;
      }
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _tabController.dispose();
    _herdSearchController.dispose();
    _prefixController.dispose();
    _nameController.dispose();
    _colorController.dispose();
    _lbsController.dispose();
    _ozController.dispose();
    _idController.dispose();
    _regController.dispose();
    _gcController.dispose();
    _legsController.dispose();
    _winningsController.dispose();
    _breedController.dispose();
    _champController.dispose();
    _genotypeController.dispose();
    super.dispose();
  }

  List<Rabbit> get _filteredHerdOptions {
    if (_herdSearchQuery.trim().isEmpty) return widget.options;
    final q = _herdSearchQuery.trim().toLowerCase();
    return widget.options.where((r) {
      final name = r.name.toLowerCase();
      final prefix = (r.breederPrefix ?? '').toLowerCase();
      final ear = (r.earNumber ?? '').toLowerCase();
      final breed = r.breed.toLowerCase();
      final color = (r.color ?? '').toLowerCase();
      final cage = (r.cage ?? '').toLowerCase();
      return name.contains(q) ||
          prefix.contains(q) ||
          ear.contains(q) ||
          breed.contains(q) ||
          color.contains(q) ||
          cage.contains(q);
    }).toList();
  }

  Widget _buildRabbitNameWidget(Rabbit rabbit, {double fontSize = 15}) {
    final isDoe = rabbit.type == RabbitType.doe || widget.type == RabbitType.doe;
    final nameColor = isDoe ? appColor(0xFFE04F9F) : appColor(0xFF2196F3);
    final prefix = (rabbit.breederPrefix ?? '').trim();
    final name = rabbit.name.trim();
    final ear = (rabbit.earNumber?.trim().isNotEmpty == true
            ? rabbit.earNumber!.trim()
            : '')
        .toUpperCase();

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: '$prefix ',
              style: TextStyle(
                color: appColor(0xFF787774),
                fontWeight: FontWeight.w700,
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              color: nameColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ear.isNotEmpty && !name.toUpperCase().endsWith(ear))
            TextSpan(
              text: ' $ear',
              style: TextStyle(
                color: appColor(0xFF787774),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      style: TextStyle(fontSize: fontSize),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: appSurface(0xFFF9F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Purple Top Banner matching Log Birth Modal
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            decoration: BoxDecoration(
              color: appSurface(0xFFE6BEFE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: appSurface(0xFF4A3E6D).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.currentRabbit != null ? 'Edit ${widget.label}' : 'Set ${widget.label}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: appColor(0xFF4A3E6D),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kAppCardWhite.withValues(alpha: 0.6),
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

          TabBar(
            controller: _tabController,
            indicatorColor: appColor(0xFF6B2D6D),
            labelColor: appColor(0xFF6B2D6D),
            unselectedLabelColor: appColor(0xFF787880),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'SELECT FROM HERD'),
              Tab(text: 'MANUAL ENTRY'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHerdTab(),
                _buildManualTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHerdTab() {
    final filtered = _filteredHerdOptions;

    return Column(
      children: [
        if (widget.options.length > 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _herdSearchController,
              onChanged: (val) => setState(() => _herdSearchQuery = val),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search by name, prefix, ear #, breed...',
                hintStyle: TextStyle(color: appColor(0xFF9E9EA7), fontSize: 13.5),
                prefixIcon: Icon(Icons.search_rounded, color: appColor(0xFF7B6BA0), size: 20),
                suffixIcon: _herdSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: appColor(0xFF7B6BA0)),
                        onPressed: () {
                          _herdSearchController.clear();
                          setState(() => _herdSearchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: appSurface(0xFFF7F2FD),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: appSurface(0xFFEDE5FA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: appSurface(0xFF7B6BA0), width: 1.5),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            itemCount: filtered.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(null);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: appSurface(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: appSurface(0xFFE5E5EA)),
                    ),
                    child: Text(
                      'Leave Blank',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: appColor(0xFF636366),
                      ),
                    ),
                  ),
                );
              }

              final rabbit = filtered[index - 1];
              final details = <String>[];
              if (rabbit.breed.isNotEmpty) details.add(rabbit.breed);
              if ((rabbit.color ?? '').isNotEmpty) details.add(rabbit.color!);
              if ((rabbit.cage ?? '').isNotEmpty) details.add('Cage: ${rabbit.cage}');

              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelect(rabbit);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kAppCardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: appSurface(0xFFE5DEEC)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRabbitNameWidget(rabbit, fontSize: 15),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                details.join(' • '),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: appColor(0xFF787774),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: appColor(0xFF94A3B8)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kAppCardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: appSurface(0xFFE5DEEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prefix (uppercase) & Name (title case)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildOutlinedField(
                        'Prefix',
                        _prefixController,
                        isUpperCase: true,
                        onTap: _onPrefixTap,
                        textColor: _prefixIsSuggestion ? appColor(0xFFB5B5BC) : null,
                        onChanged: (_) {
                          if (_prefixIsSuggestion) setState(() => _prefixIsSuggestion = false);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: _buildOutlinedField('Name', _nameController, focusNode: _nameFocus),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Breed
                _buildOutlinedField('Breed', _breedController),
                const SizedBox(height: 14),

                // Color
                _buildOutlinedField('Color', _colorController),
                const SizedBox(height: 14),

                // Weight (divided into 2 boxes: Pounds & Ounces with unit suffix on the right)
                Row(
                  children: [
                    Expanded(
                      child: _buildOutlinedField(
                        'Pounds',
                        _lbsController,
                        suffixText: 'lbs',
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOutlinedField(
                        'Ounces',
                        _ozController,
                        suffixText: 'oz',
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Ear # | Date of Birth
                Row(
                  children: [
                    Expanded(child: _buildOutlinedField('Ear #', _idController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDatePicker('Date of Birth', _dateOfBirth, (d) => setState(() => _dateOfBirth = d))),
                  ],
                ),
                const SizedBox(height: 14),

                // Legs | Reg #
                Row(
                  children: [
                    Expanded(child: _buildOutlinedField('Legs', _legsController, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOutlinedField('Reg #', _regController)),
                  ],
                ),
                const SizedBox(height: 14),

                // GC # (own line)
                _buildOutlinedField('GC #', _gcController),
                const SizedBox(height: 14),

                // Winnings (multi-line; Enter moves to the next line)
                _buildOutlinedField(
                  'Winnings',
                  _winningsController,
                  isMultiline: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSelect(null);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: appColor(0xFF636366),
                    side: BorderSide(color: appSurface(0xFFDCDCE0)),
                    backgroundColor: kAppCardWhite,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Leave Blank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: appColor(0xFF636366))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saveManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLilacLight,
                    foregroundColor: kLilacText,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.currentRabbit != null ? 'Update Ancestor' : 'Save Ancestor',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kLilacText),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _saveManual() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the ancestor'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    
    final earNo = _idController.text.trim();
    final lbs = double.tryParse(_lbsController.text.trim()) ?? 0.0;
    final oz = double.tryParse(_ozController.text.trim()) ?? 0.0;
    final double? weight = (lbs > 0 || oz > 0) ? (lbs + (oz / 16.0)) : null;

    final existing = widget.currentRabbit;
    final id = existing?.id ?? 'PED-${DateTime.now().millisecondsSinceEpoch}';

    final rabbitToSave = Rabbit(
      id: id,
      name: _nameController.text.trim(),
      type: existing?.type ?? RabbitType.pedigree,
      status: existing?.status ?? RabbitStatus.archived,
      breed: _breedController.text.isNotEmpty ? _breedController.text.trim() : (existing?.breed ?? 'Dwarf Hotot'),
      color: _colorController.text.isNotEmpty ? _colorController.text.trim() : null,
      weight: weight,
      dateOfBirth: _dateOfBirth,
      acquiredDate: _acquiredDate,
      earNumber: earNo.isNotEmpty ? earNo : null,
      registrationNumber: _regController.text.isNotEmpty ? _regController.text.trim() : null,
      grandChampionNumber: _gcController.text.isNotEmpty ? _gcController.text.trim() : null,
      grandChampionLegs: int.tryParse(_legsController.text) ?? 0,
      winnings: _winningsController.text.trim().isNotEmpty ? _winningsController.text.trim() : null,
      genetics: _genotypeController.text.isNotEmpty ? _genotypeController.text.trim() : null,
      broken: _isBroken,
      sireId: existing?.sireId,
      damId: existing?.damId,
      breederPrefix: _prefixController.text.trim().isNotEmpty ? _prefixController.text.trim().toUpperCase() : null,
      cage: existing?.cage,
      notes: existing?.notes,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await widget.db.updateRabbit(rabbitToSave);
    } else {
      await widget.db.insertRabbit(rabbitToSave);
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onSelect(rabbitToSave);
    }
  }

  Widget _buildOutlinedField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isMultiline = false,
    bool isUpperCase = false,
    String? hintText,
    String? suffixText,
    FocusNode? focusNode,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    Color? textColor,
  }) {
    final List<TextInputFormatter>? formatters = isNumber
        ? null
        : [
            isUpperCase ? _UpperCaseTextFormatter() : _WordTitleCaseFormatter(),
          ];
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: isMultiline
          ? TextInputType.multiline
          : (isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
      textCapitalization: isNumber
          ? TextCapitalization.none
          : (isUpperCase ? TextCapitalization.characters : TextCapitalization.words),
      inputFormatters: formatters,
      textInputAction: isMultiline ? TextInputAction.newline : null,
      minLines: isMultiline ? 2 : 1,
      maxLines: isMultiline ? 6 : 1,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor ?? appColor(0xFF4F4F56)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: appColor(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 13),
        floatingLabelStyle: TextStyle(color: appColor(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hintText,
        suffixText: suffixText,
        suffixStyle: TextStyle(color: appColor(0xFF8E8E93), fontWeight: FontWeight.w500, fontSize: 13),
        hintStyle: TextStyle(color: appColor(0xFF8E8E93), fontWeight: FontWeight.w500, fontSize: 13),
        filled: true,
        fillColor: kAppCardWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSurface(0xFFE5DEEC))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSurface(0xFF7B6BA0), width: 1.5)),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) onSelect(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: appColor(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 13),
          floatingLabelStyle: TextStyle(color: appColor(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: kAppCardWhite,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSurface(0xFFE5DEEC))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: appSurface(0xFF7B6BA0), width: 1.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: appColor(0xFF4F4F56)),
            const SizedBox(width: 8),
            Text(
              value != null ? FormatUtils.formatDate(value) : '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appColor(0xFF4F4F56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _WordTitleCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final buf = StringBuffer();
    bool capNext = true;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (capNext && RegExp(r'[a-zA-Z]').hasMatch(ch)) {
        buf.write(ch.toUpperCase());
        capNext = false;
      } else {
        buf.write(ch);
        capNext = ch == ' ' || ch == '\n' || ch == '\t' || ch == '-' || ch == '/';
      }
    }
    return newValue.copyWith(text: buf.toString());
  }
}