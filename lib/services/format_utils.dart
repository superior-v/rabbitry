import 'package:flutter/services.dart';
export 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'settings_service.dart';

/// Centralized formatting utilities that respect localization settings.
/// All date, weight, and currency formatting should use these helpers.
class FormatUtils {
  static final SettingsService _settings = SettingsService.instance;

  // ==================== DATE FORMATTING ====================

  /// Full date format from settings (e.g., "Jan 24, 2026", "02-14-2026" or "14-02-2026")
  /// Day numbers always have 2 digits (e.g., "Sep 03, 2026")
  static String formatDate(DateTime date) {
    try {
      String pattern = _settings.dateFormat;
      if (pattern == 'MM-DD-YYYY') pattern = 'MM-dd-yyyy';
      if (pattern == 'DD-MM-YYYY') pattern = 'dd-MM-yyyy';
      if (pattern == 'MM/dd/yyyy') pattern = 'MM-dd-yyyy';
      if (pattern == 'dd/MM/yyyy') pattern = 'dd-MM-yyyy';
      if (pattern == 'MMM d, yyyy') pattern = 'MMM dd, yyyy';
      if (pattern.contains('d') && !pattern.contains('dd')) {
        pattern = pattern.replaceAll('d', 'dd');
      }
      return DateFormat(pattern).format(date);
    } catch (_) {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  /// Formats date specifically for certificates in 'MMM d, yyyy' format (e.g. 'May 12, 2026', 'Feb 2, 2026').
  /// In the app, Rabbit dateOfBirth is stored in SQLite as ISO-8601 string ('YYYY-MM-DDTHH:mm:ss.sss')
  /// and parsed into a DateTime instance on the Rabbit model.
  static String formatCertificateDate(dynamic date) {
    if (date == null) return '—';
    if (date is DateTime) {
      return DateFormat('MMM d, yyyy', 'en_US').format(date);
    }
    if (date is String) {
      final trimmed = date.trim();
      if (trimmed.isEmpty || trimmed == 'N/A' || trimmed == '-') return '—';
      try {
        final parsed = DateTime.tryParse(trimmed);
        if (parsed != null) {
          return DateFormat('MMM d, yyyy', 'en_US').format(parsed);
        }
      } catch (_) {}
      return trimmed;
    }
    return '—';
  }

  /// Formats date specifically for Certificate of Birth v2 in zero-padded 'MMM dd, yyyy' format (e.g. 'Feb 02, 2025').
  static String formatCertificateDatePadded(dynamic date) {
    if (date == null) return '—';
    if (date is DateTime) {
      return DateFormat('MMM dd, yyyy', 'en_US').format(date);
    }
    if (date is String) {
      final trimmed = date.trim();
      if (trimmed.isEmpty || trimmed == 'N/A' || trimmed == '-') return '—';
      try {
        final parsed = DateTime.tryParse(trimmed);
        if (parsed != null) {
          return DateFormat('MMM dd, yyyy', 'en_US').format(parsed);
        }
      } catch (_) {}
      return trimmed;
    }
    return '—';
  }

  /// Age formatted in at most 3 units (e.g., "2y 3m 2w", "3y 2w 5d", "9m 4w 5d", "3w 2d", "5d")
  static String formatAge(DateTime? dob, {DateTime? targetDate}) {
    if (dob == null) return 'Unknown';
    final now = targetDate ?? DateTime.now();
    if (dob.isAfter(now)) return '0d';

    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      months--;
      final prevMonthDays = DateTime(now.year, now.month, 0).day;
      days += prevMonthDays;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    int weeks = days ~/ 7;
    int remDays = days % 7;

    List<String> parts = [];
    if (years > 0) parts.add('${years}y');
    if (months > 0) parts.add('${months}m');
    if (weeks > 0) parts.add('${weeks}w');
    if (remDays > 0) parts.add('${remDays}d');

    if (parts.isEmpty) return '0d';

    return parts.take(3).join(' ');
  }

  /// Short date for compact displays (e.g., "Jan 24" or "24 Jan")
  static String formatDateShort(DateTime date) {
    final fmt = _settings.dateFormat.toLowerCase();
    if (fmt.startsWith('dd')) {
      return DateFormat('dd MMM').format(date);
    }
    return DateFormat('MMM dd').format(date);
  }

  /// Month-year format (e.g., "Sep 2026")
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  /// Long date (e.g., "January 24, 2026" or "24 January, 2026")
  static String formatDateLong(DateTime date) {
    final fmt = _settings.dateFormat.toLowerCase();
    if (fmt.startsWith('dd')) {
      return DateFormat('dd MMMM, yyyy').format(date);
    } else if (fmt.startsWith('yyyy')) {
      return DateFormat('yyyy MMMM dd').format(date);
    }
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  /// Chart/axis label - very short (e.g., "Feb 14" or "Feb '26")
  static String formatDateChart(DateTime date, String period) {
    switch (period) {
      case 'W':
        return DateFormat('EEE').format(date);
      case 'M':
        return formatDateShort(date);
      case 'Y':
        return DateFormat('MMM yy').format(date);
      default:
        return formatDateShort(date);
    }
  }

  // ==================== WEIGHT FORMATTING ====================

  /// Returns the current weight unit string (e.g., "lbs" or "kg")
  static String get weightUnit => _settings.weightUnit;

  /// Format a weight value with unit (e.g., "4lbs 5oz" or "2.0 kg")
  static String formatWeight(double weight, {int decimals = 1}) {
    if (_settings.weightUnit == 'lbs') {
      final int lbs = weight.floor();
      final int oz = ((weight - lbs) * 16).round();
      if (oz > 0) {
        return '${lbs}lbs ${oz}oz';
      }
      return '${lbs}lbs';
    }
    return '${weight.toStringAsFixed(decimals)} ${_settings.weightUnit}';
  }

  /// Returns true if a string looks like a system ID, UUID, timestamp, or DB key rather than a user name
  static bool isSystemId(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final t = text.trim();
    return RegExp(r'^(R-|PED-|ped_|K-|F-|kit_|litter_|rabbit_|sire_|dam_|buck_|doe_|temp_|health_|weight_|\d+|[0-9a-fA-F-]{8,})', caseSensitive: false).hasMatch(t) ||
           RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}').hasMatch(t);
  }

  /// Clean display name for parent/ancestor. If it's a system ID and unresolvable, returns '-'
  static String cleanParentName(String? nameOrId) {
    if (nameOrId == null || nameOrId.trim().isEmpty) return '-';
    final t = nameOrId.trim();
    if (isSystemId(t)) return '-';
    return t;
  }

  /// Weight label for input fields (e.g., "Weight (lbs)" or "Weight (kg)")
  static String weightLabel([String prefix = 'Weight']) {
    return '$prefix (${_settings.weightUnit})';
  }

  /// Weight hint text (e.g., "0.0 lbs")
  static String get weightHint => '0.0 ${_settings.weightUnit}';

  // ==================== CURRENCY FORMATTING ====================

  /// Returns the currency symbol (e.g., "$", "€", "£")
  static String get currencySymbol {
    switch (_settings.currency) {
      case 'eur':
        return '€';
      case 'gbp':
        return '£';
      case 'inr':
        return '₹';
      case 'cad':
        return '\$';
      case 'aud':
        return 'A\$';
      case 'cny':
        return '¥';
      case 'rub':
        return '₽';
      case 'usd':
      case 'mxn':
      default:
        return '\$';
    }
  }

  /// Format a currency amount (e.g., "$123.45" or "€123.45")
  static String formatCurrency(double amount, {int decimals = 2}) {
    return '$currencySymbol${amount.toStringAsFixed(decimals)}';
  }

  /// Format currency with no decimals for chart/summary displays
  static String formatCurrencyShort(double amount) {
    return '$currencySymbol${amount.abs().toStringAsFixed(0)}';
  }

  /// Format currency with sign (e.g., "+$50" or "-$30")
  static String formatCurrencySigned(double amount, {int decimals = 0}) {
    if (amount >= 0) {
      return '+$currencySymbol${amount.toStringAsFixed(decimals)}';
    } else {
      return '-$currencySymbol${amount.abs().toStringAsFixed(decimals)}';
    }
  }

  /// Currency prefix for input fields (e.g., "$ " or "€ ")
  static String get currencyPrefix => '$currencySymbol ';

  /// Currency hint for input fields (e.g., "$0.00")
  static String get currencyHint => '${currencySymbol}0.00';

  // ==================== PHONE NUMBER FORMATTING ====================

  /// Format phone number based on country/currency (e.g. "xxx-xxx-xxxx" for US/Canada)
  static String formatPhoneNumber(String? raw, {String? countryCode}) {
    if (raw == null || raw.trim().isEmpty) return '';
    final text = raw.trim();
    if (text.startsWith('+')) return text;

    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return text;

    final currency = (countryCode ?? _settings.currency).toLowerCase();

    if (currency == 'inr') {
      final maxDigits = digits.length > 10 ? digits.substring(0, 10) : digits;
      if (maxDigits.length <= 5) return maxDigits;
      return '${maxDigits.substring(0, 5)}-${maxDigits.substring(5)}';
    } else if (currency == 'gbp') {
      final maxDigits = digits.length > 11 ? digits.substring(0, 11) : digits;
      if (maxDigits.length <= 5) return maxDigits;
      return '${maxDigits.substring(0, 5)}-${maxDigits.substring(5)}';
    } else {
      // Default: US & Canada (NANP) -> xxx-xxx-xxxx
      String d = digits;
      if (d.startsWith('1') && d.length > 10) {
        d = d.substring(1);
      }
      final maxDigits = d.length > 10 ? d.substring(0, 10) : d;
      if (maxDigits.length <= 3) {
        return maxDigits;
      } else if (maxDigits.length <= 6) {
        return '${maxDigits.substring(0, 3)}-${maxDigits.substring(3)}';
      } else {
        return '${maxDigits.substring(0, 3)}-${maxDigits.substring(3, 6)}-${maxDigits.substring(6)}';
      }
    }
  }
}

/// Formats phone numbers as the user types (e.g. auto-inserting dashes for xxx-xxx-xxxx)
class PhoneNumberFormatter extends TextInputFormatter {
  final String? countryCode;

  PhoneNumberFormatter({this.countryCode});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    if (text.startsWith('+')) {
      final cleaned = '+${text.substring(1).replaceAll(RegExp(r'[^\d\s\-]'), '')}';
      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }

    final formatted = FormatUtils.formatPhoneNumber(text, countryCode: countryCode);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
