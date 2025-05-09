import '../models/message.dart';
import '../models/chat.dart';
import 'storage_service.dart';

class ChatService {
  // Mock user ID - in a real app, this would come from authentication
  static const String currentUserId = 'current_user';
  
  // In-memory storage of messages for each chat
  final Map<String, List<Message>> _chatMessages = {};
  
  // Storage service for persistence
  final StorageService _storageService = StorageService();

  // Initialize with sample message data
  ChatService() {
    _initializeMessages();
  }

  // Load messages from storage or use sample data if storage is empty
  Future<void> _initializeMessages() async {
    // First check if we have any saved messages
    final chatIds = await _storageService.getAllChatIds();
    
    if (chatIds.isEmpty) {
      // No saved messages, use sample data
      _initSampleData();
      // Save the sample data to storage
      for (final chatId in _chatMessages.keys) {
        await _storageService.saveMessages(chatId, _chatMessages[chatId]!);
      }
    } else {
      // Load messages from storage
      for (final chatId in chatIds) {
        _chatMessages[chatId] = await _storageService.getMessages(chatId);
      }
    }
  }

  void _initSampleData() {
    // For chat 1
    _chatMessages['1'] = [
      Message(
        id: '1_1',
        senderId: '1',
        text: 'Hey, how are you doing?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Message(
        id: '1_2',
        senderId: currentUserId,
        text: 'I\'m good! Working on a new project.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      Message(
        id: '1_3',
        senderId: '1',
        text: 'Sounds interesting! What are you building?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      Message(
        id: '1_4',
        senderId: currentUserId,
        text: 'A chat app using Flutter! Pretty cool so far.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      Message(
        id: '1_5',
        senderId: '1',
        text: 'That\'s great! I\'d like to see it when it\'s done.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];

    // For chat 2
    _chatMessages['2'] = [
      Message(
        id: '2_1',
        senderId: '2',
        text: 'The meeting is scheduled for tomorrow at 10 AM',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Message(
        id: '2_2',
        senderId: currentUserId,
        text: 'Thanks for letting me know. I\'ll be there.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 55)),
      ),
    ];

    // For chat 3
    _chatMessages['3'] = [
      Message(
        id: '3_1',
        senderId: '3',
        text: 'Did you check the latest documents I sent?',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Message(
        id: '3_2',
        senderId: currentUserId,
        text: 'Not yet, I\'ll look at them this afternoon.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
      ),
      Message(
        id: '3_3',
        senderId: '3',
        text: 'Great, let me know if you have any questions.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      ),
    ];

    // For chat 4
    _chatMessages['4'] = [
      Message(
        id: '4_1',
        senderId: '4',
        text: 'Thanks for your help yesterday!',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    // For chat 5
    _chatMessages['5'] = [
      Message(
        id: '5_1',
        senderId: '5',
        text: 'Are we still meeting for lunch?',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ),
      Message(
        id: '5_2',
        senderId: currentUserId,
        text: 'Yes, 1 PM at the usual place works for me.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      ),
    ];
  }

  // Get all messages for a specific chat
  Future<List<Message>> getMessages(String chatId) async {
    // If we don't have the messages in memory yet, try to load from storage
    if (!_chatMessages.containsKey(chatId)) {
      _chatMessages[chatId] = await _storageService.getMessages(chatId);
    }
    return _chatMessages[chatId] ?? [];
  }

  // Send a new message in a chat
  Future<void> sendMessage(String chatId, String text) async {
    final messageId = '${chatId}_${(_chatMessages[chatId]?.length ?? 0) + 1}_${DateTime.now().millisecondsSinceEpoch}';
    
    final newMessage = Message(
      id: messageId,
      senderId: currentUserId,
      text: text,
      timestamp: DateTime.now(),
    );
    
    if (_chatMessages[chatId] == null) {
      _chatMessages[chatId] = [];
    }
    
    _chatMessages[chatId]!.add(newMessage);
    
    // Persist to storage
    await _storageService.saveMessages(chatId, _chatMessages[chatId]!);
  }

  // Mark all messages in a chat as read
  Future<void> markChatAsRead(String chatId) async {
    final messages = _chatMessages[chatId];
    if (messages == null) return;

    bool hasChanges = false;
    
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].senderId != currentUserId && !messages[i].isRead) {
        final message = messages[i];
        messages[i] = Message(
          id: message.id,
          senderId: message.senderId,
          text: message.text,
          timestamp: message.timestamp,
          isRead: true,
        );
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      // Persist to storage
      await _storageService.saveMessages(chatId, messages);
    }
  }

  // Get unread message count for a specific chat
  int getUnreadCount(String chatId) {
    final messages = _chatMessages[chatId];
    if (messages == null) return 0;

    return messages.where((message) => 
      message.senderId != currentUserId && !message.isRead
    ).length;
  }
  
  // Get the last message from a chat
  Message? getLastMessage(String chatId) {
    final messages = _chatMessages[chatId];
    if (messages == null || messages.isEmpty) return null;
    
    return messages.last;
  }
}