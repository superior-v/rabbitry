import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'screens/home_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dynasty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E4A8A),
          primary: const Color(0xFF5E4A8A),
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
      ),
      home: const _AppBootstrapScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
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
            backgroundColor: Colors.white,
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
