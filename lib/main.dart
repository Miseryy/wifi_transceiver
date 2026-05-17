import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/p2p_transceiver.dart';
import 'core/host_transceiver.dart';
import 'core/client_transceiver.dart';
import 'core/voice_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Voice Intercom',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DiscoveryScreen(),
    );
  }
}

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  static const _powerChannel = MethodChannel('wifi_transceiver/power');

  final _plugin = FlutterP2pConnection();
  P2PTransceiver? _transceiver;
  VoiceManager? _voiceManager;
  List<DiscoveredPeers> _peers = [];
  bool _isConnected = false;
  bool _isIntercomRunning = false;
  bool _isDisconnecting = false;
  bool _isConnecting = false;
  String? _pendingPeerName;
  String? _pendingPeerAddress;
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;
  String? _connectedDeviceRole;

  StreamSubscription? _peerSub;
  StreamSubscription? _infoSub;
  String _status = "Idle";

  // デバッグ・可視化用
  final List<String> _logs = [];
  String _ipAddress = "Unknown";
  double _sendLevel = 0;
  double _receiveLevel = 0;
  StreamSubscription? _levelSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _log(String msg) {
    final time = DateTime.now().toString().split('.').first.split(' ').last;
    if (mounted) {
      setState(() {
        _logs.insert(0, "[$time] $msg");
        if (_logs.length > 50) _logs.removeLast();
      });
    }
    debugPrint("P2P_LOG: $msg");
  }

  void _init() async {
    _log("Initializing Plugin...");
    await _plugin.initialize();
    await _plugin.register();
    _log("Plugin Initialized & Registered");

    _ipAddress = await _plugin.getIPAddress() ?? "No IP";
    _log("Current IP: $_ipAddress");

    _infoSub = _plugin.streamWifiP2PInfo().listen((info) {
      _log("Update: Formed=${info.groupFormed}, Conn=${info.isConnected}");
      _handleP2PInfo(info);
    });

    _peerSub = _plugin.streamPeers().listen((p) {
      _log("Peers Update: Found ${p.length} devices");
      if (mounted) {
        setState(() {
          _peers = p;
          if (!_isConnected) _status = "Found ${p.length} devices";
        });
      }
    });
  }

  void _handleP2PInfo(WifiP2PInfo info) {
    if (_isDisconnecting) return;
    final hasConnection =
        info.isConnected ||
        (!info.isGroupOwner &&
            info.groupFormed &&
            info.groupOwnerAddress.isNotEmpty);
    if (hasConnection && !_isConnected) {
      _onConnected(info);
    } else if (hasConnection && _isConnected) {
      _updateConnectedDevice(info);
    } else if (!hasConnection && _isConnected) {
      _onDisconnected();
    }
  }

  void _onConnected(WifiP2PInfo info) async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;

    P2PTransceiver t = info.isGroupOwner
        ? HostTransceiver(initialInfo: info)
        : ClientTransceiver(initialInfo: info);
    await t.initialize();
    await t.startConnection();

    if (mounted) {
      setState(() {
        _transceiver = t;
        _isConnected = true;
        _isConnecting = false;
        _status = "Connected as ${info.isGroupOwner ? 'Host' : 'Client'}";
        _setConnectedDevice(info);
        _voiceManager = VoiceManager(t);
        _voiceManager?.init();

        // 音量レベルの監視を開始
        _levelSub?.cancel();
        _levelSub = _voiceManager?.levelStream.listen((levels) {
          if (mounted) {
            setState(() {
              if (levels.containsKey('sent')) {
                _sendLevel = levels['sent']!;
              }
              if (levels.containsKey('received')) {
                _receiveLevel = levels['received']!;
              }
            });
          }
        });
      });
    } else {
      _isConnecting = false;
    }
  }

  void _onDisconnected() {
    unawaited(_releaseSleepLocks());
    if (mounted) {
      setState(() {
        _transceiver = null;
        _voiceManager = null;
        _isConnected = false;
        _isConnecting = false;
        _isIntercomRunning = false;
        _isDisconnecting = false;
        _pendingPeerName = null;
        _pendingPeerAddress = null;
        _connectedDeviceName = null;
        _connectedDeviceAddress = null;
        _connectedDeviceRole = null;
        _status = "Disconnected";
        _sendLevel = 0;
        _receiveLevel = 0;
        _levelSub?.cancel();
      });
    }
  }

  Future<void> _disconnect() async {
    if (_isDisconnecting) return;

    final transceiver = _transceiver;
    final voiceManager = _voiceManager;
    final shouldStopVoice = _isIntercomRunning;

    if (mounted) {
      setState(() {
        _transceiver = null;
        _voiceManager = null;
        _isConnected = false;
        _isConnecting = false;
        _isIntercomRunning = false;
        _isDisconnecting = true;
        _pendingPeerName = null;
        _pendingPeerAddress = null;
        _connectedDeviceName = null;
        _connectedDeviceAddress = null;
        _connectedDeviceRole = null;
        _status = "Disconnecting...";
        _sendLevel = 0;
        _receiveLevel = 0;
      });
    }
    await _levelSub?.cancel();
    _levelSub = null;

    try {
      if (shouldStopVoice) {
        await voiceManager?.stop();
      }
      await _releaseSleepLocks();
      if (transceiver != null) {
        await transceiver.disconnect();
      } else {
        await _plugin.removeGroup();
      }
      if (mounted) {
        setState(() {
          _isDisconnecting = false;
          _isConnecting = false;
          _status = "Disconnected";
        });
      }
    } catch (e) {
      _log("Disconnect failed: $e");
      if (mounted) {
        setState(() {
          _isDisconnecting = false;
          _isConnecting = false;
          _status = "Disconnect failed";
        });
      }
      _showError("Disconnect failed: $e");
    }
  }

  Future<void> _startDiscovery() async {
    if (!await _checkPermissions()) return;
    _log("Starting Discovery...");
    await _plugin.stopDiscovery().catchError((_) => false);
    await Future.delayed(const Duration(milliseconds: 300));
    bool ok = await _plugin.discover();
    _log("Discover Result: $ok");
    if (mounted) setState(() => _status = ok ? "Scanning..." : "Scan Busy");
  }

  Future<void> _createGroup() async {
    if (!await _checkPermissions()) return;
    _log("Force Creating Group...");
    await _plugin.removeGroup().catchError((_) => false);
    await Future.delayed(const Duration(seconds: 1));
    bool ok = await _plugin.createGroup();
    _log("Create Group Result: $ok");
    if (mounted) {
      setState(() => _status = ok ? "Group Created" : "Group Failed");
    }
  }

  Future<bool> _checkPermissions() async {
    var loc = await Permission.location.request();
    final versionString = await _plugin.getPlatformVersion();
    final version =
        int.tryParse(versionString?.replaceAll(RegExp(r'[^0-9]'), '') ?? "0") ??
        0;
    if (version >= 13 || version >= 33) {
      await Permission.nearbyWifiDevices.request();
    }
    await Permission.notification.request();
    return loc.isGranted &&
        await _plugin.checkWifiEnabled() &&
        await _plugin.checkLocationEnabled();
  }

  void _connect(DiscoveredPeers peer) async {
    _log(
      "Connecting to: ${peer.deviceName} (${peer.deviceAddress}), status=${peer.status}, isGroupOwner=${peer.isGroupOwner}",
    );
    if (mounted) {
      setState(() {
        _pendingPeerName = peer.deviceName;
        _pendingPeerAddress = peer.deviceAddress;
        _status = "Connecting to ${peer.deviceName}";
      });
    }

    try {
      bool ok = await _plugin.connect(peer.deviceAddress);
      _log("Connect Result: $ok");
      if (mounted) {
        setState(
          () => _status = ok ? "Connection requested" : "Connect failed",
        );
      }
      if (!ok) {
        if (mounted) {
          setState(() {
            _pendingPeerName = null;
            _pendingPeerAddress = null;
          });
        }
        _showError("Connect failed");
      }
    } catch (e) {
      _log("Connect failed: $e");
      if (mounted) {
        setState(() {
          _pendingPeerName = null;
          _pendingPeerAddress = null;
          _status = "Connect failed";
        });
      }
      _showError("Connect failed: $e");
    }
  }

  void _updateConnectedDevice(WifiP2PInfo info) {
    if (!mounted) return;
    setState(() => _setConnectedDevice(info));
  }

  void _setConnectedDevice(WifiP2PInfo info) {
    if (info.isGroupOwner) {
      if (info.clients.isNotEmpty) {
        final clientNames = info.clients
            .map((client) => client.deviceName)
            .where((name) => name.isNotEmpty)
            .join(", ");
        final clientAddresses = info.clients
            .map((client) => client.deviceAddress)
            .where((address) => address.isNotEmpty)
            .join(", ");
        _connectedDeviceName = clientNames.isEmpty
            ? "${info.clients.length} connected clients"
            : clientNames;
        _connectedDeviceAddress = clientAddresses.isEmpty
            ? "No client address"
            : clientAddresses;
        _connectedDeviceRole = info.clients.length == 1
            ? "Client"
            : "${info.clients.length} Clients";
      } else {
        _connectedDeviceName = _connectedDeviceName ?? "Waiting for clients";
        _connectedDeviceAddress = _connectedDeviceAddress ?? "No client yet";
        _connectedDeviceRole = "Host";
      }
    } else {
      _connectedDeviceName =
          _pendingPeerName ?? _connectedDeviceName ?? "Group Owner";
      final pendingPeerAddress = _pendingPeerAddress;
      _connectedDeviceAddress =
          pendingPeerAddress != null && pendingPeerAddress.isNotEmpty
          ? pendingPeerAddress
          : info.groupOwnerAddress.isNotEmpty
          ? info.groupOwnerAddress
          : _connectedDeviceAddress;
      _connectedDeviceRole = "Host";
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    _infoSub?.cancel();
    _levelSub?.cancel();
    unawaited(_releaseSleepLocks());
    _plugin.unregister();
    super.dispose();
  }

  Widget _buildLevelMeter(String label, double level, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label Level:",
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                color: Colors.grey.shade300,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 12,
                width:
                    MediaQuery.of(context).size.width *
                    (level * 2).clamp(0.0, 1.0),
                color: color,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedDeviceInfo() {
    final name = _connectedDeviceName ?? "Unknown device";
    final address = _connectedDeviceAddress ?? "Unknown address";
    final role = _connectedDeviceRole ?? "Peer";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "$role / $address",
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("P2P Debug Intercom"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startDiscovery,
            tooltip: "Reset P2P",
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. デバッグ情報 & ログエリア
          Container(
            height: 180,
            width: double.infinity,
            color: Colors.black.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (c, i) => Text(
                _logs[i],
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
              ),
            ),
          ),

          // 2. メイン操作エリア
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_isConnected) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _startDiscovery,
                            child: const Text("Scan"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _createGroup,
                            child: const Text("Create Group"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _peers.length,
                        itemBuilder: (c, i) => Card(
                          child: ListTile(
                            title: Text(_peers[i].deviceName),
                            subtitle: Text(_peers[i].deviceAddress),
                            onTap: () => _connect(_peers[i]),
                            trailing: const Icon(Icons.link),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 60,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Connected!",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(_status, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    _buildConnectedDeviceInfo(),
                    const SizedBox(height: 20),
                    _buildLevelMeter("MIC (SENT)", _sendLevel, Colors.blue),
                    const SizedBox(height: 15),
                    _buildLevelMeter(
                      "SPEAKER (RECEIVED)",
                      _receiveLevel,
                      Colors.orange,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _toggleVoice,
                      icon: Icon(
                        _isIntercomRunning ? Icons.mic_off : Icons.mic,
                      ),
                      label: Text(
                        _isIntercomRunning ? "Stop Intercom" : "Start Intercom",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isIntercomRunning
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        minimumSize: const Size(200, 60),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _disconnect,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: const Text("Disconnect"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleVoice() async {
    try {
      if (_isIntercomRunning) {
        await _voiceManager?.stop();
        await _releaseSleepLocks();
      } else {
        await _acquireSleepLocks();
        await _voiceManager?.start();
      }
      if (mounted) setState(() => _isIntercomRunning = !_isIntercomRunning);
    } catch (e) {
      if (!_isIntercomRunning) {
        await _releaseSleepLocks();
      }
      _log("Intercom toggle failed: $e");
      _showError("Intercom failed: $e");
    }
  }

  Future<void> _acquireSleepLocks() async {
    try {
      await _powerChannel.invokeMethod<void>('acquireSleepLocks');
      _log("Sleep locks acquired");
    } on MissingPluginException {
      _log("Sleep locks are not available on this platform");
    }
  }

  Future<void> _releaseSleepLocks() async {
    try {
      await _powerChannel.invokeMethod<void>('releaseSleepLocks');
      _log("Sleep locks released");
    } on MissingPluginException {
      _log("Sleep locks are not available on this platform");
    }
  }
}
