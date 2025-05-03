import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/bluetooth_service.dart';
import 'bluetooth_chat_screen.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({Key? key}) : super(key: key);

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  
  bool _isDiscoverable = false;
  bool _isDiscovering = false;
  late Timer _discoverableTimeoutTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Check if Bluetooth is enabled
    _checkBluetoothState();
    
    // Register listeners for device discovery
    _bluetoothService.discoveredDevices.addListener(_onDevicesChanged);
  }
  
  @override
  void dispose() {
    _bluetoothService.discoveredDevices.removeListener(_onDevicesChanged);
    super.dispose();
  }
  
  // Callback for when discovered devices change
  void _onDevicesChanged() {
    setState(() {});
  }

  // Check and request Bluetooth to be enabled
  Future<void> _checkBluetoothState() async {
    bool isEnabled = await _bluetoothService.isEnabled;
    
    if (!isEnabled) {
      await _showEnableBluetoothDialog();
    } else {
      _startDiscovery();
    }
  }
  
  // Show dialog to enable Bluetooth
  Future<void> _showEnableBluetoothDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth is disabled'),
          content: const Text('Would you like to enable Bluetooth?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Enable'),
              onPressed: () async {
                Navigator.of(context).pop();
                bool enabled = await _bluetoothService.requestEnable();
                if (enabled) {
                  _startDiscovery();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Make device discoverable
  Future<void> _makeDiscoverable() async {
    setState(() {
      _isDiscoverable = true;
    });
    
    int timeout = await _bluetoothService.requestDiscoverable(120);
    
    // Start a timer to track the discoverable state
    _discoverableTimeoutTimer = Timer(Duration(seconds: timeout), () {
      setState(() {
        _isDiscoverable = false;
      });
    });
  }

  // Start device discovery
  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
    });
    
    await _bluetoothService.startDiscovery();
    
    setState(() {
      _isDiscovering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<BluetoothDevice> devices = _bluetoothService.discoveredDevices.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isDiscovering ? null : _startDiscovery,
          ),
          IconButton(
            icon: Icon(_isDiscoverable ? Icons.visibility : Icons.visibility_off),
            onPressed: _isDiscoverable ? null : _makeDiscoverable,
            tooltip: 'Make discoverable',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isDiscovering)
            const LinearProgressIndicator(),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discovered Devices (${devices.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _isDiscoverable 
                  ? const Chip(
                      label: Text('Discoverable'),
                      avatar: Icon(Icons.visibility, size: 18),
                      backgroundColor: Colors.green,
                      labelStyle: TextStyle(color: Colors.white),
                    )
                  : TextButton.icon(
                      onPressed: _makeDiscoverable,
                      icon: const Icon(Icons.visibility_off, size: 18),
                      label: const Text('Not discoverable'),
                    ),
              ],
            ),
          ),
          
          Expanded(
            child: devices.isEmpty
              ? const Center(
                  child: Text('No devices found. Tap refresh to search again.'),
                )
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    BluetoothDevice device = devices[index];
                    return ListTile(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BluetoothChatScreen(device: device),
                          ),
                        );
                      },
                      leading: Icon(
                        device.bondState == BluetoothBondState.bonded
                          ? Icons.link
                          : Icons.devices,
                        color: device.bondState == BluetoothBondState.bonded
                          ? Colors.blue
                          : Colors.grey,
                      ),
                      title: Text(device.name ?? 'Unknown device'),
                      subtitle: Text(device.address),
                      trailing: TextButton(
                        onPressed: () async {
                          bool success = await _bluetoothService.connectToDevice(device);
                          if (success) {
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => BluetoothChatScreen(device: device),
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to connect to device'),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Connect'),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _bluetoothService.openSettings();
        },
        child: const Icon(Icons.settings_bluetooth),
      ),
    );
  }
}