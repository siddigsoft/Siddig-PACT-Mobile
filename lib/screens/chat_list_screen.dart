import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import '../models/chat_participant.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import 'user_selection_screen.dart';
import 'chat_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);

    final chats = await _chatService.getUserChats();

    // Load unread counts for each chat
    final unreadCounts = <String, int>{};
    for (final chat in chats) {
      unreadCounts[chat.id] = await _chatService.getUnreadCount(chat.id);
    }

    setState(() {
      _chats = chats;
      _unreadCounts = unreadCounts;
      _isLoading = false;
    });
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
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final unreadCount = _unreadCounts[chat.id] ?? 0;

                    return FutureBuilder<List<ChatParticipant>>(
                      future: _chatService.getChatParticipants(chat.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Loading...',
                                  style: GoogleFonts.poppins()),
                              subtitle: Text('Private Chat',
                                  style: GoogleFonts.poppins(fontSize: 12)),
                            ),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Chat', style: GoogleFonts.poppins()),
                              subtitle: Text('Private Chat',
                                  style: GoogleFonts.poppins(fontSize: 12)),
                            ),
                          );
                        }

                        final participants = snapshot.data!;
                        final currentUserId = _chatService.getCurrentUserId();

                        // Get chat title based on type
                        String chatTitle = chat.name ?? 'Chat';
                        String chatSubtitle = '';

                        if (chat.chatType == 'private' &&
                            participants.isNotEmpty) {
                          ChatParticipant? otherParticipant;

                          if (participants.length == 1) {
                            // Only one participant (edge case)
                            otherParticipant = participants.first;
                          } else {
                            // Find participant that is NOT the current user
                            otherParticipant = participants.firstWhere(
                              (p) => p.userId != currentUserId,
                              orElse: () => participants.first,
                            );
                          }

                          chatTitle = otherParticipant.userName ??
                              otherParticipant.userId ??
                              'Unknown User';
                          chatSubtitle = 'Private Chat';
                        } else if (chat.chatType == 'group') {
                          chatSubtitle = '${participants.length} members';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              chatTitle,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            subtitle: chatSubtitle.isNotEmpty
                                ? Text(
                                    chatSubtitle,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textLight,
                                    ),
                                  )
                                : null,
                            trailing: unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryOrange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(chat: chat),
                                ),
                              ).then((_) =>
                                  _loadChats()); // Refresh when returning
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.textLight.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to connect with team members',
            style: GoogleFonts.poppins(
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startNewChat,
            icon: const Icon(Icons.add),
            label: const Text('Start New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
