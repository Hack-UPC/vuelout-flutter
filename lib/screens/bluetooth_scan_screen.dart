import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/chat_service.dart';
import '../models/chat.dart';
import 'dart:async';

class BluetoothScanScreen extends StatefulWidget {
  final ChatService chatService;

  const BluetoothScanScreen({
    super.key, 
    required this.chatService,
  });

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  bool _isScanning = false;
  bool _isInitializing = true;
  String _statusMessage = "Initializing Bluetooth...";
  List<BluetoothDevice> _devices = [];
  bool _showAllDevices = true; // Show all devices by default
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    try {
      bool initialized = await widget.chatService.initializeBluetooth();
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = initialized 
            ? "Ready to scan for devices" 
            : "Failed to initialize Bluetooth";
        });
        
        // Auto-start scan when screen opens
        if (initialized) {
          _startScan();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = "Error: $e";
        });
      }
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _statusMessage = "Scanning for devices...";
    });

    try {
      // Start the scan
      await widget.chatService.startBluetoothScan();
      
      // Update the UI periodically while scanning
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _devices = widget.chatService.getDiscoveredDevices();
            _statusMessage = "Scanning... Found ${_devices.length} devices";
          });
        }
      });
      
      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 15));
      
      // Final device update after scan completes
      if (mounted) {
        _refreshTimer?.cancel();
        _refreshTimer = null;
        
        await widget.chatService.stopBluetoothScan();
        setState(() {
          _devices = widget.chatService.getDiscoveredDevices();
          _isScanning = false;
          _statusMessage = "Scan complete. ${_devices.length} devices found.";
        });
      }
    } catch (e) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = "Error during scan: $e";
        });
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _statusMessage = "Connecting to ${device.platformName}...";
    });

    try {
      bool success = await widget.chatService.connectToBluetoothDevice(device);
      
      if (!mounted) return;
      
      setState(() {
        _statusMessage = success 
          ? "Connected to ${device.platformName}" 
          : "Failed to connect to ${device.platformName}";
      });
      
      if (success) {
        // Create a chat for this device
        final deviceId = device.remoteId.toString();
        final deviceName = device.platformName.isNotEmpty 
          ? device.platformName 
          : "Device ${deviceId.substring(0, 5)}";
          
        final chat = Chat(
          id: deviceId,
          name: deviceName,
          lastMessage: "Connected via Bluetooth",
          avatarUrl: "https://randomuser.me/api/portraits/lego/1.jpg", // Generic avatar
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
        );
        
        // Open chat screen with this device
        if (mounted) {
          Navigator.pop(context, chat);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Connection error: $e";
        });
      }
    }
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.chatService.stopBluetoothScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter devices if the user only wants to see app devices
    List<BluetoothDevice> displayedDevices = _showAllDevices 
        ? _devices 
        : _devices.where((device) {
            return device.platformName.toLowerCase().contains('vuelout') || 
                   device.platformName.toLowerCase().contains('chat');
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Devices'),
        actions: [
          // Toggle between all devices and app-specific devices
          IconButton(
            icon: Icon(_showAllDevices ? Icons.filter_list_off : Icons.filter_list),
            tooltip: _showAllDevices ? 'Show app devices only' : 'Show all devices',
            onPressed: () {
              setState(() {
                _showAllDevices = !_showAllDevices;
              });
            },
          ),
        ],
      ),
      body: _isInitializing
        ? _buildLoadingView()
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: _statusMessage.contains("Error") ? Colors.red : null,
                  ),
                ),
              ),
              if (!_showAllDevices && displayedDevices.isEmpty && _devices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'No app devices found. There are ${_devices.length} other Bluetooth devices nearby.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              Expanded(
                child: displayedDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.bluetooth_searching,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No devices found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'Make sure other devices have Bluetooth turned on and are within range',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayedDevices.length,
                      itemBuilder: (context, index) {
                        final device = displayedDevices[index];
                        return _buildDeviceItem(device);
                      },
                    ),
              ),
            ],
          ),
      floatingActionButton: _isInitializing
        ? null
        : FloatingActionButton.extended(
            onPressed: _isScanning ? null : _startScan,
            backgroundColor: _isScanning ? Colors.grey : Theme.of(context).primaryColor,
            icon: Icon(_isScanning ? Icons.hourglass_full : Icons.bluetooth_searching),
            label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
          ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing Bluetooth...'),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(BluetoothDevice device) {
    String deviceName = device.platformName.isNotEmpty
      ? device.platformName 
      : "Unknown Device";
      
    String deviceId = device.remoteId.toString();
    
    // Check if this device appears to be running our app
    bool isAppDevice = deviceName.toLowerCase().contains('vuelout') || 
                       deviceName.toLowerCase().contains('chat');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAppDevice ? Colors.green : Colors.blue,
          child: Icon(
            isAppDevice ? Icons.chat : Icons.bluetooth,
            color: Colors.white,
          ),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAppDevice 
                ? 'Vuelout Chat App Device' 
                : 'Bluetooth Device',
              style: TextStyle(
                color: isAppDevice ? Colors.green : Colors.grey[600],
              ),
            ),
            Text(
              'ID: ${deviceId.substring(0, 10)}...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _connectToDevice(device),
          style: ElevatedButton.styleFrom(
            backgroundColor: isAppDevice ? Colors.green : null,
          ),
          child: const Text('Connect'),
        ),
        onTap: () => _connectToDevice(device),
      ),
    );
  }
}