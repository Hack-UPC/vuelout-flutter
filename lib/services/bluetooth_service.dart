import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';

class BluetoothChatService {
  static final BluetoothChatService _instance = BluetoothChatService._internal();
  factory BluetoothChatService() => _instance;
  BluetoothChatService._internal();

  // UUIDs for service and characteristic
  final String serviceUuid = '0000b81d-0000-1000-8000-00805f9b34fb';
  final String characteristicUuid = '7db3e235-3608-41f3-a03c-955fcbd2ea4b';
  final String deviceNamePrefix = 'VueloutChat-'; // Prefix to identify our app's devices

  // Stream controllers for message events
  final _messageReceivedController = StreamController<Message>.broadcast();
  Stream<Message> get onMessageReceived => _messageReceivedController.stream;

  // BluetoothDevice currently connected to
  BluetoothDevice? connectedDevice;
  
  // Discovered devices
  final List<BluetoothDevice> _discoveredDevices = [];
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  
  // Scanning status
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Characteristics for communication
  BluetoothCharacteristic? _messageCharacteristic;
  
  // Initialize Bluetooth and request permissions
  Future<bool> initialize() async {
    try {
      // Request Bluetooth permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();
      
      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          debugPrint('Permission not granted: $permission');
          allGranted = false;
        }
      });
      
      if (!allGranted) {
        debugPrint('Bluetooth or location permissions not granted');
        return false;
      }

      // Check if Bluetooth is available
      if (await FlutterBluePlus.isAvailable == false) {
        debugPrint('Bluetooth is not available on this device');
        return false;
      }

      // Turn on Bluetooth if it's not on
      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }
      
      // Wait for Bluetooth to be fully initialized
      await Future.delayed(const Duration(seconds: 1));
      
      return true;
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
      return false;
    }
  }

  // Start scanning for devices - scan for ALL devices to ensure maximum discovery
  Future<void> startScan() async {
    if (_isScanning) return;
    
    _discoveredDevices.clear();
    _isScanning = true;
    
    // Listen for scan results
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Add device if it's not already in the list
        if (!_discoveredDevices.contains(r.device)) {
          debugPrint('Found device: ${r.device.platformName} (${r.device.remoteId})');
          debugPrint('  RSSI: ${r.rssi}, Connectable: ${r.advertisementData.connectable}');
          
          if (r.advertisementData.serviceUuids.isNotEmpty) {
            debugPrint('  Service UUIDs: ${r.advertisementData.serviceUuids}');
          }
          
          _discoveredDevices.add(r.device);
        }
      }
    });
    
    // Start scanning - do NOT filter to maximize device discovery
    try {
      debugPrint('Starting Bluetooth scan...');
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Error starting scan: $e');
    }
    
    await Future.delayed(const Duration(seconds: 15));
    
    // Clean up
    subscription.cancel();
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    debugPrint('Scan complete. Found ${_discoveredDevices.length} devices.');
  }

  // Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;
    debugPrint('Stopping scan...');
    await FlutterBluePlus.stopScan();
    _isScanning = false;
  }

  // Connect to a device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('Connecting to device: ${device.platformName} (${device.remoteId})');
      
      // First check if we're already connected
      if (_isConnected && connectedDevice != null && connectedDevice!.remoteId == device.remoteId) {
        debugPrint('Already connected to this device');
        return true;
      }
      
      // Disconnect from any previous device
      if (_isConnected && connectedDevice != null) {
        debugPrint('Disconnecting from previous device first');
        await disconnect();
      }
      
      // Connect to the device with a timeout
      bool connected = false;
      try {
        await device.connect(timeout: const Duration(seconds: 10));
        connected = true;
      } catch (e) {
        if (e.toString().contains('already connected')) {
          // Device is already connected, proceed
          debugPrint('Device was already connected');
          connected = true;
        } else {
          debugPrint('Failed to connect: $e');
          throw e;
        }
      }
      
      if (!connected) {
        return false;
      }
      
      connectedDevice = device;
      _isConnected = true;
      
      // Discover services
      debugPrint('Discovering services...');
      List<BluetoothService> services = await device.discoverServices();
      
      // Look for our service
      bool foundService = false;
      for (BluetoothService service in services) {
        debugPrint('Found service: ${service.uuid}');
        if (service.uuid.toString() == serviceUuid) {
          foundService = true;
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            debugPrint('Found characteristic: ${characteristic.uuid}');
            if (characteristic.uuid.toString() == characteristicUuid) {
              _messageCharacteristic = characteristic;
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _handleReceivedData(value);
                }
              });
              
              break;
            }
          }
        }
      }
      
      // If we didn't find our service or characteristic, create it
      if (!foundService || _messageCharacteristic == null) {
        debugPrint('Service or characteristic not found. This is normal for initial connection.');
        // We can't actually create services on remote devices via flutter_blue_plus
        // In a production app, both devices should be running the same app code
        // and have consistent service/characteristic UUIDs
      }
      
      return true;
    } catch (e) {
      debugPrint('Failed to connect to device: $e');
      _isConnected = false;
      connectedDevice = null;
      return false;
    }
  }

  // Create service and characteristic if they don't exist
  Future<void> _createServiceAndCharacteristic() async {
    // This is not actually possible with flutter_blue_plus
    // We would need to implement platform-specific code for this
    debugPrint('Service or characteristic not found - cannot create remotely');
  }

  // Disconnect from the current device
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      debugPrint('Disconnecting from device: ${connectedDevice!.platformName}');
      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('Error during disconnect: $e');
      }
      _messageCharacteristic = null;
      connectedDevice = null;
      _isConnected = false;
    }
  }

  // Send a message to the connected device
  Future<bool> sendMessage(Message message) async {
    if (!_isConnected || _messageCharacteristic == null) {
      debugPrint('Not connected or characteristic not found');
      return false;
    }
    
    try {
      // Convert message to JSON and then to bytes
      final messageJson = jsonEncode(message.toJson());
      List<int> bytes = utf8.encode(messageJson);
      
      debugPrint('Sending message: ${message.text}');
      
      // Write to characteristic
      await _messageCharacteristic!.write(bytes);
      return true;
    } catch (e) {
      debugPrint('Failed to send message: $e');
      return false;
    }
  }

  // Process received data
  void _handleReceivedData(List<int> value) {
    try {
      // Convert bytes to JSON string
      String jsonString = utf8.decode(value);
      debugPrint('Received data: $jsonString');
      
      // Parse JSON to message
      Map<String, dynamic> messageData = jsonDecode(jsonString);
      Message message = Message.fromJson(messageData);
      
      debugPrint('Received message: ${message.text}');
      
      // Add to stream
      _messageReceivedController.add(message);
    } catch (e) {
      debugPrint('Error processing received message: $e');
    }
  }

  // Start advertising to become visible to other devices
  Future<void> startAdvertising() async {
    try {
      debugPrint('Starting advertising...');
      
      // Flutter Blue Plus doesn't support direct advertising
      // This is a limitation of the plugin
      
      // In a real implementation, you would:
      // 1. Use platform channels to access native Android/iOS Bluetooth APIs
      // 2. Set up a GATT server advertising your service UUID
      // 3. Make the device discoverable
      
      // For now, we'll rely on the scan to find all nearby devices
      // and the user can manually select which ones to connect to
      
      debugPrint('Advertising not fully supported in flutter_blue_plus.');
      debugPrint('Devices need to actively scan to discover each other.');
    } catch (e) {
      debugPrint('Error setting up advertising: $e');
    }
  }

  // Dispose resources
  void dispose() {
    stopScan();
    disconnect();
    _messageReceivedController.close();
  }
}