import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/rabbit.dart';
import '../../models/litter.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/format_utils.dart';
import '../../services/app_event_service.dart';
import '../../constants/app_colors.dart';

class LogBirthModal extends StatefulWidget {
  final Rabbit doe;
  final Litter? existingLitter;
  final VoidCallback onComplete;

  const LogBirthModal({
    Key? key,
    required this.doe,
    this.existingLitter,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LogBirthModal> createState() => _LogBirthModalState();
}

class _LogBirthModalState extends State<LogBirthModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _litterIdController = TextEditingController();
  final TextEditingController _totalBornController = TextEditingController();
  final TextEditingController _aliveBornController = TextEditingController();
  final TextEditingController _weightAvgController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _colorsProducedController = TextEditingController();
  final TextEditingController _patternsProducedController = TextEditingController();
  final TextEditingController _bucksProducedController = TextEditingController();
  final TextEditingController _doesProducedController = TextEditingController();
  final TextEditingController _peanutsProducedController = TextEditingController();
  DateTime _kindleDate = DateTime.now();
  DateTime? _bredDate;
  bool _isSaving = false;
  bool _isMissedLitter = false;
  Rabbit? _buck;
  String? _buckName;
  String? _buckPrefix;
  String? _buckEarNumber;

  // ✅ Step management
  int _currentStep = 1; // 1 = Basic info, 2 = Kit details
  List<Map<String, dynamic>> _kitDetails = [];

  // ✅ Color options
  List<String> get _colorOptions {
    final colors = SettingsService.instance.colors;
    if (!colors.contains('Unknown')) {
      return [...colors, 'Unknown'];
    }
    return colors;
  }

  @override
  void initState() {
    super.initState();
    _buck = null;
    _buckName = null;
    _buckPrefix = null;
    _buckEarNumber = null;
    _bredDate = widget.doe.lastBreedDate ?? widget.existingLitter?.breedDate;

    final buckLookupId = widget.doe.lastBreedBuckId ?? (widget.existingLitter?.buckId.isNotEmpty == true ? widget.existingLitter?.buckId : null);
    if (buckLookupId != null && buckLookupId.isNotEmpty) {
      _db.getRabbit(buckLookupId).then((buck) {
        if (buck != null && mounted) {
          setState(() {
            _buck = buck;
            _buckPrefix = buck.breederPrefix;
            _buckName = buck.name;
            _buckEarNumber = buck.earNumber;
          });
        }
      });
    }
    if (widget.existingLitter != null) {
      final l = widget.existingLitter!;
      _litterIdController.text = l.id;
      _kindleDate = l.dob;
      _bredDate = l.breedDate;
      if (l.buckName.isNotEmpty && _buckName == null) {
        _buckName = l.buckName;
      }
      // Use stored aliveKits / totalKits fields (fallback to computed counts)
      final aliveCount = l.aliveKits ?? l.totalKitsCount;
      final totalCount = l.totalKits ?? (aliveCount + (l.deadKits ?? 0));
      _aliveBornController.text = aliveCount.toString();
      _totalBornController.text = totalCount.toString();
      _notesController.text = l.notes ?? '';
      _colorsProducedController.text = l.colorsProduced ?? '';
      _patternsProducedController.text = l.patternsProduced ?? '';
      _bucksProducedController.text = l.maleCount.toString();
      _doesProducedController.text = l.femaleCount.toString();
      
      // Only include non-archived kits in the editable detail list
      final activeKits = l.kits.where((k) => !k.isArchived).toList();
      // Calculate weight avg from active kits
      if (activeKits.isNotEmpty) {
        double totalW = activeKits.fold(0.0, (sum, k) => sum + k.weight);
        _weightAvgController.text = (totalW / activeKits.length).toStringAsFixed(1);
        
        // Populate kit details for step 2 (only active kits)
        _kitDetails = activeKits.map((k) => {
          'id': k.id,
          'sex': k.sex,
          'color': k.color,
          'weight': k.weight,
          'status': k.status,
          'imagePath': k.imagePath,
        }).toList();
      }
    } else {
      _loadNextLitterId();
      if (widget.doe.breedingNotes != null && widget.doe.breedingNotes!.trim().isNotEmpty) {
        _notesController.text = widget.doe.breedingNotes!.trim();
      }
      _db.getRabbit(widget.doe.id).then((freshDoe) {
        if (freshDoe != null && mounted) {
          if (_notesController.text.isEmpty && freshDoe.breedingNotes != null && freshDoe.breedingNotes!.trim().isNotEmpty) {
            setState(() {
              _notesController.text = freshDoe.breedingNotes!.trim();
            });
          }
        }
      });
    }
  }

  String _formatDoeHeader() {
    final prefix = (widget.doe.breederPrefix ?? '').trim();
    final name = widget.doe.name.trim();
    final ear = (widget.doe.earNumber?.trim().isNotEmpty == true
            ? widget.doe.earNumber!.trim()
            : widget.doe.id.trim())
        .toUpperCase();

    final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
    if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
      return '$namePart $ear';
    }
    return namePart;
  }

