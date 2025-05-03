import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;
  final ChatService chatService;

  const ChatDetailScreen({
    super.key, 
    required this.chat,
    required this.chatService,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  late List<Message> _messages;

  @override
  void initState() {
    super.initState();
    _messages = widget.chatService.getMessages(widget.chat.id);
    // Mark messages as read when entering the chat
    widget.chatService.markChatAsRead(widget.chat.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    widget.chatService.sendMessage(widget.chat.id, text);
    _messageController.clear();
    
    // Update the message list
    setState(() {
      _messages = widget.chatService.getMessages(widget.chat.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.chat.avatarUrl),
              radius: 20,
            ),
            const SizedBox(width: 10),
            Text(widget.chat.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Implement call functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Implement more options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10.0),
              reverse: false,  // Show newest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == ChatService.currentUserId;
                
                return _buildMessageBubble(message, isMe);
              },
            ),
          ),
          
          // Message input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(25.0),
            ),
            margin: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onPressed: () {
                    // Implement emoji picker
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Type a message",
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final messageTime = DateFormat.jm().format(message.timestamp);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundImage: NetworkImage(widget.chat.avatarUrl),
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isMe ? Colors.green[300] : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    messageTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 8),
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ],
      ),
    );
  }
}