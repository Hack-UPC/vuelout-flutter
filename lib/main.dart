import 'package:flutter/material.dart';
import 'models/chat.dart';
import 'models/message.dart';
import 'screens/chat_list_screen.dart';
import 'services/chat_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vuelout Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Initialize chat service
  final ChatService _chatService = ChatService();
  
  // Sample data for chats
  List<Chat> _chats = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _initializeChats();
  }

  Future<void> _initializeChats() async {
    // Allow time for chat service to load messages from storage
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Create chat list with latest data
    final chats = [
      Chat(
        id: '1',
        name: 'John Doe',
        lastMessage: await _getLastMessageText('1', 'Hey, how are you doing?'),
        avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
        lastMessageTime: await _getLastMessageTime('1', DateTime.now().subtract(const Duration(minutes: 5))),
        unreadCount: _chatService.getUnreadCount('1'),
      ),
      Chat(
        id: '2',
        name: 'Sarah Smith',
        lastMessage: await _getLastMessageText('2', 'The meeting is scheduled for tomorrow at 10 AM'),
        avatarUrl: 'https://randomuser.me/api/portraits/women/2.jpg',
        lastMessageTime: await _getLastMessageTime('2', DateTime.now().subtract(const Duration(hours: 1))),
        unreadCount: _chatService.getUnreadCount('2'),
      ),
      Chat(
        id: '3',
        name: 'Mike Johnson',
        lastMessage: await _getLastMessageText('3', 'Did you check the latest documents I sent?'),
        avatarUrl: 'https://randomuser.me/api/portraits/men/3.jpg',
        lastMessageTime: await _getLastMessageTime('3', DateTime.now().subtract(const Duration(hours: 2))),
        unreadCount: _chatService.getUnreadCount('3'),
      ),
      Chat(
        id: '4',
        name: 'Emma Wilson',
        lastMessage: await _getLastMessageText('4', 'Thanks for your help yesterday!'),
        avatarUrl: 'https://randomuser.me/api/portraits/women/4.jpg',
        lastMessageTime: await _getLastMessageTime('4', DateTime.now().subtract(const Duration(days: 1))),
        unreadCount: _chatService.getUnreadCount('4'),
      ),
      Chat(
        id: '5',
        name: 'Alex Brown',
        lastMessage: await _getLastMessageText('5', 'Are we still meeting for lunch?'),
        avatarUrl: 'https://randomuser.me/api/portraits/men/5.jpg',
        lastMessageTime: await _getLastMessageTime('5', DateTime.now().subtract(const Duration(days: 1, hours: 3))),
        unreadCount: _chatService.getUnreadCount('5'),
      ),
    ];

    if (mounted) {
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    }
  }
  
  Future<String> _getLastMessageText(String chatId, String defaultText) async {
    final messages = await _chatService.getMessages(chatId);
    if (messages.isNotEmpty) {
      return messages.last.text;
    }
    return defaultText;
  }
  
  Future<DateTime> _getLastMessageTime(String chatId, DateTime defaultTime) async {
    final messages = await _chatService.getMessages(chatId);
    if (messages.isNotEmpty) {
      return messages.last.timestamp;
    }
    return defaultTime;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading 
      ? const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        )
      : ChatListScreen(
          chats: _chats,
          chatService: _chatService,
        );
  }
}
