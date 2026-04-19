import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'database/db_hook.dart';
import 'peripheral/initialize.dart';
import 'central/intialize.dart';
import 'recieve/recieve-message.dart';
import 'packet/get-deviceID.dart';
import 'layout/main_layout.dart';
import 'mesh/relay_loop.dart';

// ─── Global State ───────────────────────────────────────────────────────────
class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final ValueNotifier<List<Map<String, dynamic>>> devices = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> chatMessages = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> heartbeats = ValueNotifier([]);
}

// ─── Warm Colour Palette ────────────────────────────────────────────────────
class BeaconColors {
  static const background  = Color(0xFFFAF7F2);   // warm off-white
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFFF6EE);    // faint peach tint
  static const primary     = Color(0xFFD96B45);    // deeper terracotta
  static const secondary   = Color(0xFF6BBFA0);    // muted sage-green
  static const accent      = Color(0xFFE8A87C);    // warm amber
  static const textDark    = Color(0xFF2C2217);
  static const textMid     = Color(0xFF7A6A5A);
  static const textLight   = Color(0xFFB8A898);
  static const cardBorder  = Color(0xFFEDE3D8);
  static const navBg       = Color(0xFFFFFBF7);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: BeaconColors.navBg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());

  SchedulerBinding.instance.addPostFrameCallback((_) {
    _initializeApp();
  });
}

void _initializeApp() async {
  onDeviceListUpdated = (devs) {
    AppState().devices.value = devs;
  };

  onPeripheralMessageReceived = (msg, senderHardwareMac) async {
    final decoded = await decodeAndSaveMessage(msg, senderHardwareMac);

    if (decoded == null) return;

    if (decoded['messageId'] != null) {
      await insertMessageDevice(
        messageId: decoded['messageId'],
        deviceId: senderHardwareMac,
      );
    }

    if (decoded['isNew'] == false) return;

    final isHeartbeat =
        (decoded['message'].toString().contains('Heartbeat')) ||
        msg.toString().contains('Heartbeat');

    final payload = decoded;
    payload['relayerMac'] = senderHardwareMac;

    if (isHeartbeat) {
      final list = List<Map<String, dynamic>>.from(AppState().heartbeats.value);
      list.insert(0, payload);
      if (list.length > 50) list.removeLast();
      AppState().heartbeats.value = list;
    } else {
      final list = List<Map<String, dynamic>>.from(AppState().chatMessages.value);
      list.insert(0, payload);
      AppState().chatMessages.value = list;
    }
  };

  final savedMessages = await getMessages();
  AppState().chatMessages.value = savedMessages.reversed.toList();
  final chatHistory = savedMessages.where((m) => m['isSos'] != 1).toList();
  final sosHistory = savedMessages.where((m) => m['isSos'] == 1).toList();
  AppState().chatMessages.value = chatHistory.reversed.toList();
  AppState().heartbeats.value = sosHistory.reversed.toList();

  await setupBlePeripheral();
  startAutoScanner();
  startRelayLoop();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: BeaconColors.background,
        primaryColor: BeaconColors.primary,
        colorScheme: const ColorScheme.light(
          primary:   BeaconColors.primary,
          secondary: BeaconColors.secondary,
          surface:   BeaconColors.surface,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: BeaconColors.textDark, fontWeight: FontWeight.w800),
          titleLarge:   TextStyle(color: BeaconColors.textDark, fontWeight: FontWeight.w700, fontSize: 20),
          titleMedium:  TextStyle(color: BeaconColors.textDark, fontWeight: FontWeight.w600, fontSize: 16),
          bodyMedium:   TextStyle(color: BeaconColors.textMid,  fontSize: 14, height: 1.5),
          bodySmall:    TextStyle(color: BeaconColors.textLight, fontSize: 11),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: BeaconColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: BeaconColors.textMid),
          titleTextStyle: TextStyle(
            color: BeaconColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: BeaconColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: BeaconColors.cardBorder, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BeaconColors.surfaceWarm,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: BeaconColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          hintStyle: const TextStyle(color: BeaconColors.textLight, fontFamily: 'Inter'),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: BeaconColors.textDark,
          contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const MainLayout(),
    );
  }
}
