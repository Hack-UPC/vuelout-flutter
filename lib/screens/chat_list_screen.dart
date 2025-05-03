import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
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
      body: widget.chats.isEmpty 
        ? const Center(child: Text('No chats yet'))
        : ListView.builder(
            itemCount: widget.chats.length,
            itemBuilder: (context, index) {
              final chat = widget.chats[index];
              
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
        onPressed: () {
          // Navigate to new chat screen
        },
        child: const Icon(Icons.chat),
      ),
    );
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