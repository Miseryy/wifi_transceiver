import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wifi_transceiver/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const p2pChannel = MethodChannel('flutter_p2p_connection');
    const foundPeersChannel = MethodChannel(
      'flutter_p2p_connection_foundPeers',
    );
    const connectedPeersChannel = MethodChannel(
      'flutter_p2p_connection_connectedPeers',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(p2pChannel, (call) async {
          switch (call.method) {
            case 'initialize':
            case 'resume':
            case 'pause':
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foundPeersChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectedPeersChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_p2p_connection'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_p2p_connection_foundPeers'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_p2p_connection_connectedPeers'),
          null,
        );
  });

  testWidgets('shows discovery controls before connecting', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('P2P Debug Intercom'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Create Group'), findsOneWidget);
  });
}
