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

      return true;
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
      return false;
    }
  }

  // Start scanning for devices
  Future<void> startScan() async {
    if (_isScanning) return;
    
    _discoveredDevices.clear();
    _isScanning = true;
    
    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!_discoveredDevices.contains(r.device)) {
          _discoveredDevices.add(r.device);
        }
      }
    });
    
    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidScanMode: AndroidScanMode.lowLatency,
    );
    
    _isScanning = false;
  }

  // Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
  }

  // Connect to a device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Connect to the device
      await device.connect();
      connectedDevice = device;
      _isConnected = true;
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Look for our service
      for (BluetoothService service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
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
      if (_messageCharacteristic == null) {
        await _createServiceAndCharacteristic();
      }
      
      return true;
    } catch (e) {
      debugPrint('Failed to connect to device: $e');
      _isConnected = false;
      return false;
    }
  }

  // Create service and characteristic if they don't exist
  Future<void> _createServiceAndCharacteristic() async {
    // This would require platform-specific code and is a complex process
    // For a real app, you would need native code to create the service
    debugPrint('Service or characteristic not found and creation not implemented');
  }

  // Disconnect from the current device
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
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
      
      // Parse JSON to message
      Map<String, dynamic> messageData = jsonDecode(jsonString);
      Message message = Message.fromJson(messageData);
      
      // Add to stream
      _messageReceivedController.add(message);
    } catch (e) {
      debugPrint('Error processing received message: $e');
    }
  }

  // Advertising to become visible to other devices
  Future<void> startAdvertising() async {
    // Currently not fully supported in flutter_blue_plus
    // This would need native code integration
    debugPrint('Advertising not fully implemented in flutter_blue_plus');
  }

  // Dispose resources
  void dispose() {
    _messageReceivedController.close();
    disconnect();
  }
}