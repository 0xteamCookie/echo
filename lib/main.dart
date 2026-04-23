import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'database/db_hook.dart';
import 'peripheral/initialize.dart';
import 'central/intialize.dart';
import 'crypto/ed25519.dart' as ed25519;
import 'receive/receive_message.dart';
import 'layout/main_layout.dart';
import 'mesh/relay_loop.dart';
import 'models/rescuer_session.dart';
import 'auth/auth_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'online/sync.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'send/send_heartbeat.dart';
import 'services/activity_monitor.dart';
import 'services/mesh_foreground_service.dart';

enum UserRole {
  user,
  rescuer,
}

// ─── Global State ───────────────────────────────────────────────────────────
class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final ValueNotifier<UserRole> role = ValueNotifier(UserRole.user);
  final ValueNotifier<RescuerSession?> rescuerSession = ValueNotifier(null);
  final ValueNotifier<List<Map<String, dynamic>>> devices = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> chatMessages = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> heartbeats = ValueNotifier([]);
}

/// Root navigator key — used by background services (ActivityMonitor) that
/// need to surface modal UI (fall-detected countdown) without holding a
/// BuildContext of their own.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
  await dotenv.load(fileName: ".env");

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
  // Restore any saved rescuer session from secure storage
  await AuthService.isLoggedIn();

  // P2-11: ensure the device's long-lived Ed25519 identity exists so every
  // outgoing packet can be signed. Failure here is non-fatal — sending just
  // falls back to unsigned v2 frames (covered by the getPublicKeyB64 → ''
  // short-circuit in send_message.dart).
  try {
    await ed25519.ensureKeypair();
  } catch (e) {
    debugPrint('ed25519 keypair init failed: $e');
  }

  // Sync messages to internet
  syncMessages();

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

    // Route on the authoritative isSos flag from the decoded packet; never on
    // substring matches against the (untrusted) human message body (P0-4).
    final isSos = decoded['isSos'] == 1;

    final payload = decoded;
    payload['relayerMac'] = senderHardwareMac;

    if (isSos) {
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
  final chatHistory = savedMessages.where((m) => m['isSos'] != 1).toList();
  final sosHistory = savedMessages.where((m) => m['isSos'] == 1).toList();
  AppState().chatMessages.value = chatHistory.reversed.toList();
  AppState().heartbeats.value = sosHistory.reversed.toList();

  // Sync automatically when internet reconnects
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
    if (!result.contains(ConnectivityResult.none)) {
       syncMessages();
    }
  });

  await setupBlePeripheral();
  startAutoScanner();
  startRelayLoop();

  // P0-3: keep the mesh alive when the user leaves the app.
  // Best-effort: any failure here (e.g. iOS, or permission denied) is logged
  // and swallowed so the foreground UI still works.
  try {
    await MeshForegroundService.initAndStart();
  } catch (e) {
    debugPrint('Foreground service start failed: $e');
  }

  // P2-15: wire the fall-detector SOS trigger and (if the user opted in)
  // start the accelerometer listener. The actual 30 s countdown UI is owned
  // by the home screen — see `home_screen.dart`.
  ActivityMonitor.instance.installHooks(
    sosTrigger: (msg) async {
      await sendSosHeartbeat(department: 'Rescue', additionalMessage: msg);
    },
    warningHandler: ({required countdown, required onCancel, required onConfirm}) {
      _showFallWarningDialog(countdown, onCancel, onConfirm);
    },
  );
  try {
    await ActivityMonitor.instance.start();
  } catch (e) {
    debugPrint('ActivityMonitor start failed: $e');
  }
}

void _showFallWarningDialog(
  Duration countdown,
  VoidCallback onCancel,
  VoidCallback onConfirm,
) {
  final navCtx = rootNavigatorKey.currentContext;
  if (navCtx == null) return;
  showDialog<void>(
    context: navCtx,
    barrierDismissible: false,
    builder: (ctx) => _FallWarningDialog(
      duration: countdown,
      onCancel: () {
        onCancel();
        Navigator.of(ctx).pop();
      },
      onSendNow: () {
        onConfirm();
        Navigator.of(ctx).pop();
      },
    ),
  );
}

class _FallWarningDialog extends StatefulWidget {
  final Duration duration;
  final VoidCallback onCancel;
  final VoidCallback onSendNow;

  const _FallWarningDialog({
    required this.duration,
    required this.onCancel,
    required this.onSendNow,
  });

  @override
  State<_FallWarningDialog> createState() => _FallWarningDialogState();
}

class _FallWarningDialogState extends State<_FallWarningDialog> {
  late int _secondsLeft;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.duration.inSeconds;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft = (_secondsLeft - 1).clamp(0, 999);
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_rounded, color: Color(0xFFD96B45), size: 40),
      title: const Text('Possible fall detected'),
      content: Text(
        'Auto-SOS will broadcast in $_secondsLeft s unless you cancel.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text("I'm OK"),
        ),
        ElevatedButton(
          onPressed: widget.onSendNow,
          child: const Text('Send now'),
        ),
      ],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
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
