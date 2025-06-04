import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VisionService {
  final String apiKey;

  VisionService({required this.apiKey});

  Future<String?> detectLandmark(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
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
