import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../constants/app_colors.dart';
import '../../services/settings_service.dart';

/// Shows a bottom sheet modal to select a Rabbit (Doe or Buck)
/// with a title and an 'X' close button in the top right to dismiss without selecting.
Future<Rabbit?> showRabbitPickerBottomSheet({
  required BuildContext context,
  required String title,
  required List<Rabbit> rabbits,
  List<Rabbit>? openRabbits,
  String? openSectionTitle,
  String? allSectionTitle,
  String? archivedSectionTitle,
  Rabbit? selectedRabbit,
  String? selectedRabbitId,
  bool showSectionHeaders = true,
}) {
  return showModalBottomSheet<Rabbit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RabbitPickerModal(
      title: title,
      rabbits: rabbits,
      openRabbits: openRabbits,
      openSectionTitle: openSectionTitle,
      allSectionTitle: allSectionTitle,
      archivedSectionTitle: archivedSectionTitle,
      selectedRabbitId: selectedRabbitId ?? selectedRabbit?.id,
      showSectionHeaders: showSectionHeaders,
    ),
  );
}

/// Shows a bottom sheet modal to select MULTIPLE Rabbits
/// with checkboxes, search, Select All / Clear All, and a Done button.
Future<List<Rabbit>?> showMultiRabbitPickerBottomSheet({
  required BuildContext context,
  required String title,
  required List<Rabbit> rabbits,
  List<Rabbit>? selectedRabbits,
  List<String>? selectedRabbitIds,
}) {
  return showModalBottomSheet<List<Rabbit>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MultiRabbitPickerModal(
      title: title,
      rabbits: rabbits,
      initialSelectedIds: selectedRabbitIds ?? selectedRabbits?.map((r) => r.id).toList() ?? [],
    ),
  );
}

class RabbitPickerModal extends StatefulWidget {
  final String title;
  final List<Rabbit> rabbits;
  final List<Rabbit>? openRabbits;
  final String? openSectionTitle;
  final String? allSectionTitle;
  final String? archivedSectionTitle;
  final String? selectedRabbitId;
  final bool showSectionHeaders;

