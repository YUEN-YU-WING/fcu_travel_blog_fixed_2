import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class VisionService {
  final String apiKey;

  VisionService({required this.apiKey});

  Future<String?> detectLandmark(dynamic imageInput) async {
    Uint8List bytes;
    
    // Handle different input types for mobile vs web
    if (imageInput is File) {
      // Mobile platform - use File
      bytes = await imageInput.readAsBytes();
    } else if (imageInput is XFile) {
      // Web platform - use XFile
      bytes = await imageInput.readAsBytes();
    } else {
      throw ArgumentError('Unsupported image input type');
    }

    final base64Image = base64Encode(bytes);

    final url = 'https://vision.googleapis.com/v1/images:annotate?key=$apiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "requests": [
          {
            "image": {"content": base64Image},
            "features": [{"type": "LANDMARK_DETECTION", "maxResults": 3}]
          }
        ]
      }),
    );

    final result = jsonDecode(response.body);
    final landmarks = result['responses'][0]['landmarkAnnotations'];
    if (landmarks != null && landmarks.isNotEmpty) {
      return landmarks[0]['description']; // 例如 "Eiffel Tower"
    }
    return null;
  }
}
