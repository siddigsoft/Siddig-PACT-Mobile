// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_contact.dart';
import '../services/chat_service.dart';
import '../services/chat_contact_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_handler.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ChatContactService _contactService = ChatContactService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  List<ChatParticipant> _participants = [];
  bool _participantsLoaded = false;
  ChatContact? _chatContact;
  String? _contactUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadMessages();
    _loadParticipants();
    _loadContactInfo();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _chatService.getChatMessages(widget.chat.id);

    setState(() {
      _messages = messages.reversed.toList(); // Show newest at bottom
      _isLoading = false;
    });

    // Scroll to bottom after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadParticipants() async {
    final participants = await _chatService.getChatParticipants(widget.chat.id);
    // Debug: print participants loaded
    // ignore: avoid_print
    print('_loadParticipants for ${widget.chat.id}: $participants');

    setState(() {
      _participants = participants;
      _participantsLoaded = true;
    });

    // Get the contact user ID if this is a private chat
    if (widget.chat.chatType == 'private' && _currentUserId != null) {
      final otherParticipant = participants.firstWhere(
        (p) => p.userId != _currentUserId,
        orElse: () => participants.isNotEmpty
            ? participants.first
            : ChatParticipant(
                chatId: widget.chat.id,
                userId: '',
                userName: 'Unknown',
                joinedAt: DateTime.now(),
              ),
      );
      _contactUserId = otherParticipant.userId;
    }
  }

  // Load contact information from chat_contacts table
  Future<void> _loadContactInfo() async {
    if (_currentUserId == null || widget.chat.chatType != 'private') return;

    // Wait for participants to load first to get the contact user ID
    await Future.delayed(const Duration(milliseconds: 100));

    if (_contactUserId == null || _contactUserId!.isEmpty) return;

    try {
      final contact =
          await _contactService.getContact(_currentUserId!, _contactUserId!);

      // If contact doesn't exist, create it with default name
      if (contact == null && _contactUserId!.isNotEmpty) {
        final defaultName =
            await _contactService.fetchUserProfileName(_contactUserId!);
        final newContact = await _contactService.saveContact(
          userId: _currentUserId!,
          contactUserId: _contactUserId!,
          defaultName: defaultName,
        );
        setState(() {
          _chatContact = newContact;
        });
      } else if (contact != null) {
        setState(() {
          _chatContact = contact;
        });
      }
    } catch (e) {
      print('Error loading contact info: $e');
    }
  }

  // Get sender name from participants list
  String _getSenderName(String senderId) {
    if (senderId == _currentUserId) {
      return 'You';
    }

    final participant = _participants.firstWhere(
      (p) => p.userId == senderId,
      orElse: () => ChatParticipant(
        chatId: widget.chat.id,
        userId: senderId,
        userName: 'Unknown User',
        joinedAt: DateTime.now(),
      ),
    );

    return participant.userName ?? 'User ${senderId.substring(0, 8)}';
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.chat.id);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final message = await _chatService.sendMessage(widget.chat.id, content);
      if (message != null) {
        setState(() {
          _messages.add(message);
        });
        _messageController.clear();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        context.showError(e, onRetry: _sendMessage);
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _getChatTitle() {
    if (widget.chat.chatType == 'private') {
      // Use contact's custom name if available
      if (_chatContact != null) {
        return _chatContact!.displayName;
      }

      // Otherwise fall back to participant name
      if (!_participantsLoaded || _participants.isEmpty) {
        return 'Loading...';
      }

      ChatParticipant otherParticipant;

      if (_participants.length == 1) {
        otherParticipant = _participants.first;
      } else {
        ChatParticipant? found;
        if (_currentUserId != null) {
          found = _participants.firstWhere(
            (p) => p.userId != _currentUserId,
            orElse: () => _participants.first,
          );

          if (found.userId == _currentUserId && _participants.length > 1) {
            final currentIndex =
                _participants.indexWhere((p) => p.userId == _currentUserId);
            final otherIndex = currentIndex == 0 ? 1 : 0;
            found = _participants[otherIndex];
          }
        } else {
          found =
              _participants.length > 1 ? _participants[1] : _participants.first;
        }

        otherParticipant = found;
      }

      return otherParticipant.userName ?? 'Unknown User';
    } else {
      // For group chats, show the chat name
      return widget.chat.name ?? 'Group Chat';
    }
  }

  // Show dialog to edit contact name
  Future<void> _editContactName() async {
    if (_currentUserId == null || _contactUserId == null) return;

    final TextEditingController nameController = TextEditingController(
      text: _chatContact?.customName ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Contact Name',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Enter custom name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, nameController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final updatedContact = await _contactService.updateContactName(
          userId: _currentUserId!,
          contactUserId: _contactUserId!,
          customName: result,
          defaultName: _chatContact?.defaultName,
        );

        setState(() {
          _chatContact = updatedContact;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact name updated to "$result"'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update contact name: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }

    nameController.dispose();
  }

  // Confirm and delete the entire chat
  Future<void> _confirmDeleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this entire chat? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteChat();
    }
  }

  // Delete the chat and navigate back
  Future<void> _deleteChat() async {
    try {
      await _chatService.deleteChat(widget.chat.id);

      // Also delete the contact if it exists
      if (_currentUserId != null && _contactUserId != null) {
        await _contactService.deleteContact(_currentUserId!, _contactUserId!);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _getChatTitle(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Edit contact name button (only for private chats)
          if (widget.chat.chatType == 'private')
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: _editContactName,
              tooltip: 'Edit contact name',
            ),
          // Delete chat button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _confirmDeleteChat,
            tooltip: 'Delete chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isCurrentUser =
                              message.senderId == _currentUserId;

                          return _buildMessageBubble(message, isCurrentUser);
                        },
                      ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundGray,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isCurrentUser) {
    final senderName = _getSenderName(message.senderId);

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _confirmDeleteMessage(message),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isCurrentUser ? AppColors.primaryGradient : null,
            color: isCurrentUser ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isCurrentUser
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isCurrentUser
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show sender name for group chats or non-current user
              if (!isCurrentUser || widget.chat.chatType == 'group')
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName,
                    style: GoogleFonts.poppins(
                      color: isCurrentUser
                          ? Colors.white.withOpacity(0.9)
                          : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                message.content ?? '',
                style: GoogleFonts.poppins(
                  color: isCurrentUser ? Colors.white : AppColors.textDark,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMessageTime(message.createdAt),
                style: GoogleFonts.poppins(
                  color: isCurrentUser
                      ? Colors.white.withOpacity(0.7)
                      : AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // Confirm and delete a single message
  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Message',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMessage(message);
    }
  }

  // Delete a single message
  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await _chatService.deleteMessage(message.id);

      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
            'No messages yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: GoogleFonts.poppins(
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
