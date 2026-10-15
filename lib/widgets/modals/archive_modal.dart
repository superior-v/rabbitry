import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/rabbit.dart';
import '../../models/transaction.dart' as finance;
import '../../services/database_service.dart';
import '../../services/format_utils.dart';
import '../../constants/app_colors.dart';

class ArchiveModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;
  final ArchiveReason? preselectedReason;

  const ArchiveModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
    this.preselectedReason,
  }) : super(key: key);

  @override
  State<ArchiveModal> createState() => _ArchiveModalState();
}

class _ArchiveModalState extends State<ArchiveModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _buyerController = TextEditingController();
  final TextEditingController _yieldController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _deathCauseController = TextEditingController();
  final TextEditingController _cullReasonController = TextEditingController();

  ArchiveReason? _selectedReason;
  DateTime _archiveDate = DateTime.now();
  bool _isSaving = false;
  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.preselectedReason;
    if (widget.rabbit.salePrice != null && widget.rabbit.salePrice! > 0) {
      _salePriceController.text = widget.rabbit.salePrice!.toStringAsFixed(2);
    }
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _db.getContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _salePriceController.dispose();
    _buyerController.dispose();
    _yieldController.dispose();
    _costController.dispose();
    _deathCauseController.dispose();
    _cullReasonController.dispose();
    super.dispose();
  }

  Widget _buildRabbitHeaderName(Rabbit rabbit, {double fontSize = 14}) {
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
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF787774),
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: nameColor,
            ),
          ),
          if (ear.isNotEmpty && !name.toUpperCase().endsWith(ear))
            TextSpan(
              text: ' $ear',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF787774),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getHeaderTitle() {
    if (widget.preselectedReason != null) {
      switch (widget.preselectedReason!) {
        case ArchiveReason.sold:
          return 'Sell Rabbit';
        case ArchiveReason.cull:
          return 'Cull Rabbit';
        case ArchiveReason.dead:
          return 'Record Death';
        case ArchiveReason.butchered:
          return 'Butcher Rabbit';
        case ArchiveReason.stud:
          return 'Stud Rabbit';
      }
    }
    return 'Archive Rabbit';
  }

  String _getSubmitButtonText() {
    final reason = _selectedReason ?? widget.preselectedReason;
    if (reason != null) {
      switch (reason) {
        case ArchiveReason.sold:
          return 'Confirm Sale';
        case ArchiveReason.cull:
          return 'Cull Rabbit';
        case ArchiveReason.dead:
          return 'Record death';
        case ArchiveReason.butchered:
          return 'Record Butchering';
        case ArchiveReason.stud:
          return 'Archive as Stud';
      }
    }
    return 'Archive Rabbit';
  }

  Color _getSubmitButtonColor() {
    return const Color(0xFFE6BEFE);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _archiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C2C2E),
            ),
            datePickerTheme: const DatePickerThemeData(
              headerBackgroundColor: Color(0xFFE2BFFB),
              headerForegroundColor: Color(0xFF463466),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _archiveDate = picked);
    }
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
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kLilacLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F4F56), size: 18),
            const SizedBox(width: 8),
            Text(
              FormatUtils.formatDate(value),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2E)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLockedReason = widget.preselectedReason != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header banner (matches NEW TASK modal style)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                      color: const Color(0xFF4A3E6D).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getHeaderTitle(),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A3E6D),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _buildRabbitHeaderName(widget.rabbit, fontSize: 14),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
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

          // Modal body fields
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Only show reason selector if reason is not locked/preselected
                if (!isLockedReason) ...[
                  const Text(
                    'REASON',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4A3E6D), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildCategoryRadio('Sold', ArchiveReason.sold)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildCategoryRadio('Cull', ArchiveReason.cull)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildCategoryRadio('Died', ArchiveReason.dead)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildCategoryRadio('Butchered', ArchiveReason.butchered)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildCategoryRadio('Stud', ArchiveReason.stud)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Date Field
                _buildDatePickerField(
                  label: 'Date',
                  value: _archiveDate,
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 16),

                // Dynamic fields based on reason
                if (_selectedReason != null) ..._buildReasonSpecificFields(),

                // Notes field (clean label, no *, no Additional, no hintText)
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                    floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kLilacLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),

                const SizedBox(height: 16),

                // Subtle archive hint container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F6FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E0F2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.archive_outlined, color: Color(0xFF7B6BA0), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This rabbit will be moved to the Archive tab.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF636366)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Primary Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selectedReason == null || _isSaving ? null : _saveArchive,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6BEFE),
                      foregroundColor: const Color(0xFF4A3E6D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A3E6D)),
                            ),
                          )
                        : Text(
                            _getSubmitButtonText(),
                            style: const TextStyle(
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
        ],
      ),
    );
  }

  Widget _buildCategoryRadio(String label, ArchiveReason reason) {
    final isSelected = _selectedReason == reason;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReason = reason;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF6F0FD) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFFE5E5EA),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFFC7C7CC),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF7B6BA0) : Colors.white,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 10, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF4A3E6D) : const Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReasonSpecificFields() {
    switch (_selectedReason!) {
      case ArchiveReason.sold:
        return [
          // Sale Price
          TextField(
            controller: _salePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Sale Price',
              prefixText: '${FormatUtils.currencySymbol} ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C2C2E), fontSize: 15),
              labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kLilacLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Buyer Autocomplete
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _contacts.map((c) => c['name'] as String).toList();
              }
              return _contacts
                  .map((c) => c['name'] as String)
                  .where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) {
              _buyerController.text = selection;
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (_buyerController.text.isNotEmpty && controller.text.isEmpty) {
                controller.text = _buyerController.text;
              }
              controller.addListener(() {
                _buyerController.text = controller.text;
              });
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Buyer Name',
                  labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                  floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kLilacLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4A3E6D)),
                ),
                style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
              );
            },
          ),
          const SizedBox(height: 16),
        ];

      case ArchiveReason.cull:
        return [
          TextField(
            controller: _cullReasonController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Reason for Culling',
              labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kLilacLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD44C47), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
          ),
          const SizedBox(height: 16),
        ];

      case ArchiveReason.dead:
        return [
          TextField(
            controller: _deathCauseController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Cause of Death',
              labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kLilacLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF787774), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
          ),
          const SizedBox(height: 16),
        ];

      case ArchiveReason.butchered:
        return [
          TextField(
            controller: _yieldController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: FormatUtils.weightLabel('Yield Weight'),
              labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kLilacLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Processing Cost',
              prefixText: '${FormatUtils.currencySymbol} ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C2C2E), fontSize: 15),
              labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kLilacLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
          ),
          const SizedBox(height: 16),
        ];

      case ArchiveReason.stud:
        return [
          // Stud Fee (Optional)
          TextField(
            controller: _salePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Stud Fee (Optional)',
              prefixText: '${FormatUtils.currencySymbol} ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C2C2E), fontSize: 15),
              labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kLilacLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Client / Doe Owner Autocomplete
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return _contacts.map((c) => c['name'] as String).toList();
              }
              return _contacts
                  .map((c) => c['name'] as String)
                  .where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) {
              _buyerController.text = selection;
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (_buyerController.text.isNotEmpty && controller.text.isEmpty) {
                controller.text = _buyerController.text;
              }
              controller.addListener(() {
                _buyerController.text = controller.text;
              });
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Client / Doe Owner (Optional)',
                  labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                  floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 16),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kLilacLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4A3E6D)),
                ),
                style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
              );
            },
          ),
          const SizedBox(height: 16),
        ];
    }
  }

  Future<void> _saveArchive() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason'),
          backgroundColor: Color(0xFFD44C47),
        ),
      );
      return;
    }

    if (_selectedReason == ArchiveReason.sold) {
      if (_salePriceController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter sale price'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    if (_selectedReason == ArchiveReason.butchered) {
      if (_yieldController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter yield weight'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    if (_selectedReason == ArchiveReason.dead) {
      if (_deathCauseController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter cause of death'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    if (_selectedReason == ArchiveReason.cull) {
      if (_cullReasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter cull reason'),
            backgroundColor: Color(0xFFD44C47),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final salePrice = (_selectedReason == ArchiveReason.sold || _selectedReason == ArchiveReason.stud) && _salePriceController.text.trim().isNotEmpty
          ? double.tryParse(_salePriceController.text.trim())
          : null;
      final buyer = (_selectedReason == ArchiveReason.sold || _selectedReason == ArchiveReason.stud) && _buyerController.text.trim().isNotEmpty
          ? _buyerController.text.trim()
          : null;
      final yieldWeight = _selectedReason == ArchiveReason.butchered && _yieldController.text.trim().isNotEmpty
          ? double.tryParse(_yieldController.text.trim())
          : null;
      final cost = _selectedReason == ArchiveReason.butchered && _costController.text.trim().isNotEmpty
          ? double.tryParse(_costController.text.trim())
          : null;
      final deathCause = _selectedReason == ArchiveReason.dead && _deathCauseController.text.trim().isNotEmpty
          ? _deathCauseController.text.trim()
          : null;
      final cullReason = _selectedReason == ArchiveReason.cull && _cullReasonController.text.trim().isNotEmpty
          ? _cullReasonController.text.trim()
          : null;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      await _db.archiveRabbit(
        widget.rabbit.id,
        _selectedReason!,
        notes,
        salePrice,
        buyer,
        yieldWeight,
        cost,
        deathCause,
        cullReason,
        archiveDate: _archiveDate,
      );

      if (_selectedReason == ArchiveReason.sold && salePrice != null && salePrice > 0) {
        final transaction = finance.Transaction(
          id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
          type: finance.TransactionType.income,
          category: finance.TransactionCategory.soldKit,
          amount: salePrice,
          date: _archiveDate,
          description: 'Sold ${widget.rabbit.name} (${widget.rabbit.id})',
          notes: buyer != null ? 'Buyer: $buyer' : null,
          linkType: finance.LinkType.rabbit,
          rabbitId: widget.rabbit.id,
          buyerInfo: buyer,
        );
        await _db.insertTransaction(transaction);
      }

      if (_selectedReason == ArchiveReason.stud && salePrice != null && salePrice > 0) {
        final transaction = finance.Transaction(
          id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
          type: finance.TransactionType.income,
          category: finance.TransactionCategory.studFee,
          amount: salePrice,
          date: _archiveDate,
          description: 'Stud fee for ${widget.rabbit.name} (${widget.rabbit.id})',
          notes: buyer != null ? 'Client: $buyer' : null,
          linkType: finance.LinkType.rabbit,
          rabbitId: widget.rabbit.id,
          buyerInfo: buyer,
        );
        await _db.insertTransaction(transaction);
      }

      if (_selectedReason == ArchiveReason.butchered) {
        final butcherCost = cost ?? 0;
        final butcherYield = yieldWeight ?? 0;

        if (butcherYield > 0) {
          final transaction = finance.Transaction(
            id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
            type: finance.TransactionType.income,
            category: finance.TransactionCategory.meatHarvest,
            amount: butcherYield,
            date: _archiveDate,
            description: 'Butchered ${widget.rabbit.name} (${widget.rabbit.id}) - $butcherYield ${FormatUtils.weightUnit}',
            linkType: finance.LinkType.rabbit,
            rabbitId: widget.rabbit.id,
          );
          await _db.insertTransaction(transaction);
        }

        if (butcherCost > 0) {
          final expenseTransaction = finance.Transaction(
            id: 'txn_exp_${DateTime.now().millisecondsSinceEpoch}',
            type: finance.TransactionType.expense,
            category: finance.TransactionCategory.otherExpense,
            amount: butcherCost,
            date: _archiveDate,
            description: 'Processing cost for ${widget.rabbit.name}',
            linkType: finance.LinkType.rabbit,
            rabbitId: widget.rabbit.id,
          );
          await _db.insertTransaction(expenseTransaction);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.rabbit.name} archived successfully'),
            backgroundColor: const Color(0xFF7B6BA0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving rabbit: $e'),
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
}
