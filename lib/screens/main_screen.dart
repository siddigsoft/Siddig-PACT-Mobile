// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components/bottom_navigation_bar.dart';
import 'field_operations_enhanced_screen.dart';
// import 'forms_screen.dart'; // Removed forms screen
// import 'equipment_screen.dart'; // Removed equipment screen
import 'safety_hub_screen.dart';
import 'chat_list_screen.dart';
import 'reports_screen.dart';
import 'wallet_screen.dart';
import '../widgets/online_offline_toggle.dart';
import '../widgets/network_status_indicator.dart';
import '../widgets/movable_online_offline_toggle.dart';
import '../widgets/incoming_call_dialog.dart';
import '../services/webrtc_service.dart';
import '../models/call_state.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  StreamSubscription<CallState>? _callStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeWebRTC() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('❌ Cannot initialize WebRTC: User not authenticated');
        return;
      }

      // Get user profile for name and avatar
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, username, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      String userName = 'User';
      String? userAvatar;

      if (response != null) {
        userName = (response['full_name'] as String?) ??
            (response['username'] as String?) ??
            user.email?.split('@').first ??
            'User';
        userAvatar = response['avatar_url'] as String?;
      }

      // Initialize WebRTC service
      await WebRTCService().initialize(
        user.id,
        userName,
        userAvatar: userAvatar,
      );

      debugPrint('✅ WebRTC service initialized for user: $userName');

      // Listen for incoming calls
      _callStateSubscription = WebRTCService().callStateStream.listen((state) {
        if (state.status == CallStatus.ringing &&
            state.remoteUserId != null &&
            mounted) {
          // Show incoming call dialog
          showIncomingCallDialog(
            context,
            callerId: state.remoteUserId!,
            callerName: state.remoteUserName ?? 'Unknown',
            callerAvatar: null,
            callId: state.callId!,
            callToken: state.callToken!,
            isAudioOnly: state.isAudioOnly,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ Error initializing WebRTC: $e');
    }
  }

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
      body: Stack(
        children: [
          _buildCurrentScreen(),
          // Offline mode banner at top
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OfflineModeBanner(),
          ),
          // Movable Online/Offline toggle (only for data collectors)
          MovableOnlineOfflineToggle(
            variant: ToggleVariant.uber,
          ),
        ],
      ),
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
