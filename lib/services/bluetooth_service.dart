import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/message.dart';

class BluetoothService {
  // Singleton instance
  static final BluetoothService _instance = BluetoothService._internal();

  factory BluetoothService() => _instance;

  BluetoothService._internal();

  // Instance of the Bluetooth Serial plugin
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  
  // To keep track of the connection
  BluetoothConnection? _connection;
  bool isConnected = false;
  
  // Stream controllers for incoming messages and connection state changes
  final ValueNotifier<Message?> incomingMessage = ValueNotifier(null);
  final ValueNotifier<bool> connectionStatus = ValueNotifier(false);
  final ValueNotifier<String?> connectionError = ValueNotifier(null);
  final ValueNotifier<List<BluetoothDevice>> discoveredDevices = ValueNotifier([]);

  // Keep track of the connection subscription
  StreamSubscription? _connectionSubscription;
  
  // Connection timeout duration
  static const Duration connectionTimeout = Duration(seconds: 8);
  
  // Maximum connection attempts
  static const int maxConnectionAttempts = 3;

  // Get Bluetooth state - fix to handle nullable return value
  Future<bool> get isEnabled async => await _bluetooth.isEnabled ?? false;

  // Request to enable Bluetooth
  Future<bool> requestEnable() async {
    return await _bluetooth.requestEnable() ?? false;
  }

  // Turn off Bluetooth
  Future<bool> requestDisable() async {
    return await _bluetooth.requestDisable() ?? false;
  }

  // Open Bluetooth settings
  Future<void> openSettings() async {
    await _bluetooth.openSettings();
  }

  // Start device discovery
  Future<void> startDiscovery() async {
    discoveredDevices.value = [];
    
    try {
      _bluetooth.cancelDiscovery();
      
      // Get bonded devices first
      List<BluetoothDevice> bondedDevices = await _bluetooth.getBondedDevices();
      discoveredDevices.value = [...bondedDevices];
      
      // Start discovery for new devices
      _bluetooth.startDiscovery().listen((BluetoothDiscoveryResult result) {
        final existingIndex = discoveredDevices.value.indexWhere(
          (device) => device.address == result.device.address
        );
        
        if (existingIndex >= 0) {
          // Update existing device
          discoveredDevices.value = List.from(discoveredDevices.value)
            ..[existingIndex] = result.device;
        } else {
          // Add new device
          discoveredDevices.value = [...discoveredDevices.value, result.device];
        }
      }, onError: (error) {
        print('Discovery error: $error');
        // Continue with bonded devices even if discovery fails
      });
    } catch (e) {
      print('Error starting discovery: $e');
    }
  }

