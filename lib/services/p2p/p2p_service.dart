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
  
  // Connect to a peer
  Future<bool> connectToPeer(NearbyDevice peer) async {
    try {
      print("P2PService: Connecting to peer: ${peer.info.id}, type: ${peer.runtimeType}...");
      final result = await _nearbyService.connect(peer);
      print("P2PService: Connect result: $result");
      if (result) {
        _connectedDevice = peer;
        
        // Listen for connection status
        _connectedDeviceSubscription = _nearbyService
            .getConnectedDeviceStream(peer)
            .listen(_handleConnectedDeviceUpdate);
        
        // Start communication channel
        await _setupCommunicationChannel();
        
        _connectionStatusController.add(true);
      }
      
      return result;
    } catch (e) {
      print('Error connecting to peer: $e');
      return false;
    }
  }
  
  // Disconnect from the current peer
  Future<bool> disconnect() async {
    if (_connectedDevice == null) return true;
    
    try {
      final result = await _nearbyService.disconnect(_connectedDevice!);
      if (result) {
        await _connectedDeviceSubscription?.cancel();
        _connectedDeviceSubscription = null;
        _connectedDevice = null;
        _connectionStatusController.add(false);
      }
      
      return result;
    } catch (e) {
      print('Error disconnecting: $e');
      return false;
    }
  }
  
  // Setup the communication channel for exchanging messages
  Future<void> _setupCommunicationChannel() async {
    if (_connectedDevice == null) return;
    
    print("P2PService: Setting up communication channel with ${_connectedDevice!.info.id}");
    
    final messagesListener = NearbyServiceMessagesListener(
      onData: _handleIncomingMessage,
    );
    
    final filesListener = NearbyServiceFilesListener(
      onData: _handleIncomingFiles,
    );
    
    try {
      await _nearbyService.startCommunicationChannel(
        NearbyCommunicationChannelData(
          _connectedDevice!.info.id,
          messagesListener: messagesListener,
          filesListener: filesListener,
        ),
      );
      print("P2PService: Communication channel established successfully");
    } catch (e) {
      print("P2PService: Error establishing communication channel: $e");
    }
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
  void _handleIncomingMessage(ReceivedNearbyMessage message) {
    print("P2PService: Received message from ${message.sender.id}, type: ${message.content.runtimeType}");
    
    if (message.content is NearbyMessageTextRequest) {
      final textRequest = message.content as NearbyMessageTextRequest;
      print("P2PService: Text message: ${textRequest.value}");
      
      // Create a Message object from the received text
      final receivedMessage = Message(
        id: textRequest.id,
        senderId: message.sender.id,
        text: textRequest.value,
        timestamp: DateTime.now(),
        isRead: true,
      );
      
      // Add the message to the stream
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
  
  // Dispose resources
  void dispose() async {
    await disconnect();
    await stopDiscovery();
    
    await _peersController.close();
    await _messagesController.close();
    await _connectionStatusController.close();
  }
}