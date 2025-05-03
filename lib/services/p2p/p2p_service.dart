import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nearby_service/nearby_service.dart';
import '../../models/message.dart';

class P2PService {
  // Singleton instance
  static final P2PService _instance = P2PService._internal();
  
  factory P2PService() => _instance;
  
  P2PService._internal();
  
  // NearbyService instance
  final NearbyService _nearbyService = NearbyService.getInstance(
    logLevel: NearbyServiceLogLevel.debug,
  );
  
  // Stream controllers
  final _peersController = StreamController<List<NearbyDevice>>.broadcast();
  final _messagesController = StreamController<Message>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();
  
  // Connected device
  NearbyDevice? _connectedDevice;
  StreamSubscription? _connectedDeviceSubscription;
  
  // Timer to periodically check connection health
  Timer? _connectionHealthTimer;
  
  // State variables
  bool _isInitialized = false;
  bool _isDiscovering = false;
  
  // Getters for streams
  Stream<List<NearbyDevice>> get peersStream => _peersController.stream;
  Stream<Message> get messagesStream => _messagesController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  
  // Add getter for the nearbyService
  NearbyService get nearbyService => _nearbyService;
  
  NearbyDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice?.status.isConnected ?? false;
  bool get isInitialized => _isInitialized;
  bool get isDiscovering => _isDiscovering;
  
  // Initialize the P2P service
  Future<bool> initialize({String? deviceName}) async {
    if (_isInitialized) return true;
    
    try {
      await _nearbyService.initialize(
        data: NearbyInitializeData(
          iosDeviceName: deviceName ?? 'Vuelout User',
        ),
      );
      
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing P2P service: $e');
      return false;
    }
  }
  
  // Android-specific permissions check
  Future<bool> checkAndRequestPermissions() async {
    if (_nearbyService.android == null) return true;
    
    try {
      // Request permissions
      final hasPermissions = await _nearbyService.android!.requestPermissions();
      if (!hasPermissions) return false;
      
      // Check WiFi
      final isWifiEnabled = await _nearbyService.android!.checkWifiService();
      if (!isWifiEnabled) {
        await _nearbyService.openServicesSettings();
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }
  
  // iOS-specific role setting
  Future<void> setIOSRole(bool isBrowser) async {
    if (_nearbyService.ios != null) {
      _nearbyService.ios!.setIsBrowser(value: isBrowser);
    }
  }
  
  // Start discovering peers
  Future<bool> startDiscovery() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      print("P2PService: Starting discovery...");
      final result = await _nearbyService.discover();
      print("P2PService: Discovery started: $result");
      if (result) {
        _isDiscovering = true;
        
        // Listen for discovered peers
        _nearbyService.getPeersStream().listen((peers) {
          print("P2PService: Peers changed: ${peers.length} peers found");
          for (var peer in peers) {
            print("P2PService: Found peer: ${peer.info.id}, type: ${peer.runtimeType}");
          }
          _peersController.add(peers);
        });
      }
      
      return result;
    } catch (e) {
      print('Error starting discovery: $e');
      return false;
    }
  }
  
  // Stop discovering peers
  Future<bool> stopDiscovery() async {
    try {
      final result = await _nearbyService.stopDiscovery();
      if (result) {
        _isDiscovering = false;
      }
      return result;
    } catch (e) {
      print('Error stopping discovery: $e');
      return false;
    }
  }
  
  // Connect to a peer with retry mechanism
  Future<bool> connectToPeer(NearbyDevice peer) async {
    try {
      // Try to stop discovery first to avoid BUSY errors
      try {
        await stopDiscovery();
      } catch (e) {
        print("P2PService: Ignoring error while stopping discovery before connecting: $e");
        // Continue anyway - don't let this stop the connection attempt
      }

      // Wait a moment to ensure discovery is fully stopped
      await Future.delayed(const Duration(milliseconds: 500));
      
      print("P2PService: Connecting to peer: ${peer.info.id}, type: ${peer.runtimeType}...");
      
      // First connection attempt
      var result = await _nearbyService.connect(peer);
      print("P2PService: Connect result: $result");
      
      // If failed, retry after a short delay
      if (!result) {
        print("P2PService: First connection attempt failed, retrying in 1 second...");
        await Future.delayed(const Duration(seconds: 1));
        result = await _nearbyService.connect(peer);
        print("P2PService: Retry connection result: $result");
      }
      
      if (result) {
        _connectedDevice = peer;
        
        // Listen for connection status with improved error handling
        _connectedDeviceSubscription?.cancel(); // Cancel any existing subscription
        _connectedDeviceSubscription = _nearbyService
            .getConnectedDeviceStream(peer)
            .listen(
              _handleConnectedDeviceUpdate,
              onError: (error) {
                print("P2PService: Error in connected device stream: $error");
                // Avoid losing connection due to stream errors
                if (_connectedDevice != null) {
                  print("P2PService: Maintaining connection despite stream error");
                }
              },
            );
        
        // Start communication channel with retry - IMPORTANT FOR BIDIRECTIONAL COMM
        await _setupCommunicationChannel();
        
        // Give the other device a moment to also set up their side of the channel
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Ensure both sides know the connection is established
        _connectionStatusController.add(true);
        
        // Send a handshake message to help establish bidirectional communication
        _sendHandshakeMessage();
        
        // After successful connection, periodically check connection health
        _startConnectionHealthCheck();
      }
      
      return result;
    } catch (e) {
      print('Error connecting to peer: $e');
      return false;
    }
  }

