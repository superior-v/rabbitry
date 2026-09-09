enum TransactionType {
  income,
  expense,
}

enum TransactionCategory {
  // Income
  rabbitSale,
  litterSale,
  studFee,
  manureSales,
  meatHarvest,
  showWinnings,
  refund,
  otherIncome,

  // Expense (FinanceExpense categories)
  feedHay,
  bedding,
  veterinary,
  medicationsSupplements,
  cagesEquipment,
  supplies,
  showEntryFees,
  travel,
  registrationPedigreeFees,
  marketingListings,

  // Legacy mappings for backward-compatibility
  medical,
  feed,
  equipment,
  vetVisit,
  showFee,
  otherExpense,
  soldKit,
}

enum LinkType {
  general,
  rabbit,
  litter,
  kit,
}

class Transaction {
  final String id;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final DateTime date;
  final String? description;
  final String? notes;

  // Linking
  final LinkType linkType;
  final String? rabbitId;
  final String? litterId;
  final String? kitId;

  // Batch tracking
  final String? batchId;
  final bool isBatchTransaction;

  // Kit sale specific
  final String? kitColor;
  final String? kitSex;
  final String? buyerInfo;

  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    this.notes,
    this.linkType = LinkType.general,
    this.rabbitId,
    this.litterId,
    this.kitId,
    this.batchId,
    this.isBatchTransaction = false,
    this.kitColor,
    this.kitSex,
    this.buyerInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Get category display name
  String get categoryName {
    switch (category) {
      case TransactionCategory.rabbitSale:
        return 'Rabbit sale';
      case TransactionCategory.litterSale:
      case TransactionCategory.soldKit:
        return 'Litter sale';
      case TransactionCategory.studFee:
        return 'Breeding stud fee';
      case TransactionCategory.manureSales:
        return 'Manure / compost sale';
      case TransactionCategory.meatHarvest:
        return 'Fur / meat sale';
      case TransactionCategory.showWinnings:
        return 'Show winnings';
      case TransactionCategory.refund:
        return 'Refund';
      case TransactionCategory.otherIncome:
        return 'Other income';
      case TransactionCategory.feedHay:
      case TransactionCategory.feed:
        return 'Feed / hay';
      case TransactionCategory.bedding:
        return 'Bedding';
      case TransactionCategory.veterinary:
      case TransactionCategory.vetVisit:
        return 'Veterinary';
      case TransactionCategory.medicationsSupplements:
      case TransactionCategory.medical:
        return 'Medications / supplements';
      case TransactionCategory.cagesEquipment:
      case TransactionCategory.equipment:
        return 'Cages & equipment';
      case TransactionCategory.supplies:
        return 'Supplies';
      case TransactionCategory.showEntryFees:
      case TransactionCategory.showFee:
        return 'Show entry fees';
      case TransactionCategory.travel:
        return 'Travel';
      case TransactionCategory.registrationPedigreeFees:
        return 'Registration / pedigree fees';
      case TransactionCategory.marketingListings:
        return 'Marketing / listings';
      case TransactionCategory.otherExpense:
        return 'Other expense';
    }
  }

  // Check if category is typically income
  static bool isIncomeCategory(TransactionCategory category) {
    return [
      TransactionCategory.rabbitSale,
      TransactionCategory.litterSale,
      TransactionCategory.soldKit,
      TransactionCategory.studFee,
      TransactionCategory.manureSales,
      TransactionCategory.meatHarvest,
      TransactionCategory.showWinnings,
      TransactionCategory.refund,
      TransactionCategory.otherIncome,
    ].contains(category);
  }

  // Get all income categories
  static List<TransactionCategory> get incomeCategories => [
        TransactionCategory.rabbitSale,
        TransactionCategory.litterSale,
        TransactionCategory.studFee,
        TransactionCategory.manureSales,
        TransactionCategory.meatHarvest,
        TransactionCategory.showWinnings,
        TransactionCategory.refund,
        TransactionCategory.otherIncome,
      ];

  // Get all expense categories (10 items from FinanceExpense Category JPG)
  static List<TransactionCategory> get expenseCategories => [
        TransactionCategory.feedHay,
        TransactionCategory.bedding,
        TransactionCategory.veterinary,
        TransactionCategory.medicationsSupplements,
        TransactionCategory.cagesEquipment,
        TransactionCategory.supplies,
        TransactionCategory.showEntryFees,
        TransactionCategory.travel,
        TransactionCategory.registrationPedigreeFees,
        TransactionCategory.marketingListings,
      ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'category': category.toString(),
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'notes': notes,
      'linkType': linkType.toString(),
      'rabbitId': rabbitId,
      'litterId': litterId,
      'kitId': kitId,
      'batchId': batchId,
      'isBatchTransaction': isBatchTransaction ? 1 : 0,
      'kitColor': kitColor,
      'kitSex': kitSex,
      'buyerInfo': buyerInfo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    final catStr = map['category'] as String?;
    TransactionCategory cat = TransactionCategory.otherExpense;
    if (catStr == 'TransactionCategory.soldKit' || catStr == 'soldKit') {
      cat = TransactionCategory.litterSale;
    } else {
      cat = TransactionCategory.values.firstWhere(
        (e) => e.toString() == catStr || e.name == catStr,
        orElse: () => TransactionCategory.otherExpense,
      );
    }
    return Transaction(
      id: map['id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == map['type'] || e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      category: cat,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      linkType: LinkType.values.firstWhere(
        (e) => e.toString() == map['linkType'],
        orElse: () => LinkType.general,
      ),
      rabbitId: map['rabbitId'] as String?,
      litterId: map['litterId'] as String?,
      kitId: map['kitId'] as String?,
      batchId: map['batchId'] as String?,
      isBatchTransaction: map['isBatchTransaction'] == 1,
      kitColor: map['kitColor'] as String?,
      kitSex: map['kitSex'] as String?,
      buyerInfo: map['buyerInfo'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    TransactionCategory? category,
    double? amount,
    DateTime? date,
    String? description,
    String? notes,
    LinkType? linkType,
    String? rabbitId,
    String? litterId,
    String? kitId,
    String? batchId,
    bool? isBatchTransaction,
    String? kitColor,
    String? kitSex,
    String? buyerInfo,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      linkType: linkType ?? this.linkType,
      rabbitId: rabbitId ?? this.rabbitId,
      litterId: litterId ?? this.litterId,
      kitId: kitId ?? this.kitId,
      batchId: batchId ?? this.batchId,
      isBatchTransaction: isBatchTransaction ?? this.isBatchTransaction,
      kitColor: kitColor ?? this.kitColor,
      kitSex: kitSex ?? this.kitSex,
      buyerInfo: buyerInfo ?? this.buyerInfo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
