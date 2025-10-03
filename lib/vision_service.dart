import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class VisionService {
  final String? serverUrl; // 如果有自架後端就填，沒有就直接串Google
  final String? googleApiKey; // 直接串Google時必填

  VisionService({this.serverUrl, this.googleApiKey});

  /// 1. 用圖片網址偵測地標
  Future<String> detectLandmarkByUrl(String imageUrl) async {
    if (serverUrl != null) {
      // 呼叫你自己的Server
      try {
        final response = await http.post(
          Uri.parse('$serverUrl/landmark'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'imageUrl': imageUrl}),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['landmark'] ?? '未知地標';
        } else {
          return '伺服器錯誤: ${response.statusCode}';
        }
      } catch (e) {
        return '連線失敗: $e';
      }
    } else if (googleApiKey != null) {
      // 直接呼叫 Google Vision API
      return await _detectLandmarkByUrlGoogle(imageUrl);
    } else {
      throw Exception('請提供 serverUrl 或 googleApiKey');
    }
  }

  /// 2. 用本地 bytes 偵測地標
  Future<String> detectLandmarkByBytes(Uint8List bytes) async {
    if (googleApiKey == null) {
      throw Exception('detectLandmarkByBytes 只能用 googleApiKey 直連Google');
    }
    final base64Image = base64Encode(bytes);
    return await _detectLandmarkGoogle({
      "image": {"content": base64Image}
    });
  }

  /// 內部: 直接呼叫 Google Vision API (imageUri)
  Future<String> _detectLandmarkByUrlGoogle(String imageUrl) async {
    return await _detectLandmarkGoogle({
      "image": {"source": {"imageUri": imageUrl}}
    });
  }

  /// Google Vision API 共用
  Future<String> _detectLandmarkGoogle(Map<String, dynamic> imageObj) async {
    final endpoint = "https://vision.googleapis.com/v1/images:annotate?key=$googleApiKey";
    final payload = {
      "requests": [
        {
          ...imageObj,
          "features": [
            {"type": "LANDMARK_DETECTION", "maxResults": 1}
          ],
          "imageContext": {
            "languageHints": ["zh-TW"] // 優先回傳中文
          }
        }
      ]
    };
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      try {
        return body['responses'][0]['landmarkAnnotations'][0]['description'] ?? '未知地標';
      } catch (_) {
        return '';
      }
    } else {
      return '伺服器錯誤: ${response.statusCode}';
    }
  }
}