// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'components/bottom_navigation_bar.dart';
import 'field_operations_enhanced_screen.dart';
import 'forms_screen.dart';
import 'equipment_screen.dart';
import 'safety_hub_screen.dart';
import 'chat_list_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const FieldOperationsEnhancedScreen(),
    const FormsScreen(),
    const EquipmentScreen(),
    const SafetyHubScreen(),
    const ChatListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_currentIndex],
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
