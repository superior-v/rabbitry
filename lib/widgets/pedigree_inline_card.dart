import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';

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

  Future<void> _loadPedigree() async {
    try {
      final tree = await _db.buildPedigreeTree(widget.rabbit.id, maxGenerations: 2);
      final sire = tree.sire != null ? await _db.getRabbit(tree.sire!.id) : null;
      final dam = tree.dam != null ? await _db.getRabbit(tree.dam!.id) : null;
      
      Rabbit? ss, sd, ds, dd;
      if (tree.sire != null) {
        ss = tree.sire!.sire != null ? await _db.getRabbit(tree.sire!.sire!.id) : null;
        sd = tree.sire!.dam != null ? await _db.getRabbit(tree.sire!.dam!.id) : null;
      }
      if (tree.dam != null) {
        ds = tree.dam!.sire != null ? await _db.getRabbit(tree.dam!.sire!.id) : null;
        dd = tree.dam!.dam != null ? await _db.getRabbit(tree.dam!.dam!.id) : null;
      }
      
      if (mounted) {
        setState(() {
          _sire = sire; _dam = dam;
          _siresSire = ss; _siresDam = sd;
          _damsSire = ds; _damsDam = dd;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color get _primaryColor => widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;
  Color get _washColor => widget.rabbit.type == RabbitType.buck ? kBlueWash : kPinkWash;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.treeStructure(PhosphorIconsStyle.bold), size: 16, color: kNeutral500),
                    const SizedBox(width: 8),
                    const Text(
                      'PEDIGREE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('3', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1F2937), height: 1)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('generations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Generations Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: kNeutral100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          Text('$selectedGenerations Generations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: kNeutral500),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(100)),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.downloadSimple(), size: 14, color: kNeutral600),
                          const SizedBox(width: 6),
                          const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: kNeutral100),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('SUBJECT'),
                _buildBaseCard(
                  name: widget.rabbit.name,
                  id: widget.rabbit.id,
                  breed: widget.rabbit.breed ?? '--',
                  color: _washColor,
                  borderColor: _primaryColor.withOpacity(0.5),
                  isFullBorder: true,
                ),

                const SizedBox(height: 24),
                _buildLabel('PARENTS'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildBaseCard(
                        name: _sire?.name ?? 'Sire',
                        id: _sire?.id ?? 'Add Buck',
                        breed: _sire?.breed ?? '--',
                        borderColor: kBlueDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBaseCard(
                        name: _dam?.name ?? 'Dam',
                        id: _dam?.id ?? 'Add Doe',
                        breed: _dam?.breed ?? '--',
                        borderColor: kPinkDeep,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildLabel('GRANDPARENTS'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sire's Parents
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubLabel('${_sire?.name ?? "Sire"}\'s parents'),
                          _buildBaseCard(
                            name: _siresSire?.name ?? 'Sire\'s Sire',
                            id: _siresSire?.id ?? '--',
                            borderColor: kBlueDeep,
                            isSmall: true,
                          ),
                          const SizedBox(height: 8),
                          _buildBaseCard(
                            name: _siresDam?.name ?? 'Sire\'s Dam',
                            id: _siresDam?.id ?? '--',
                            borderColor: kPinkDeep,
                            isSmall: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dam's Parents
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubLabel('${_dam?.name ?? "Dam"}\'s parents'),
                          _buildBaseCard(
                            name: _damsSire?.name ?? 'Dam\'s Sire',
                            id: _damsSire?.id ?? '--',
                            borderColor: kBlueDeep,
                            isSmall: true,
                          ),
                          const SizedBox(height: 8),
                          _buildBaseCard(
                            name: _damsDam?.name ?? 'Dam\'s Dam',
                            id: _damsDam?.id ?? '--',
                            borderColor: kPinkDeep,
                            isSmall: true,
                          ),
                        ],
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kNeutral400, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: kNeutral400, letterSpacing: 0.3),
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
  }) {
    final isPlaceholder = name.contains('Sire') || name.contains('Dam') || id.contains('Add');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 10 : 12),
      decoration: BoxDecoration(
        color: color ?? (isPlaceholder ? kNeutral50.withOpacity(0.5) : const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(12),
        border: isFullBorder
            ? Border.all(color: borderColor, width: 1.5)
            : Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: isSmall ? 12 : 14,
              fontWeight: FontWeight.w800,
              color: isPlaceholder ? kNeutral400 : const Color(0xFF1F2937),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            id,
            style: TextStyle(
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: isPlaceholder ? kNeutral300 : kNeutral400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (breed != null && !isSmall) ...[
            const SizedBox(height: 2),
            Text(
              breed,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kNeutral400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
