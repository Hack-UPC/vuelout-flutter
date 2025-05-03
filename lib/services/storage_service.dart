import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class StorageService {
  static const String _messagePrefix = 'chat_messages_';

  // Save messages for a specific chat
  Future<void> saveMessages(String chatId, List<Message> messages) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Convert messages to JSON
    final List<Map<String, dynamic>> jsonMessages = 
        messages.map((message) => message.toJson()).toList();
    
    // Save as a JSON string
    await prefs.setString(
      _messagePrefix + chatId, 
      jsonEncode(jsonMessages),
    );
  }

  // Load messages for a specific chat
  Future<List<Message>> getMessages(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get the JSON string
    final String? jsonString = prefs.getString(_messagePrefix + chatId);
    
    if (jsonString == null) {
      return [];
    }
    
    try {
      // Parse JSON and convert to Message objects
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }

  // Clear all messages for a chat
  Future<void> clearMessages(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagePrefix + chatId);
  }

  // Get all chat IDs that have stored messages
  Future<List<String>> getAllChatIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    return keys
        .where((key) => key.startsWith(_messagePrefix))
        .map((key) => key.substring(_messagePrefix.length))
        .toList();
  }
}