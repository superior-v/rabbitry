import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import 'modals/move_cage_modal.dart';
import 'dart:convert'; // ✅ Add this import for jsonDecode

class QuickInfoCard extends StatefulWidget {
  final Rabbit rabbit;

  const QuickInfoCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<QuickInfoCard> createState() => _QuickInfoCardState();
}

class _QuickInfoCardState extends State<QuickInfoCard> {
  late Rabbit _currentRabbit;

  @override
  void initState() {
    super.initState();
    _currentRabbit = widget.rabbit;
  }

  Future<void> _refreshRabbitData() async {
    final updatedRabbit = await DatabaseService().getRabbit(_currentRabbit.id);
    if (updatedRabbit != null && mounted) {
      setState(() {
        _currentRabbit = updatedRabbit;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Text(
                  'QUICK INFO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          _buildEditableInfoRow(context, 'Cage', _currentRabbit.cage ?? 'Unassigned', () => _showCageSelector(context)),
          _buildEditableInfoRow(context, 'Breed', _currentRabbit.breed, () => _showBreedSelector(context)),
          _buildEditableInfoRow(context, 'Color', _currentRabbit.color ?? 'Not set', () => _showColorSelector(context)),
          _buildEditableInfoRow(context, 'Weight', _currentRabbit.weight != null ? '${_currentRabbit.weight!.toStringAsFixed(1)} lbs' : 'Not recorded', () async {
            await _showWeightModal(context);
            await _refreshRabbitData();
          }, showInfoIcon: true),
          _buildStaticInfoRow('Born', 'Mar 15, 2024'),
          _buildStaticInfoRow('Age', _calculateAge()),
          _buildEditableInfoRow(context, 'Origin', _currentRabbit.origin ?? 'Not set', () => _showOriginSelector(context)),
        ],
      ),
    );
  }

  // Editable row with chevron
  Widget _buildEditableInfoRow(BuildContext context, String label, String value, VoidCallback onTap, {bool showInfoIcon = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF37352F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (showInfoIcon) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF9B9A97)),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9B9A97)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Static row (no editing)
  Widget _buildStaticInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF787774),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateAge() {
    return '10m 12d';
  }

  // Replace the entire _showCageSelector method with this:

  void _showCageSelector(BuildContext context) async {
    // ✅ Load locations from database instead of hardcoding
    final db = DatabaseService();
    final barnsData = await db.getAllBarns();

    // Parse barns into location format
    List<Map<String, dynamic>> locations = [];

    for (var barn in barnsData) {
      final rowsRaw = barn['rows'];
      List<dynamic> rows = [];

      if (rowsRaw is String && rowsRaw.isNotEmpty) {
        try {
          rows = jsonDecode(rowsRaw) as List<dynamic>;
        } catch (e) {
          print('Error decoding barn rows: $e');
        }
      } else if (rowsRaw is List) {
        rows = rowsRaw;
      }

      for (var row in rows) {
        if (row is Map) {
          final rowName = row['name'] as String?;
          final cagesRaw = row['cages'];
          List<String> cagesList = [];

          if (cagesRaw is List) {
            cagesList = cagesRaw.map((c) => c.toString()).toList();
          }

          if (rowName != null && cagesList.isNotEmpty) {
            locations.add({
              'location': rowName,
              'cages': cagesList,
            });
          }
        }
      }
    }

    // Initialize state
    String? selectedCage = _currentRabbit.cage;
    String? selectedLocation;

    // Auto-detect the location based on the current cage
    if (selectedCage != null) {
      for (var loc in locations) {
        if ((loc['cages'] as List<String>).contains(selectedCage)) {
          selectedLocation = loc['location'] as String;
          break;
        }
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Helper to get cages for the currently selected location
          List<String> currentDropdownCages = [];
          if (selectedLocation != null) {
            final locData = locations.firstWhere(
              (element) => element['location'] == selectedLocation,
              orElse: () => {
                'cages': <String>[]
              },
            );
            currentDropdownCages = locData['cages'] as List<String>;
          }

          // Replace the Container inside showModalBottomSheet with this:

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20, // ✅ Add bottom padding
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85, // ✅ Limit height to 85% of screen
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Move Cage',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ✅ Wrap everything else in Expanded + SingleChildScrollView
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Cage Display
                        const Text(
                          'Current Cage',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentRabbit.location ?? 'Unknown'} • ${_currentRabbit.cage ?? 'Unassigned'}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // New Location Section
                        const Text(
                          'New Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Dropdowns
                        Row(
                          children: [
                            // Location (Row) Dropdown
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: const Text('Select Row', style: TextStyle(fontSize: 13)),
                                    value: selectedLocation,
                                    items: locations.map((loc) {
                                      return DropdownMenuItem(
                                        value: loc['location'] as String,
                                        child: Text(loc['location'] as String, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setModalState(() {
                                        selectedLocation = value;
                                        selectedCage = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Cage Dropdown
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: const Text('Select Cage', style: TextStyle(fontSize: 13)),
                                    value: selectedCage,
                                    items: selectedLocation == null
                                        ? []
                                        : currentDropdownCages.map((cage) {
                                            return DropdownMenuItem(
                                              value: cage,
                                              child: Text(cage, style: const TextStyle(fontSize: 13)),
                                            );
                                          }).toList(),
                                    onChanged: selectedLocation == null
                                        ? null
                                        : (value) {
                                            setModalState(() {
                                              selectedCage = value;
                                            });
                                          },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Quick Select (Chips)
                        _buildLocationCageSelector(
                          locations,
                          selectedCage,
                          (cage, location) {
                            setModalState(() {
                              selectedCage = cage;
                              selectedLocation = location;
                            });
                          },
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ✅ Action Buttons - Keep these OUTSIDE the scrollview
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedCage == null
                            ? null
                            : () async {
                                final updatedRabbit = _currentRabbit.copyWith(
                                  cage: selectedCage,
                                  location: selectedLocation,
                                );
                                await DatabaseService().updateRabbit(updatedRabbit);
                                Navigator.pop(context);
                                await _refreshRabbitData();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Cage updated to $selectedCage'),
                                      backgroundColor: const Color(0xFF0F7B6C),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7B6C),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Change Cage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationCageSelector(List<Map<String, dynamic>> locations, String? selectedCage, Function(String cage, String location) onSelect) {
    return Container(
      width: double.infinity, // Ensure it takes full width
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Select',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          ...locations.map((loc) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    loc['location'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (loc['cages'] as List<String>).map((cage) {
                    final isSelected = selectedCage == cage;
                    return InkWell(
                      onTap: () {
                        // Use the callback to update the parent state
                        onSelect(cage, loc['location'] as String);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE8F5F3) : const Color(0xFFF7F7F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0F7B6C) : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          cage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? const Color(0xFF0F7B6C) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  String? _selectedLocation;

  // Breed Selector - loads breeds from settings and populates genetics
  void _showBreedSelector(BuildContext context) async {
    await SettingsService.instance.init();
    final breedsList = SettingsService.instance.breeds;
    String? selectedBreed = _currentRabbit.breed;
    String? selectedGenotype;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Breed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Color(0xFF787774),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentRabbit.breed,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF37352F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Breed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text(
                          'Select breed from settings...',
                          style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
                        ),
                        value: selectedBreed,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF37352F)),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF37352F)),
                        items: breedsList.map((breed) {
                          return DropdownMenuItem(
                            value: breed['name'],
                            child: Text(breed['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBreed = value;
                            // Find and set genotype based on selected breed
                            final breedData = breedsList.firstWhere(
                              (b) => b['name'] == value,
                              orElse: () => {
                                'name': '',
                                'genotype': ''
                              },
                            );
                            selectedGenotype = breedData['genotype'];
                          });
                        },
                      ),
                    ),
                  ),
                  // Show genotype when breed is selected
                  if (selectedGenotype != null && selectedGenotype!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0F7B6C).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GENOTYPE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF787774),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedGenotype!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F7B6C),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF787774),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: selectedBreed == null
                            ? null
                            : () async {
                                // Update rabbit breed and genetics
                                final updatedRabbit = _currentRabbit.copyWith(
                                  breed: selectedBreed,
                                  genetics: selectedGenotype,
                                );
                                await DatabaseService().updateRabbit(updatedRabbit);
                                Navigator.pop(context);

                                // Refresh the rabbit data
                                await _refreshRabbitData();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Breed updated to $selectedBreed'),
                                      backgroundColor: const Color(0xFF0F7B6C),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7B6C),
                          disabledBackgroundColor: const Color(0xFFE9E9E7),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Color Selector
  void _showColorSelector(BuildContext context) {
    String? selectedColor = _currentRabbit.color;
    bool isCustom = false;
    final customColorController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Color(0xFF787774),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentRabbit.color ?? 'Not set',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF37352F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'New Color',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text(
                          'Select color...',
                          style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
                        ),
                        value: isCustom ? 'Custom' : selectedColor,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF37352F)),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF37352F)),
                        items: const [
                          DropdownMenuItem(value: 'Castor', child: Text('Castor')),
                          DropdownMenuItem(value: 'Black', child: Text('Black')),
                          DropdownMenuItem(value: 'White', child: Text('White')),
                          DropdownMenuItem(value: 'Broken Castor', child: Text('Broken Castor')),
                          DropdownMenuItem(value: 'Chinchilla', child: Text('Chinchilla')),
                          DropdownMenuItem(value: 'Custom', child: Text('Custom...')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == 'Custom') {
                              isCustom = true;
                              selectedColor = null;
                            } else {
                              isCustom = false;
                              selectedColor = value;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (isCustom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customColorController,
                      decoration: InputDecoration(
                        hintText: 'Enter custom color...',
                        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedColor = value.isNotEmpty ? value : null;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF787774),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: selectedColor == null
                            ? null
                            : () async {
                                final colorToSave = isCustom ? customColorController.text.trim() : selectedColor;
                                if (colorToSave == null || colorToSave.isEmpty) return;

                                final updatedRabbit = _currentRabbit.copyWith(
                                  color: colorToSave,
                                );
                                await DatabaseService().updateRabbit(updatedRabbit);
                                Navigator.pop(context);
                                await _refreshRabbitData();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Color updated to $colorToSave'),
                                      backgroundColor: const Color(0xFF0F7B6C),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7B6C),
                          disabledBackgroundColor: const Color(0xFFE9E9E7),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Origin Selector
  void _showOriginSelector(BuildContext context) {
    String? selectedOrigin = _currentRabbit.origin;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Origin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Color(0xFF787774),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentRabbit.origin ?? 'Not set',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF37352F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'New Origin',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text(
                          'Select origin...',
                          style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
                        ),
                        value: selectedOrigin,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF37352F)),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF37352F)),
                        items: const [
                          DropdownMenuItem(value: 'Purchased', child: Text('Purchased')),
                          DropdownMenuItem(value: 'Bred On-Site', child: Text('Bred On-Site')),
                          DropdownMenuItem(value: 'Gift', child: Text('Gift')),
                          DropdownMenuItem(value: 'Rescue', child: Text('Rescue')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedOrigin = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF787774),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: selectedOrigin == null
                            ? null
                            : () async {
                                final updatedRabbit = _currentRabbit.copyWith(
                                  origin: selectedOrigin,
                                );
                                await DatabaseService().updateRabbit(updatedRabbit);
                                Navigator.pop(context);
                                await _refreshRabbitData();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Origin updated to $selectedOrigin'),
                                      backgroundColor: const Color(0xFF0F7B6C),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7B6C),
                          disabledBackgroundColor: const Color(0xFFE9E9E7),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWeightModal(BuildContext context) async {
    final db = DatabaseService();
    final weightHistory = await db.getWeightHistory(_currentRabbit.id); // Changed rabbit to _currentRabbit

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Weight History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Weight',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentRabbit.weight != null ? '${_currentRabbit.weight} lbs' : 'Not recorded', // Changed rabbit to _currentRabbit
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Recent Entries',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              ...weightHistory.take(5).map((entry) {
                return _buildWeightEntry(
                  '${entry['weight']} lbs',
                  _formatDate(DateTime.parse(entry['date'])),
                );
              }).toList(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddWeightDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B6C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Log New Weight',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildWeightEntry(String weight, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            weight,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF37352F),
            ),
          ),
          Text(
            date,
            style: const TextStyle(fontSize: 13, color: Color(0xFF787774)),
          ),
        ],
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context) async {
    final TextEditingController weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Weight'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight (lbs)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF787774)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final weightText = weightController.text.trim();
              if (weightText.isEmpty) return;

              final weight = double.tryParse(weightText);
              if (weight == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid weight'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Save weight to database
              await DatabaseService().insertWeightRecord(
                _currentRabbit.id, // Changed rabbit to _currentRabbit
                weight,
                DateTime.now(),
                null,
              );

              Navigator.pop(context);

              // Refresh the rabbit data
              await _refreshRabbitData();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Weight logged successfully'),
                    backgroundColor: Color(0xFF0F7B6C),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F7B6C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
