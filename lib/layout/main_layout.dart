import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/sos_screen.dart';
import '../screens/devices_screen.dart';
import '../database/db_hook.dart';
import '../main.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 1; 

  final List<Widget> _screens = [
    const SosScreen(),
    const HomeScreen(),
    const ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scout'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.black26),
            onPressed: () async {
              await nukeDatabase();
              AppState().chatMessages.value = [];
              AppState().heartbeats.value = [];
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Database Nuked! Ready for fresh testing.")),
                );
              }
            },
          ),
          GestureDetector(
            onDoubleTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicesScreen())),
            child: const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.blur_on, color: Colors.black26), // Subtle icon
            ),
          )
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFE27D60),
          unselectedItemColor: Colors.black38,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'SOS'),
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          ],
        ),
      ),
    );
  }
}