  String _formatBuckHeader() {
    if (_buck != null) {
      final prefix = (_buck!.breederPrefix ?? '').trim();
      final name = _buck!.name.trim();
      final ear = (_buck!.earNumber?.trim().isNotEmpty == true
              ? _buck!.earNumber!.trim()
              : _buck!.id.trim())
          .toUpperCase();
      final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
      if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
        return '$namePart $ear';
      }
      return namePart;
    }

    final fallbackName = (_buckName ?? widget.doe.lastBreedBuckId ?? widget.existingLitter?.buckName ?? 'Unknown Sire').trim();
    final buckId = (widget.doe.lastBreedBuckId ?? widget.existingLitter?.buckId ?? '').trim();
    if (buckId.isNotEmpty && !fallbackName.toUpperCase().contains(buckId.toUpperCase())) {
      return '$fallbackName ${buckId.toUpperCase()}';
    }
    return fallbackName;
  }

  String get _formattedBredDate {
    final date = _bredDate ??
        widget.doe.lastBreedDate ??
        (widget.doe.kindleDate != null
            ? widget.doe.kindleDate!.subtract(const Duration(days: 31))
            : null);
    if (date != null) {
      return FormatUtils.formatDate(date);
    }
    return FormatUtils.formatDate(_kindleDate);
  }

  Future<void> _loadNextLitterId() async {
    final nextId = await _db.getNextLitterId();
    setState(() {
      _litterIdController.text = nextId;
    });
  }

  @override
  void dispose() {
    _litterIdController.dispose();
    _totalBornController.dispose();
    _aliveBornController.dispose();
    _weightAvgController.dispose();
    _notesController.dispose();
    _colorsProducedController.dispose();
    _patternsProducedController.dispose();
    _bucksProducedController.dispose();
    _doesProducedController.dispose();
    _peanutsProducedController.dispose();
    super.dispose();
  }

  void _adjustKitDetailsToMatchAliveBorn() {
    final aliveBorn = int.tryParse(_aliveBornController.text) ?? 0;
    final avgWeight = double.tryParse(_weightAvgController.text) ?? 0.0;

    final archivedCount = widget.existingLitter != null
        ? widget.existingLitter!.kits.where((k) => k.isArchived).length
        : 0;
    final targetActiveCount = (aliveBorn - archivedCount).clamp(0, aliveBorn);

    if (_kitDetails.length < targetActiveCount) {
      final startCount = _kitDetails.length + archivedCount;
      final newKits = List.generate(
        targetActiveCount - _kitDetails.length,
        (index) => {
          'id': 'K-${startCount + index + 1}',
          'sex': 'U',
          'color': 'Unknown',
          'weight': avgWeight,
          'status': 'Nursing',
        },
      );
      _kitDetails.addAll(newKits);
    } else if (_kitDetails.length > targetActiveCount) {
      _kitDetails = _kitDetails.sublist(0, targetActiveCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFEADBEE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log Birth',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4A3E6D), letterSpacing: 0.3),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDoeHeader(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A3E6D)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatBuckHeader(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A3E6D)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 42),
                        child: Text(
                          _formattedBredDate,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4A3E6D)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
          // Bottom buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildBottomButtons(),
          ),
        ],
      ),
    );
  }

  void _toggleMissedLitter(bool value) {
    if (_isMissedLitter == value) return;
    setState(() {
      _isMissedLitter = value;
      if (_isMissedLitter) {
        _totalBornController.text = '0';
        _aliveBornController.text = '0';
      }
    });
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Litter ID & Birth Date
        Row(
          children: [
            Expanded(
              child: _buildOutlinedField(
                label: 'Litter ID',
                controller: _litterIdController,
                prefixIcon: Icons.tag,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDatePickerField(
                label: 'Birth Date',
                value: _kindleDate,
                onTap: () => _selectDate(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (!_isMissedLitter) ...[
          // Row 2: Kits Born & Kits Alive
          Row(
            children: [
              Expanded(
                child: _buildOutlinedField(
                  label: 'Kits Born',
                  controller: _totalBornController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    if (_aliveBornController.text.isEmpty) {
                      _aliveBornController.text = value;
                    }
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutlinedField(
                  label: 'Kits Alive',
                  controller: _aliveBornController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Does & Bucks
          Row(
            children: [
              Expanded(
                child: _buildOutlinedField(
                  label: 'Does',
                  controller: _doesProducedController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutlinedField(
                  label: 'Bucks',
                  controller: _bucksProducedController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Purple Container Card for Colors, Patterns, Peanuts, Notes, Avg Weight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kLilacWash,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kLilacLight),
            ),
            child: Column(
              children: [
                _buildOutlinedField(
                  label: 'Colors',
                  controller: _colorsProducedController,
                ),
                const SizedBox(height: 10),
                _buildOutlinedField(
                  label: 'Patterns',
                  controller: _patternsProducedController,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildOutlinedField(
                        label: 'Peanuts',
                        controller: _peanutsProducedController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildOutlinedField(
                        label: 'Avg Kit Weight',
                        controller: _weightAvgController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildOutlinedField(
                  label: 'Notes',
                  controller: _notesController,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Missed Litter Toggle
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleMissedLitter(!_isMissedLitter),
          onHorizontalDragUpdate: (details) {
            if (details.primaryDelta != null) {
              if (details.primaryDelta! > 0.5) {
                _toggleMissedLitter(true);
              } else if (details.primaryDelta! < -0.5) {
                _toggleMissedLitter(false);
              }
            }
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! > 0) {
                _toggleMissedLitter(true);
              } else if (details.primaryVelocity! < 0) {
                _toggleMissedLitter(false);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kLilacWash,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kLilacLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Missed Litter',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kLilacText),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _isMissedLitter ? const Color(0xFF7B6BA0) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMissedLitter ? const Color(0xFF7B6BA0) : const Color(0xFFC7C7CC),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: _isMissedLitter ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))
                              ],
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
        if (_isMissedLitter) ...[
          const SizedBox(height: 10),
          _buildOutlinedField(
            label: 'Notes',
            controller: _notesController,
            hint: 'Notes on missed breeding...',
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  // ✅ Helper widgets for the new themed layout
  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
    Color textColor = const Color(0xFF3A3A3C),
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF4F4F56), size: 18) : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    Color textColor = const Color(0xFF3A3A3C),
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 17),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F4F56), size: 18),
            const SizedBox(width: 8),
            Text(
              FormatUtils.formatDate(value),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._kitDetails.asMap().entries.map((entry) {
          final index = entry.key;
          final kit = entry.value;
          return _buildKitCard(index, kit);
        }).toList(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildKitCard(int index, Map<String, dynamic> kit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5DEEC)),
      ),
      child: Column(
        children: [
          // Purple Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF6B2D6D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            alignment: Alignment.center,
            child: Text(
              'Kit ${index + 1}/${_kitDetails.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Row 1: Gender Pills: Buck, Doe, Unknown
                Row(
                  children: [
                    _buildKitSexPill('M', 'Buck', kit['sex'] == 'M', () {
                      setState(() => _kitDetails[index]['sex'] = 'M');
                    }),
                    const SizedBox(width: 8),
                    _buildKitSexPill('F', 'Doe', kit['sex'] == 'F', () {
                      setState(() => _kitDetails[index]['sex'] = 'F');
                    }),
                    const SizedBox(width: 8),
                    _buildKitSexPill('U', 'Unknown', kit['sex'] == 'U' || kit['sex'] == null, () {
                      setState(() => _kitDetails[index]['sex'] = 'U');
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 2: Color dropdown & Weight input
                Row(
                  children: [
                    Expanded(
                      flex: 12,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: (kit['color'] != null && _colorOptions.contains(kit['color']))
                                ? kit['color']
                                : null,
                            hint: const Text('Color', style: TextStyle(color: Color(0xFF787774), fontSize: 14)),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2E2D32)),
                            items: _colorOptions.map((color) {
                              return DropdownMenuItem(
                                value: color,
                                child: Text(color, style: const TextStyle(fontSize: 14, color: Color(0xFF2E2D32))),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _kitDetails[index]['color'] = value);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 9,
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: TextEditingController(text: kit['weight'] != null && (kit['weight'] as num) > 0 ? kit['weight'].toString() : '')
                            ..selection = TextSelection.collapsed(offset: (kit['weight'] != null && (kit['weight'] as num) > 0 ? kit['weight'].toString() : '').length),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF2E2D32)),
                          decoration: InputDecoration(
                            hintText: 'Weight',
                            hintStyle: const TextStyle(color: Color(0xFF787774), fontSize: 14),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF6B2D6D), width: 1.5),
                            ),
                          ),
                          onChanged: (val) {
                            _kitDetails[index]['weight'] = double.tryParse(val) ?? 0.0;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 3: Notes
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: TextEditingController(text: kit['details'] ?? kit['notes'] ?? '')
                      ..selection = TextSelection.collapsed(offset: (kit['details'] ?? kit['notes'] ?? '').length),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF2E2D32)),
                    decoration: InputDecoration(
                      hintText: 'Notes',
                      hintStyle: const TextStyle(color: Color(0xFF787774), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6B2D6D), width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      _kitDetails[index]['details'] = val;
                      _kitDetails[index]['notes'] = val;
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitSexPill(String val, String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6B4E8C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF6B4E8C) : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF787774),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_currentStep == 1) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: _isMissedLitter ? null : _validateAndProceed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: kLilac, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Add Kit Details',
                style: TextStyle(color: kLilacText, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBirth,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLilacLight,
                foregroundColor: kLilacText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLilacText))
                  : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5, color: kLilacText)),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(color: Color(0xFF2E2D32), fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBirth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEDE8F5),
                  foregroundColor: const Color(0xFF6B2D6D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B2D6D)))
                    : const Text(
                        'LOG BIRTH',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5, color: Color(0xFF6B2D6D)),
                      ),
              ),
            ),
          ),
        ],
      );
    }
  }

  void _validateAndProceed() {
    final totalBorn = int.tryParse(_totalBornController.text);
    final aliveBorn = int.tryParse(_aliveBornController.text);

    if (_litterIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a Litter ID'), backgroundColor: Colors.red),
      );
      return;
    }

    if (totalBorn == null || aliveBorn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid numbers'), backgroundColor: Colors.red),
      );
      return;
    }

    if (aliveBorn > totalBorn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alive kits cannot exceed total born'), backgroundColor: Colors.red),
      );
      return;
    }

    _adjustKitDetailsToMatchAliveBorn();
    setState(() => _currentStep = 2);
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _kindleDate.isAfter(now) ? now : _kindleDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _kindleDate = picked);
    }
  }

  Future<void> _saveBirth() async {
    final totalBorn = int.tryParse(_totalBornController.text) ?? 0;
    final aliveBorn = int.tryParse(_aliveBornController.text) ?? 0;

    setState(() => _isSaving = true);

    try {
      await SettingsService.instance.init();
      final weaningWeeks = widget.doe.customWeanWeek ?? SettingsService.instance.weanAge;

      _adjustKitDetailsToMatchAliveBorn();

      if (widget.existingLitter != null) {
        // Build updated active kits from the detail form
        final updatedActiveKits = _kitDetails.map((k) => Kit(
          id: k['id'] ?? '',
          sex: k['sex'] ?? 'U',
          color: k['color'] ?? 'Unknown',
          weight: (k['weight'] as num?)?.toDouble() ?? 0.0,
          status: k['status'] ?? 'Nursing',
          imagePath: k['imagePath'] as String?,
        )).toList();

        // Preserve archived kits (sold, butchered, dead) that were filtered out
        final archivedKits = widget.existingLitter!.kits
            .where((k) => k.isArchived)
            .toList();

        // Combine: updated active kits + archived kits preserved (deduplicated by ID)
        final activeIds = updatedActiveKits.map((k) => k.id).toSet();
        final uniqueArchived = archivedKits.where((k) => !activeIds.contains(k.id)).toList();
        final allKits = [...updatedActiveKits, ...uniqueArchived];

        // Prepare updated litter object
        final updatedLitter = widget.existingLitter!.copyWith(
          dob: _kindleDate,
          notes: _notesController.text,
          totalKits: int.tryParse(_totalBornController.text) ?? 0,
          aliveKits: int.tryParse(_aliveBornController.text) ?? 0,
          kits: allKits,
          colorsProduced: _colorsProducedController.text,
          patternsProduced: _patternsProducedController.text,
          bucksProduced: int.tryParse(_bucksProducedController.text) ?? 0,
          doesProduced: int.tryParse(_doesProducedController.text) ?? 0,
          deadKits: (int.tryParse(_totalBornController.text) ?? 0) - (int.tryParse(_aliveBornController.text) ?? 0),
        );
        await _db.updateLitter(updatedLitter);
      } else {
        await _db.logBirth(
          widget.doe.id,
          totalBorn,
          aliveBorn,
          _kindleDate,
          weaningWeeks,
          litterId: _litterIdController.text.trim(),
          kits: _kitDetails,
          missedLitter: _isMissedLitter,
          colorsProduced: _colorsProducedController.text,
          patternsProduced: _patternsProducedController.text,
          bucksProduced: int.tryParse(_bucksProducedController.text),
          doesProduced: int.tryParse(_doesProducedController.text),
          peanutsProduced: int.tryParse(_peanutsProducedController.text),
          notes: _notesController.text,
        );
      }

      notifyDataChanged();
      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingLitter != null 
            ? 'Litter ${_litterIdController.text} updated successfully'
            : 'Birth logged: ${_litterIdController.text} with $aliveBorn kits'),
          backgroundColor: kPinkDeep,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
