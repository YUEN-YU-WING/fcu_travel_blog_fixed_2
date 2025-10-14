// test/vision_service_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcu_travel_blog_fixed_2/vision_service.dart';

void main() {
  group('VisionService', () {
    test('detectLandmarkByBytes throws if googleApiKey is not provided', () async {
      final vs = VisionService(); // 沒提供 googleApiKey
      expect(
            () => vs.detectLandmarkByBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()),
      );
    });

    test('detectLandmarkByUrl throws if neither serverUrl nor googleApiKey is provided', () async {
      final vs = VisionService(); // 兩者都沒給
      expect(
            () => vs.detectLandmarkByUrl('https://example.com/image.jpg'),
        throwsA(isA<Exception>()),
      );
    });

    test('detectLandmarkByBytes returns Future<String> when googleApiKey is provided (network skipped)', () {
      final vs = VisionService(googleApiKey: 'dummy-key');
      // 這個呼叫會觸發網路，故僅驗證回傳型別，並 skip 實跑
      expect(
            () => vs.detectLandmarkByBytes(Uint8List.fromList([1, 2, 3])),
        isA<Future<String>>(),
        reason: 'API 簽章應該正確回傳 Future<String>',
      );
    }, skip: '需要 mock http 才能不打到真正的 Google API');

    test('detectLandmarkByUrl returns Future<String> when serverUrl is provided (network skipped)', () {
      // 指向假伺服器，只驗證型別
      final vs = VisionService(serverUrl: 'http://localhost:8080');
      expect(
            () => vs.detectLandmarkByUrl('https://example.com/image.jpg'),
        isA<Future<String>>(),
        reason: 'API 簽章應該正確回傳 Future<String>',
      );
    }, skip: '需要本機/測試伺服器或 http mock');

    test('detectLandmarkByUrl returns Future<String> when googleApiKey is provided (network skipped)', () {
      final vs = VisionService(googleApiKey: 'dummy-key');
      expect(
            () => vs.detectLandmarkByUrl('https://example.com/image.jpg'),
        isA<Future<String>>(),
        reason: 'API 簽章應該正確回傳 Future<String>',
      );
    }, skip: '需要 mock http 才能不打到真正的 Google API');
  });
}