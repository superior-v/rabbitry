import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../constants/app_colors.dart';

class LogBreedingModal extends StatefulWidget {
  final Rabbit? doe;
  final Rabbit? buck;
  final DateTime? initialBreedDate;
  final String? deleteBreedingPlanId;
  final VoidCallback onComplete;

  const LogBreedingModal({
    Key? key,
    this.doe,
    this.buck,
    this.initialBreedDate,
    this.deleteBreedingPlanId,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LogBreedingModal> createState() => _LogBreedingModalState();
}

class _LogBreedingModalState extends State<LogBreedingModal> {
  final DatabaseService _db = DatabaseService();
  List<Rabbit> _bucks = [];
  List<Rabbit> _does = [];
  Rabbit? _selectedBuck;
  Rabbit? _selectedDoe;
  DateTime _breedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  // Timeline days (loaded from settings, editable by user)
  int _palpationDays = 14;
  int _nestBoxDays = 28;
  final TextEditingController _breedingNotesController = TextEditingController();
  final TextEditingController _fallOffsController = TextEditingController();
  final TextEditingController _customGestationController = TextEditingController();
  int _gestationDays = 31;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _customGestationController.dispose();
    _breedingNotesController.dispose();
    _fallOffsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await SettingsService.instance.init();
    final settings = SettingsService.instance;
    final bucks = await _db.getAvailableBucks();
    
    List<Rabbit> openDoes = [];
    if (widget.doe == null) {
      openDoes = await _db.getOpenDoes();
    }

    Rabbit? preselectedBuck;
    DateTime preselectedDate = DateTime.now();
    int preselectedPalpation = settings.palpationDays;
    int preselectedNestBox = settings.nestBoxDays;
    int preselectedGestation = settings.gestationDays;
    String preselectedNotes = '';
    String preselectedFallOffs = '';

    if (widget.doe != null) {
      final doe = widget.doe!;
      preselectedPalpation = doe.customPalpationDay ?? settings.palpationDays;
      preselectedNestBox = doe.customNestBoxDay ?? settings.nestBoxDays;
      preselectedGestation = doe.customGestationDay ?? settings.gestationDays;
      preselectedDate = widget.initialBreedDate ?? doe.lastBreedDate ?? DateTime.now();
      preselectedNotes = doe.breedingNotes ?? '';
      preselectedFallOffs = doe.fallOffs?.toString() ?? '';

      if (widget.buck != null) {
        preselectedBuck = bucks.firstWhere(
          (b) => b.id == widget.buck!.id,
          orElse: () {
            bucks.add(widget.buck!);
            return widget.buck!;
          },
        );
      } else if (doe.lastBreedBuckId != null) {
        preselectedBuck = bucks.firstWhere(
          (b) => b.id == doe.lastBreedBuckId,
          orElse: () => Rabbit(
            id: doe.lastBreedBuckId!,
            name: doe.lastBreedBuckId!,
            type: RabbitType.buck,
            status: RabbitStatus.active,
            breed: '',
          ),
        );
        if (!bucks.any((b) => b.id == preselectedBuck!.id)) {
          bucks.add(preselectedBuck);
        }
      }
    } else {
      if (widget.initialBreedDate != null) {
        preselectedDate = widget.initialBreedDate!;
      }
      if (widget.buck != null) {
        preselectedBuck = bucks.firstWhere(
          (b) => b.id == widget.buck!.id,
          orElse: () {
            bucks.add(widget.buck!);
            return widget.buck!;
          },
        );
      }
    }

    setState(() {
      _palpationDays = preselectedPalpation;
      _nestBoxDays = preselectedNestBox;
      _gestationDays = preselectedGestation;
      _bucks = bucks;
      _does = openDoes;
      _selectedBuck = preselectedBuck;
      _selectedDoe = widget.doe;
      _breedDate = preselectedDate;
      _breedingNotesController.text = preselectedNotes;
      _fallOffsController.text = preselectedFallOffs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: kLilacLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilac, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Breeding',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kLilacText, letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.doe != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${widget.doe!.name} • ${widget.doe!.id}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kLilacText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: kLilacText),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Flexible(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doe Selection Dropdown (if widget.doe is null)
                  if (widget.doe == null) ...[
                    if (_isLoading)
                      const SizedBox.shrink()
                    else if (_does.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE58F)),
                        ),
                        child: const Text(
                          'No open does available. Please add or open a doe first.',
                          style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      _buildDropdownField<Rabbit>(
                        label: 'Select Doe',
                        value: _selectedDoe,
                        prefixIcon: Icons.female_rounded,
                        items: _does.map((doe) {
                          return DropdownMenuItem(
                            value: doe,
                            child: Text('${doe.name} (${doe.id})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (doe) {
                          setState(() {
                            _selectedDoe = doe;
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Buck Selection
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (_bucks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE58F)),
                      ),
                      child: const Text(
                        'No bucks available. Please add a buck first.',
                        style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    _buildDropdownField<Rabbit>(
                      label: 'Select Buck',
                      value: _selectedBuck,
                      prefixIcon: Icons.male_rounded,
                      items: _bucks.map((buck) {
                        return DropdownMenuItem(
                          value: buck,
                          child: Text('${buck.name} (${buck.id})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (buck) {
                        setState(() => _selectedBuck = buck);
                      },
                    ),
                  const SizedBox(height: 16),

                  // Purple Container Card for Breed Date, Fall Offs, Breeding Notes
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: kLilacWash,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kLilacLight),
                    ),
                    child: Column(
                      children: [
                        _buildDatePickerField(
                          label: 'Breed Date',
                          value: _breedDate,
                          onTap: () => _selectDate(context),
                        ),
                        const SizedBox(height: 16),
                        _buildOutlinedField(
                          label: 'Fall Offs',
                          controller: _fallOffsController,
                          prefixIcon: Icons.repeat_on_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildOutlinedField(
                          label: 'Breeding Notes',
                          controller: _breedingNotesController,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timeline Preview
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: kLilacWash.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kLilacLight.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Breeding Timeline',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF7B6BA0), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        _buildTimelineItem('palpation', 'Palpation', _breedDate.add(Duration(days: _palpationDays))),
                        _buildTimelineItem('nestbox', 'Nest Box', _breedDate.add(Duration(days: _nestBoxDays))),
                        _buildTimelineItem('gestation', 'Due Date', _breedDate.add(Duration(days: _gestationDays))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: ((widget.doe != null || _selectedDoe != null) && _selectedBuck != null && !_isSaving) ? _saveBreeding : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLilacLight,
                  foregroundColor: kLilacText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLilacText))
                    : const Text(
                        'SAVE',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5, color: kLilacText),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTimelineDate(String type) async {
    DateTime initialDate;
    if (type == 'palpation') {
      initialDate = _breedDate.add(Duration(days: _palpationDays));
    } else if (type == 'nestbox') {
      initialDate = _breedDate.add(Duration(days: _nestBoxDays));
    } else {
      initialDate = _breedDate.add(Duration(days: _gestationDays));
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _breedDate,
      lastDate: _breedDate.add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() {
        final diff = picked.difference(_breedDate).inDays;
        if (type == 'palpation') {
          _palpationDays = diff;
        } else if (type == 'nestbox') {
          _nestBoxDays = diff;
        } else {
          _gestationDays = diff;
        }
      });
    }
  }

  Widget _buildTimelineItem(String key, String label, DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 15, color: Color(0xFF7B6BA0), fontWeight: FontWeight.w500),
          ),
          Text(
            DateFormat('MM-dd-yyyy').format(date),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A3A3A),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _selectTimelineDate(key),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.edit, size: 14, color: Color(0xFF9B8EC4)),
            ),
          ),
        ],
      ),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
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
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF7B6BA0), size: 18),
            const SizedBox(width: 8),
            Text(
              DateFormat('MM-dd-yyyy').format(value),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData prefixIcon,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF7B6BA0), size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7B6BA0)),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _breedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _breedDate = picked);
    }
  }

  Future<void> _saveBreeding() async {
    final doeToBreed = widget.doe ?? _selectedDoe;
    if (doeToBreed == null || _selectedBuck == null) return;

    setState(() => _isSaving = true);

    try {
      await _db.logBreeding(
        doeToBreed.id,
        _selectedBuck!.id,
        _breedDate,
        _gestationDays,
        customPalpationDays: _palpationDays,
        customNestBoxDays: _nestBoxDays,
        fallOffs: int.tryParse(_fallOffsController.text),
        breedingNotes: _breedingNotesController.text,
      );

      if (widget.deleteBreedingPlanId != null) {
        await _db.deleteBreedingPlan(widget.deleteBreedingPlanId!);
      }

      // Call callback FIRST to trigger parent refresh
      widget.onComplete();

      // Then close this modal
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
