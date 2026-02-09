import '../models/finance_transaction.dart';

class FinanceCategories {
  static final Map<String, TransactionCategory> income = {
    'sold_kit': TransactionCategory(
      key: 'sold_kit',
      label: 'Sold Kit',
      icon: 'sell',
      type: TransactionType.income,
    ),
    'meat_harvest': TransactionCategory(
      key: 'meat_harvest',
      label: 'Meat Harvest',
      icon: 'restaurant',
      type: TransactionType.income,
      isVirtual: true,
    ),
    'stud_fee': TransactionCategory(
      key: 'stud_fee',
      label: 'Stud Fee',
      icon: 'male',
      type: TransactionType.income,
    ),
    'sold_adult': TransactionCategory(
      key: 'sold_adult',
      label: 'Sold Adult',
      icon: 'person_remove',
      type: TransactionType.income,
    ),
    'manure_sales': TransactionCategory(
      key: 'manure_sales',
      label: 'Manure Sales',
      icon: 'grass',
      type: TransactionType.income,
    ),
    'other_income': TransactionCategory(
      key: 'other_income',
      label: 'Other Income',
      icon: 'paid',
      type: TransactionType.income,
    ),
  };

  static final Map<String, TransactionCategory> expense = {
    'feed': TransactionCategory(
      key: 'feed',
      label: 'Feed',
      icon: 'grain',
      type: TransactionType.expense,
    ),
    'medical': TransactionCategory(
      key: 'medical',
      label: 'Medical',
      icon: 'medical_services',
      type: TransactionType.expense,
    ),
    'equipment': TransactionCategory(
      key: 'equipment',
      label: 'Equipment',
      icon: 'build',
      type: TransactionType.expense,
    ),
    'show_fee': TransactionCategory(
      key: 'show_fee',
      label: 'Show Fee',
      icon: 'emoji_events',
      type: TransactionType.expense,
    ),
    'bedding': TransactionCategory(
      key: 'bedding',
      label: 'Bedding',
      icon: 'forest',
      type: TransactionType.expense,
    ),
    'vet': TransactionCategory(
      key: 'vet',
      label: 'Vet Visit',
      icon: 'local_hospital',
      type: TransactionType.expense,
    ),
    'supplies': TransactionCategory(
      key: 'supplies',
      label: 'Supplies',
      icon: 'inventory_2',
      type: TransactionType.expense,
    ),
    'other_expense': TransactionCategory(
      key: 'other_expense',
      label: 'Other Expense',
      icon: 'receipt',
      type: TransactionType.expense,
    ),
  };

  static TransactionCategory? getCategory(String key) {
    return income[key] ?? expense[key];
  }

  static List<TransactionCategory> getByType(TransactionType type) {
    return type == TransactionType.income
        ? income.values.toList()
        : expense.values.toList();
  }
}