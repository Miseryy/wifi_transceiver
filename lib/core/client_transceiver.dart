import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'p2p_transceiver.dart';

class ClientTransceiver implements P2PTransceiver {
  ClientTransceiver({WifiP2PInfo? initialInfo}) : _initialInfo = initialInfo;

  final _plugin = FlutterP2pConnection();
  final WifiP2PInfo? _initialInfo;
  bool _isConnected = false;
  String? _peerAddress; // ホスト（Group Owner）のIP
  RawDatagramSocket? _socket;
  StreamSubscription? _infoSub;

  final _statusController = StreamController<bool>.broadcast();
  final _audioController = StreamController<List<int>>.broadcast();

  @override
  bool get isConnected => _isConnected;
  @override
  String? get peerAddress => _peerAddress;
  @override
  Stream<bool> get connectionStatusStream => _statusController.stream;
  @override
  Stream<List<int>> get audioStream => _audioController.stream;

  @override
  Future<void> initialize() async {
    await _plugin.initialize();
  }

  @override
  Future<void> startConnection() async {
    final initialInfo = _initialInfo;
    if (initialInfo != null && _canUseConnection(initialInfo)) {
      await _markConnected(initialInfo.groupOwnerAddress);
      return;
    }
    _listenForConnection();
  }

  // 外部（UI）から特定のデバイスに接続する場合
  Future<void> connectToDevice(DiscoveredPeers device) async {
    await _plugin.connect(device.deviceAddress);
  }

  void _listenForConnection() {
    _infoSub ??= _plugin.streamWifiP2PInfo().listen((info) async {
      debugPrint(
        "Client P2P Info: isConnected=${info.isConnected}, groupFormed=${info.groupFormed}, owner=${info.groupOwnerAddress}",
      );
      if (_canUseConnection(info)) {
        await _markConnected(info.groupOwnerAddress);
      }
    });
  }

  bool _canUseConnection(WifiP2PInfo? info) {
    return info != null &&
        !info.isGroupOwner &&
        (info.isConnected || info.groupFormed) &&
        info.groupOwnerAddress.isNotEmpty;
  }

  Future<void> _markConnected(String groupOwnerAddress) async {
    if (_isConnected) return;
    _isConnected = true;
    _peerAddress = groupOwnerAddress.replaceFirst("/", "");
    _statusController.add(true);
    await _setupUdpSocket();
  }

  Future<void> _setupUdpSocket() async {
    if (_socket != null) return;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8888);
    _socket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = _socket?.receive();
        if (dg != null) {
          _audioController.add(dg.data);
        }
      }
    });
  }

  @override
  Future<void> sendAudioFrame(List<int> frame) async {
    if (_socket != null && _peerAddress != null) {
      _socket?.send(frame, InternetAddress(_peerAddress!), 8888);
    }
  }

  @override
  Future<void> disconnect() async {
    await _plugin.stopDiscovery();
    await _plugin.removeGroup(); // または切断処理
    await _infoSub?.cancel();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _statusController.add(false);
  }
}
