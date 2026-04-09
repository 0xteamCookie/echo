import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'layout/main_layout.dart';
import 'peripheral/initialize.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupBlePeripheral(); 
=======
import 'package:flutter/services.dart';

// Peripheral and Central logic imports
import 'peripheral/initialize.dart';
import 'central/intialize.dart'; // Make sure this matches your actual file name

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  // Initialize the peripheral (broadcasting) side
  await setupBlePeripheral();
  
>>>>>>> e402c24d7948dc117fba4becefdb07b2480b3474
  runApp(const MyApp());
}

// ─── Theme colours ────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0D14);
const _surface = Color(0xFF111827);
const _surfaceAlt = Color(0xFF1A2235);
const _accent = Color(0xFF00E5FF);
const _accentDim = Color(0xFF0097A7);
const _green = Color(0xFF00E676);
const _textPrimary = Color(0xFFE8F0FE);
const _textSecondary = Color(0xFF7B8DB0);
const _divider = Color(0xFF1E2D45);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Scout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _surface,
        ),
      ),
<<<<<<< HEAD
      home: const MainLayout(),
      debugShowCheckedModeBanner: false,
=======
      home: const BleScoutScreen(),
>>>>>>> e402c24d7948dc117fba4becefdb07b2480b3474
    );
  }
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class BleScoutScreen extends StatefulWidget {
  const BleScoutScreen({super.key});

  @override
  State<BleScoutScreen> createState() => _BleScoutScreenState();
}

