import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'p2p_transceiver.dart';

/// 将来的にSoLoudなどに差し替え可能なように、再生部分を抽象化
abstract class AudioPlayer {
  Future<void> init();
  void play(Uint8List data);
  Future<void> stop();
}

/// flutter_pcm_soundを使用した暫定的な実装
class PcmAudioPlayer implements AudioPlayer {
  @override
  Future<void> init() async {
    // APIに合わせて引数を修正
    await FlutterPcmSound.setup(sampleRate: 16000, channelCount: 1);
    await FlutterPcmSound.setLogLevel(LogLevel.none); // ログが多いため抑制
    await FlutterPcmSound.play();
  }

  @override
  void play(Uint8List data) {
    // PcmArrayInt16にラップして送信
    // recordパッケージからくるのは little endian のバイト列なのでそのまま ByteData に渡せる
    final pcmData = PcmArrayInt16(bytes: data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes));
    FlutterPcmSound.feed(pcmData);
  }

  @override
  Future<void> stop() async {
    await FlutterPcmSound.stop();
    await FlutterPcmSound.release();
  }
}

class VoiceManager {
  final P2PTransceiver transceiver;
  final _audioRecorder = AudioRecorder();
  final AudioPlayer _player = PcmAudioPlayer();
  
  final _levelController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get levelStream => _levelController.stream;

  StreamSubscription? _recordingSubscription;
  StreamSubscription? _receivingSubscription;

  VoiceManager(this.transceiver);

  // PCMデータ(Int16)から音量を計算する簡易的な関数
  double _calculateLevel(Uint8List data) {
    if (data.isEmpty) return 0;
    double sum = 0;
    final int16List = data.buffer.asInt16List(data.offsetInBytes, data.lengthInBytes ~/ 2);
    for (var sample in int16List) {
      sum += sample.abs();
    }
    // 0.0 ~ 1.0 に正規化 (32768は16bitの最大値)
    return (sum / int16List.length) / 32768.0;
  }

  Future<void> init() async {
    if (!await _audioRecorder.hasPermission()) {
      print("No microphone permission");
      return;
    }
    await _player.init();
  }

  Future<void> start() async {
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );
    
    final stream = await _audioRecorder.startStream(config);
    
    _recordingSubscription = stream.listen((data) {
      // 送信データの音量を計算
      _levelController.add({'sent': _calculateLevel(Uint8List.fromList(data))});
      transceiver.sendAudioFrame(data);
    });

    _receivingSubscription = transceiver.audioStream.listen((data) {
      final udata = Uint8List.fromList(data);
      // 受信データの音量を計算
      _levelController.add({'received': _calculateLevel(udata)});
      _player.play(udata);
    });
  }

  Future<void> stop() async {
    await _audioRecorder.stop();
    await _player.stop();
    await _recordingSubscription?.cancel();
    await _receivingSubscription?.cancel();
    _recordingSubscription = null;
    _receivingSubscription = null;
  }
}
