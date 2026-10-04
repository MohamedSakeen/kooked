import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/scan_vision_engine.dart';
import 'package:kooked/services/scan_vision_types.dart';

ScanVisionResult successOf(ScanModelSource source, String name) {
  return ScanVisionResult.success(
    source: source,
    items: <Map<String, dynamic>>[
      <String, dynamic>{'name': name, 'qty': 1.0, 'unit': 'pcs'},
    ],
  );
}

ScanVisionResult emptyOf(ScanModelSource source) {
  return ScanVisionResult.empty(source: source);
}

ScanVisionResult failedOf(
  ScanModelSource source,
  String reason, {
  ScanVisionStage stage = ScanVisionStage.execution,
}) {
  return ScanVisionResult.failed(
    source: source,
    failure: ScanVisionFailure(stage: stage, reason: reason),
  );
}

void main() {
  late File image;
  late int localCalls;
  late int cloudCalls;

  setUp(() {
    image = File('scan.jpg');
    localCalls = 0;
    cloudCalls = 0;
  });

  ScanVisionEngine engineWith({
    required Future<ScanVisionResult> Function(File) local,
    required Future<List<Map<String, dynamic>>> Function(File) cloud,
  }) {
    return ScanVisionEngine(
      runLocal: (file, {minConfidence}) {
        localCalls++;
        return local(file);
      },
      runCloud: (file) {
        cloudCalls++;
        return cloud(file);
      },
    );
  }

  group('ScanVisionStrategy local-first', () {
    test('returns local success and never contacts the cloud', () async {
      final engine = engineWith(
        local: (_) async => successOf(ScanModelSource.local, 'banana'),
        cloud: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{'name': 'cloud-item'},
        ],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localFirst,
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, ScanModelSource.local);
      expect(result.items.first['name'], 'banana');
      expect(localCalls, 1);
      expect(cloudCalls, 0);
    });

    test('falls back to cloud when local is EMPTY', () async {
      final engine = engineWith(
        local: (_) async => emptyOf(ScanModelSource.local),
        cloud: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{'name': 'cloud-item'},
        ],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localFirst,
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, ScanModelSource.cloud);
      expect(localCalls, 1);
      expect(cloudCalls, 1);
    });

    test('falls back to cloud when local FAILED', () async {
      final engine = engineWith(
        local: (_) async => failedOf(
          ScanModelSource.local,
          'Model execution failed: boom',
        ),
        cloud: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{'name': 'cloud-item'},
        ],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localFirst,
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, ScanModelSource.cloud);
    });
  });

  group('ScanVisionStrategy cloud-first', () {
    test('returns cloud success and never loads the local model', () async {
      final engine = engineWith(
        local: (_) async => successOf(ScanModelSource.local, 'banana'),
        cloud: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{'name': 'cloud-item'},
        ],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.cloudFirst,
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, ScanModelSource.cloud);
      expect(cloudCalls, 1);
      expect(localCalls, 0,
          reason: 'cloud success must not touch the on-device model');
    });

    test('falls back to local when cloud FAILED', () async {
      final engine = engineWith(
        local: (_) async => successOf(ScanModelSource.local, 'banana'),
        cloud: (_) async => throw const ScanVisionException(
          'Cannot reach AI server.',
        ),
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.cloudFirst,
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, ScanModelSource.local);
      expect(cloudCalls, 1);
      expect(localCalls, 1);
    });

    test('falls back to local when cloud returns nothing', () async {
      final engine = engineWith(
        local: (_) async => successOf(ScanModelSource.local, 'banana'),
        cloud: (_) async => <Map<String, dynamic>>[],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.cloudFirst,
      );

      expect(result.isSuccess, isTrue);
      expect(result.source, ScanModelSource.local);
    });
  });

  group('ScanVisionStrategy local-only and cloud-only', () {
    test('localOnly never contacts the cloud', () async {
      final engine = engineWith(
        local: (_) async => emptyOf(ScanModelSource.local),
        cloud: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{'name': 'cloud-item'},
        ],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localOnly,
      );

      expect(result.isEmpty, isTrue);
      expect(cloudCalls, 0);
      expect(localCalls, 1);
    });

    test('localOnly surfaces a local failure without a server message', () async {
      final engine = engineWith(
        local: (_) async => failedOf(
          ScanModelSource.local,
          'Could not initialize on-device model: dll missing',
        ),
        cloud: (_) async => <Map<String, dynamic>>[],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localOnly,
      );

      expect(result.isFailed, isTrue);
      expect(result.failure!.reason, contains('dll missing'));
      expect(result.userMessage!.toLowerCase().contains('server'), isFalse);
      expect(cloudCalls, 0);
    });

    test('cloudOnly never loads the local model', () async {
      final engine = engineWith(
        local: (_) async => successOf(ScanModelSource.local, 'banana'),
        cloud: (_) async => throw const ScanVisionException('offline'),
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.cloudOnly,
      );

      expect(result.isFailed, isTrue);
      expect(localCalls, 0);
      expect(cloudCalls, 1);
    });

    test('cloudOnly reports EMPTY when cloud finds nothing', () async {
      final engine = engineWith(
        local: (_) async => successOf(ScanModelSource.local, 'banana'),
        cloud: (_) async => <Map<String, dynamic>>[],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.cloudOnly,
      );

      expect(result.isEmpty, isTrue);
      expect(result.source, ScanModelSource.cloud);
      expect(result.userMessage, 'No food items detected');
    });
  });

  group('EMPTY is never reported as a network failure', () {
    test('local EMPTY plus unreachable cloud stays EMPTY', () async {
      final engine = engineWith(
        local: (_) async => emptyOf(ScanModelSource.local),
        cloud: (_) async => throw const ScanVisionException(
          'Cannot reach AI server. Please make sure the backend server is running.',
        ),
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localFirst,
      );

      expect(result.status, ScanVisionStatus.empty);
      expect(result.isFailed, isFalse);
      expect(result.userMessage, 'No food items detected');

      final message = result.userMessage!.toLowerCase();
      for (final forbidden in <String>[
        'cannot reach',
        'server',
        'unreachable',
        'connect',
        'network',
        'offline',
      ]) {
        expect(message.contains(forbidden), isFalse,
            reason: 'EMPTY surfaced "$message", which contains "$forbidden"');
      }
    });

    test('cloud EMPTY plus failed local stays EMPTY', () async {
      final engine = engineWith(
        local: (_) async => failedOf(
          ScanModelSource.local,
          'Model execution failed: boom',
        ),
        cloud: (_) async => <Map<String, dynamic>>[],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.cloudFirst,
      );

      expect(result.isEmpty, isTrue);
      expect(result.userMessage, 'No food items detected');
      expect(result.fallbackFailure, isNotNull,
          reason: 'the local failure is still recorded for diagnostics');
      expect(result.fallbackFailure!.reason, contains('boom'));
    });
  });

  group('both engines failing', () {
    test('reports the primary reason and records the fallback reason', () async {
      final engine = engineWith(
        local: (_) async => failedOf(
          ScanModelSource.local,
          'Model execution failed: local boom',
        ),
        cloud: (_) async => throw const ScanVisionException(
          'Cannot reach AI server.',
        ),
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localFirst,
      );

      expect(result.isFailed, isTrue);
      expect(result.failure!.reason, contains('local boom'));
      expect(result.fallbackFailure!.reason, contains('Cannot reach AI server'));
    });

    test('a throwing local runner becomes FAILED, not an exception', () async {
      final engine = ScanVisionEngine(
        runLocal: (file, {minConfidence}) async =>
            throw StateError('runner exploded'),
        runCloud: (file) async => <Map<String, dynamic>>[],
      );

      final result = await engine.analyze(
        image,
        strategy: ScanVisionStrategy.localOnly,
      );

      expect(result.isFailed, isTrue);
      expect(result.failure!.reason, contains('runner exploded'));
    });
  });

  group('ScanVisionStrategy metadata', () {
    test('declares participation and ordering for all four strategies', () {
      expect(ScanVisionStrategy.localFirst.allowsLocal, isTrue);
      expect(ScanVisionStrategy.localFirst.allowsCloud, isTrue);
      expect(ScanVisionStrategy.localFirst.primary, ScanModelSource.local);

      expect(ScanVisionStrategy.cloudFirst.allowsLocal, isTrue);
      expect(ScanVisionStrategy.cloudFirst.allowsCloud, isTrue);
      expect(ScanVisionStrategy.cloudFirst.primary, ScanModelSource.cloud);

      expect(ScanVisionStrategy.localOnly.allowsLocal, isTrue);
      expect(ScanVisionStrategy.localOnly.allowsCloud, isFalse);

      expect(ScanVisionStrategy.cloudOnly.allowsLocal, isFalse);
      expect(ScanVisionStrategy.cloudOnly.allowsCloud, isTrue);

      expect(ScanVisionStrategy.localFirst.secondary, ScanModelSource.cloud);
      expect(ScanVisionStrategy.cloudFirst.secondary, ScanModelSource.local);
    });

    test('defaults to cloud-first', () async {
      final engine = engineWith(
        local: (_) async => successOf(ScanModelSource.local, 'banana'),
        cloud: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{'name': 'cloud-item'},
        ],
      );

      final result = await engine.analyze(image);

      expect(result.source, ScanModelSource.cloud);
      expect(localCalls, 0);
    });
  });
}