class _BleScoutScreenState extends State<BleScoutScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _devices = [];
  final List<_HeartbeatEntry> _heartbeats = [];
  int _selectedTab = 0; // 0 = Devices, 1 = Heartbeat, 2 = Broadcast

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  
  // Add controller for custom message
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wire up Central callbacks before starting the scanner
    onDeviceListUpdated = (devices) {
      if (mounted) setState(() => _devices = devices);
    };

    onMessageReceived = (msg) {
      if (mounted) {
        setState(() {
          _heartbeats.insert(
            0,
            _HeartbeatEntry(message: msg, time: DateTime.now()),
          );
          if (_heartbeats.length > 50) _heartbeats.removeLast();
        });
      }
    };

    // Initialize the central (scanning) side
    startAutoScanner();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _buildCurrentTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedTab) {
      case 0:
        return _buildDeviceList();
      case 1:
        return _buildHeartbeatLog();
      case 2:
        return _buildPeripheralControls();
      default:
        return const SizedBox();
    }
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withOpacity(_pulseAnim.value),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(_pulseAnim.value * 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'BLE SCOUT',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _divider),
            ),
            child: Text(
              '${_devices.length} found',
              style: const TextStyle(
                fontSize: 11,
                color: _textSecondary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab(0, 'DEVICES', Icons.bluetooth_searching),
            const SizedBox(width: 10),
            _tab(1, 'HEARTBEAT', Icons.monitor_heart_outlined,
                badge: _heartbeats.isNotEmpty ? _heartbeats.length : null),
            const SizedBox(width: 10),
            _tab(2, 'BROADCAST', Icons.cell_tower),
            const SizedBox(width: 15),
            if (_selectedTab == 0)
              GestureDetector(
                onTap: () => restartScan(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 14, color: _accent),
                      SizedBox(width: 6),
                      Text(
                        'SEARCH',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: _accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(int index, String label, IconData icon, {int? badge}) {
    final active = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _accent : _divider,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? _accent : _textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: active ? _accent : _textSecondary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Peripheral controls ────────────────────────────────────────────────────

  Widget _buildPeripheralControls() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cell_tower, size: 64, color: _accentDim),
          const SizedBox(height: 20),
          const Text(
            "BROADCAST CONTROLS",
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Send messages or act as a beacon for other devices on the mesh.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          
          // Input Box for Custom Message
          TextField(
            controller: _msgController,
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: _surface,
              hintText: "Enter custom message / prefix",
              hintStyle: const TextStyle(color: _textSecondary),
              prefixIcon: const Icon(Icons.edit_note, color: _accentDim),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          _actionButton(
            label: "SEND ONCE",
            icon: Icons.send,
            color: Colors.orangeAccent,
            onTap: () {
              final msg = _msgController.text.trim().isNotEmpty
                  ? _msgController.text
                  : "Manual Alert!";
              sendMessageToCentral(msg);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message Sent!'), duration: Duration(seconds: 1)),
              );
            },
          ),
          const SizedBox(height: 16),
          _actionButton(
            label: "START AUTO-HEARTBEAT",
            icon: Icons.play_arrow,
            color: _green,
            onTap: () {
              startHeartbeat(_msgController.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Heartbeat Started'), duration: Duration(seconds: 1)),
              );
            },
          ),
          const SizedBox(height: 16),
          _actionButton(
            label: "STOP AUTO-HEARTBEAT",
            icon: Icons.stop,
            color: Colors.redAccent,
            onTap: () {
              stopHeartbeat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Heartbeat Stopped'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Device list ────────────────────────────────────────────────────────────

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bluetooth_searching,
        title: 'Scanning...',
        subtitle: 'Looking for nearby BLE devices',
      );
    }

    final sorted = [..._devices]
      ..sort((a, b) {
        if (a['connected'] == true && b['connected'] != true) return -1;
        if (b['connected'] == true && a['connected'] != true) return 1;
        return (b['rssi'] as int).compareTo(a['rssi'] as int);
      });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _DeviceCard(
        device: sorted[i],
        onConnect: connectToDevice,
      ),
    );
  }

  // ── Heartbeat log ──────────────────────────────────────────────────────────

  Widget _buildHeartbeatLog() {
    if (_heartbeats.isEmpty) {
      return _buildEmptyState(
        icon: Icons.monitor_heart_outlined,
        title: 'No messages yet',
        subtitle: 'Connect to a peripheral to see heartbeat data',
      );
    }

    return Column(
      children: [
        _buildLatestHero(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: _heartbeats.length,
            itemBuilder: (_, i) => _HeartbeatRow(entry: _heartbeats[i], index: i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: GestureDetector(
            onTap: () => setState(() => _heartbeats.clear()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _divider),
              ),
              child: const Center(
                child: Text(
                  'CLEAR LOG',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestHero() {
    final latest = _heartbeats.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_green.withOpacity(0.08), _accent.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart, size: 13, color: _green),
              const SizedBox(width: 6),
              const Text(
                'LATEST',
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: _green),
              ),
              const Spacer(),
              Text(
                _formatTime(latest.time),
                style: const TextStyle(fontSize: 10, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            latest.message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Icon(
              icon,
              size: 48,
              color: _accent.withOpacity(_pulseAnim.value * 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, color: _textPrimary, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: _textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

// ─── Device card widget ───────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onConnect});
  final Map<String, dynamic> device;
  final Function(String) onConnect;

  @override
  Widget build(BuildContext context) {
    final connected = device['connected'] == true;
    final rssi = device['rssi'] as int? ?? -100;
    final name = device['name'] as String? ?? 'Unknown';
    final id = device['id'] as String? ?? '';
    final services = (device['serviceUuids'] as List?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: connected ? _accent.withOpacity(0.07) : _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? _accent.withOpacity(0.4) : _divider,
          width: connected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SignalBars(rssi: rssi),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      id,
                      style: const TextStyle(
                          fontSize: 10, color: _textSecondary, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => onConnect(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: connected ? _green.withOpacity(0.15) : _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: connected ? _green.withOpacity(0.6) : _accent.withOpacity(0.6),
                    ),
                  ),
                  child: Text(
                    connected ? 'SUBSCRIBED' : 'CONNECT',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: connected ? _green : _accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (services.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: _divider, height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: services.map((s) => _UuidChip(uuid: s)).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.network_cell, size: 11, color: _textSecondary),
              const SizedBox(width: 4),
              Text(
                '$rssi dBm',
                style: const TextStyle(fontSize: 10, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});
  final int rssi;

  int get _level {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < level;
        return Container(
          width: 4,
          height: 6.0 + i * 4,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? _accent : _divider,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _UuidChip extends StatelessWidget {
  const _UuidChip({required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context) {
    final short = uuid.length > 8 ? '…${uuid.substring(uuid.length - 8)}' : uuid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _accentDim.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _accentDim.withOpacity(0.3)),
      ),
      child: Text(
        short.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          color: _accentDim,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _HeartbeatRow extends StatelessWidget {
  const _HeartbeatRow({required this.entry, required this.index});
  final _HeartbeatEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isFirst = index == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              _fmt(entry.time),
              style: TextStyle(
                fontSize: 10,
                color: isFirst ? _accent : _textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: _divider,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontSize: 12,
                color: isFirst ? _textPrimary : _textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

class _HeartbeatEntry {
  const _HeartbeatEntry({required this.message, required this.time});
  final String message;
  final DateTime time;
}