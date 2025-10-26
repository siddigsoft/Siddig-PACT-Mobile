import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_message_read.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user ID
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  // Get all chats for current user
  Future<List<Chat>> getUserChats() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Get all chats where user is a participant
      final response = await _supabase
          .from('chat_participants')
          .select('chat_id, chats(*)')
          .eq('user_id', currentUser.id);

      final chats = <Chat>[];
      for (final row in response) {
        if (row['chats'] != null) {
          final chat = Chat.fromJson(row['chats']);
          // Load participants for this chat
          final participants = await getChatParticipants(chat.id);
          chat.participants.addAll(participants);
          chats.add(chat);
        }
      }

      return chats;
    } catch (e) {
      print('Error getting user chats: $e');
      return [];
    }
  }

  // Create a new private chat between two users
  Future<Chat?> createPrivateChat(String otherUserId,
      {String? chatName}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return null;

    // Check if chat already exists
    final existingChat = await _findExistingPrivateChat(otherUserId);
    if (existingChat != null) return existingChat;

    try {
      // Create pair key (sorted user IDs)
      final userIds = [currentUser.id, otherUserId]..sort();
      final pairKey = '${userIds[0]}-${userIds[1]}';

      // Create chat
      final chatResponse = await _supabase
          .from('chats')
          .insert({
            'name': chatName ?? 'Private Chat',
            'type': 'private',
            'is_group': false,
            'created_by': currentUser.id,
            'pair_key': pairKey,
          })
          .select()
          .single();

      final chat = Chat.fromJson(chatResponse);

      // Add participants
      await _supabase.from('chat_participants').insert([
        {'chat_id': chat.id, 'user_id': currentUser.id},
        {'chat_id': chat.id, 'user_id': otherUserId},
      ]);

      // Load participants with user names
      final participants = await getChatParticipants(chat.id);
      chat.participants.addAll(participants);

      return chat;
    } catch (e) {
      print('Error creating private chat: $e');
      return null;
    }
  }

  // Find existing private chat between two users
  Future<Chat?> _findExistingPrivateChat(String otherUserId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return null;

    final userIds = [currentUser.id, otherUserId]..sort();
    final pairKey = '${userIds[0]}-${userIds[1]}';

    try {
      final response = await _supabase
          .from('chats')
          .select()
          .eq('pair_key', pairKey)
          .eq('type', 'private')
          .single();

      return Chat.fromJson(response);
    } catch (e) {
      // Chat doesn't exist
      return null;
    }
  }

  // Get messages for a chat
  Future<List<ChatMessage>> getChatMessages(String chatId,
      {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true)
          .limit(limit);

      return response.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      print('Error getting chat messages: $e');
      return [];
    }
  }

  // Send a message
  Future<ChatMessage?> sendMessage(String chatId, String content,
      {String contentType = 'text'}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return null;

    try {
      final response = await _supabase
          .from('chat_messages')
          .insert({
            'chat_id': chatId,
            'sender_id': currentUser.id,
            'content': content,
            'content_type': contentType,
            'status': 'sent',
          })
          .select()
          .single();

      return ChatMessage.fromJson(response);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase.from('chat_message_reads').upsert({
        'message_id': messageId,
        'user_id': currentUser.id,
        'read_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Get unread message count for a chat
  Future<int> getUnreadCount(String chatId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return 0;

    try {
      // Get total messages in chat
      final totalMessages = await _supabase
          .from('chat_messages')
          .select('id')
          .eq('chat_id', chatId)
          .neq('sender_id', currentUser.id); // Exclude own messages

      // Get read messages
      final readMessages = await _supabase
          .from('chat_message_reads')
          .select('message_id')
          .eq('user_id', currentUser.id);

      final readMessageIds = readMessages.map((r) => r['message_id']).toSet();

      return totalMessages
          .where((msg) => !readMessageIds.contains(msg['id']))
          .length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Get all users (for user selection)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email, role')
          .neq('id', _supabase.auth.currentUser?.id ?? '');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // Get chat participants
  Future<List<ChatParticipant>> getChatParticipants(String chatId) async {
    try {
      // Try to join with profiles table first
      final response = await _supabase
          .from('chat_participants')
          .select('*, profiles!inner(full_name)')
          .eq('chat_id', chatId);

      // Debug: print raw response to help trace participant loading issues
      // ignore: avoid_print
      print('getChatParticipants response for $chatId: $response');

      return response.map((json) {
        return ChatParticipant(
          chatId: json['chat_id'],
          userId: json['user_id'],
          userName: json['profiles']?['full_name'] ?? 'User ${json['user_id'].substring(0, 8)}',
          joinedAt: DateTime.parse(json['joined_at']),
        );
      }).toList();
    } catch (e) {
      // If join fails, try without join and query profiles separately
      print('Join with profiles failed, trying separate queries: $e');
      try {
        final response = await _supabase
            .from('chat_participants')
            .select('*')
            .eq('chat_id', chatId);

        final participants = <ChatParticipant>[];

        for (final json in response) {
          String? userName;

          // Try to get user name from profiles table
          try {
            final profileResponse = await _supabase
                .from('profiles')
                .select('full_name')
                .eq('id', json['user_id'])
                .maybeSingle();

            if (profileResponse != null && profileResponse['full_name'] != null) {
              userName = profileResponse['full_name'];
            }
          } catch (e) {
            print('Error getting profile for ${json['user_id']}: $e');
          }

          // Fallback to user ID if no name found
          userName ??= 'User ${json['user_id'].substring(0, 8)}';

          participants.add(ChatParticipant(
            chatId: json['chat_id'],
            userId: json['user_id'],
            userName: userName,
            joinedAt: DateTime.parse(json['joined_at']),
          ));
        }

        return participants;
      } catch (e) {
        // ignore: avoid_print
        print('Error getting chat participants: $e');
        return [];
      }
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get unread messages for this chat
      final unreadMessages = await _supabase
          .from('chat_messages')
          .select('id')
          .eq('chat_id', chatId)
          .neq('sender_id', currentUser.id);

      if (unreadMessages.isNotEmpty) {
        final messageIds = unreadMessages.map((msg) => msg['id']).toList();

        // Mark as read (upsert to avoid duplicates)
        await _supabase.from('chat_message_reads').upsert(
              messageIds
                  .map((messageId) => {
                        'message_id': messageId,
                        'user_id': currentUser.id,
                        'read_at': DateTime.now().toIso8601String(),
                      })
                  .toList(),
              onConflict: 'message_id,user_id',
            );
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}
