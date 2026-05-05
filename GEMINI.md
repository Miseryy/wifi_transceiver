# Project: P2P Voice Intercom (Android-to-Android)

Wi-Fi Directを活用し、インターネット環境がない状況でもAndroid端末同士でリアルタイム音声通話を実現するFlutterプロジェクト。

---

## 1. 技術スタック
*   **Framework:** Flutter (Dart)
*   **P2P Connection:** `flutter_p2p_connection` (Wi-Fi Direct API)
*   **Audio Handling:** 
    *   Recording: `record` (PCM 16bit / 16kHz ストリーミング)
    *   Playback: `flutter_pcm_sound` (暫定実装) / `flutter_soloud` (将来の低遅延化用)
*   **Communication:** `Dart:io` (UDP Sockets / Port 8888)

---

## 2. システムアーキテクチャ

### 接続基盤 (Unified Discovery Model)
特定の「ホスト/クライアント」を事前に決めず、両方の端末が「Scan」と「Create Group」を自由に行える柔軟なモデルを採用。
1.  **Discovery:** 周囲のデバイスをスキャン。
2.  **Negotiation:** 接続時にOSレベルで Group Owner (Host) を自動決定。
3.  **Role Injection:** 決定された役割に応じて `HostTransceiver` または `ClientTransceiver` を動的に生成。

### 音声パイプライン (Voice Pipeline)
`AudioPlayer` インターフェースにより、再生エンジンを疎結合化。
*   `Mic -> PCM (16bit/16kHz) -> UDP Packet -> Peer`
*   `Peer -> UDP Packet -> PcmArrayInt16 -> AudioPlayer (スピーカー)`

---

## 3. 実装状況

### Phase 1: 接続基盤の構築 [DONE]
*   [x] Wi-Fi Directによるデバイス探索機能の実装。
*   [x] Android 12/13/14+ の権限（Location / Nearby Devices）対応。
*   [x] 接続状態のリアルタイム監視とデバッグログのUI表示。
*   [x] 接続「ビジー」状態を回避するためのリセットロジックの実装。

### Phase 2: 音声ストリーミングの実装 [DONE]
*   [x] `record` パッケージを用いたPCMデータのリアルタイム取得。
*   [x] UDPソケットによる小刻みな音声パケットの双方向送信。
*   [x] `flutter_pcm_sound` による受信データの再生。
*   [x] 録音・再生を管理する `VoiceManager` の実装。

### Phase 3: 最適化 [IN PROGRESS]
*   [ ] **低遅延化:** `flutter_soloud` への再生エンジン移行。
*   [ ] **ジッター対策:** 受信バッファ（Jitter Buffer）の実装。
*   [ ] **ノイズ対策:** エコーキャンセル等の検討。

---

## 4. 実行要件
*   **Android OS:** 5.0 (API 21) 以上
*   **Permissions:** `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`, `NEARBY_WIFI_DEVICES` (Android 13+)
*   **Physical Device:** 2台の実機が必要（エミュレータ不可）

---

## 5. Tips & トラブルシューティング
*   **Scanに出ない場合:** どちらかの端末のWi-Fiを一旦OFF/ONし、右上のリフレッシュボタンを押して再試行。
*   **Busyエラー:** `reasonCode=2` が出た場合は、OSのWi-Fi Direct設定画面を開くと解消しやすい。
*   **ハウリング:** テスト時はイヤホン推奨。

---

## 6. クラス構成
*   `P2PTransceiver`: 通信インターフェース
*   `HostTransceiver / ClientTransceiver`: 役割別の通信実装
*   `VoiceManager`: 録音・再生の統合管理
*   `AudioPlayer`: 再生エンジンの抽象化
