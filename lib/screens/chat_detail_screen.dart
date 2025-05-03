import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isBluetoothChat = false;
  bool _isConnected = false;
  
  // To track active Bluetooth connection
  BluetoothDevice? _connectedDevice;
  
  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkBluetoothConnection();
    
    // Listen for incoming messages from Bluetooth
    widget.chatService.onChatUpdated.listen((chatId) {
      if (chatId == widget.chat.id) {
        _reloadMessages();
      }
    });
  }
  
  void _checkBluetoothConnection() {
    _connectedDevice = widget.chatService.getConnectedDevice();
    _isConnected = widget.chatService.isConnectedToBluetooth();
    
    // Check if this chat is with a Bluetooth device
    _isBluetoothChat = _connectedDevice != null && 
        _connectedDevice!.remoteId.toString() == widget.chat.id;
  }

  Future<void> _loadMessages() async {
    // Mark messages as read when entering the chat
    await widget.chatService.markChatAsRead(widget.chat.id);
    
    // Load messages from persistence
    final messages = await widget.chatService.getMessages(widget.chat.id);
    
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _reloadMessages() async {
    _checkBluetoothConnection();
    
    // Reload messages
    final messages = await widget.chatService.getMessages(widget.chat.id);
    
    if (mounted) {
      setState(() {
        _messages = messages;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    // Clear the text field immediately for better UX
    _messageController.clear();
    
    // Show sending indicator
    setState(() {
      _isSending = true;
    });
    
    try {
      // Send and persist the message
      bool success = await widget.chatService.sendMessage(widget.chat.id, text);
      
      if (!success && _isBluetoothChat) {
        // Show a snackbar if bluetooth sending failed
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message. Check Bluetooth connection.'),
              backgroundColor: Colors.red,
            )
          );
        }
      }
    } finally {
      // Reload the messages to include the new one
      if (mounted) {
        final messages = await widget.chatService.getMessages(widget.chat.id);
        setState(() {
          _messages = messages;
          _isSending = false;
        });
      }
    }
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chat.name),
                if (_isBluetoothChat) 
                  Text(
                    _isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isBluetoothChat)
            IconButton(
              icon: Icon(
                _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: _isConnected ? Colors.blue : Colors.grey,
              ),
              onPressed: _isConnected 
                ? _disconnectBluetooth 
                : null,
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
          // Bluetooth status banner
          if (_isBluetoothChat && !_isConnected)
            Container(
              color: Colors.red.shade100,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8.0),
                  Text(
                    'Bluetooth disconnected. Messages will not be sent.',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          
          // Messages list
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
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
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !(_isBluetoothChat && !_isConnected), // Disable if bluetooth disconnected
                  ),
                ),
                _isSending
                  ? const SizedBox(
                      height: 24, 
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      color: (_isBluetoothChat && !_isConnected) 
                        ? Colors.grey 
                        : Theme.of(context).primaryColor,
                      onPressed: (_isBluetoothChat && !_isConnected) 
                        ? null 
                        : _sendMessage,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _disconnectBluetooth() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Disconnect from this Bluetooth device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.chatService.disconnectFromBluetoothDevice();
              if (mounted) {
                setState(() {
                  _isConnected = false;
                });
              }
            },
            child: const Text('Disconnect'),
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