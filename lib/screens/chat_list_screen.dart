import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'bluetooth_scan_screen.dart';

class ChatListScreen extends StatefulWidget {
  final List<Chat> chats;
  final ChatService chatService;

  const ChatListScreen({
    super.key, 
    required this.chats,
    required this.chatService,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Chat> _chats = [];
  BluetoothDevice? _connectedDevice;
  bool _isBluetoothConnected = false;
  
  @override
  void initState() {
    super.initState();
    _chats = widget.chats;
    _checkBluetoothConnection();
    
    // Listen for chat updates (especially from Bluetooth)
    widget.chatService.onChatUpdated.listen((chatId) {
      _refreshChats();
    });
  }
  
  Future<void> _checkBluetoothConnection() async {
    _isBluetoothConnected = widget.chatService.isConnectedToBluetooth();
    _connectedDevice = widget.chatService.getConnectedDevice();
    
    if (mounted) {
      setState(() {});
    }
  }
  
  Future<void> _refreshChats() async {
    // This would fetch the latest chat data including any new Bluetooth chats
    // For now we'll just update the Bluetooth connection status
    await _checkBluetoothConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          if (_isBluetoothConnected) 
            _buildBluetoothStatusIcon(),
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: () => _navigateToBluetoothScan(),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Implement menu
            },
          ),
        ],
      ),
      body: _chats.isEmpty 
        ? const Center(child: Text('No chats yet'))
        : ListView.builder(
            itemCount: _chats.length,
            itemBuilder: (context, index) {
              final chat = _chats[index];
              
              // Get unread count from the chat service
              final unreadCount = widget.chatService.getUnreadCount(chat.id);
              
              return ChatListItem(
                chat: chat,
                unreadCount: unreadCount,
                onTap: () => _navigateToChatDetail(chat),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToBluetoothScan(),
        tooltip: 'Find nearby devices',
        child: const Icon(Icons.bluetooth_searching),
      ),
    );
  }

  Widget _buildBluetoothStatusIcon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: 'Connected to: ${_connectedDevice?.platformName ?? "Unknown device"}',
        child: const Icon(
          Icons.bluetooth_connected,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Future<void> _navigateToBluetoothScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BluetoothScanScreen(
          chatService: widget.chatService,
        ),
      ),
    );
    
    // If we got back a Chat, that means a device was connected
    if (result is Chat) {
      setState(() {
        // Add the new chat if it doesn't exist
        if (!_chats.any((chat) => chat.id == result.id)) {
          _chats = [..._chats, result];
        }
      });
      
      // Navigate to the chat detail screen
      _navigateToChatDetail(result);
    }
    
    // Refresh regardless
    _refreshChats();
  }

  void _navigateToChatDetail(Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          chat: chat,
          chatService: widget.chatService,
        ),
      ),
    ).then((_) {
      // Update the UI when coming back from the chat detail screen
      // to reflect any changes in unread messages
      setState(() {});
    });
  }
}

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final int unreadCount;
  final VoidCallback onTap;

  const ChatListItem({
    super.key, 
    required this.chat,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(chat.avatarUrl),
        radius: 25,
      ),
      title: Text(
        chat.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat.jm().format(chat.lastMessageTime),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12.0,
            ),
          ),
          const SizedBox(height: 5),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}