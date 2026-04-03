import 'package:flutter/material.dart';
import '../screens/messaging_screen.dart';
import '../screens/home_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/map_screen.dart';
import '../screens/sos_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 2; 

  final List<Widget> _screens = [
    const MessagingScreen(),
    const ChatbotScreen(),
    const HomeScreen(),
    const MapScreen(),
    const SosScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messaging',
          ),
         
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy), 
            label: 'Chatbot',
          ),
           BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded), // SOS icon
            label: 'SOS',
          ),
        ],
      ),
    );
  }
}