  // Send a handshake message to establish bidirectional communication
  Future<void> _sendHandshakeMessage() async {
    if (_connectedDevice == null || !_connectedDevice!.status.isConnected) {
      return;
    }

    try {
      print("P2PService: Sending handshake message to ${_connectedDevice!.info.id}");
      
      // Send a special handshake message
      _nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextRequest.create(value: "__HANDSHAKE__"),
          receiver: _connectedDevice!.info,
        ),
      );
    } catch (e) {
      print('Error sending handshake: $e');
    }
  }

  // Timer to periodically check connection health
  void _startConnectionHealthCheck() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_connectedDevice == null) {
        timer.cancel();
        return;
      }
      
      try {
        // Just log the current status for debugging
        final isConnected = _connectedDevice?.status.isConnected ?? false;
        print("P2PService: Connection health check - Status: ${isConnected ? 'CONNECTED' : 'DISCONNECTED'}");
        
        // If connection was lost, try to reconnect
        if (!isConnected && _connectedDevice != null) {
          print("P2PService: Detected connection loss, attempting to restore...");
          final device = _connectedDevice;
          // Delay the reconnect attempt to avoid conflicts
          Future.delayed(const Duration(seconds: 1), () {
            if (device != null && !device.status.isConnected) {
              _nearbyService.connect(device).then((success) {
                print("P2PService: Reconnection attempt result: $success");
                if (success) {
                  _setupCommunicationChannel();
                  _connectionStatusController.add(true);
                }
              });
            }
          });
        }
      } catch (e) {
        print("P2PService: Error during connection health check: $e");
      }
    });
  }

  // Setup the communication channel for exchanging messages with retry
  Future<void> _setupCommunicationChannel() async {
    if (_connectedDevice == null) return;
    
    print("P2PService: Setting up communication channel with ${_connectedDevice!.info.id}");
    
    final messagesListener = NearbyServiceMessagesListener(
      onData: _handleIncomingMessage,
    );
    
    final filesListener = NearbyServiceFilesListener(
      onData: _handleIncomingFiles,
    );
    
    // Try to establish communication channel with retries
    int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _nearbyService.startCommunicationChannel(
          NearbyCommunicationChannelData(
            _connectedDevice!.info.id,
            messagesListener: messagesListener,
            filesListener: filesListener,
          ),
        );
        print("P2PService: Communication channel established successfully on attempt $attempt");
        return; // Success, exit the function
      } catch (e) {
        print("P2PService: Error establishing communication channel (attempt $attempt/$maxRetries): $e");
        if (attempt < maxRetries) {
          // Wait before retrying
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }
    print("P2PService: Failed to establish communication channel after $maxRetries attempts");
  }
  
  // Handle updates to the connected device
  void _handleConnectedDeviceUpdate(NearbyDevice? device) {
    print("P2PService: Connected device update - Old: ${_connectedDevice?.info.id}, New: ${device?.info.id}, Connected: ${device?.status.isConnected}");
    
    final wasConnected = _connectedDevice?.status.isConnected ?? false;
    final isNowConnected = device?.status.isConnected ?? false;
    
    _connectedDevice = device;
    
    if (wasConnected && !isNowConnected) {
      print("P2PService: Device disconnected");
      _connectionStatusController.add(false);
    } else if (!wasConnected && isNowConnected) {
      print("P2PService: Device connected");
      _connectionStatusController.add(true);
    }
  }
  
  // Handle incoming messages
  void _handleIncomingMessage(ReceivedNearbyMessage message) async {
    print("P2PService: Received message from ${message.sender.id}, type: ${message.content.runtimeType}");
    
    if (message.content is NearbyMessageTextRequest) {
      final textRequest = message.content as NearbyMessageTextRequest;
      print("P2PService: Text message: ${textRequest.value}");
      
      // Special handling for handshake messages
      if (textRequest.value == "__HANDSHAKE__") {
        print("P2PService: Received handshake message, ensuring communication channel");
        
        // If we receive a handshake, ensure we have a communication channel with this peer
        if (_connectedDevice == null || _connectedDevice!.info.id != message.sender.id) {
          // Store the sender as our connected device if we don't have it yet
          print("P2PService: Setting connected device from handshake");
          
          // Find the device in discovered peers if possible
          try {
            // Use await to get the actual List<NearbyDevice> from the Future
            final peers = await _nearbyService.getPeers();
            
            // Find the matching peer in the list
            final matchingPeer = peers.firstWhere(
              (device) => device.info.id == message.sender.id,
              orElse: () => throw Exception("Device not found in peers list"),
            );
            
            _connectedDevice = matchingPeer;
            print("P2PService: Found matching peer in discovered devices list");
          } catch (e) {
            // If not found in peers list, use the message sender info
            print("P2PService: Creating device from message sender: ${e.toString()}");
            // We can't create a NearbyDevice directly, so we'll connect by ID instead
            _nearbyService.connectById(message.sender.id).then((connected) {
              if (connected) {
                print("P2PService: Successfully connected to device from handshake");
              }
            });
          }
          
          // Ensure we have a proper communication channel setup
          _setupCommunicationChannel();
          
          // Update connection status
          _connectionStatusController.add(true);
          
          // Start the health check
          _startConnectionHealthCheck();
        }
        
        // Send a handshake response to complete the bidirectional setup
        _nearbyService.send(
          OutgoingNearbyMessage(
            content: NearbyMessageTextRequest.create(value: "__HANDSHAKE_ACK__"),
            receiver: message.sender,
          ),
        );
        
        // Don't show handshake messages in the UI
        return;
      } else if (textRequest.value == "__HANDSHAKE_ACK__") {
        print("P2PService: Received handshake acknowledgment");
        // Don't show handshake acknowledgments in the UI
        return;
      }
      
      // Regular message handling for normal messages
      final receivedMessage = Message(
        id: textRequest.id,
        senderId: message.sender.id,
        text: textRequest.value,
        timestamp: DateTime.now(),
        isRead: true,
      );
      
      // Add the message to the stream for UI display
      _messagesController.add(receivedMessage);
      
      // Send a response to confirm receipt
      _nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextResponse(id: textRequest.id),
          receiver: message.sender,
        ),
      );
      print("P2PService: Sent receipt confirmation");
    }
  }
  
  // Handle incoming files
  void _handleIncomingFiles(ReceivedNearbyFilesPack pack) {
    // For now, just print that files were received
    // In a real app, you might want to save them to a permanent location
    print('Received ${pack.files.length} files from ${pack.sender.id}');
  }
  
  // Send a message to the connected peer
  Future<bool> sendMessage(String text) async {
    if (_connectedDevice == null || !_connectedDevice!.status.isConnected) {
      return false;
    }
    
    try {
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create a Message object
      final message = Message(
        id: messageId,
        senderId: 'current_user', // Using the same ID as ChatService
        text: text,
        timestamp: DateTime.now(),
      );
      
      // Add the message to our own stream so the UI updates
      _messagesController.add(message);
      
      // Send the message via P2P
      _nearbyService.send(
        OutgoingNearbyMessage(
          content: NearbyMessageTextRequest.create(value: text),
          receiver: _connectedDevice!.info,
        ),
      );
      
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Disconnect from the current peer
  Future<bool> disconnect() async {
    if (_connectedDevice == null) return true;
    
    try {
      print("P2PService: Disconnecting from peer: ${_connectedDevice?.info.id}");
      
      // Cancel health check timer
      _connectionHealthTimer?.cancel();
      
      // Cancel any active subscriptions
      await _connectedDeviceSubscription?.cancel();
      _connectedDeviceSubscription = null;
      
      // Disconnect from the peer
      final result = await _nearbyService.disconnect(_connectedDevice!);
      print("P2PService: Disconnect result: $result");
      
      if (result) {
        _connectedDevice = null;
        _connectionStatusController.add(false);
      } else {
        // Even if the disconnect call fails, consider the connection closed on our side
        print("P2PService: Forcing disconnect state despite API failure");
        _connectedDevice = null;
        _connectionStatusController.add(false);
      }
      
      return result;
    } catch (e) {
      print('Error disconnecting from peer: $e');
      
      // Even if we get an error, consider the connection closed on our side
      _connectedDevice = null;
      _connectionStatusController.add(false);
      
      return false;
    }
  }
  
  // Dispose resources
  void dispose() async {
    _connectionHealthTimer?.cancel();
    await disconnect();
    await stopDiscovery();
    
    await _peersController.close();
    await _messagesController.close();
    await _connectionStatusController.close();
  }
}