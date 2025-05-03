import 'package:flutter/material.dart';
import 'models/chat.dart';
import 'screens/chat_list_screen.dart';

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
  // Sample data for chats
  final List<Chat> _chats = [
    Chat(
      id: '1',
      name: 'John Doe',
      lastMessage: 'Hey, how are you doing?',
      avatarUrl: 'https://randomuser.me/api/portraits/men/1.jpg',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 2,
    ),
    Chat(
      id: '2',
      name: 'Sarah Smith',
      lastMessage: 'The meeting is scheduled for tomorrow at 10 AM',
      avatarUrl: 'https://randomuser.me/api/portraits/women/2.jpg',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: 0,
    ),
    Chat(
      id: '3',
      name: 'Mike Johnson',
      lastMessage: 'Did you check the latest documents I sent?',
      avatarUrl: 'https://randomuser.me/api/portraits/men/3.jpg',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 3,
    ),
    Chat(
      id: '4',
      name: 'Emma Wilson',
      lastMessage: 'Thanks for your help yesterday!',
      avatarUrl: 'https://randomuser.me/api/portraits/women/4.jpg',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
    ),
    Chat(
      id: '5',
      name: 'Alex Brown',
      lastMessage: 'Are we still meeting for lunch?',
      avatarUrl: 'https://randomuser.me/api/portraits/men/5.jpg',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      unreadCount: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(chats: _chats);
  }
}
