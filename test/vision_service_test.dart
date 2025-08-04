import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fcu_travel_blog_fixed_2/vision_service.dart';

void main() {
  group('VisionService', () {
    late VisionService visionService;

    setUp(() {
      visionService = VisionService(apiKey: 'test-api-key');
    });

    test('should accept File input for mobile platforms', () {
      // This test verifies the method signature accepts File input
      expect(() => visionService.detectLandmark(File('/dev/null')), isA<Future<String?>>());
    });

    test('should accept XFile input for web platforms', () {
      // This test verifies the method signature accepts XFile input
      final xFile = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'test.jpg');
      expect(() => visionService.detectLandmark(xFile), isA<Future<String?>>());
    });

    test('should throw ArgumentError for unsupported input types', () async {
      // Test that unsupported input types are rejected
      expect(
        () => visionService.detectLandmark('invalid-input'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}