import 'dart:async';

abstract class P2PTransceiver {
  bool get isConnected;
  String? get peerAddress;

  /// 初期化処理（権限チェックやプラグインの準備）
  Future<void> initialize();

  /// 接続の開始（ホストは待機、クライアントは検索・接続）
  Future<void> startConnection();

  /// 音声データの送信
  Future<void> sendAudioFrame(List<int> frame);

  /// 切断処理
  Future<void> disconnect();

  /// 状態通知用のストリーム（UIで使用）
  Stream<bool> get connectionStatusStream;

  /// 受信した音声データのストリーム
  Stream<List<int>> get audioStream;
}
