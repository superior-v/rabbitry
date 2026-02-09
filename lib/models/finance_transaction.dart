import 'package:flutter/material.dart';

enum TransactionType {
  income,
  expense,
}

enum TransactionContext {
  general,
  rabbit,
  litter,
  kit,
}

class TransactionCategory {
  final String key;
  final String label;
  final String icon;
  final TransactionType type;
  final bool isVirtual;

  const TransactionCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.type,
    this.isVirtual = false,
  });
}

class FinanceTransaction {
  final String id;
  final TransactionType type;
  final String category;
  final double amount;
  final String? description;
  final DateTime date;
  final String? rabbitId;
  final String? rabbitName;
  final DateTime createdAt;

  // Additional properties for your screens
  final TransactionContext context;
  final String entity;
  final String? entityId;
  final String? litterId;
  final String? kitId;
  final String? sub;
  final String? batchId;
  final bool isVirtual;

  FinanceTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    this.description,
    required this.date,
    this.rabbitId,
    this.rabbitName,
    DateTime? createdAt,
    required this.context,
    required this.entity,
    this.entityId,
    this.litterId,
    this.kitId,
    this.sub,
    this.batchId,
    this.isVirtual = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'rabbitId': rabbitId,
      'rabbitName': rabbitName,
      'createdAt': createdAt.toIso8601String(),
      'context': context.toString().split('.').last,
      'entity': entity,
      'entityId': entityId,
      'litterId': litterId,
      'kitId': kitId,
      'sub': sub,
      'batchId': batchId,
      'isVirtual': isVirtual ? 1 : 0,
    };
  }

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'],
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      category: map['category'],
      amount: map['amount'],
      description: map['description'],
      date: DateTime.parse(map['date']),
      rabbitId: map['rabbitId'],
      rabbitName: map['rabbitName'],
      createdAt: DateTime.parse(map['createdAt']),
      context: TransactionContext.values.firstWhere(
        (e) => e.toString().split('.').last == map['context'],
        orElse: () => TransactionContext.general,
      ),
      entity: map['entity'] ?? '',
      entityId: map['entityId'],
      litterId: map['litterId'],
      kitId: map['kitId'],
      sub: map['sub'],
      batchId: map['batchId'],
      isVirtual: map['isVirtual'] == 1,
    );
  }

  IconData get icon {
    switch (category) {
      case 'Feed':
        return Icons.grass;
      case 'Veterinary':
        return Icons.medical_services;
      case 'Sales':
        return Icons.attach_money;
      case 'Supplies':
        return Icons.shopping_bag;
      case 'Breeding':
        return Icons.favorite;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Color get categoryColor {
    switch (category) {
      case 'Feed':
        return Color(0xFF10B981);
      case 'Veterinary':
        return Color(0xFFEF4444);
      case 'Sales':
        return Color(0xFF0F7B6C);
      case 'Supplies':
        return Color(0xFF8B5CF6);
      case 'Breeding':
        return Color(0xFFF59E0B);
      default:
        return Color(0xFF64748B);
    }
  }
}

class FinanceFilters {
  String timePeriod;
  DateTime? dateFrom;
  DateTime? dateTo;
  String transactionType;
  String linkType;
  String? rabbitId;
  String? litterId;
  String batchFilter;

  FinanceFilters({
    this.timePeriod = 'all',
    this.dateFrom,
    this.dateTo,
    this.transactionType = 'all',
    this.linkType = 'all',
    this.rabbitId,
    this.litterId,
    this.batchFilter = 'all',
  });

  int get activeFilterCount {
    int count = 0;
    if (timePeriod != 'all') count++;
    if (transactionType != 'all') count++;
    if (linkType != 'all') count++;
    if (rabbitId != null) count++;
    if (litterId != null) count++;
    if (batchFilter != 'all') count++;
    return count;
  }
}
