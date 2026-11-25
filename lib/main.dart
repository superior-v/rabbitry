import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/appearance_service.dart';
import 'services/notification_service.dart';
import 'screens/home_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppearanceService.instance.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter startup error: ${details.exceptionAsString()}');
  };

  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught zone error: $error');
    debugPrintStack(stackTrace: stackTrace);
  });
}

Future<void> _initializeApp() async {
  try {
    await SettingsService.instance.init().timeout(const Duration(seconds: 12));
  } catch (e, st) {
    debugPrint('Settings init failed: $e');
    debugPrintStack(stackTrace: st);
  }

  try {
    await NotificationService.instance.init().timeout(const Duration(seconds: 12));
  } catch (e, st) {
    debugPrint('Notification init failed: $e');
    debugPrintStack(stackTrace: st);
  }

  final db = DatabaseService();
  try {
    await db.database.timeout(const Duration(seconds: 20));
  } catch (e, st) {
    debugPrint('Database open failed: $e');
    debugPrintStack(stackTrace: st);
  }

  try {
    await db.backfillSoldTransactionsFix().timeout(const Duration(seconds: 10));
  } catch (e, st) {
    debugPrint('Backfill transaction fix failed: $e');
    debugPrintStack(stackTrace: st);
  }

  try {
    await db.fixLitterSireDamNamesFix().timeout(const Duration(seconds: 10));
  } catch (e, st) {
    debugPrint('Litter sire/dam fix failed: $e');
    debugPrintStack(stackTrace: st);
  }

  try {
    await NotificationService.instance.scheduleDailyDigest();
  } catch (e, st) {
    debugPrint('Daily digest scheduling failed: $e');
    debugPrintStack(stackTrace: st);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (AppearanceService.instance.mode.value == ThemeMode.system) {
      AppearanceService.refreshAllWidgetsForTheme();
      if (mounted) setState(() {});
    }
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7B6BA0),
        primary: const Color(0xFF7B6BA0),
        brightness: Brightness.light,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: const Color(0xFFE2BFFB),
        headerForegroundColor: const Color(0xFF463466),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        todayBorder: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF8B5CF6);
          }
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF8B5CF6);
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFC7C7CC);
          }
          return const Color(0xFF2C2C2E);
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF8B5CF6);
          }
          return null;
        }),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: const Color(0xFF8B5CF6),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: const Color(0xFF787880),
        ),
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF2B2138),
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF5E4A8A),
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5E4A8A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const darkBg = Color(0xFF121318);
    const darkCard = Color(0xFF1E2028);
    const darkElevated = Color(0xFF262936);
    const darkText = Color(0xFFF1F3F9);
    const darkSubtext = Color(0xFFB4B9C8);
    const darkAccent = Color(0xFFA78BFA);

    final baseDarkText = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: darkText,
      displayColor: darkText,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        onPrimary: Colors.white,
        secondary: Color(0xFFF472B6),
        onSecondary: Colors.white,
        surface: darkCard,
        onSurface: darkText,
        error: Color(0xFFF87171),
      ),
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      canvasColor: darkCard,
      dividerColor: const Color(0xFF2D303E),
      iconTheme: const IconThemeData(color: darkText),
      cardTheme: const CardThemeData(
        color: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkText,
        iconColor: darkSubtext,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF7E8494)),
        labelStyle: TextStyle(color: darkSubtext),
        floatingLabelStyle: TextStyle(color: darkAccent),
        suffixStyle: TextStyle(color: darkSubtext),
        prefixStyle: TextStyle(color: darkSubtext),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: darkText),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: darkSubtext,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        modalBackgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: darkElevated,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: darkText, fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkElevated,
        contentTextStyle: TextStyle(color: darkText),
      ),
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: const Color(0xFF261E38),
        headerForegroundColor: darkText,
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        todayBorder: const BorderSide(color: darkAccent, width: 1.5),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF7C52B8);
          }
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return darkAccent;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF555968);
          }
          return darkText;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF7C52B8);
          }
          return null;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return darkText;
        }),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: darkAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: darkSubtext,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF221C30),
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF7C52B8),
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C52B8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      useMaterial3: true,
      textTheme: baseDarkText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppearanceService.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Dynasty',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const _AppBootstrapScreen(),
          builder: (context, child) {
            final dark = AppearanceService.instance.isDark(context);
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
              ),
            );
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}

class _AppBootstrapScreen extends StatefulWidget {
  const _AppBootstrapScreen();

  @override
  State<_AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<_AppBootstrapScreen> {
  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: kAppCardWhite,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Startup failed on this device.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _bootstrapFuture = _initializeApp();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return HomeDashboardScreen();
      },
    );
  }
}
