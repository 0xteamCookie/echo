import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database/db_hook.dart';
import 'peripheral/initialize.dart';
import 'central/intialize.dart';
import 'recieve/recieve-message.dart';
import 'layout/main_layout.dart';

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

  final savedMessages = await getMessages();
  AppState().chatMessages.value = savedMessages.reversed.toList();

  await setupBlePeripheral();

  // Wire up callbacks
  onDeviceListUpdated = (devs) {
    AppState().devices.value = devs;
  };

  onPeripheralMessageReceived = (msg, senderDeviceId) async {
    final decoded = await decodeAndSaveMessage(msg);
    final isHeartbeat =
        (decoded != null &&
            decoded['message'].toString().contains('Heartbeat')) ||
        msg.toString().contains('Heartbeat');

    final payload =
        decoded ??
        {
          'message': msg,
          'deviceId': 'Unknown',
          'time': DateTime.now().toIso8601String(),
        };

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
  startAutoScanner();
  runApp(const MyApp());
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