  // Connect to a device with robust error handling and retry logic
  Future<bool> connectToDevice(BluetoothDevice device) async {
    // Reset any previous error
    connectionError.value = null;
    
    if (_connection != null) {
      await disconnectDevice();
    }

    // Multiple connection attempts with backoff
    for (int attempt = 1; attempt <= maxConnectionAttempts; attempt++) {
      try {
        print('Connection attempt $attempt of $maxConnectionAttempts');
        
        // If not first attempt, wait with backoff
        if (attempt > 1) {
          final backoffDelay = Duration(milliseconds: 500 * attempt);
          print('Waiting ${backoffDelay.inMilliseconds}ms before retry...');
          await Future.delayed(backoffDelay);
        }

        // First check device bond state
        print('Checking bond state for device ${device.address}');
        if (device.bondState != BluetoothBondState.bonded) {
          try {
            print('Device is not bonded, attempting to bond...');
            bool bonded = await FlutterBluetoothSerial.instance.bondDeviceAtAddress(device.address) ?? false;
            if (bonded) {
              print('Successfully bonded with device');
              // Allow some time for the bond to stabilize
              await Future.delayed(const Duration(milliseconds: 1000));
            }
          } catch (e) {
            print('Error during bonding: $e');
            // Continue anyway as some devices can connect without bonding
          }
        } else {
          print('Device is already bonded');
        }

        // Make sure discovery is canceled before connecting
        print('Canceling any ongoing discovery...');
        await _bluetooth.cancelDiscovery();
        
        // Allow a moment for the discovery to fully cancel
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Use a completer for better timeout handling
        final Completer<BluetoothConnection> connectionCompleter = Completer();
        
        print('Initiating connection to ${device.address}...');
        // Attempt to establish connection
        BluetoothConnection.toAddress(device.address).then((connection) {
          if (!connectionCompleter.isCompleted) {
            print('Connection established successfully');
            connectionCompleter.complete(connection);
          }
        }).catchError((error) {
          if (!connectionCompleter.isCompleted) {
            print('Connection attempt failed: $error');
            connectionCompleter.completeError(error);
          }
        });
        
        // Add timeout
        _connection = await connectionCompleter.future.timeout(
          connectionTimeout,
          onTimeout: () {
            print('Connection timed out after ${connectionTimeout.inSeconds} seconds');
            throw TimeoutException('Connection timed out');
          }
        );
        
        // Wait a moment to ensure connection is stable
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Test if connection is actually working by sending a small ping
        try {
          print('Testing connection stability...');
          _connection!.output.add(Uint8List.fromList([0])); // Send a zero byte as ping
          await _connection!.output.allSent.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              throw TimeoutException('Connection test failed');
            }
          );
          print('Connection test successful');
        } catch (e) {
          print('Connection test failed: $e');
          throw Exception('Connection established but failed stability test');
        }
        
        isConnected = true;
        connectionStatus.value = true;
        connectionError.value = null;
        
        print('Setting up data listeners...');
        // Listen for incoming data with error handling
        _connectionSubscription = _connection!.input!.listen(
          (Uint8List data) {
            try {
              if (data.isEmpty) {
                print('Received empty data packet');
                return;
              }
              
              final String messageStr = ascii.decode(data);
              
              try {
                // Parse the incoming JSON message
                final Map<String, dynamic> messageMap = json.decode(messageStr);
                final Message message = Message.fromJson(messageMap);
                
                // Notify listeners about new message
                incomingMessage.value = message;
              } catch (e) {
                print('Error parsing message: $e');
                // If JSON parsing fails, create a simple message
                final message = Message(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  senderId: device.address,
                  text: messageStr,
                  timestamp: DateTime.now(),
                );
                incomingMessage.value = message;
              }
            } catch (e) {
              print('Error processing received data: $e');
            }
          },
          onDone: () {
            print('Device connection closed normally');
            _handleDisconnection();
          },
          onError: (error) {
            print('Connection error in data stream: $error');
            connectionError.value = 'Connection error: $error';
            _handleDisconnection();
          },
          cancelOnError: false,
        );
        
        print('Connection complete and stable');
        return true;
        
      } on TimeoutException catch (e) {
        print('Attempt $attempt failed with timeout: $e');
        if (attempt == maxConnectionAttempts) {
          connectionError.value = 'Connection timeout after multiple attempts. Make sure both devices have Bluetooth enabled and are in range.';
          _handleDisconnection();
          return false;
        }
      } on PlatformException catch (e) {
        print('Attempt $attempt failed with platform exception: $e');
        // If this is a "read failed" or "socket might closed" error, retry
        if (e.message?.contains('read failed') == true || 
            e.message?.contains('socket might closed') == true) {
          if (attempt == maxConnectionAttempts) {
            connectionError.value = 'Could not establish a stable connection after multiple attempts. Try toggling Bluetooth off and on again.';
            _handleDisconnection();
            return false;
          }
        } else {
          // For other platform exceptions, stop retrying
          connectionError.value = 'Connection failed: ${e.message}';
          _handleDisconnection();
          return false;
        }
      } catch (e) {
        print('Attempt $attempt failed with error: $e');
        if (attempt == maxConnectionAttempts) {
          connectionError.value = 'Failed to connect after multiple attempts: $e';
          _handleDisconnection();
          return false;
        }
      } finally {
        // If we've created a connection but hit an exception, make sure to clean up
        if (_connection != null && !isConnected) {
          try {
            await _connection!.close();
          } catch (_) {}
          _connection = null;
        }
      }
    }
    
    return false;
  }

  // Handle disconnection cleanup
  void _handleDisconnection() {
    if (_connectionSubscription != null) {
      _connectionSubscription!.cancel();
      _connectionSubscription = null;
    }
    
    _connection = null;
    isConnected = false;
    connectionStatus.value = false;
  }

  // Send a message with retry logic
  Future<bool> sendMessage(Message message) async {
    if (_connection == null || !isConnected) {
      return false;
    }
    
    try {
      // Convert message to JSON and send
      final String messageJson = json.encode(message.toJson());
      final Uint8List data = Uint8List.fromList(utf8.encode(messageJson + "\n"));
      
      // Add retry logic for sending
      int retryCount = 0;
      const int maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          _connection!.output.add(data);
          await _connection!.output.allSent.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Send operation timed out');
            }
          );
          return true;
        } on TimeoutException {
          retryCount++;
          if (retryCount >= maxRetries) rethrow;
          // Wait before retry
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      return false;
    } catch (e) {
      print('Error sending message: $e');
      
      // Check if connection is still valid
      if (e.toString().contains('socket closed') || 
          e.toString().contains('timeout')) {
        _handleDisconnection();
      }
      
      return false;
    }
  }

  // Disconnect from device with more robust error handling
  Future<void> disconnectDevice() async {
    if (_connectionSubscription != null) {
      await _connectionSubscription!.cancel();
      _connectionSubscription = null;
    }
    
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (e) {
        print('Error closing connection: $e');
      } finally {
        _connection = null;
        isConnected = false;
        connectionStatus.value = false;
      }
    }
  }

  // Check if device is bonded
  Future<bool> isDeviceBonded(String address) async {
    try {
      List<BluetoothDevice> bondedDevices = await _bluetooth.getBondedDevices();
      return bondedDevices.any((device) => device.address == address);
    } catch (e) {
      print('Error checking bonded devices: $e');
      return false;
    }
  }

  // Request to make the device discoverable
  Future<int> requestDiscoverable(int timeoutSeconds) async {
    try {
      final int? result = await _bluetooth.requestDiscoverable(timeoutSeconds);
      return result ?? 0;
    } catch (e) {
      print('Error making device discoverable: $e');
      return 0;
    }
  }
}