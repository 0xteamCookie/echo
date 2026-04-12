import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'database/db_hook.dart';
import 'peripheral/initialize.dart';
import 'central/intialize.dart';
import 'recieve/recieve-message.dart';
import 'packet/get-deviceID.dart'; 
import 'layout/main_layout.dart';
import 'mesh/decision-relay.dart';

// ─── Global State ───────────────────────────────────────────────────────────
class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final ValueNotifier<List<Map<String, dynamic>>> devices = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> chatMessages = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> heartbeats = ValueNotifier(
    [],
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
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
      // Remember we got this from senderHardwareMac so we don't bounce it back to them
      await insertMessageDevice(
        messageId: decoded['messageId'],
        deviceId: senderHardwareMac,
      );
    }

    // Only propagate completely new messages to the UI list
    if (decoded['isNew'] == false) return;

    final isHeartbeat =
        (decoded['message'].toString().contains('Heartbeat')) ||
        msg.toString().contains('Heartbeat');

    final payload = decoded;
    payload['relayerMac'] = senderHardwareMac; // Add relayer MAC for UI display

    if (isHeartbeat) {
      final list = List<Map<String, dynamic>>.from(AppState().heartbeats.value);
      list.insert(0, payload);
      if (list.length > 50) list.removeLast();
      AppState().heartbeats.value = list;
    } else {
      final list = List<Map<String, dynamic>>.from(
        AppState().chatMessages.value,
      );
      list.insert(0, payload);
      AppState().chatMessages.value = list;
    }
  };

  final savedMessages = await getMessages();
  AppState().chatMessages.value = savedMessages.reversed.toList();

  await setupBlePeripheral();
  startAutoScanner();
  startRelayLoop();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Scout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F6F0),
        primaryColor: const Color(0xFFE27D60),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFE27D60),
          secondary: Color(0xFF85DCB8),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9F6F0),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF4A4A4A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF4A4A4A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        fontFamily: 'Inter',
      ),
      home: const MainLayout(),
    );
  }
}
