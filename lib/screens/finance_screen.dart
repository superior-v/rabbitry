import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../services/database_service.dart';
import 'add_transaction_screen.dart';

enum GroupingMode {
  chronological,
  byRabbit,
  byLitter,
  byCategory,
  byMonth,
  byBatch,
}

enum DateFilter {
  allTime,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

class FinanceScreen extends StatefulWidget {
  @override
  _FinanceScreenState createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final DatabaseService _db = DatabaseService();

  List<Transaction> _transactions = [];
  List<Rabbit> _rabbits = [];
  // ignore: unused_field
  List<Litter> _litters = [];

  bool _isLoading = true;
  String _searchQuery = '';
  GroupingMode _groupingMode = GroupingMode.chronological;
  DateFilter _dateFilter = DateFilter.allTime;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Summary values
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netAmount = 0;

  // Expanded groups tracking
  Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await _db.getAllTransactions();
      final rabbits = await _db.getAllRabbits();
      final litters = await _db.getLitters();
      final summary = await _db.getFinanceSummary();

      // Initialize with sample data if empty
      if (transactions.isEmpty) {
        await _initializeSampleTransactions();
        final reloadedTransactions = await _db.getAllTransactions();
        final reloadedSummary = await _db.getFinanceSummary();

        setState(() {
          _transactions = reloadedTransactions;
          _rabbits = rabbits;
          _litters = litters;
          _totalIncome = reloadedSummary['income'] ?? 0;
          _totalExpense = reloadedSummary['expense'] ?? 0;
          _netAmount = reloadedSummary['net'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _transactions = transactions;
          _rabbits = rabbits;
          _litters = litters;
          _totalIncome = summary['income'] ?? 0;
          _totalExpense = summary['expense'] ?? 0;
          _netAmount = summary['net'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading finance data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeSampleTransactions() async {
    final sampleTransactions = [
      // January 2026
      Transaction(
        id: 'txn_001',
        type: TransactionType.income,
        category: TransactionCategory.soldKit,
        amount: 45.00,
        date: DateTime(2026, 1, 23),
        description: 'Kit #1 - Black Otter, Buck',
        linkType: LinkType.rabbit,
        rabbitId: 'D-101',
        litterId: 'L-105',
        batchId: 'batch_001',
        isBatchTransaction: true,
      ),
      Transaction(
        id: 'txn_002',
        type: TransactionType.income,
        category: TransactionCategory.soldKit,
        amount: 45.00,
        date: DateTime(2026, 1, 23),
        description: 'Kit #2 - Black Otter, Doe',
        linkType: LinkType.rabbit,
        rabbitId: 'D-101',
        litterId: 'L-105',
        batchId: 'batch_001',
        isBatchTransaction: true,
      ),
      Transaction(
        id: 'txn_003',
        type: TransactionType.income,
        category: TransactionCategory.soldKit,
        amount: 45.00,
        date: DateTime(2026, 1, 23),
        description: 'Kit #3 - Broken, Buck',
        linkType: LinkType.rabbit,
        rabbitId: 'D-101',
        litterId: 'L-105',
        batchId: 'batch_001',
        isBatchTransaction: true,
      ),
      Transaction(
        id: 'txn_004',
        type: TransactionType.expense,
        category: TransactionCategory.medical,
        amount: 12.50,
        date: DateTime(2026, 1, 20),
        description: 'Antibiotics',
        linkType: LinkType.rabbit,
        rabbitId: 'D-101',
      ),
      Transaction(
        id: 'txn_005',
        type: TransactionType.expense,
        category: TransactionCategory.feed,
        amount: 24.00,
        date: DateTime(2026, 1, 15),
        description: '50lb Pellets',
        linkType: LinkType.general,
      ),
      Transaction(
        id: 'txn_006',
        type: TransactionType.income,
        category: TransactionCategory.meatHarvest,
        amount: 18.00,
        date: DateTime(2026, 1, 12),
        description: 'Litter L-078 Cull • Virtual',
        linkType: LinkType.litter,
        litterId: 'L-078',
      ),
      Transaction(
        id: 'txn_007',
        type: TransactionType.expense,
        category: TransactionCategory.showFee,
        amount: 35.00,
        date: DateTime(2026, 1, 5),
        description: 'Nationals Entry',
        linkType: LinkType.rabbit,
        rabbitId: 'B-02',
      ),
      // December 2025
      Transaction(
        id: 'txn_008',
        type: TransactionType.income,
        category: TransactionCategory.studFee,
        amount: 50.00,
        date: DateTime(2025, 12, 28),
        description: 'Service for Jane Doe',
        linkType: LinkType.rabbit,
        rabbitId: 'B-02',
      ),
      Transaction(
        id: 'txn_009',
        type: TransactionType.expense,
        category: TransactionCategory.equipment,
        amount: 150.00,
        date: DateTime(2025, 12, 15),
        description: 'New Cages',
        linkType: LinkType.general,
      ),
      Transaction(
        id: 'txn_010',
        type: TransactionType.expense,
        category: TransactionCategory.vetVisit,
        amount: 60.00,
        date: DateTime(2025, 12, 12),
        description: 'Routine Checkup',
        linkType: LinkType.rabbit,
        rabbitId: 'EXT-001',
      ),
      Transaction(
        id: 'txn_011',
        type: TransactionType.expense,
        category: TransactionCategory.feed,
        amount: 22.00,
        date: DateTime(2025, 12, 10),
        description: '50lb Pellets',
        linkType: LinkType.general,
      ),
      Transaction(
        id: 'txn_012',
        type: TransactionType.income,
        category: TransactionCategory.manureSales,
        amount: 15.00,
        date: DateTime(2025, 12, 5),
        description: 'Compost',
        linkType: LinkType.general,
      ),
      // November 2025
      Transaction(
        id: 'txn_013',
        type: TransactionType.expense,
        category: TransactionCategory.medical,
        amount: 25.00,
        date: DateTime(2025, 11, 20),
        description: 'Mastitis Treatment',
        linkType: LinkType.rabbit,
        rabbitId: 'D-101',
      ),
      Transaction(
        id: 'txn_014',
        type: TransactionType.expense,
        category: TransactionCategory.feed,
        amount: 22.00,
        date: DateTime(2025, 11, 10),
        description: '50lb Pellets',
        linkType: LinkType.general,
      ),
      Transaction(
        id: 'txn_015',
        type: TransactionType.expense,
        category: TransactionCategory.medical,
        amount: 18.00,
        date: DateTime(2025, 11, 5),
        description: 'Ear Mite Treatment',
        linkType: LinkType.rabbit,
        rabbitId: 'B-01',
      ),
      // October 2025
      Transaction(
        id: 'txn_016',
        type: TransactionType.income,
        category: TransactionCategory.studFee,
        amount: 50.00,
        date: DateTime(2025, 10, 15),
        description: 'Service',
        linkType: LinkType.rabbit,
        rabbitId: 'B-01',
      ),
      Transaction(
        id: 'txn_017',
        type: TransactionType.expense,
        category: TransactionCategory.supplies,
        amount: 15.00,
        date: DateTime(2025, 10, 10),
        description: 'Tattoo Ink',
        linkType: LinkType.general,
      ),
      Transaction(
        id: 'txn_018',
        type: TransactionType.income,
        category: TransactionCategory.soldKit,
        amount: 35.00,
        date: DateTime(2025, 10, 1),
        description: 'Litter L-085',
        linkType: LinkType.litter,
        litterId: 'L-085',
        rabbitId: 'D-101',
      ),
      // September 2025
      Transaction(
        id: 'txn_019',
        type: TransactionType.expense,
        category: TransactionCategory.otherExpense,
        amount: 6.00,
        date: DateTime(2025, 9, 25),
        description: 'ARBA Registration',
        linkType: LinkType.rabbit,
        rabbitId: 'D-101',
      ),
      Transaction(
        id: 'txn_020',
        type: TransactionType.expense,
        category: TransactionCategory.feed,
        amount: 21.00,
        date: DateTime(2025, 9, 20),
        description: '50lb Pellets',
        linkType: LinkType.general,
      ),
      Transaction(
        id: 'txn_021',
        type: TransactionType.income,
        category: TransactionCategory.meatHarvest,
        amount: 18.00,
        date: DateTime(2025, 9, 10),
        description: 'Litter L-078 Cull • Virtual',
        linkType: LinkType.litter,
        litterId: 'L-078',
      ),
      // August 2025
      Transaction(
        id: 'txn_022',
        type: TransactionType.income,
        category: TransactionCategory.soldKit,
        amount: 40.00,
        date: DateTime(2025, 8, 28),
        description: 'Litter L-070 (Sire Link)',
        linkType: LinkType.rabbit,
        rabbitId: 'B-02',
        litterId: 'L-070',
      ),
      Transaction(
        id: 'txn_023',
        type: TransactionType.expense,
        category: TransactionCategory.equipment,
        amount: 45.00,
        date: DateTime(2025, 8, 20),
        description: 'Travel Cage',
        linkType: LinkType.general,
      ),
      Transaction(
        id: 'txn_024',
        type: TransactionType.expense,
        category: TransactionCategory.supplies,
        amount: 14.00,
        date: DateTime(2025, 8, 15),
        description: 'Nutri-Drops',
        linkType: LinkType.general,
      ),
    ];

    for (var transaction in sampleTransactions) {
      await _db.insertTransaction(transaction);
    }
  }

  List<Transaction> get _filteredTransactions {
    var filtered = _transactions.where((t) {
      // Date filter
      if (_dateFilter != DateFilter.allTime) {
        final now = DateTime.now();
        DateTime startDate;
        DateTime endDate = now;

        switch (_dateFilter) {
          case DateFilter.thisMonth:
            startDate = DateTime(now.year, now.month, 1);
            break;
          case DateFilter.lastMonth:
            startDate = DateTime(now.year, now.month - 1, 1);
            endDate = DateTime(now.year, now.month, 0);
            break;
          case DateFilter.thisYear:
            startDate = DateTime(now.year, 1, 1);
            break;
          case DateFilter.custom:
            startDate = _customStartDate ?? DateTime(2020);
            endDate = _customEndDate ?? now;
            break;
          default:
            startDate = DateTime(2020);
        }

        if (t.date.isBefore(startDate) || t.date.isAfter(endDate)) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesDescription = t.description?.toLowerCase().contains(query) ?? false;
        final matchesCategory = t.categoryName.toLowerCase().contains(query);
        final matchesRabbit = t.rabbitId?.toLowerCase().contains(query) ?? false;

        if (!matchesDescription && !matchesCategory && !matchesRabbit) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  String _getRabbitName(String? rabbitId) {
    if (rabbitId == null) return 'Unknown';
    final rabbit = _rabbits.firstWhere(
      (r) => r.id == rabbitId,
      orElse: () => Rabbit(id: rabbitId, name: rabbitId, type: RabbitType.doe, status: RabbitStatus.open, breed: ''),
    );
    return '${rabbit.name} ($rabbitId)';
  }

  // ignore: unused_element
  String _getLitterName(String? litterId) {
    if (litterId == null) return 'Unknown';
    return litterId;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildSearchAndGrouping(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildTransactionList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'finance_fab',
        onPressed: _addTransaction,
        backgroundColor: Color(0xFF0F7B6C),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Finance & Ledger',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        // Date filter button
        TextButton.icon(
          onPressed: _showDateFilterDialog,
          icon: Icon(Icons.calendar_today, size: 16, color: Colors.black87),
          label: Text(
            _getDateFilterLabel(),
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ),
        // Export button
        IconButton(
          icon: Icon(PhosphorIcons.export(PhosphorIconsStyle.regular), color: Colors.black87),
          onPressed: _exportData,
        ),
      ],
    );
  }

  String _getDateFilterLabel() {
    switch (_dateFilter) {
      case DateFilter.allTime:
        return 'All Time';
      case DateFilter.thisMonth:
        return 'This Month';
      case DateFilter.lastMonth:
        return 'Last Month';
      case DateFilter.thisYear:
        return 'This Year';
      case DateFilter.custom:
        return 'Custom';
    }
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'INCOME',
              _totalIncome,
              Color(0xFF0F7B6C),
              isIncome: true,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'EXPENSE',
              _totalExpense,
              Color(0xFFDC2626),
              isIncome: false,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF0F7B6C), width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'NET',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF787774),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_netAmount >= 0 ? '+' : ''}\$${_netAmount.abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _netAmount >= 0 ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
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

  Widget _buildSummaryCard(String label, double amount, Color color, {required bool isIncome}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF787774),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndGrouping() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFE9E9E7)),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Color(0xFF9B9A97), fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF787774), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          // Grouping button
          GestureDetector(
            onTap: _showGroupingMenu,
            child: Container(
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Color(0xFF37352F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.view_agenda, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    _getGroupingLabel(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          // Filter button
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(0xFFE9E9E7)),
            ),
            child: IconButton(
              icon: Icon(Icons.filter_list, color: Colors.black87, size: 20),
              onPressed: _showFilterDialog,
            ),
          ),
        ],
      ),
    );
  }

  String _getGroupingLabel() {
    switch (_groupingMode) {
      case GroupingMode.chronological:
        return 'Month';
      case GroupingMode.byRabbit:
        return 'Rabbit';
      case GroupingMode.byLitter:
        return 'Litter';
      case GroupingMode.byCategory:
        return 'Category';
      case GroupingMode.byMonth:
        return 'Month';
      case GroupingMode.byBatch:
        return 'Batch';
    }
  }

  Widget _buildTransactionList() {
    final transactions = _filteredTransactions;

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.receipt(PhosphorIconsStyle.duotone), size: 64, color: Color(0xFFE9E9E7)),
            SizedBox(height: 16),
            Text(
              'No transactions found',
              style: TextStyle(
                color: Color(0xFF787774),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    switch (_groupingMode) {
      case GroupingMode.chronological:
      case GroupingMode.byMonth:
        return _buildMonthGroupedList(transactions);
      case GroupingMode.byRabbit:
        return _buildRabbitGroupedList(transactions);
      case GroupingMode.byLitter:
        return _buildLitterGroupedList(transactions);
      case GroupingMode.byCategory:
        return _buildCategoryGroupedList(transactions);
      case GroupingMode.byBatch:
        return _buildBatchGroupedList(transactions);
    }
  }

  Widget _buildMonthGroupedList(List<Transaction> transactions) {
    // Group by month
    Map<String, List<Transaction>> grouped = {};
    for (var t in transactions) {
      final key = DateFormat('MMMM yyyy').format(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final monthKey = grouped.keys.elementAt(index);
        final monthTransactions = grouped[monthKey]!;
        final monthTotal = monthTransactions.fold<double>(
          0,
          (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount),
        );
        final isExpanded = _expandedGroups.contains(monthKey);

        return Column(
          children: [
            // Month header
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroups.remove(monthKey);
                  } else {
                    _expandedGroups.add(monthKey);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Color(0xFF787774)),
                    SizedBox(width: 12),
                    Text(
                      monthKey,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${monthTransactions.length} entries',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9B9A97),
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${monthTotal >= 0 ? '+' : ''}\$${monthTotal.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: monthTotal >= 0 ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Color(0xFF787774),
                    ),
                  ],
                ),
              ),
            ),
            // Transactions
            if (isExpanded) ...monthTransactions.map((t) => _buildTransactionCard(t)),
          ],
        );
      },
    );
  }

