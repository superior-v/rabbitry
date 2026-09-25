import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../constants/app_colors.dart';

/// Shows a bottom sheet modal to select a Rabbit (Doe or Buck)
/// with a title and an 'X' close button in the top right to dismiss without selecting.
Future<Rabbit?> showRabbitPickerBottomSheet({
  required BuildContext context,
  required String title,
  required List<Rabbit> rabbits,
  Rabbit? selectedRabbit,
  String? selectedRabbitId,
}) {
  return showModalBottomSheet<Rabbit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RabbitPickerModal(
      title: title,
      rabbits: rabbits,
      selectedRabbitId: selectedRabbitId ?? selectedRabbit?.id,
    ),
  );
}

class RabbitPickerModal extends StatefulWidget {
  final String title;
  final List<Rabbit> rabbits;
  final String? selectedRabbitId;

  const RabbitPickerModal({
    Key? key,
    required this.title,
    required this.rabbits,
    this.selectedRabbitId,
  }) : super(key: key);

  @override
  State<RabbitPickerModal> createState() => _RabbitPickerModalState();
}

class _RabbitPickerModalState extends State<RabbitPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Rabbit> get _filteredRabbits {
    List<Rabbit> list = widget.rabbits;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = widget.rabbits.where((r) {
        final name = r.name.toLowerCase();
        final prefix = (r.breederPrefix ?? '').toLowerCase();
        final ear = (r.earNumber ?? '').toLowerCase();
        final id = r.id.toLowerCase();
        final breed = r.breed.toLowerCase();
        final color = (r.color ?? '').toLowerCase();
        final cage = (r.cage ?? '').toLowerCase();
        final location = (r.location ?? '').toLowerCase();
        return name.contains(q) ||
            prefix.contains(q) ||
            ear.contains(q) ||
            id.contains(q) ||
            breed.contains(q) ||
            color.contains(q) ||
            cage.contains(q) ||
            location.contains(q);
      }).toList();
    } else {
      list = List<Rabbit>.from(widget.rabbits);
    }
    list.sort((a, b) {
      final breedCompare = a.breed.toLowerCase().compareTo(b.breed.toLowerCase());
      if (breedCompare != 0) return breedCompare;
      final nameA = '${a.breederPrefix ?? ''} ${a.name}'.trim().toLowerCase();
      final nameB = '${b.breederPrefix ?? ''} ${b.name}'.trim().toLowerCase();
      return nameA.compareTo(nameB);
    });
    return list;
  }

  Widget _buildRabbitNameWidget(Rabbit rabbit, {double fontSize = 15}) {
    final isDoe = rabbit.type == RabbitType.doe;
    final nameColor = isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3);
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
              style: const TextStyle(
                color: Color(0xFF787774),
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
              style: const TextStyle(
                color: Color(0xFF787774),
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
    final isDoeList = widget.rabbits.isNotEmpty && widget.rabbits.first.type == RabbitType.doe;
    final filtered = _filteredRabbits;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header matching app lilac theme with 'X' button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE6BEFE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3E6D).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A3E6D),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF4A3E6D),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          if (widget.rabbits.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search by name, prefix, ear #, breed...',
                  hintStyle: const TextStyle(color: kNeutral400, fontSize: 13.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7B6BA0), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF7B6BA0)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: kLilacWash,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kLilacLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                  ),
                ),
              ),
            ),

          // List of rabbits
          Expanded(
            child: widget.rabbits.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDoeList ? Icons.female_rounded : Icons.male_rounded,
                            size: 48,
                            color: kNeutral400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No ${isDoeList ? "does" : "bucks"} available',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3A3A3C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No matches found for "$_searchQuery"',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF787774),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final rabbit = filtered[index];
                          final isSelected = rabbit.id == widget.selectedRabbitId;
                          final details = <String>[];
                          if (rabbit.breed.isNotEmpty) details.add(rabbit.breed);
                          if ((rabbit.color ?? '').isNotEmpty) details.add(rabbit.color!);
                          if ((rabbit.cage ?? '').isNotEmpty) details.add('Cage: ${rabbit.cage}');

                          return InkWell(
                            onTap: () => Navigator.pop(context, rabbit),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFFE5E5EA),
                                  width: isSelected ? 1.5 : 1,
                                ),
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
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF787774),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF7B6BA0),
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
