// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'components/bottom_navigation_bar.dart';
import 'field_operations_enhanced_screen.dart';
// import 'forms_screen.dart'; // Removed forms screen
// import 'equipment_screen.dart'; // Removed equipment screen
import 'safety_hub_screen.dart';
import 'chat_list_screen.dart';
import 'reports_screen.dart';
import 'wallet_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    if (index >= 0 && index < 5) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const FieldOperationsEnhancedScreen(key: ValueKey('home'));
      case 1:
        return const ReportsScreen(key: ValueKey('reports'));
      case 2:
        return const SafetyHubScreen(key: ValueKey('safety'));
      case 3:
        return const ChatListScreen(key: ValueKey('chat'));
      case 4:
        return const WalletScreen(key: ValueKey('wallet'));
      default:
        return const FieldOperationsEnhancedScreen(key: ValueKey('home'));
    }
  }
}