  const RabbitPickerModal({
    Key? key,
    required this.title,
    required this.rabbits,
    this.openRabbits,
    this.openSectionTitle,
    this.allSectionTitle,
    this.archivedSectionTitle,
    this.selectedRabbitId,
    this.showSectionHeaders = true,
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

  List<Rabbit> _filterAndSort(List<Rabbit> source) {
    List<Rabbit> list = source;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = source.where((r) {
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
      list = List<Rabbit>.from(source);
    }
    list.sort((a, b) {
      final aArchived = a.isArchived;
      final bArchived = b.isArchived;
      if (aArchived != bArchived) {
        return aArchived ? 1 : -1;
      }
      if (SettingsService.instance.sortDoeBuck == 'Ear Number') {
        final earA = (a.earNumber ?? a.id).trim().toLowerCase();
        final earB = (b.earNumber ?? b.id).trim().toLowerCase();
        final earCompare = earA.compareTo(earB);
        if (earCompare != 0) return earCompare;
        return a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
      }
      final nameCompare = a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
      if (nameCompare != 0) return nameCompare;
      final breedCompare = a.breed.trim().toLowerCase().compareTo(b.breed.trim().toLowerCase());
      if (breedCompare != 0) return breedCompare;
      final prefixCompare = (a.breederPrefix ?? '').trim().toLowerCase().compareTo((b.breederPrefix ?? '').trim().toLowerCase());
      if (prefixCompare != 0) return prefixCompare;
      final earA = (a.earNumber ?? a.id).trim().toLowerCase();
      final earB = (b.earNumber ?? b.id).trim().toLowerCase();
      return earA.compareTo(earB);
    });
    return list;
  }

  Widget _buildRabbitNameWidget(Rabbit rabbit, {double fontSize = 15}) {
    final isDoe = rabbit.type == RabbitType.doe;
    final isArchived = rabbit.isArchived;
    final nameColor = isArchived
        ? const Color(0xFF787774)
        : (isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3));
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
              style: TextStyle(
                color: isArchived ? const Color(0xFF8E8E93) : const Color(0xFF787774),
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
                color: isArchived ? const Color(0xFF8E8E93) : const Color(0xFF787774),
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
    final isDoeList = (widget.rabbits.isNotEmpty && widget.rabbits.first.type == RabbitType.doe) ||
        (widget.openRabbits != null && widget.openRabbits!.isNotEmpty && widget.openRabbits!.first.type == RabbitType.doe) ||
        widget.title.toLowerCase().contains('doe');

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
            child: widget.rabbits.isEmpty && (widget.openRabbits?.isEmpty ?? true)
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
                : _buildSectionedList(isDoeList: isDoeList),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF787774),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildRabbitTile(Rabbit rabbit) {
    final isSelected = rabbit.id == widget.selectedRabbitId;
    final isArchived = rabbit.isArchived;
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
          color: isSelected
              ? const Color(0xFFF3E8FF)
              : (isArchived ? const Color(0xFFF4F4F6) : const Color(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7B6BA0)
                : const Color(0xFFE5E5EA),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isArchived ? const Color(0xFF8E8E93) : const Color(0xFF787774),
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
  }

  Widget _buildSectionedList({required bool isDoeList}) {
    final openIds = widget.openRabbits?.map((r) => r.id).toSet() ?? <String>{};
    final filteredOpen = widget.openRabbits != null
        ? _filterAndSort(widget.openRabbits!.where((r) => !r.isArchived).toList())
        : <Rabbit>[];
    final otherActive = widget.rabbits
        .where((r) => !r.isArchived && !openIds.contains(r.id))
        .toList();
    final filteredActive = _filterAndSort(otherActive);
    final archived = widget.rabbits.where((r) => r.isArchived).toList();
    final filteredArchived = _filterAndSort(archived);

    final totalCount = filteredOpen.length + filteredActive.length + filteredArchived.length;
    if (totalCount == 0) {
      return Center(
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
      );
    }

    final children = <Widget>[];

    // If section headers are disabled (e.g., Future Breeding Plan picker),
    // remove ALL DOES / ALL BUCKS / ARCHIVED DOES / ARCHIVED BUCKS headers,
    // and place archived at the bottom in grey color.
    if (!widget.showSectionHeaders) {
      for (final r in filteredOpen) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildRabbitTile(r),
        ));
      }
      for (final r in filteredActive) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildRabbitTile(r),
        ));
      }
      for (final r in filteredArchived) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildRabbitTile(r),
        ));
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: children,
      );
    }

    final String openTitle = widget.openSectionTitle ?? 'OPEN DOES';
    final String allTitle = widget.allSectionTitle ??
        ((widget.openRabbits != null && widget.openRabbits!.isNotEmpty)
            ? 'ALL OTHER DOES'
            : (isDoeList ? 'ALL DOES' : 'ALL BUCKS'));
    final String archivedTitle = widget.archivedSectionTitle ??
        (isDoeList ? 'ARCHIVED DOES' : 'ARCHIVED BUCKS');

    final bool hasOpenSection = widget.openRabbits != null;
    final bool hasArchivedSection = filteredArchived.isNotEmpty ||
        (widget.rabbits.any((r) => r.isArchived) && _searchQuery.isEmpty);

    final bool showAllHeader = hasOpenSection || hasArchivedSection || widget.allSectionTitle != null;

    // 1. OPEN SECTION
    if (hasOpenSection) {
      if (filteredOpen.isNotEmpty) {
        children.add(_buildSectionHeader(openTitle));
        for (final r in filteredOpen) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildRabbitTile(r),
          ));
        }
      } else if (_searchQuery.isEmpty) {
        children.add(_buildSectionHeader(openTitle));
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Center(
            child: Text(
              'No open does available',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ));
      }
    }

    // 2. ALL OTHER DOES / ALL BUCKS SECTION
    if (filteredActive.isNotEmpty) {
      if (showAllHeader) {
        children.add(_buildSectionHeader(allTitle));
      }
      for (final r in filteredActive) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildRabbitTile(r),
        ));
      }
    }

    // 3. ARCHIVED SECTION
    if (filteredArchived.isNotEmpty) {
      children.add(_buildSectionHeader(archivedTitle));
      for (final r in filteredArchived) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildRabbitTile(r),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: children,
    );
  }
}