  Widget _buildRabbitGroupedList(List<Transaction> transactions) {
    // Group by rabbit
    Map<String, List<Transaction>> grouped = {};

    for (var t in transactions) {
      String key;
      if (t.linkType == LinkType.general || t.rabbitId == null) {
        key = 'general_herd';
      } else {
        key = t.rabbitId!;
      }
      grouped.putIfAbsent(key, () => []).add(t);
    }

    // Sort by total amount descending
    var sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'general_herd') return 1;
        if (b == 'general_herd') return -1;
        final aTotal = grouped[a]!.fold<double>(0, (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount));
        final bTotal = grouped[b]!.fold<double>(0, (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount));
        return bTotal.compareTo(aTotal);
      });

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final rabbitTransactions = grouped[key]!;
        final total = rabbitTransactions.fold<double>(
          0,
          (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount),
        );
        final isExpanded = _expandedGroups.contains(key);
        final isGeneral = key == 'general_herd';

        return Column(
          children: [
            // Rabbit header
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroups.remove(key);
                  } else {
                    _expandedGroups.add(key);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isGeneral ? Color(0xFFF7F7F5) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE9E9E7)),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isGeneral ? Color(0xFFE9E9E7) : Color(0xFFE8F5F3),
                      ),
                      child: Icon(
                        isGeneral ? Icons.home : Icons.pets,
                        size: 20,
                        color: isGeneral ? Color(0xFF787774) : Color(0xFF0F7B6C),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGeneral ? 'General Herd' : _getRabbitName(key),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${rabbitTransactions.length} entries',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9B9A97),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${total >= 0 ? '+' : ''}\$${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: total >= 0 ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Color(0xFF787774),
                    ),
                  ],
                ),
              ),
            ),
            // Transactions
            if (isExpanded) ...rabbitTransactions.map((t) => _buildTransactionCard(t, showRabbit: false)),
          ],
        );
      },
    );
  }

  Widget _buildLitterGroupedList(List<Transaction> transactions) {
    // Group by litter
    Map<String, List<Transaction>> grouped = {};

    for (var t in transactions) {
      String key = t.litterId ?? 'no_litter';
      grouped.putIfAbsent(key, () => []).add(t);
    }

    var sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'no_litter') return 1;
        if (b == 'no_litter') return -1;
        return b.compareTo(a);
      });

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final litterTransactions = grouped[key]!;
        final total = litterTransactions.fold<double>(
          0,
          (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount),
        );
        final isExpanded = _expandedGroups.contains(key);
        final isNoLitter = key == 'no_litter';

        return Column(
          children: [
            // Litter header
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroups.remove(key);
                  } else {
                    _expandedGroups.add(key);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.gitBranch(PhosphorIconsStyle.duotone),
                      size: 20,
                      color: isNoLitter ? Color(0xFF787774) : Color(0xFF0F7B6C),
                    ),
                    SizedBox(width: 12),
                    Text(
                      isNoLitter ? 'No Litter' : key,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${litterTransactions.length} entries',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9B9A97),
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${total >= 0 ? '+' : ''}\$${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: total >= 0 ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Color(0xFF787774),
                    ),
                  ],
                ),
              ),
            ),
            // Transactions
            if (isExpanded) ...litterTransactions.map((t) => _buildTransactionCard(t)),
          ],
        );
      },
    );
  }

  Widget _buildCategoryGroupedList(List<Transaction> transactions) {
    // Group by category
    Map<TransactionCategory, List<Transaction>> grouped = {};

    for (var t in transactions) {
      grouped.putIfAbsent(t.category, () => []).add(t);
    }

    var sortedCategories = grouped.keys.toList()
      ..sort((a, b) {
        final aTotal = grouped[a]!.fold<double>(0, (sum, t) => sum + t.amount);
        final bTotal = grouped[b]!.fold<double>(0, (sum, t) => sum + t.amount);
        return bTotal.compareTo(aTotal);
      });

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final categoryTransactions = grouped[category]!;
        final total = categoryTransactions.fold<double>(
          0,
          (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount),
        );
        final isExpanded = _expandedGroups.contains(category.toString());

        return Column(
          children: [
            // Category header
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedGroups.remove(category.toString());
                  } else {
                    _expandedGroups.add(category.toString());
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _getCategoryIcon(category),
                    SizedBox(width: 12),
                    Text(
                      categoryTransactions.first.categoryName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${categoryTransactions.length} entries',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9B9A97),
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${total >= 0 ? '+' : ''}\$${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: total >= 0 ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Color(0xFF787774),
                    ),
                  ],
                ),
              ),
            ),
            // Transactions
            if (isExpanded) ...categoryTransactions.map((t) => _buildTransactionCard(t, showCategory: false)),
          ],
        );
      },
    );
  }

  Widget _buildBatchGroupedList(List<Transaction> transactions) {
    // Separate batch and individual transactions
    Map<String, List<Transaction>> batches = {};
    List<Transaction> individual = [];

    for (var t in transactions) {
      if (t.isBatchTransaction && t.batchId != null) {
        batches.putIfAbsent(t.batchId!, () => []).add(t);
      } else {
        individual.add(t);
      }
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Batch transactions
        ...batches.entries.map((entry) {
          final batchTransactions = entry.value;
          final total = batchTransactions.fold<double>(0, (sum, t) => sum + t.amount);
          final firstTxn = batchTransactions.first;
          final dateStr = DateFormat('MMM d').format(firstTxn.date);

          return GestureDetector(
            onTap: () {
              // Show batch details
            },
            child: Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Color(0xFFE8F5F3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF0F7B6C).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.tag(PhosphorIconsStyle.duotone),
                    size: 24,
                    color: Color(0xFF0F7B6C),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${firstTxn.categoryName} (×${batchTransactions.length})',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFF0F7B6C),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Batch',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          '$dateStr • ${firstTxn.litterId ?? 'Unknown Litter'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9B9A97),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+\$${total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F7B6C),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Color(0xFF787774)),
                ],
              ),
            ),
          );
        }),

        // Individual transactions header
        if (individual.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'INDIVIDUAL TRANSACTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9B9A97),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...individual.map((t) => _buildTransactionCard(t)),
        ],
      ],
    );
  }

  Widget _buildTransactionCard(Transaction t, {bool showRabbit = true, bool showCategory = true}) {
    final isIncome = t.type == TransactionType.income;
    final dateStr = DateFormat('MMM d').format(t.date);

    return GestureDetector(
      onTap: () => _editTransaction(t),
      onLongPress: () => _showTransactionOptions(t),
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE9E9E7)),
        ),
        child: Row(
          children: [
            // Category icon
            if (showCategory)
              Container(
                width: 40,
                height: 40,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _getCategoryColor(t.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _getCategoryIcon(t.category),
              ),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        t.categoryName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (t.isBatchTransaction) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFFE8F5F3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Batch',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F7B6C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  if (showRabbit && t.rabbitId != null)
                    Row(
                      children: [
                        Icon(
                          t.linkType == LinkType.litter ? PhosphorIcons.gitBranch(PhosphorIconsStyle.regular) : Icons.pets,
                          size: 12,
                          color: Color(0xFF9B9A97),
                        ),
                        SizedBox(width: 4),
                        Text(
                          t.linkType == LinkType.litter ? t.litterId ?? '' : _getRabbitName(t.rabbitId),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9B9A97),
                          ),
                        ),
                      ],
                    )
                  else if (t.linkType == LinkType.general)
                    Row(
                      children: [
                        Icon(Icons.home, size: 12, color: Color(0xFF9B9A97)),
                        SizedBox(width: 4),
                        Text(
                          'General Herd',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9B9A97),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: 2),
                  Text(
                    '$dateStr${t.description != null ? ' • ${t.description}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B9A97),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              '${isIncome ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isIncome ? Color(0xFF0F7B6C) : Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCategoryIcon(TransactionCategory category) {
    IconData iconData;
    Color color = _getCategoryColor(category);

    switch (category) {
      case TransactionCategory.soldKit:
        iconData = PhosphorIcons.tag(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.medical:
        iconData = PhosphorIcons.firstAidKit(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.feed:
        iconData = PhosphorIcons.bowlFood(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.meatHarvest:
        iconData = PhosphorIcons.knife(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.showFee:
        iconData = PhosphorIcons.trophy(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.studFee:
        iconData = PhosphorIcons.genderMale(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.equipment:
        iconData = PhosphorIcons.wrench(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.vetVisit:
        iconData = PhosphorIcons.stethoscope(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.manureSales:
        iconData = PhosphorIcons.leaf(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.supplies:
        iconData = PhosphorIcons.package(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.otherExpense:
        iconData = PhosphorIcons.receipt(PhosphorIconsStyle.duotone);
        break;
      case TransactionCategory.otherIncome:
        iconData = PhosphorIcons.coins(PhosphorIconsStyle.duotone);
        break;
    }

    return Icon(iconData, size: 22, color: color);
  }

  Color _getCategoryColor(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.soldKit:
        return Color(0xFF0F7B6C);
      case TransactionCategory.medical:
        return Color(0xFFDC2626);
      case TransactionCategory.feed:
        return Color(0xFF0F7B6C);
      case TransactionCategory.meatHarvest:
        return Color(0xFF787774);
      case TransactionCategory.showFee:
        return Color(0xFFDC2626);
      case TransactionCategory.studFee:
        return Color(0xFF2E7BB5);
      case TransactionCategory.equipment:
        return Color(0xFFDC2626);
      case TransactionCategory.vetVisit:
        return Color(0xFFDC2626);
      case TransactionCategory.manureSales:
        return Color(0xFF0F7B6C);
      case TransactionCategory.supplies:
        return Color(0xFFDC2626);
      case TransactionCategory.otherExpense:
        return Color(0xFFDC2626);
      case TransactionCategory.otherIncome:
        return Color(0xFF0F7B6C);
    }
  }

  void _showGroupingMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group By',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            _buildGroupingOption(GroupingMode.chronological, 'Chronological', Icons.list),
            _buildGroupingOption(GroupingMode.byRabbit, 'By Rabbit', Icons.pets),
            _buildGroupingOption(GroupingMode.byLitter, 'By Litter', PhosphorIcons.gitBranch(PhosphorIconsStyle.regular)),
            _buildGroupingOption(GroupingMode.byCategory, 'By Category', Icons.category),
            _buildGroupingOption(GroupingMode.byMonth, 'By Month', Icons.calendar_today),
            _buildGroupingOption(GroupingMode.byBatch, 'By Batch', PhosphorIcons.stack(PhosphorIconsStyle.regular)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupingOption(GroupingMode mode, String label, IconData icon) {
    final isSelected = _groupingMode == mode;

    return ListTile(
      leading: Icon(icon, color: isSelected ? Color(0xFF0F7B6C) : Color(0xFF787774)),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Color(0xFF0F7B6C) : Colors.black87,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Color(0xFF0F7B6C)) : null,
      onTap: () {
        setState(() {
          _groupingMode = mode;
          _expandedGroups.clear();
        });
        Navigator.pop(context);
      },
    );
  }

  void _showDateFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            _buildDateFilterOption(DateFilter.allTime, 'All Time'),
            _buildDateFilterOption(DateFilter.thisMonth, 'This Month'),
            _buildDateFilterOption(DateFilter.lastMonth, 'Last Month'),
            _buildDateFilterOption(DateFilter.thisYear, 'This Year'),
            _buildDateFilterOption(DateFilter.custom, 'Custom Range'),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterOption(DateFilter filter, String label) {
    final isSelected = _dateFilter == filter;

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Color(0xFF0F7B6C) : Colors.black87,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Color(0xFF0F7B6C)) : null,
      onTap: () {
        if (filter == DateFilter.custom) {
          Navigator.pop(context);
          _showCustomDateRangePicker();
        } else {
          setState(() => _dateFilter = filter);
          Navigator.pop(context);
        }
      },
    );
  }

  void _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null ? DateTimeRange(start: _customStartDate!, end: _customEndDate!) : null,
    );

    if (picked != null) {
      setState(() {
        _dateFilter = DateFilter.custom;
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  void _showFilterDialog() {
    // TODO: Implement filter dialog for income/expense type filtering
  }

  void _addTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTransactionScreen()),
    );

    if (result == true) {
      await _loadData();
    }
  }

  void _editTransaction(Transaction transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  void _showTransactionOptions(Transaction t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Color(0xFF0F7B6C)),
              title: Text('Edit Transaction'),
              onTap: () {
                Navigator.pop(context);
                _editTransaction(t);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: Color(0xFF787774)),
              title: Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicateTransaction(t);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Color(0xFFDC2626)),
              title: Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
              onTap: () {
                Navigator.pop(context);
                _deleteTransaction(t);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _duplicateTransaction(Transaction t) async {
    final newTransaction = t.copyWith(
      id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
    );

    await _db.insertTransaction(newTransaction);
    await _loadData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Transaction duplicated')),
    );
  }

  void _deleteTransaction(Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete this ${t.categoryName} transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteTransaction(t.id);
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction deleted')),
      );
    }
  }

  void _exportData() {
    // TODO: Implement CSV/PDF export
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export feature coming soon!')),
    );
  }
}
