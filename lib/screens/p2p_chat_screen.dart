import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nearby_service/nearby_service.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/p2p/p2p_service.dart';

class P2PChatScreen extends StatefulWidget {
  const P2PChatScreen({super.key});

  @override
  State<P2PChatScreen> createState() => _P2PChatScreenState();
}

class _P2PChatScreenState extends State<P2PChatScreen> {
  final P2PService _p2pService = P2PService();
  final TextEditingController _messageController = TextEditingController();
  
  List<NearbyDevice> _nearbyDevices = [];
  List<Message> _messages = [];
  bool _isInitializing = true;
  bool _isDiscovering = false;
  bool _isConnecting = false;
  bool _isIOSBrowser = true; // Default role for iOS
  
  StreamSubscription? _peersSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeP2PService();
  }

  Future<void> _initializeP2PService() async {
    setState(() {
      _isInitializing = true;
    });

    // Initialize the P2P service
    await _p2pService.initialize();

    // Setup streams
    _peersSubscription = _p2pService.peersStream.listen((peers) {
      setState(() {
        _nearbyDevices = peers;
      });
    });

    _messagesSubscription = _p2pService.messagesStream.listen((message) {
      setState(() {
        _messages = [..._messages, message];
      });
    });

    _connectionSubscription = _p2pService.connectionStatusStream.listen((isConnected) {
      setState(() {});
      
      if (isConnected) {
        // Stop discovery when connected
        _stopDiscovery();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to peer')),
        );
      } else if (_p2pService.connectedDevice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected from peer')),
        );
      }
    });

    // On Android, check permissions
    if (_p2pService.nearbyService.android != null) {
      final hasPermissions = await _p2pService.checkAndRequestPermissions();
      if (!hasPermissions) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions or WiFi required for P2P')),
        );
      }
    }

    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _toggleDiscovery() async {
    if (_isDiscovering) {
      await _stopDiscovery();
    } else {
      await _startDiscovery();
    }
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
    });

    // For iOS, set the role first
    await _p2pService.setIOSRole(_isIOSBrowser);

    final result = await _p2pService.startDiscovery();
    if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start discovery')),
      );
    }

    setState(() {
      _isDiscovering = result;
    });
  }

  Future<void> _stopDiscovery() async {
    final result = await _p2pService.stopDiscovery();
    setState(() {
      _isDiscovering = !result;
    });
  }

  Future<void> _connectToPeer(NearbyDevice peer) async {
    setState(() {
      _isConnecting = true;
    });

    final result = await _p2pService.connectToPeer(peer);
    
    setState(() {
      _isConnecting = false;
    });

    if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect')),
      );
    }
  }

  Future<void> _disconnect() async {
    await _p2pService.disconnect();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear the text field immediately for better UX
    _messageController.clear();

    // Send and add the message locally
    final result = await _p2pService.sendMessage(text);
    
    if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _peersSubscription?.cancel();
    _messagesSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _p2pService.isConnected;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Chat'),
        actions: [
          if (!isConnected) 
            IconButton(
              icon: Icon(_isDiscovering ? Icons.wifi_off : Icons.wifi_find),
              onPressed: _isInitializing ? null : _toggleDiscovery,
              tooltip: _isDiscovering ? 'Stop Discovery' : 'Start Discovery',
            ),
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: _isInitializing 
        ? const Center(child: CircularProgressIndicator())
        : isConnected
          ? _buildChatView()
          : _buildDiscoveryView(),
    );
  }

  Widget _buildDiscoveryView() {
    return Column(
      children: [
        // iOS role selector
        if (_p2pService.nearbyService.ios != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Role:'),
                const SizedBox(width: 16),
                ToggleButtons(
                  isSelected: [_isIOSBrowser, !_isIOSBrowser],
                  onPressed: _isDiscovering ? null : (index) {
                    setState(() {
                      _isIOSBrowser = index == 0;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Browser'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Advertiser'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        Expanded(
          child: _nearbyDevices.isEmpty
            ? Center(
                child: _isDiscovering 
                  ? const Text('Searching for nearby devices...')
                  : const Text('Tap the WiFi icon to start discovery'),
              )
            : ListView.builder(
                itemCount: _nearbyDevices.length,
                itemBuilder: (context, index) {
                  final device = _nearbyDevices[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(getDeviceName(device)),
                    subtitle: Text('ID: ${device.info.id.substring(0, min(8, device.info.id.length))}...'),
                    trailing: ElevatedButton(
                      onPressed: _isConnecting ? null : () => _connectToPeer(device),
                      child: _isConnecting ? 
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ) : 
                        const Text('Connect'),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildChatView() {
    final peer = _p2pService.connectedDevice!;
    
    return Column(
      children: [
        // Connected peer info bar
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.green.withOpacity(0.1),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getDeviceName(peer),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Connected via P2P',
                      style: TextStyle(
                        color: Colors.grey[600], 
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Messages list
        Expanded(
          child: _messages.isEmpty
            ? const Center(child: Text('No messages yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(10.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isMe = message.senderId == "current_user";
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          const CircleAvatar(
                            backgroundColor: Colors.grey,
                            radius: 16,
                            child: Icon(Icons.person, size: 16, color: Colors.white),
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
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
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "Type a message",
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
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
    );
  }

  // Helper function to get device name, as NearbyDeviceInfo doesn't have a name property
  String getDeviceName(NearbyDevice device) {
    // For iOS devices, the iOS framework includes device names
    if (device is NearbyIOSDevice) {
      return device.info.id;  // On iOS, id is actually the display name
    }
    
    // For Android devices, use a generic name with the last part of MAC address
    if (device is NearbyAndroidDevice) {
      return "Android Device (${device.info.id.substring(max(0, device.info.id.length - 5))})";
    }
    
    return "Peer Device";
  }
}