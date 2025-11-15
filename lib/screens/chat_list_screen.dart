import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat.dart';
import '../models/chat_participant.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import 'user_selection_screen.dart';
import 'chat_screen.dart';
import '../theme/app_design_system.dart';
import '../widgets/app_widgets.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  List<Chat> _chats = [];
  bool _isLoading = true;
  Map<String, int> _unreadCounts = {};

  String _fallbackLabel(String id) {
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    return 'User $shortId';
  }

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final cachedChats = await _chatService.getCachedUserChats();
    if (cachedChats.isNotEmpty && mounted) {
      setState(() {
        _chats = cachedChats;
        _unreadCounts = {
          for (final chat in cachedChats) chat.id: _unreadCounts[chat.id] ?? 0
        };
        _isLoading = false;
      });
    }

    try {
      final chats = await _chatService.getUserChats();

      // Load unread counts for each chat
      final unreadCounts = <String, int>{};
      for (final chat in chats) {
        unreadCounts[chat.id] = await _chatService.getUnreadCount(chat.id);
      }

      if (!mounted) return;
      setState(() {
        _chats = chats;
        _unreadCounts = unreadCounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (_chats.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load chats right now.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startNewChat() async {
    final selectedUser = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const UserSelectionScreen()),
    );

    if (selectedUser != null && mounted) {
      final chat = await _chatService.createPrivateChat(selectedUser['id']);
      if (chat != null) {
        await _loadChats(); // Refresh the list
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(chat: chat),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textDark,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.primaryOrange,
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
              ),
            )
          : _chats.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.all(AppDesignSystem.spaceMD),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final unreadCount = _unreadCounts[chat.id] ?? 0;

                    final participants = chat.participants;
                    final currentUserId = _chatService.getCurrentUserId();

                    String chatTitle = chat.name;
                    String chatSubtitle = '';

                    if (chat.chatType == 'private') {
                      String? displayName = chat.otherParticipantName;
                      String? counterpartId = chat.otherParticipantId;

                      if ((displayName == null || displayName.isEmpty) &&
                          counterpartId != null) {
                        ChatParticipant? participant;
                        for (final item in participants) {
                          if (item.userId == counterpartId) {
                            participant = item;
                            break;
                          }
                        }
                        displayName = participant?.userName;
                      }

                      if ((displayName == null || displayName.isEmpty) &&
                          counterpartId == null &&
                          participants.isNotEmpty) {
                        ChatParticipant? other;
                        for (final participant in participants) {
                          if (participant.userId != currentUserId) {
                            other = participant;
                            break;
                          }
                        }
                        other ??= participants.first;
                        counterpartId = other.userId;
                        displayName = other.userName;
                      }

                      if ((displayName == null || displayName.isEmpty) &&
                          chat.createdByName != null &&
                          chat.createdByName!.isNotEmpty &&
                          chat.createdBy != currentUserId) {
                        displayName = chat.createdByName;
                        counterpartId ??= chat.createdBy;
                      }

                      if ((displayName == null || displayName.isEmpty) &&
                          counterpartId != null) {
                        displayName = _fallbackLabel(counterpartId);
                      }

                      chatTitle = displayName ?? _fallbackLabel(chat.id);
                      chatSubtitle = 'Private Chat';
                    } else if (chat.chatType == 'group') {
                      chatSubtitle = '${participants.length} members';
                      if (chatTitle.isEmpty &&
                          chat.createdByName != null &&
                          chat.createdByName!.isNotEmpty) {
                        chatTitle = chat.createdByName!;
                      }
                    } else if (chat.createdByName != null &&
                        chat.createdByName!.isNotEmpty) {
                      chatTitle = chat.createdByName!;
                    }

                    if (chatTitle.isEmpty) {
                      chatTitle = _fallbackLabel(chat.id);
                    }

                    return AppCard(
                      margin:
                          EdgeInsets.only(bottom: AppDesignSystem.spaceSM),
                      shadows: AppDesignSystem.shadowSM,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(chat: chat),
                          ),
                        ).then((_) => _loadChats());
                      },
                      child: Padding(
                        padding: EdgeInsets.all(AppDesignSystem.spaceSM),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  chatTitle.isNotEmpty
                                      ? chatTitle[0].toUpperCase()
                                      : '?',
                                  style:
                                      AppDesignSystem.headlineMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: AppDesignSystem.spaceMD),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chatTitle,
                                    style:
                                        AppDesignSystem.titleLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (chatSubtitle.isNotEmpty) ...[
                                    SizedBox(height: AppDesignSystem.spaceXS),
                                    Text(
                                      chatSubtitle,
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppDesignSystem.spaceSM,
                                  vertical: AppDesignSystem.spaceXS,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(
                                    AppDesignSystem.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: AppDesignSystem.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ).animate().scale(
                                    duration: 300.ms,
                                    curve: Curves.elasticOut,
                                  ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (index * 50).ms)
                        .slideX(begin: 0.2, end: 0);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewChat,
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Chat',
          style: AppDesignSystem.labelLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ).animate().scale(delay: 500.ms, duration: 400.ms),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppDesignSystem.spaceLG),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: AppColors.primaryOrange,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          SizedBox(height: AppDesignSystem.spaceLG),
          Text(
            'No conversations yet',
            style: AppDesignSystem.headlineLarge,
          ).animate().fadeIn(delay: 200.ms),
          SizedBox(height: AppDesignSystem.spaceSM),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDesignSystem.spaceLG),
            child: Text(
              'Start a new chat to connect with team members',
              style: AppDesignSystem.bodyLarge.copyWith(
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 300.ms),
          SizedBox(height: AppDesignSystem.spaceLG),
          ElevatedButton.icon(
            onPressed: _startNewChat,
            icon: const Icon(Icons.add),
            label: const Text('Start New Chat'),
            style: AppDesignSystem.primaryButton(),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }
}
