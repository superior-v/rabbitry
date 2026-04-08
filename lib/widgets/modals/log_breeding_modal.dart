import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../constants/app_colors.dart';

class LogBreedingModal extends StatefulWidget {
  final Rabbit doe;
  final VoidCallback onComplete;

  const LogBreedingModal({
    Key? key,
    required this.doe,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LogBreedingModal> createState() => _LogBreedingModalState();
}

class _LogBreedingModalState extends State<LogBreedingModal> {
  final DatabaseService _db = DatabaseService();
  List<Rabbit> _bucks = [];
  Rabbit? _selectedBuck;
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
    setState(() {
      _palpationDays = settings.palpationDays;
      _nestBoxDays = settings.nestBoxDays;
      _gestationDays = settings.gestationDays;
      _bucks = bucks;
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: kLilacWash,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilacLight, width: 1)),
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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kLilacDeep, letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.doe.name} • ${widget.doe.id}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kLilacText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: kLilacDeep),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    // Dropdown styled like OutlinedField
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kLilacLight),
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                    
                          labelStyle: TextStyle(color: kLilacDeep, fontWeight: FontWeight.w700, fontSize: 14),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.male_rounded, color: kLilacDeep, size: 20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Rabbit>(
                            value: _selectedBuck,
                            isExpanded: true,
                            hint: const Text('Select a buck', style: TextStyle(fontSize: 15)),
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
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Breed Date
                  _buildDatePickerField(
                    label: 'Breed Date',
                    value: _breedDate,
                    onTap: () => _selectDate(context),
                  ),
                  const SizedBox(height: 16),

                  // Timeline Preview
                  Container(
                    padding: const EdgeInsets.all(16),
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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kLilacDeep, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        _buildTimelineItem('Palpation', _breedDate.add(Duration(days: _palpationDays)), Icons.touch_app_rounded),
                        _buildTimelineItem('Nest Box', _breedDate.add(Duration(days: _nestBoxDays)), Icons.home_rounded),
                        _buildTimelineItem('Due Date', _breedDate.add(Duration(days: _gestationDays)), Icons.child_friendly_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Fall Offs
                  _buildOutlinedField(
                    label: 'Fall Offs (Optional)',
                    controller: _fallOffsController,
                    hint: 'Number of successful covers',
                    prefixIcon: Icons.repeat_on_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Breeding Notes
                  _buildOutlinedField(
                    label: 'Breeding Notes (Optional)',
                    controller: _breedingNotesController,
                    hint: 'Any special observations...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedBuck == null || _isSaving ? null : _saveBreeding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLilacDeep,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'LOG BREEDING RECORD',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, DateTime date, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [

          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 14, color: kLilacText, fontWeight: FontWeight.w500),
          ),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kNeutral800,
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
        labelStyle: const TextStyle(color: kLilacDeep, fontWeight: FontWeight.w700, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacDeep, width: 1.5)),
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
          labelStyle: const TextStyle(color: kLilacDeep, fontWeight: FontWeight.w700, fontSize: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: kLilacDeep, size: 18),
            const SizedBox(width: 8),
            Text(
              '${value.day}/${value.month}/${value.year}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _breedDate,
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _breedDate = picked);
    }
  }

  Future<void> _saveBreeding() async {
    if (_selectedBuck == null) return;

    setState(() => _isSaving = true);

    try {
      await _db.logBreeding(
        widget.doe.id,
        _selectedBuck!.id,
        _breedDate,
        _gestationDays,
        customPalpationDays: _palpationDays,
        customNestBoxDays: _nestBoxDays,
        fallOffs: int.tryParse(_fallOffsController.text),
        breedingNotes: _breedingNotesController.text,
      );

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
