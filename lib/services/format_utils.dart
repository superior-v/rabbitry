import 'package:intl/intl.dart';
import 'settings_service.dart';

/// Centralized formatting utilities that respect localization settings.
/// All date, weight, and currency formatting should use these helpers.
class FormatUtils {
  static final SettingsService _settings = SettingsService.instance;

  // ==================== DATE FORMATTING ====================

  /// Full date format from settings (e.g., "02/14/2026" or "14/02/2026")
  static String formatDate(DateTime date) {
    return DateFormat(_settings.dateFormat).format(date);
  }

  /// Short date for compact displays (e.g., "Feb 14" or "14 Feb")
  static String formatDateShort(DateTime date) {
    final fmt = _settings.dateFormat;
    if (fmt.startsWith('dd')) {
      return DateFormat('d MMM').format(date);
    } else if (fmt.startsWith('yyyy')) {
      return DateFormat('MMM d').format(date);
    }
    return DateFormat('MMM d').format(date);
  }

  /// Month-year format (e.g., "February 2026")
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Long date (e.g., "February 14, 2026" or "14 February, 2026")
  static String formatDateLong(DateTime date) {
    final fmt = _settings.dateFormat;
    if (fmt.startsWith('dd')) {
      return DateFormat('d MMMM, yyyy').format(date);
    } else if (fmt.startsWith('yyyy')) {
      return DateFormat('yyyy MMMM d').format(date);
    }
    return DateFormat('MMMM d, yyyy').format(date);
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

  /// Format a weight value with unit (e.g., "4.5 lbs" or "2.0 kg")
  static String formatWeight(double weight, {int decimals = 1}) {
    return '${weight.toStringAsFixed(decimals)} ${_settings.weightUnit}';
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
}
