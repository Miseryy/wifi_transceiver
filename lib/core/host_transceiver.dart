import 'dart:async';
import 'dart:io';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'p2p_transceiver.dart';

class HostTransceiver implements P2PTransceiver {
  HostTransceiver({WifiP2PInfo? initialInfo}) : _initialInfo = initialInfo;

  final _plugin = FlutterP2pConnection();
  final WifiP2PInfo? _initialInfo;
  bool _isConnected = false;
  String? _peerAddress;
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
    if (_initialInfo != null && _canUseConnection(_initialInfo)) {
      await _markConnected();
      return;
    }
    _listenForConnection();
  }

  void _listenForConnection() {
    _infoSub ??= _plugin.streamWifiP2PInfo().listen((info) async {
      print(
        "Host P2P Info: isConnected=${info.isConnected}, groupFormed=${info.groupFormed}, clients=${info.clients.length}",
      );
      if (_canUseConnection(info)) {
        await _markConnected();
      }
    });
  }

  bool _canUseConnection(WifiP2PInfo? info) {
    return info != null &&
        info.isGroupOwner &&
        (info.isConnected || info.groupFormed);
  }

  Future<void> _markConnected() async {
    if (_isConnected) return;
    _isConnected = true;
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
          // 受信したパケットの送信元を相手のIPとして記録（スラッシュ対策込み）
          final incomingAddr = dg.address.address.replaceFirst("/", "");
          if (_peerAddress != incomingAddr) {
            _peerAddress = incomingAddr;
          }
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
    await _plugin.removeGroup();
    await _infoSub?.cancel();
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _statusController.add(false);
  }
}
