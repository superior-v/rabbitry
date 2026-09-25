import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/format_utils.dart';
import '../../constants/app_colors.dart';
import 'rabbit_picker_modal.dart';

class FutureBreedingPlanModal extends StatefulWidget {
  final VoidCallback onSaved;

  const FutureBreedingPlanModal({
    super.key,
    required this.onSaved,
  }) : super();

  @override
  State<FutureBreedingPlanModal> createState() => _FutureBreedingPlanModalState();
}

class _FutureBreedingPlanModalState extends State<FutureBreedingPlanModal> {
  final DatabaseService _db = DatabaseService();
  List<Rabbit> _does = [];
  List<Rabbit> _bucks = [];
  Rabbit? _selectedDoe;
  Rabbit? _selectedBuck;
  DateTime _plannedDate = DateTime.now().add(const Duration(days: 7));
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final rabbits = await _db.getAllRabbits();
    final does = rabbits.where((r) => r.type == RabbitType.doe && r.status != RabbitStatus.archived).toList();
    final bucks = rabbits.where((r) => r.type == RabbitType.buck && r.status != RabbitStatus.archived).toList();

    if (mounted) {
      setState(() {
        _does = does;
        _bucks = bucks;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDoe() async {
    final picked = await showRabbitPickerBottomSheet(
      context: context,
      title: 'Select Doe',
      rabbits: _does,
      selectedRabbit: _selectedDoe,
    );
    if (picked != null) {
      setState(() => _selectedDoe = picked);
    }
  }

  Future<void> _pickBuck() async {
    final picked = await showRabbitPickerBottomSheet(
      context: context,
      title: 'Select Buck',
      rabbits: _bucks,
      selectedRabbit: _selectedBuck,
    );
    if (picked != null) {
      setState(() => _selectedBuck = picked);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C2C2E),
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: const Color(0xFFE2BFFB),
              headerForegroundColor: const Color(0xFF463466),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              todayBorder: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
              todayForegroundColor: const WidgetStatePropertyAll(Color(0xFF8B5CF6)),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF2C2C2E);
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF8B5CF6);
                }
                return null;
              }),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _plannedDate = picked);
    }
  }

  Future<void> _savePlan() async {
    if (_selectedDoe == null || _selectedBuck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both a Doe and a Buck'),
          backgroundColor: Color(0xFFD44C47),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _db.insertBreedingPlan({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'doeId': _selectedDoe!.id,
        'buckId': _selectedBuck!.id,
        'plannedDate': _plannedDate.toIso8601String(),
        'notes': _notesController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving plan: $e'),
            backgroundColor: const Color(0xFFD44C47),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: kLilacLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilac, width: 1)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3E6D).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Future Breeding Plan',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A3E6D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B6BA0)),
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doe Selector
                    if (_does.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE58F)),
                        ),
                        child: const Text(
                          'No does available. Please add a doe first.',
                          style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      )
                    else
                      _buildRabbitSelectorField(
                        label: 'Select Doe',
                        selectedRabbit: _selectedDoe,
                        onTap: _pickDoe,
                        prefixIcon: Icons.female_rounded,
                        prefixColor: const Color(0xFFE04F9F),
                      ),
                    const SizedBox(height: 16),

                    // Buck Selector
                    if (_bucks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE58F)),
                        ),
                        child: const Text(
                          'No bucks available. Please add a buck first.',
                          style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      )
                    else
                      _buildRabbitSelectorField(
                        label: 'Select Buck',
                        selectedRabbit: _selectedBuck,
                        onTap: _pickBuck,
                        prefixIcon: Icons.male_rounded,
                        prefixColor: const Color(0xFF2196F3),
                      ),
                    const SizedBox(height: 16),

                    // Planned Date
                    _buildDatePickerField(
                      label: 'Planned Date',
                      value: _plannedDate,
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    _buildOutlinedField(
                      label: 'Notes',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _savePlan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6BEFE),
                          foregroundColor: const Color(0xFF4A3E6D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A3E6D)),
                                ),
                              )
                            : const Text(
                                'Save Breeding Plan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A3E6D),
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
    );
  }

  Widget _buildRabbitSelectorField({
    required String label,
    required Rabbit? selectedRabbit,
    required VoidCallback onTap,
    required IconData prefixIcon,
    required Color prefixColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(prefixIcon, color: prefixColor, size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4F4F56)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: selectedRabbit != null
            ? _buildRabbitNameWidget(selectedRabbit, fontSize: 15)
            : Text(
                'Select $label',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: kNeutral400),
              ),
      ),
    );
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

  Widget _buildDatePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF787774), size: 18),
            const SizedBox(width: 8),
            Text(
              FormatUtils.formatDate(value),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF787774)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400, fontSize: 14),
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
}
