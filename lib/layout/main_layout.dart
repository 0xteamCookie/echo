import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/home_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/sos_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/ack_db_screen.dart';
import '../screens/map_screen.dart';
import '../screens/scanner_screen.dart';
import '../database/db_hook.dart';
import '../main.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _currentIndex = 1;

  late final AnimationController _slideController;
  late final List<AnimationController> _navIconControllers;

  final List<Widget> _screens = const [
    SosScreen(),
    HomeScreen(),
    ChatScreen(),
    MapScreen(),
  ];

  static const _navItems = [
    _NavItem(
      icon: Icons.favorite_rounded,
      label: 'SOS',
      activeColor: Color(0xFFD96B45),
    ),
    _NavItem(
      icon: Icons.home_rounded,
      label: 'Home',
      activeColor: Color(0xFF6BBFA0),
    ),
    _NavItem(
      icon: Icons.chat_bubble_rounded,
      label: 'Chat',
      activeColor: Color(0xFFE8A87C),
    ),
    _NavItem(
      icon: Icons.map_rounded,
      label: 'Map',
      activeColor: Color.fromARGB(255, 0, 87, 55),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();

    _navIconControllers = List.generate(
      4,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        value: 0,
      ),
    );
    _navIconControllers[_currentIndex].forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    for (final c in _navIconControllers) c.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    _navIconControllers[_currentIndex].reverse();
    _navIconControllers[index].forward();
    _slideController.forward(from: 0);
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: SafeArea(child: _buildNav()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: BeaconColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cell_tower_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Beacon'),
        ],
      ),
      centerTitle: true,
      actions: [
        _AppBarIconButton(
          icon: Icons.qr_code_scanner_rounded,
          tooltip: 'Scan QR Code',
          onPressed: () =>
              Navigator.push(context, _warmRoute(const ScannerScreen())),
        ),
        _AppBarIconButton(
          icon: Icons.list_alt_rounded,
          tooltip: 'Message Log',
          onPressed: () =>
              Navigator.push(context, _warmRoute(const AckDbScreen())),
        ),
        _AppBarIconButton(
          icon: Icons.delete_sweep_rounded,
          tooltip: 'Nuke DB',
          onPressed: () async {
            await nukeDatabase();
            AppState().chatMessages.value = [];
            AppState().heartbeats.value = [];
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Database cleared. Fresh start!')),
              );
            }
          },
        ),
        GestureDetector(
          onDoubleTap: () =>
              Navigator.push(context, _warmRoute(const DevicesScreen())),
          child: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Tooltip(
              message: 'Devices (double-tap)',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BeaconColors.cardBorder,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: BeaconColors.textMid,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: BeaconColors.navBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BeaconColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: BeaconColors.primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            _navItems.length,
            (i) => _NavButton(
              item: _navItems[i],
              isSelected: _currentIndex == i,
              controller: _navIconControllers[i],
              onTap: () => _onTabTap(i),
            ),
          ),
        ),
      ),
    );
  }

  PageRoute<T> _warmRoute<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, animation, __) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
    );
  }
}
class _NavItem {
  final IconData icon;
  final String label;
  final Color activeColor;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.activeColor,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final AnimationController controller;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = controller.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? item.activeColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  item.icon,
                  size: 22,
                  color: Color.lerp(
                    BeaconColors.textLight,
                    item.activeColor,
                    t,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? item.activeColor : BeaconColors.textLight,
                  fontFamily: 'Inter',
                ),
                child: Text(item.label),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: BeaconColors.cardBorder,
            foregroundColor: BeaconColors.textMid,
            shape: const CircleBorder(),
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
