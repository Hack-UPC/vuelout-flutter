import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/chat_service.dart';
import '../models/chat.dart';
import 'chat_detail_screen.dart';

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
      await widget.chatService.startBluetoothScan();
      
      // Update the list of devices periodically during scanning
      for (int i = 0; i < 5; i++) {
        if (!mounted) return;
        
        await Future.delayed(const Duration(seconds: 2));
        
        setState(() {
          _devices = widget.chatService.getDiscoveredDevices();
        });
      }
    } finally {
      if (mounted) {
        await widget.chatService.stopBluetoothScan();
        
        setState(() {
          _isScanning = false;
          _statusMessage = "Scan complete. ${_devices.length} devices found.";
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
    widget.chatService.stopBluetoothScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
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
              Expanded(
                child: _devices.isEmpty
                  ? const Center(
                      child: Text('No devices found. Try scanning again.'),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        return _buildDeviceItem(device);
                      },
                    ),
              ),
            ],
          ),
      floatingActionButton: _isInitializing
        ? null
        : FloatingActionButton(
            onPressed: _isScanning ? null : _startScan,
            backgroundColor: _isScanning ? Colors.grey : Theme.of(context).primaryColor,
            child: Icon(_isScanning ? Icons.hourglass_full : Icons.search),
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
    
    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.bluetooth),
      ),
      title: Text(deviceName),
      subtitle: Text(deviceId),
      trailing: ElevatedButton(
        onPressed: () => _connectToDevice(device),
        child: const Text('Connect'),
      ),
    );
  }
}