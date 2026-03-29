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
      final sireLitters = await db.query('litters', where: 'buckId = ?', whereArgs: [widget.rabbit.id], orderBy: 'breedDate DESC');
      final allData = [...littersData, ...sireLitters];
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
        _filteredLitters = _litters.where((l) => 
          l.id.toLowerCase().contains(query.toLowerCase()) ||
          (l.doeName ?? '').toLowerCase().contains(query.toLowerCase()) ||
          (l.buckName ?? '').toLowerCase().contains(query.toLowerCase())
        ).toList();
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
        _buildSectionHeader('LITTER HISTORY'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kNeutral200),
          ),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(color: kNeutral100.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                  child: TextField(
                    onChanged: _filterLitters,
                    decoration: InputDecoration(
                      hintText: 'Search litters...',
                      hintStyle: TextStyle(fontSize: 13, color: kNeutral400, fontWeight: FontWeight.w500),
                      prefixIcon: Icon(Icons.search, size: 18, color: kNeutral400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              if (_filteredLitters.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No litters found', style: TextStyle(color: kNeutral400)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredLitters.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: kNeutral100),
                  itemBuilder: (context, index) => _buildLitterTile(_filteredLitters[index]),
                ),
              
              const SizedBox(height: 8),
              // Footer Summary
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: kNeutral100.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      '$totalLitters litters • $totalKits kits lifetime • $survival',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral500, letterSpacing: 0.2),
                    ),
                  ),
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
    final dateStr = DateFormat('MMM d \'yy').format(litter.kindleDate ?? litter.breedDate);
    
    String ageStr = 'Unknown';
    if (litter.kindleDate != null) {
      final ageDays = DateTime.now().difference(litter.kindleDate!).inDays;
      if (ageDays < 7) ageStr = '$ageDays days';
      else ageStr = '${(ageDays / 7).floor()} weeks';
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: _primaryColor,
        collapsedIconColor: kNeutral300,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(litter.id, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
            Text(dateStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kNeutral400)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('with $partner (${(partnerId.length > 4 ? partnerId.substring(0, 4) : partnerId).toUpperCase()})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500)),
            const SizedBox(height: 6),
            Text('${litter.totalKits} born • ${litter.aliveKits} alive • ${litter.status == 'Weaned' ? 'Weaned' : ageStr}', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral500)),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: kNeutral100.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KITS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral400, letterSpacing: 0.6)),
                const SizedBox(height: 12),
                if (litter.kits.isEmpty)
                  Text('No kits recorded', style: TextStyle(color: kNeutral400, fontSize: 13))
                else
                  ...litter.kits.map((k) => _buildKitRow(k)),
                
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildActionButton('View Litter', PhosphorIconsFill.arrowSquareOut, onTap: () {
                      HomeDashboardScreen.switchToTab(2);
                    }),
                    const SizedBox(width: 8),
                    _buildActionButton('Weights', PhosphorIconsFill.scales, onTap: () {
                      HomeDashboardScreen.switchToTab(2);
                    }),
                    const SizedBox(width: 8),
                    _buildActionButton('Wean', PhosphorIconsFill.circlesThreePlus, onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => WeanLitterModal(doe: widget.rabbit, onComplete: () => _loadLitterHistory()),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitRow(Kit kit) {
    final bool isDied = ['Dead', 'Cull'].contains(kit.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(
              kit.sex == 'Male' ? PhosphorIconsFill.genderMale : (kit.sex == 'Female' ? PhosphorIconsFill.genderFemale : PhosphorIconsFill.question),
              size: 14, 
              color: kNeutral300
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '#${kit.id.isEmpty ? '?' : kit.id.substring(kit.id.length - 1)} ${kit.color ?? 'Unknown'} • ${kit.weight ?? 0} lbs',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
            ),
            Text(
              isDied ? 'Died day 2' : 'Alive', 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDied ? Colors.redAccent : const Color(0xFF22C55E).withOpacity(0.6))
            ),
            const SizedBox(width: 8),
            Icon(Icons.more_vert, size: 16, color: kNeutral300),
          ],
        ),
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
      child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.6)),
    );
  }
}
