import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../services/database_service.dart';

class LitterHistoryCard extends StatefulWidget {
  final Rabbit rabbit;

  const LitterHistoryCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<LitterHistoryCard> createState() => _LitterHistoryCardState();
}

class _LitterHistoryCardState extends State<LitterHistoryCard> {
  final DatabaseService _db = DatabaseService();
  List<Litter> _litters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLitterHistory();
  }

  Future<void> _loadLitterHistory() async {
    try {
      // Get litters where this rabbit is the dam (mother) or sire (father)
      final littersData = await _db.getLittersByDoe(widget.rabbit.id);

      // Also check if rabbit is a sire (for bucks)
      final db = await _db.database;
      final sireLitters = await db.query(
        'litters',
        where: 'buckId = ?',
        whereArgs: [
          widget.rabbit.id
        ],
        orderBy: 'breedDate DESC',
      );

      // Combine and convert to Litter objects
      final allLittersData = [
        ...littersData,
        ...sireLitters
      ];

      // Remove duplicates by id
      final seenIds = <String>{};
      final uniqueLitters = allLittersData.where((l) {
        final id = l['id'] as String?;
        if (id == null || seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();

      final litters = uniqueLitters.map((data) => Litter.fromMap(data)).toList();

      // Sort by kindle date (most recent first)
      litters.sort((a, b) => (b.kindleDate ?? b.breedDate).compareTo(a.kindleDate ?? a.breedDate));

      if (mounted) {
        setState(() {
          _litters = litters;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading litter history: $e');
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
                  'LITTER HISTORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to add litter screen
                  },
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF787774)),
                      SizedBox(width: 4),
                      Text(
                        'Add',
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
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF0F7B6C)),
              ),
            )
          else if (_litters.isEmpty)
            Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.child_care_outlined,
                    size: 48,
                    color: Color(0xFFE9E9E7),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No litter history',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9B9A97),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.rabbit.type == RabbitType.doe ? 'Litters will appear here after kindling' : 'Litters sired will appear here',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B9A97),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._litters
                .map((litter) => _buildLitterItem(
                      context,
                      litter,
                    ))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildLitterItem(BuildContext context, Litter litter) {
    // Determine partner based on rabbit's role
    String partner;
    if (widget.rabbit.id == litter.doeId) {
      // This rabbit is the dam, show sire as partner
      partner = '${litter.buckName} (${litter.buckId})';
    } else {
      // This rabbit is the sire, show dam as partner
      partner = '${litter.doeName} (${litter.doeId})';
    }

    // Format date
    final dateStr = _formatDate(litter.kindleDate ?? litter.breedDate);

    // Calculate kit count
    final kitsCount = litter.aliveKits ?? litter.kits.where((k) => !k.isArchived).length;
    final kitsStr = '$kitsCount kits';

    // Get status color
    final statusColor = _getStatusColor(litter.status);

    return InkWell(
      onTap: () => _showLitterDetails(context, litter),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        litter.id,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          litter.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'with $partner',
                    style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  kitsStr,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Color(0xFF9B9A97),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'nursing':
        return Color(0xFF5B8AD0);
      case 'weaned':
        return Color(0xFF6B9E78);
      case 'sold':
        return Color(0xFF9B9A97);
      case 'mature':
        return Color(0xFF9B9A97);
      case 'pending':
        return Color(0xFFE5A000);
      case 'pregnant':
        return Color(0xFF9C6ADE);
      default:
        return Color(0xFF787774);
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showLitterDetails(BuildContext context, Litter litter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
                          litter.id,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Litter Details',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF787774),
                          ),
                        ),
                      ],
                    ),
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
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Kindle Date', litter.kindleDate != null ? _formatDate(litter.kindleDate!) : 'Not kindled'),
                    _buildDetailRow('Breed Date', _formatDate(litter.breedDate)),
                    _buildDetailRow('Sire', '${litter.buckName} (${litter.buckId})'),
                    _buildDetailRow('Dam', '${litter.doeName} (${litter.doeId})'),
                    _buildDetailRow('Breed', litter.breed),
                    _buildDetailRow('Born Alive', '${litter.aliveKits ?? litter.kits.length} kits'),
                    _buildDetailRow('Still Born', '${litter.deadKits ?? 0} kits'),
                    _buildDetailRow('Current Count', '${litter.totalKitsCount} kits'),
                    _buildDetailRow('Location', '${litter.location} • ${litter.cage}'),
                    if (litter.weanDate != null) _buildDetailRow('Weaning Date', _formatDate(litter.weanDate!)),
                    _buildDetailRow('Status', litter.status),
                    if (litter.notes != null && litter.notes!.isNotEmpty) _buildDetailRow('Notes', litter.notes!),
                    SizedBox(height: 20),
                    if (litter.kits.isNotEmpty) ...[
                      Text(
                        'Kit Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...litter.kits.map((kit) => _buildKitCard(kit)).toList(),
                    ] else
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No kit details available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9B9A97),
                            ),
                          ),
                        ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF37352F),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitCard(Kit kit) {
    final sexDisplay = kit.sex == 'M' ? 'Male' : (kit.sex == 'F' ? 'Female' : 'Unknown');
    final statusColor = kit.isArchived ? Color(0xFF9B9A97) : Color(0xFF6B9E78);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              kit.sex == 'M' ? Icons.male : Icons.female,
              size: 18,
              color: kit.sex == 'M' ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kit.id,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                Text(
                  '$sexDisplay • ${kit.color} • ${kit.weight}g',
                  style: TextStyle(fontSize: 11, color: Color(0xFF787774)),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              kit.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
