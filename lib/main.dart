import 'package:flutter/material.dart';
import 'models/chat.dart';
import 'models/message.dart';
import 'services/chat_service.dart';
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
  final ChatService _chatService = ChatService();
  List<Chat> _chats = [];
  bool _isLoading = true;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeChats();
  }

  Future<void> _initializeChats() async {
    await Future.delayed(const Duration(milliseconds: 500));

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
        unreadCount: 2, // 2 mensajes no leídos
      ),
      Chat(
        id: '3',
        name: 'Mike Johnson',
        lastMessage: await _getLastMessageText('3', 'Did you check the latest documents I sent?'),
        avatarUrl: 'https://randomuser.me/api/portraits/men/3.jpg',
        lastMessageTime: await _getLastMessageTime('3', DateTime.now().subtract(const Duration(hours: 2))),
        unreadCount: 1, // 1 mensaje no leído
      ),
      Chat(
        id: '4',
        name: 'Emma Wilson',
        lastMessage: await _getLastMessageText('4', 'Thanks for your help yesterday!'),
        avatarUrl: 'https://randomuser.me/api/portraits/women/4.jpg',
        lastMessageTime: await _getLastMessageTime('4', DateTime.now().subtract(const Duration(days: 1))),
        unreadCount: 0, // Sin mensajes no leídos
      ),
      Chat(
        id: '5',
        name: 'Alex Brown',
        lastMessage: await _getLastMessageText('5', 'Are we still meeting for lunch?'),
        avatarUrl: 'https://randomuser.me/api/portraits/men/5.jpg',
        lastMessageTime: await _getLastMessageTime('5', DateTime.now().subtract(const Duration(days: 1, hours: 3))),
        unreadCount: 0, // Sin mensajes no leídos
      ),
      Chat(
        id: '6',
        name: 'Sophia Adams',
        lastMessage: await _getLastMessageText('6', 'Can you review the proposal I sent?'),
        avatarUrl: 'https://randomuser.me/api/portraits/women/5.jpg',
        lastMessageTime: await _getLastMessageTime('6', DateTime.now().subtract(const Duration(days: 2))),
        unreadCount: 3, // 3 mensajes no leídos
      ),
      Chat(
        id: '7',
        name: 'David Taylor',
        lastMessage: await _getLastMessageText('7', 'Happy Birthday! Enjoy your day!'),
        avatarUrl: 'https://randomuser.me/api/portraits/men/6.jpg',
        lastMessageTime: await _getLastMessageTime('7', DateTime.now().subtract(const Duration(days: 3))),
        unreadCount: 5, // 5 mensajes no leídos
      ),
      Chat(
        id: '8',
        name: 'Olivia Carter',
        lastMessage: await _getLastMessageText('8', 'I will call you tomorrow at 3 PM'),
        avatarUrl: 'https://randomuser.me/api/portraits/women/6.jpg',
        lastMessageTime: await _getLastMessageTime('8', DateTime.now().subtract(const Duration(days: 4))),
        unreadCount: 0, // Sin mensajes no leídos
      ),
      Chat(
        id: '9',
        name: 'Lucas King',
        lastMessage: await _getLastMessageText('9', 'Let\'s meet on Friday!'),
        avatarUrl: 'https://randomuser.me/api/portraits/men/7.jpg',
        lastMessageTime: await _getLastMessageTime('9', DateTime.now().subtract(const Duration(days: 5))),
        unreadCount: 0, // Sin mensajes no leídos
      ),
      Chat(
        id: '10',
        name: 'Mia Roberts',
        lastMessage: await _getLastMessageText('10', 'The task is complete. Thanks for your help!'),
        avatarUrl: 'https://randomuser.me/api/portraits/women/7.jpg',
        lastMessageTime: await _getLastMessageTime('10', DateTime.now().subtract(const Duration(days: 6))),
        unreadCount: 0, // Sin mensajes no leídos
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
    final theme = Theme.of(context);

    bool hasUnreadMessages = _chats.any((chat) => chat.unreadCount > 0);

    final List<Widget> pages = [
      Center(child: Text('Home page', style: theme.textTheme.titleLarge)),
      const Column(
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notification 1'),
              subtitle: Text('This is a notificacion'),
            ),
          ),
        ],
      ),
      _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ChatListScreen(chats: _chats, chatService: _chatService),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentPageIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.messenger_outline),
                if (hasUnreadMessages)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            selectedIcon: const Icon(Icons.messenger),
            label: 'Messages',
          ),
        ],
      ),
    );
  }
}