class MultiRabbitPickerModal extends StatefulWidget {
  final String title;
  final List<Rabbit> rabbits;
  final List<String> initialSelectedIds;

  const MultiRabbitPickerModal({
    Key? key,
    required this.title,
    required this.rabbits,
    this.initialSelectedIds = const [],
  }) : super(key: key);

  @override
  State<MultiRabbitPickerModal> createState() => _MultiRabbitPickerModalState();
}

class _MultiRabbitPickerModalState extends State<MultiRabbitPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
  }

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
      final aArchived = a.status == RabbitStatus.archived;
      final bArchived = b.status == RabbitStatus.archived;
      if (aArchived != bArchived) {
        return aArchived ? 1 : -1;
      }
      if (SettingsService.instance.sortDoeBuck == 'Ear Number') {
        final earA = (a.earNumber ?? a.id).trim().toLowerCase();
        final earB = (b.earNumber ?? b.id).trim().toLowerCase();
        final earCompare = earA.compareTo(earB);
        if (earCompare != 0) return earCompare;
        return a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
      }
      final nameCompare = a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
      if (nameCompare != 0) return nameCompare;
      final breedCompare = a.breed.trim().toLowerCase().compareTo(b.breed.trim().toLowerCase());
      if (breedCompare != 0) return breedCompare;
      final prefixCompare = (a.breederPrefix ?? '').trim().toLowerCase().compareTo((b.breederPrefix ?? '').trim().toLowerCase());
      if (prefixCompare != 0) return prefixCompare;
      final earA = (a.earNumber ?? a.id).trim().toLowerCase();
      final earB = (b.earNumber ?? b.id).trim().toLowerCase();
      return earA.compareTo(earB);
    });
    return list;
  }

  Widget _buildRabbitNameWidget(Rabbit rabbit, {double fontSize = 15}) {
    final isDoe = rabbit.type == RabbitType.doe;
    final isArchived = rabbit.status == RabbitStatus.archived;
    final nameColor = isDoe
        ? (isArchived ? const Color(0xFFF48FB1) : const Color(0xFFE04F9F))
        : (isArchived ? const Color(0xFF80BFFF) : const Color(0xFF2196F3));
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
    final filtered = _filteredRabbits;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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

          // Action Toolbar: Select All / Clear All & Count
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedIds.length} Selected',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A3E6D),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedIds.length == filtered.length) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds = filtered.map((r) => r.id).toSet();
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _selectedIds.length == filtered.length ? 'Clear All' : 'Select All',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7B6BA0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // List of rabbits with selection checkboxes
          Expanded(
            child: widget.rabbits.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No bunnies available',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A3A3C),
                        ),
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
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final rabbit = filtered[index];
                          final isSelected = _selectedIds.contains(rabbit.id);
                          final details = <String>[];
                          if (rabbit.breed.isNotEmpty) details.add(rabbit.breed);
                          if ((rabbit.color ?? '').isNotEmpty) details.add(rabbit.color!);
                          if ((rabbit.cage ?? '').isNotEmpty) details.add('Cage: ${rabbit.cage}');

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(rabbit.id);
                                } else {
                                  _selectedIds.add(rabbit.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE5E5EA),
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
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFC7C7CC),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Confirm Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF2F2F7), width: 1)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final selectedList = widget.rabbits.where((r) => _selectedIds.contains(r.id)).toList();
                  Navigator.pop(context, selectedList);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6BEFE),
                  foregroundColor: const Color(0xFF4A3E6D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedIds.isEmpty
                      ? 'Done (0 selected)'
                      : 'Done (${_selectedIds.length} selected)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A3E6D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

