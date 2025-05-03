import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/message.dart';
import '../services/bluetooth_service.dart';
import '../services/chat_service.dart';

class BluetoothChatScreen extends StatefulWidget {
  final BluetoothDevice device;
  
  const BluetoothChatScreen({
    Key? key,
    required this.device,
  }) : super(key: key);

  @override
  State<BluetoothChatScreen> createState() => _BluetoothChatScreenState();
}

class _BluetoothChatScreenState extends State<BluetoothChatScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final ChatService _chatService = ChatService();
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  String _chatId = '';
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionError;
  
  @override
  void initState() {
    super.initState();
    
    // Use device address as chat ID
    _chatId = widget.device.address;
    
    // Initialize the chat and load messages
    _initChat();
    
    // Register listener for connection status changes
    _bluetoothService.connectionStatus.addListener(_onConnectionStatusChanged);
    
    // Register listener for incoming messages
    _bluetoothService.incomingMessage.addListener(_onMessageReceived);
    
    // Register listener for connection errors
    _bluetoothService.connectionError.addListener(_onConnectionErrorChanged);
    
    // Set initial connection status
    _isConnected = _bluetoothService.isConnected;
    
    // Attempt initial connection if not already connected
    if (!_isConnected) {
      _attemptConnection();
    }
  }
  
  @override
  void dispose() {
    _bluetoothService.connectionStatus.removeListener(_onConnectionStatusChanged);
    _bluetoothService.incomingMessage.removeListener(_onMessageReceived);
    _bluetoothService.connectionError.removeListener(_onConnectionErrorChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Initialize chat and load messages
  Future<void> _initChat() async {
    final messages = await _chatService.getMessages(_chatId);
    
    if (mounted) {
      setState(() {
        _messages = messages;
      });
      
      // Scroll to bottom
      if (_messages.isNotEmpty) {
        _scrollToBottom();
      }
    }
  }
  
  // Called when connection status changes
  void _onConnectionStatusChanged() {
    if (mounted) {
      setState(() {
        _isConnected = _bluetoothService.connectionStatus.value;
        if (_isConnected) {
          _isConnecting = false;
        }
      });
      
      if (!_isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from device'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (_isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  // Called when there's a connection error
  void _onConnectionErrorChanged() {
    if (mounted) {
      setState(() {
        _connectionError = _bluetoothService.connectionError.value;
        _isConnecting = false;
      });
      
      if (_connectionError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_connectionError!),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _attemptConnection,
            ),
          ),
        );
      }
    }
  }
  
  // Attempt to connect with visual feedback
  Future<void> _attemptConnection() async {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });
    
    try {
      await _bluetoothService.connectToDevice(widget.device);
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }
  
  // Called when a new message is received
  void _onMessageReceived() {
    final message = _bluetoothService.incomingMessage.value;
    
    if (message != null && mounted) {
      setState(() {
        _messages.add(message);
      });
      
      // Save message to chat service
      _chatService.sendMessage(_chatId, message.text);
      
      // Scroll to bottom
      _scrollToBottom();
    }
  }
  
  // Send a message with error handling
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || !_isConnected) {
      return;
    }
    
    final text = _messageController.text;
    _messageController.clear();
    
    // Create a message
    final message = Message(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      senderId: ChatService.currentUserId,
      text: text,
      timestamp: DateTime.now(),
    );
    
    // Add to UI
    setState(() {
      _messages.add(message);
    });
    
    // Save to chat service
    await _chatService.sendMessage(_chatId, text);
    
    // Send via Bluetooth with error handling
    bool sent = await _bluetoothService.sendMessage(message);
    
    if (!sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send message. Tap to retry.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _retrySendMessage(message),
          ),
        ),
      );
    }
    
    // Scroll to bottom
    _scrollToBottom();
  }
  
  // Retry sending a message
  Future<void> _retrySendMessage(Message message) async {
    if (!_isConnected) {
      await _attemptConnection();
    }
    
    if (_isConnected) {
      bool sent = await _bluetoothService.sendMessage(message);
      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message again'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Scroll to bottom of the chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name ?? 'Unknown Device'),
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  size: 14,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnecting ? 'Connecting...' : (_isConnected ? 'Connected' : 'Disconnected'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isConnecting ? Colors.orange : (_isConnected ? Colors.green : Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!_isConnected && !_isConnecting)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _attemptConnection,
              tooltip: 'Reconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          if (_isConnecting)
            const LinearProgressIndicator(),
            
          // Messages area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_connectionError != null)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Connection error: $_connectionError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const Text('No messages yet'),
                        if (!_isConnected && !_isConnecting)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.bluetooth_searching),
                              label: const Text('Connect to device'),
                              onPressed: _attemptConnection,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == ChatService.currentUserId;
                      
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 8.0,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                            horizontal: 14.0,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(18.0),
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
                                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Connection status indicator at bottom
          if (_connectionError != null && !_isConnected && !_isConnecting)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Connection issue: ${_connectionError!}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _attemptConnection,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, -1),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                // Text input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(24.0),
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: _isConnected,
                  ),
                ),
                
                // Send button
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _isConnected ? _sendMessage : _isConnecting ? null : _attemptConnection,
                  elevation: 0,
                  backgroundColor: _isConnected
                      ? Theme.of(context).colorScheme.primary
                      : _isConnecting ? Colors.grey : Colors.orange,
                  child: Icon(_isConnected ? Icons.send : Icons.bluetooth_searching),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}