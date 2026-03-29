import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';
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

enum TransactionTypeFilter { all, income, expense }

class FinanceScreen extends StatefulWidget {
  final String? initialRabbitId;
  const FinanceScreen({Key? key, this.initialRabbitId}) : super(key: key);

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
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
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
    if (widget.initialRabbitId != null) {
      _groupingMode = GroupingMode.byRabbit;
      _expandedGroups.add(widget.initialRabbitId!);
    }
    _loadData();
  }

  void setRabbitFilter(String rabbitId) {
    setState(() {
      _groupingMode = GroupingMode.byRabbit;
      _expandedGroups.add(rabbitId);
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await _db.getAllTransactions();
      final rabbits = await _db.getAllRabbits();
      final litters = await _db.getLitters();
      final summary = await _db.getFinanceSummary();

      setState(() {
        _transactions = transactions;
        _rabbits = rabbits;
        _litters = litters;
        _totalIncome = summary['income'] ?? 0;
        _totalExpense = summary['expense'] ?? 0;
        _netAmount = summary['net'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading finance data: $e');
      setState(() => _isLoading = false);
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

      // Type filter
      if (_typeFilter != TransactionTypeFilter.all) {
        if (_typeFilter == TransactionTypeFilter.income && t.type != TransactionType.income) return false;
        if (_typeFilter == TransactionTypeFilter.expense && t.type != TransactionType.expense) return false;
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
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep),
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
        backgroundColor: kLilacDeep,
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(
          PhosphorIcons.plus(PhosphorIconsStyle.bold),
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kLilacWash,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Icon(PhosphorIcons.currencyDollar(PhosphorIconsStyle.duotone), color: kLilacDeep, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Finance & Ledger',
            style: TextStyle(
              color: kLilacText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      actions: [
        // Date filter button
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: _showDateFilterDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kLilacLight,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold), size: 14, color: kLilacText),
                  const SizedBox(width: 6),
                  Text(
                    _getDateFilterLabel(),
                    style: const TextStyle(
                      color: kLilacText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Export button
        IconButton(
          icon: Icon(PhosphorIcons.export(PhosphorIconsStyle.duotone), color: kLilacDeep),
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
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kNeutral200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'INCOME',
              _totalIncome,
              kBlueDeep,
              kBlueWash,
              kBlueLight,
              kBlueText,
              true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSummaryCard(
              'EXPENSE',
              _totalExpense,
              kPinkDeep,
              kPinkWash,
              kPinkLight,
              kPinkText,
              false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSummaryCard(
              'NET',
              _netAmount.abs(),
              kLilacDeep,
              kLilacWash,
              kLilacLight,
              kLilacText,
              true,
              isNet: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color deep, Color wash, Color light, Color text, bool isIncome, {bool isNet = false}) {
    bool isNegNet = isNet && _netAmount < 0;
    Color displayColor = isNegNet ? kPinkText : deep;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: light),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: text,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isNet 
                ? '${_netAmount >= 0 ? '+' : '−'}${FormatUtils.formatCurrencyShort(amount)}'
                : '${isIncome ? '+' : '−'}${FormatUtils.formatCurrencyShort(amount)}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: displayColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndGrouping() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kNeutral200)),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: kNeutral100,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: kNeutral300),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search entries...',
                  hintStyle: TextStyle(color: kNeutral500, fontSize: 13),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), color: kNeutral500, size: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Grouping button
          GestureDetector(
            onTap: _showGroupingMenu,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: kLilacWash,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: kLilacLight),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.rows(PhosphorIconsStyle.bold), color: kLilacDeep, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _getGroupingLabel(),
                    style: const TextStyle(
                      color: kLilacDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter button
          GestureDetector(
            onTap: _showFilterDialog,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: _typeFilter != TransactionTypeFilter.all ? kLilacLight : kNeutral300),
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIcons.funnel(PhosphorIconsStyle.bold), 
                      color: _typeFilter != TransactionTypeFilter.all ? kLilacDeep : kNeutral700, 
                      size: 18
                    ),
                  ),
                ),
                if (_typeFilter != TransactionTypeFilter.all)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: kLilacDeep,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
      final key = FormatUtils.formatMonthYear(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: kNeutral100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kNeutral200),
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold), size: 18, color: kNeutral500),
                    const SizedBox(width: 12),
                    Text(
                      monthKey,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kNeutral900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${monthTransactions.length} entries',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kNeutral600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${monthTotal >= 0 ? '+' : '−'}${FormatUtils.formatCurrencyShort(monthTotal.abs())}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: monthTotal >= 0 ? kBlueDeep : kPinkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold) : PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                      size: 16,
                      color: kNeutral400,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: kNeutral50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kNeutral200),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isGeneral ? kNeutral100 : kLilacWash,
                        border: Border.all(color: isGeneral ? kNeutral200 : kLilacLight),
                      ),
                      child: Icon(
                        isGeneral ? PhosphorIcons.house(PhosphorIconsStyle.fill) : PhosphorIcons.pawPrint(PhosphorIconsStyle.fill),
                        size: 18,
                        color: isGeneral ? kNeutral500 : kLilacDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGeneral ? 'General Herd' : _getRabbitName(key),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kNeutral900,
                            ),
                          ),
                          Text(
                            '${rabbitTransactions.length} entries',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kNeutral600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      FormatUtils.formatCurrencySigned(total),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: total >= 0 ? kBlueDeep : kPinkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold) : PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                      size: 16,
                      color: kNeutral400,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: kNeutral100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kNeutral200),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.gitBranch(PhosphorIconsStyle.duotone),
                      size: 18,
                      color: isNoLitter ? kNeutral500 : kLilacDeep,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isNoLitter ? 'No Litter' : key,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kNeutral900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${litterTransactions.length} entries',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kNeutral600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      FormatUtils.formatCurrencySigned(total),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: total >= 0 ? kBlueDeep : kPinkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold) : PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                      size: 16,
                      color: kNeutral400,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: kNeutral50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kNeutral200),
                ),
                child: Row(
                  children: [
                    _getCategoryIcon(category, isIncome: total >= 0),
                    const SizedBox(width: 12),
                    Text(
                      categoryTransactions.first.categoryName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kNeutral900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${categoryTransactions.length} entries',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kNeutral600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      FormatUtils.formatCurrencySigned(total),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: total >= 0 ? kBlueDeep : kPinkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold) : PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                      size: 16,
                      color: kNeutral400,
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
          final dateStr = FormatUtils.formatDateShort(firstTxn.date);

          return GestureDetector(
            onTap: () {
              // Show batch details
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: kLilacWash,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kLilacLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        PhosphorIcons.stack(PhosphorIconsStyle.bold),
                        size: 20,
                        color: kLilacDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${firstTxn.categoryName} (×${batchTransactions.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kNeutral900,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$dateStr • ${firstTxn.litterId ?? 'Litter'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: kNeutral500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    FormatUtils.formatCurrencyShort(total),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kLilacDeep,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), color: kNeutral400, size: 16),
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
    final dateStr = FormatUtils.formatDateShort(t.date);
    final themeColor = isIncome ? kBlueDeep : kPinkDeep;
    final themeWash = isIncome ? kBlueWash : kPinkWash;
    final themeLight = isIncome ? kBlueLight : kPinkLight;

    return GestureDetector(
      onTap: () => _editTransaction(t),
      onLongPress: () => _showTransactionOptions(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: kNeutral200)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon box
            if (showCategory)
              Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: themeWash,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeLight),
                ),
                child: _getCategoryIcon(t.category, isIncome: isIncome),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kNeutral900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (t.isBatchTransaction) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kLilacWash,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: kLilacLight),
                          ),
                          child: const Text(
                            'Batch',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: kLilacDeep,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (showRabbit && t.rabbitId != null)
                        Row(
                          children: [
                            Icon(
                              t.linkType == LinkType.litter ? PhosphorIcons.gitBranch(PhosphorIconsStyle.bold) : PhosphorIcons.pawPrint(PhosphorIconsStyle.bold),
                              size: 11,
                              color: kNeutral500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t.linkType == LinkType.litter ? t.litterId ?? '' : _getRabbitName(t.rabbitId),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kNeutral600,
                              ),
                            ),
                          ],
                        )
                      else if (t.linkType == LinkType.general)
                        Row(
                          children: [
                            Icon(PhosphorIcons.house(PhosphorIconsStyle.bold), size: 11, color: kNeutral500),
                            const SizedBox(width: 4),
                            const Text(
                              'General Herd',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kNeutral600,
                              ),
                            ),
                          ],
                        ),
                      if (t.description != null && t.description!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: kNeutral400, fontSize: 11)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: kNeutral500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: kNeutral400,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            const SizedBox(width: 12),
            Text(
              '${isIncome ? '+' : '−'}${FormatUtils.formatCurrency(t.amount)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isIncome ? kBlueDeep : kPinkText,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCategoryIcon(TransactionCategory category, {required bool isIncome}) {
    IconData iconData;
    Color color = isIncome ? kBlueDeep : kPinkDeep;

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

    return Icon(iconData, size: 20, color: color);
  }

  Color _getCategoryColor(TransactionCategory category) {
    if (category.index <= 2 || category == TransactionCategory.otherIncome || category == TransactionCategory.manureSales) {
      return kBlueDeep;
    }
    return kPinkDeep;
  }

  void _showGroupingMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Group By',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kNeutral900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildGroupingOption(GroupingMode.chronological, 'Chronological', PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold), setModalState),
              _buildGroupingOption(GroupingMode.byMonth, 'By Month', PhosphorIcons.calendar(PhosphorIconsStyle.bold), setModalState),
              _buildGroupingOption(GroupingMode.byRabbit, 'By Rabbit', PhosphorIcons.pawPrint(PhosphorIconsStyle.bold), setModalState),
              _buildGroupingOption(GroupingMode.byLitter, 'By Litter', PhosphorIcons.gitBranch(PhosphorIconsStyle.bold), setModalState),
              _buildGroupingOption(GroupingMode.byCategory, 'By Category', PhosphorIcons.tag(PhosphorIconsStyle.bold), setModalState),
              _buildGroupingOption(GroupingMode.byBatch, 'By Batch', PhosphorIcons.stack(PhosphorIconsStyle.bold), setModalState),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupingOption(GroupingMode mode, String label, IconData icon, StateSetter setModalState) {
    final isSelected = _groupingMode == mode;

    return GestureDetector(
      onTap: () {
        setModalState(() => _groupingMode = mode); // Update modal's local state
        setState(() { // Update main state and trigger rebuild of the underlying screen
          _groupingMode = mode;
          _expandedGroups.clear();
        });
        Navigator.pop(context); // Close the modal
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? kLilacWash : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? kLilacLight : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? kLilacDeep : kNeutral500, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? kLilacDeep : kNeutral700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: kLilacDeep, size: 16),
          ],
        ),
      ),
    );
  }

  void _showDateFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kNeutral900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildDateFilterOption(DateFilter.allTime, 'All Time'),
            _buildDateFilterOption(DateFilter.thisMonth, 'This Month'),
            _buildDateFilterOption(DateFilter.lastMonth, 'Last Month'),
            _buildDateFilterOption(DateFilter.thisYear, 'This Year'),
            _buildDateFilterOption(DateFilter.custom, 'Custom Range'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterOption(DateFilter filter, String label) {
    final isSelected = _dateFilter == filter;

    return GestureDetector(
      onTap: () {
        if (filter == DateFilter.custom) {
          Navigator.pop(context);
          _showCustomDateRangePicker();
        } else {
          setState(() => _dateFilter = filter);
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? kLilacWash : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? kLilacLight : Colors.transparent),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? kLilacDeep : kNeutral700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: kLilacDeep, size: 16),
          ],
        ),
      ),
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
    // Current selection for the modal
    TransactionTypeFilter tempFilter = _typeFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kNeutral900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: kNeutral600, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'TRANSACTION TYPE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: kNeutral500,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFilterChip(TransactionTypeFilter.all, 'All', PhosphorIcons.list(PhosphorIconsStyle.bold), tempFilter, (newFilter) {
                    setModalState(() => tempFilter = newFilter);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip(TransactionTypeFilter.income, 'Income', PhosphorIcons.trendUp(PhosphorIconsStyle.bold), tempFilter, (newFilter) {
                    setModalState(() => tempFilter = newFilter);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip(TransactionTypeFilter.expense, 'Expense', PhosphorIcons.trendDown(PhosphorIconsStyle.bold), tempFilter, (newFilter) {
                    setModalState(() => tempFilter = newFilter);
                  }),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() => tempFilter = TransactionTypeFilter.all);
                        setState(() => _typeFilter = TransactionTypeFilter.all);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: kNeutral100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Clear All',
                            style: TextStyle(fontWeight: FontWeight.w700, color: kNeutral600),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _typeFilter = tempFilter);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: kLilacDeep,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: kLilacDeep.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Apply',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(TransactionTypeFilter type, String label, IconData icon, TransactionTypeFilter current, Function(TransactionTypeFilter) onSelect) {
    bool isSelected = current == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kLilacWash : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? kLilacLight : kNeutral200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? kLilacDeep : kNeutral500,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? kLilacText : kNeutral500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              leading: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold), color: kNeutral700),
              title: const Text('Edit Transaction', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _editTransaction(t);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIcons.copy(PhosphorIconsStyle.bold), color: Color(0xFF787774)),
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
