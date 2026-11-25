import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App appearance (Light / Dark / System) with a true crafted Dark Mode palette.
class AppearanceService {
  AppearanceService._();
  static final AppearanceService instance = AppearanceService._();

  static const _prefsKey = 'appearanceMode'; // 'light' | 'dark' | 'system'

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = _fromString(prefs.getString(_prefsKey));
    } catch (e) {
      debugPrint('Appearance load failed: $e');
    }
  }

  Future<void> setMode(ThemeMode newMode) async {
    if (mode.value == newMode) return;
    mode.value = newMode;
    refreshAllWidgetsForTheme();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _toString(newMode));
    } catch (e) {
      debugPrint('Appearance save failed: $e');
    }
  }

  /// Context-free check so dynamic color helpers & palette getters resolve at build time.
  bool get isDarkMode {
    switch (mode.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  bool isDark(BuildContext context) {
    switch (mode.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  /// Forces all active Elements and RenderObjects to rebuild and re-read
  /// dynamic colors in place without losing navigation stack or state.
  static void refreshAllWidgetsForTheme() {
    try {
      final root = WidgetsBinding.instance.rootElement;
      if (root != null) {
        void visit(Element el) {
          el.markNeedsBuild();
          final ro = el.renderObject;
          if (ro != null) {
            try {
              ro.reassemble();
            } catch (_) {}
            ro.markNeedsLayout();
            ro.markNeedsPaint();
          }
          el.visitChildren(visit);
        }

        visit(root);
      }
      try {
        (PaintingBinding.instance.systemFonts as dynamic).notifyListeners();
      } catch (_) {}
    } catch (e) {
      debugPrint('Theme refresh notice: $e');
    }
  }

  static ThemeMode _fromString(String? s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}

/// Convenience global getter for dark mode state.
bool get isAppDark => AppearanceService.instance.isDarkMode;

/// Elevated card surface color that replaces `Colors.white` on cards, modals,
/// sheets, dropdowns, and input boxes (`#FFFFFF` in Light -> `#1E2028` in Dark).
Color get kAppCardWhite =>
    isAppDark ? const Color(0xFF1E2028) : const Color(0xFFFFFFFF);

/// Returns a genuine [Color] for foregrounds, text, and icons.
/// In Dark Mode, guarantees high contrast on dark surfaces (never darkens text).
Color appColor(int lightArgb, [int? darkOverride]) {
  if (!AppearanceService.instance.isDarkMode) {
    return Color(lightArgb);
  }
  return Color(darkOverride ?? _resolveDarkGeneralArgb(lightArgb));
}

/// Returns a genuine [Color] for surfaces, backgrounds, cards, headers, rows,
/// pills, and borders.
Color appSurface(int lightArgb, [int? darkOverride]) {
  if (!AppearanceService.instance.isDarkMode) {
    return Color(lightArgb);
  }
  return Color(darkOverride ?? _resolveDarkSurfaceArgb(lightArgb));
}

/// Const-compatible dynamic foreground [Color] for default parameter values.
class AppColor extends Color {
  final int _lightArgb;
  final int? _darkOverride;

  const AppColor(this._lightArgb, [this._darkOverride]) : super(_lightArgb);

  int get _activeArgb {
    if (!AppearanceService.instance.isDarkMode) return _lightArgb;
    final override = _darkOverride;
    if (override != null) return override;
    return _resolveDarkGeneralArgb(_lightArgb);
  }

  @override
  double get a => ((_activeArgb >> 24) & 0xFF) / 255.0;

  @override
  double get r => ((_activeArgb >> 16) & 0xFF) / 255.0;

  @override
  double get g => ((_activeArgb >> 8) & 0xFF) / 255.0;

  @override
  double get b => (_activeArgb & 0xFF) / 255.0;

  @override
  int get value => _activeArgb & 0xFFFFFFFF;

  @override
  int toARGB32() => _activeArgb & 0xFFFFFFFF;

  @override
  int get alpha => (_activeArgb >> 24) & 0xFF;

  @override
  int get red => (_activeArgb >> 16) & 0xFF;

  @override
  int get green => (_activeArgb >> 8) & 0xFF;

  @override
  int get blue => _activeArgb & 0xFF;

  @override
  double get opacity => alpha / 255.0;

  @override
  Color withAlpha(int a) {
    final int clamped = a & 0xFF;
    final int lightWithA = (clamped << 24) | (_lightArgb & 0x00FFFFFF);
    final int darkBase = _darkOverride ?? _resolveDarkGeneralArgb(_lightArgb);
    final int darkWithA = (clamped << 24) | (darkBase & 0x00FFFFFF);
    return appColor(lightWithA, darkWithA);
  }

  @override
  Color withOpacity(double opacity) {
    return withAlpha((255.0 * opacity.clamp(0.0, 1.0)).round());
  }

  @override
  Color withValues({
    double? alpha,
    double? red,
    double? green,
    double? blue,
    ui.ColorSpace? colorSpace,
  }) {
    if (red == null && green == null && blue == null && colorSpace == null) {
      if (alpha != null) {
        return withAlpha((alpha.clamp(0.0, 1.0) * 255.0).round());
      }
      return Color(_activeArgb);
    }
    return Color(_activeArgb).withValues(
      alpha: alpha,
      red: red,
      green: green,
      blue: blue,
      colorSpace: colorSpace,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is Color) {
      return toARGB32() == other.toARGB32();
    }
    return false;
  }

  @override
  int get hashCode => toARGB32().hashCode;
}

/// Const-compatible dynamic surface [Color] for default parameter values.
class AppSurfaceColor extends AppColor {
  const AppSurfaceColor(super.lightArgb, [super.darkOverride]);

  @override
  int get _activeArgb {
    if (!AppearanceService.instance.isDarkMode) return _lightArgb;
    final override = _darkOverride;
    if (override != null) return override;
    return _resolveDarkSurfaceArgb(_lightArgb);
  }

  @override
  Color withAlpha(int a) {
    final int clamped = a & 0xFF;
    final int lightWithA = (clamped << 24) | (_lightArgb & 0x00FFFFFF);
    final int darkBase = _darkOverride ?? _resolveDarkSurfaceArgb(_lightArgb);
    final int darkWithA = (clamped << 24) | (darkBase & 0x00FFFFFF);
    return appSurface(lightWithA, darkWithA);
  }
}

const Map<int, int> _kExplicitSurfaceDarkRgb = <int, int>{
  // Elevated Card, Modal, Dropdown, & Unselected Pill Surfaces
  0xFFFFFF: 0x1E2028,
  0xFCFCFD: 0x1E2028,
  0xFAFAFC: 0x1E2028,
  0xFEFEFE: 0x1E2028,
  0xFDFDFE: 0x1E2028,
  0xFAFAFA: 0x1E2028,

  // Deep Dark Scaffold / Page Backgrounds & Recessed Input Boxes
  0xEEDAFE: 0x121318,
  0xEEDAFF: 0x121318,
  0xFAF9FC: 0x121318,
  0xF1ECF7: 0x121318,
  0xF2F2F7: 0x151720,
  0xF9F9FB: 0x151720,
  0xF8F8FA: 0x151720,
  0xF8F9FA: 0x151720,
  0xF8FAFC: 0x151720,
  0xF3F4F6: 0x151720,
  0xF1F5F9: 0x151720,
  0xF5F5F7: 0x151720,
  0xF5F5F5: 0x161822,
  0xF7F7FA: 0x151720,
  0xF7F7F5: 0x161822,
  0xF6F5F8: 0x151720,
  0xF4F4F6: 0x161822,
  0xF1F1EF: 0x181A24,
  0xF0EFF5: 0x151720,
  0xF5F7FA: 0x161822,

  // Top App Bars & Purple Headers / Primary Action Buttons
  0xE6BEFE: 0x221C30,
  0xE2BFFB: 0x2B223E,
  0xD4B3EE: 0x382D52,
  0xC3B1E1: 0x342A4C,

  // Pink Breed Group Headers & Gradients
  0xFFBCE7: 0x332233,
  0xFADCE5: 0x2E202A,
  0xF2B8C6: 0x34232E,
  0xFFF0F9: 0x231B26,

  // Hero Stat Card & Sire Gradients
  0x86DAFF: 0x263248,
  0x7CE7FF: 0x263248,
  0xA8D4F0: 0x243044,
  0xF0F9FF: 0x1D2434,
  0xE8FAFF: 0x1D2434,
  0xE0F2FE: 0x1E283A,
  0xE1F3FE: 0x1E283A,
  0xD8EEFB: 0x202C40,

  // Subtle Alternating Card Rows & Tinted Purple Washes
  0xF9F5FE: 0x242232,
  0xFAF7FF: 0x242232,
  0xF8F5FF: 0x242232,
  0xF5F3FF: 0x242232,
  0xF6F0FD: 0x242232,
  0xF7F3FB: 0x242232,
  0xF7F5FA: 0x242232,
  0xF5F3F8: 0x242232,
  0xF9F7FC: 0x242232,
  0xF4F0FA: 0x232030,
  0xF5F1FC: 0x232030,
  0xF3EFFA: 0x232030,
  0xF2EAF9: 0x262235,
  0xEDE9FE: 0x2A253D,
  0xF0ECFE: 0x2A253D,
  0xE8DFFA: 0x2B2640,
  0xF3E8FF: 0x2B2540,
  0xEADBEE: 0x2C253E,
  0xEAE3F2: 0x282438,
  0xE2D6EE: 0x322C46,

  // Soft Pink / Red Washes (Doe rows / Dam pedigree / Error tints)
  0xFDF2F5: 0x28202A,
  0xFFEEF6: 0x28202A,
  0xFCE4EC: 0x2E212C,
  0xFFF0F5: 0x28202A,
  0xFDF2F4: 0x2B2026,
  0xFCE7F3: 0x2D202C,
  0xFBCFE8: 0x382637,
  0xFEF2F2: 0x2C1F24,
  0xFEE2E2: 0x362228,
  0xFFEBEC: 0x2E2024,

  // Soft Blue Washes (Buck rows / Sire pedigree / Info tints)
  0xF0F7FD: 0x1E2633,
  0xEAF4FF: 0x1E2633,
  0xD9EEFB: 0x202A3A,
  0xEFF6FB: 0x1E2633,
  0xEFF6FF: 0x1E2633,
  0xE3F2FD: 0x202A3A,
  0xEBF8FF: 0x1E2838,
  0xEBF2FA: 0x1E2636,
  0xDBEAFE: 0x1E293B,
  0xBFDBFE: 0x26354D,
  0xCDEEFE: 0x1F2C3F,
  0xBAE5FD: 0x25374E,

  // Soft Green / Teal Washes (Income / Health / Nursing tints)
  0xF0FDF4: 0x1B2A24,
  0xDCFCE7: 0x21352C,
  0xD4F7D4: 0x1E3026,
  0xC0EFC0: 0x253C2F,
  0xE0F2F1: 0x1C2D2C,
  0xCCFBF1: 0x1D302E,

  // Soft Yellow / Amber / Orange Washes (Warning / Palpate / Quarantine tints)
  0xFEF9C3: 0x2B271A,
  0xFEF08A: 0x38321F,
  0xFFF8E1: 0x2B251B,
  0xFFF9E6: 0x2B261C,
  0xFFF3E0: 0x2C231B,
  0xFDF3E8: 0x2B231D,

  // Borders, Dividers, Input Tracks, & Segmented Control Base
  0xE4E4E9: 0x161820,
  0xE5E5EA: 0x2D303E,
  0xE4E4EA: 0x2D303E,
  0xEEEEF4: 0x282B38,
  0xEBEBF0: 0x2B2E3C,
  0xEBE8F0: 0x2B2938,
  0xE2E8F0: 0x2D3140,
  0xEDF2F7: 0x262936,
  0xEEEEEE: 0x2C2F3C,
  0xECECED: 0x2A2D3A,
  0xE9E9E7: 0x2C2F3C,
  0xE8E8E8: 0x2C2F3C,
  0xE1E1E8: 0x2E3140,
  0xE0E0E0: 0x323544,
  0xD1D5DB: 0x343846,
  0xD1D1D6: 0x343846,
  0xC7C7CC: 0x383C4A,

  // Dark Pill / Sub-Header Surfaces
  0x8F8A90: 0x181922,
  0x7A757C: 0x282A36,
  0x1E1E24: 0x323544,
};

const Map<int, int> _kExplicitGeneralDarkRgb = <int, int>{
  // Primary Dark Text -> Crisp Off-White
  0x000000: 0xF1F3F9,
  0x0F172A: 0xF1F3F9,
  0x111827: 0xF1F3F9,
  0x18181B: 0xF1F3F9,
  0x1A1A1A: 0xF1F3F9,
  0x1E293B: 0xF1F3F9,
  0x1F2937: 0xF1F3F9,
  0x222222: 0xF1F3F9,
  0x231F20: 0xF1F3F9,
  0x262626: 0xF1F3F9,
  0x262629: 0xF1F3F9,
  0x2B2138: 0xF1EFF7,
  0x2C2C2C: 0xF1F3F9,
  0x2C2C2E: 0xF1F3F9,
  0x333333: 0xECEDF4,
  0x333336: 0xECEDF4,
  0x334155: 0xE6E9F2,
  0x37352F: 0xECEDF4,
  0x3A3A3C: 0xECEDF4,
  0x3B3B43: 0xECEDF4,
  0x3F3B46: 0xECEDF4,
  0x4A4451: 0xE8E4F0,
  0x4A4A4A: 0xE4E6F0,
  0x4A4A4D: 0xE4E6F0,
  0x4A4A4E: 0xE4E6F0,

  // Secondary Text & Icons -> Soft Silver-Lavender
  0x475569: 0xB8C0D0,
  0x4F4F56: 0xC2C6D4,
  0x52525B: 0xB8BDCB,
  0x545459: 0xB8BDCB,
  0x555555: 0xB8BDCB,
  0x55555C: 0xB8BDCB,
  0x58595B: 0xB4B9C8,
  0x59595E: 0xB4B9C8,
  0x636366: 0xB4B9C8,
  0x64748B: 0xACB4C4,
  0x66666D: 0xB4B9C8,
  0x6A6171: 0xBFB8CA,
  0x6B6B6B: 0xB0B5C4,
  0x6B7280: 0xB0B6C6,
  0x6D6E71: 0xB0B5C4,
  0x6E6E73: 0xB0B5C4,
  0x777777: 0xA8AEBE,
  0x787774: 0xA8AEBE,
  0x787878: 0xA8AEBE,

  // Muted / Caption / Hint / Placeholder Text & Icons -> Readable Muted Slate
  // (Never darkened into a background color!)
  0x787880: 0x9499AA,
  0x888888: 0x9096A6,
  0x8E8E93: 0x8E94A6,
  0x94A3B8: 0x8E96A8,
  0x9B9A97: 0x8C909E,
  0x9CA3AF: 0x8C92A4,
  0x9E9E9E: 0x8A90A0,
  0xA0A0A0: 0x8A90A0,
  0xA1A1AA: 0x8A90A0,
  0xA5A1AE: 0x928EA0,
  0xAAAAAA: 0x888E9E,
  0xAEAEB2: 0x888E9E,
  0xB3A7C2: 0x9B90AD,
  0xBFBFBD: 0x828796,
  0xC4C4C8: 0x828796,
  0xC7C7CC: 0x7E8494,
  0xCCCBC8: 0x7E8494,
  0xD1D5DB: 0x787E8E,
  0xE1E1E8: 0x747A8A,
  0xE5E5EA: 0x707686,
  0xE9E9E7: 0x707686,

  // Purple / Lilac Foregrounds & Accents
  0x463466: 0xD4C8EC,
  0x4A3E6D: 0xD4C8EC,
  0x5A4880: 0xCFC2E8,
  0x5C4A70: 0xCFC2E8,
  0x5E4A8A: 0xB9A6F8,
  0x662C91: 0xC084FC,
  0x6B4E8C: 0xC4B5FD,
  0x6D3FD1: 0xB794F4,
  0x7B6BA0: 0xB8A5F2,
  0x8B5CF6: 0xA78BFA,
  0x9B8EC4: 0xB8A9E0,
  0x9C6ADE: 0xC084FC,
  0xB388C7: 0xD8B4FE,
  0xB388FF: 0xC4B5FD,
  0xE2BFFB: 0xE2BFFB,
  0xE6BEFE: 0xE6BEFE,

  // Pink / Doe Foregrounds & Accents
  0xB5567A: 0xF472B6,
  0xC2185B: 0xF472B6,
  0xC47A8B: 0xF48FB1,
  0xD4809A: 0xF48FB1,
  0xE04F9F: 0xF472B6,
  0xEC4899: 0xF472B6,
  0xEC6FA7: 0xF48FB1,
  0xF48FB1: 0xF48FB1,
  0xFF2E7E: 0xFB7185,

  // Blue / Buck Foregrounds & Accents
  0x0284C7: 0x38BDF8,
  0x1976D2: 0x60A5FA,
  0x2196F3: 0x60A5FA,
  0x2E7BB5: 0x60A5FA,
  0x38BDF8: 0x38BDF8,
  0x3A7BB8: 0x60A5FA,
  0x3B82F6: 0x60A5FA,
  0x3DB7E4: 0x38BDF8,
  0x4A76B8: 0x68A8F8,
  0x4AA8E8: 0x60A5FA,
  0x5B8AD0: 0x68A8F8,
  0x5B9BD5: 0x68A8F8,
  0x7DD3FC: 0x7DD3FC,
  0x80BFFF: 0x80BFFF,
  0xBAE6FD: 0xBAE6FD,

  // Green / Teal Status Foregrounds
  0x00695C: 0x34D399,
  0x0D9488: 0x2DD4BF,
  0x10B981: 0x34D399,
  0x2E7D32: 0x4ADE80,
  0x2F855A: 0x4ADE80,
  0x459F89: 0x34D399,
  0x4CAF50: 0x4ADE80,

  // Amber / Orange Status Foregrounds
  0xD97706: 0xFBBF24,
  0xEF6C00: 0xFB923C,
  0xF59E0B: 0xFBBF24,
  0xF5A623: 0xFBBF24,

  // Red / Danger Status Foregrounds
  0xB71C1C: 0xF87171,
  0xC53030: 0xF87171,
  0xD32F2F: 0xF87171,
  0xD44C47: 0xF87171,
  0xD94452: 0xF87171,
  0xE05263: 0xFB7185,
  0xE63946: 0xF87171,
  0xEF4444: 0xF87171,

  // White foreground stays white
  0xFFFFFF: 0xFFFFFF,
};

int _resolveDarkSurfaceArgb(int argb) {
  final int alpha = (argb >> 24) & 0xFF;
  if (alpha == 0) return argb;
  final int rgb = argb & 0x00FFFFFF;

  final int? mapped = _kExplicitSurfaceDarkRgb[rgb];
  if (mapped != null) {
    return (alpha << 24) | mapped;
  }

  final int r = (rgb >> 16) & 0xFF;
  final int g = (rgb >> 8) & 0xFF;
  final int b = rgb & 0xFF;
  final int maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final int minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final double chroma = (maxC - minC) / 255.0;

  final hsl = HSLColor.fromColor(Color(0xFF000000 | rgb));
  final double l = hsl.lightness;
  final double s = hsl.saturation;

  if (l >= 0.96 && chroma < 0.08) {
    return (alpha << 24) | 0x1E2028;
  }
  if (l >= 0.88 && chroma < 0.08) {
    return (alpha << 24) | 0x161822;
  }
  if (l >= 0.72 && chroma < 0.08) {
    return (alpha << 24) | 0x2D303E;
  }
  if (l >= 0.70) {
    final darkSurface = hsl
        .withSaturation((s * 0.38).clamp(0.14, 0.32))
        .withLightness(0.19)
        .toColor();
    return (alpha << 24) | (darkSurface.toARGB32() & 0x00FFFFFF);
  }
  return argb;
}

int _resolveDarkGeneralArgb(int argb) {
  final int alpha = (argb >> 24) & 0xFF;
  if (alpha == 0) return argb;
  final int rgb = argb & 0x00FFFFFF;

  final int? explicitGen = _kExplicitGeneralDarkRgb[rgb];
  if (explicitGen != null) {
    return (alpha << 24) | explicitGen;
  }

  final int r = (rgb >> 16) & 0xFF;
  final int g = (rgb >> 8) & 0xFF;
  final int b = rgb & 0xFF;
  final int maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final int minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final double chroma = (maxC - minC) / 255.0;

  final hsl = HSLColor.fromColor(Color(0xFF000000 | rgb));
  final double l = hsl.lightness;
  final double s = hsl.saturation;

  // Neutral / near-neutral text & icons (black, charcoal, grey, silver)
  if (chroma < 0.10) {
    if (l <= 0.32) {
      return (alpha << 24) | 0xF1F3F9;
    }
    if (l <= 0.50) {
      return (alpha << 24) | 0xB8BDCB;
    }
    if (l <= 0.88) {
      return (alpha << 24) | 0x888E9E;
    }
    return argb;
  }

  // Colored text/icons -> Ensure bright, legible lightness (>= 0.72) on dark surfaces
  if (l < 0.72) {
    final c = hsl
        .withSaturation(s.clamp(0.48, 0.85))
        .withLightness(0.74)
        .toColor();
    return (alpha << 24) | (c.toARGB32() & 0x00FFFFFF);
  }

  return argb;
}

/// Legacy compatibility filter constant (identity).
const ColorFilter kDarkModeFilter = ColorFilter.mode(
  Colors.transparent,
  BlendMode.dst,
);

/// Pass-through guard (no negative inversion filter is applied in Dark Mode).
class DarkModeGuard extends StatelessWidget {
  final Widget child;
  const DarkModeGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
