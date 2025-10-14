// lib/vision_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class VisionService {
  /// 如果有自架後端就填，沒有就直接串 Google
  final String? serverUrl;

  /// 直接串 Google Vision API 時必填
  final String? googleApiKey;

  /// 逾時（預設 12 秒）
  final Duration timeout;

  VisionService({
    this.serverUrl,
    this.googleApiKey,
    this.timeout = const Duration(seconds: 12),
  });

  /// 1) 用圖片網址偵測地標
  ///
  /// - 若提供 `serverUrl`：呼叫你的伺服器 `POST $serverUrl/landmark`，body: `{"imageUrl": "..."}`。
  /// - 否則若提供 `googleApiKey`：改走 Google Vision API。
  /// - 兩者都沒有 → 丟錯。
  Future<String> detectLandmarkByUrl(String imageUrl) async {
    if (imageUrl.isEmpty) return '';

    if (serverUrl != null) {
      try {
        final resp = await http
            .post(
          Uri.parse('$serverUrl/landmark'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'imageUrl': imageUrl}),
        )
            .timeout(timeout);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final lm = _extractLandmark(data); // landmark / result / name / title
          return lm.isNotEmpty ? lm : '';
        } else {
          return '伺服器錯誤: ${resp.statusCode}';
        }
      } catch (e) {
        return '連線失敗: $e';
      }
    } else if (googleApiKey != null) {
      return await _detectLandmarkByUrlGoogle(imageUrl);
    } else {
      throw Exception('請提供 serverUrl 或 googleApiKey');
    }
  }

  /// 2) 用本地 bytes 偵測地標（僅支援直連 Google）
  Future<String> detectLandmarkByBytes(Uint8List bytes) async {
    if (googleApiKey == null) {
      throw Exception('detectLandmarkByBytes 只能用 googleApiKey 直連 Google');
    }
    final base64Image = base64Encode(bytes);
    return await _detectLandmarkGoogle({
      "image": {"content": base64Image}
    });
  }

  /// 內部：直接呼叫 Google Vision API（imageUri）
  Future<String> _detectLandmarkByUrlGoogle(String imageUrl) async {
    return await _detectLandmarkGoogle({
      "image": {"source": {"imageUri": imageUrl}}
    });
  }

  /// Google Vision API 共用呼叫
  Future<String> _detectLandmarkGoogle(Map<String, dynamic> imageObj) async {
    final endpoint =
        "https://vision.googleapis.com/v1/images:annotate?key=$googleApiKey";
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

    try {
      final response = await http
          .post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        try {
          final desc = body['responses']?[0]?['landmarkAnnotations']?[0]?['description'];
          return (desc is String) ? desc : '';
        } catch (_) {
          return '';
        }
      } else {
        return '伺服器錯誤: ${response.statusCode}';
      }
    } catch (e) {
      return '連線失敗: $e';
    }
  }

  /// 嘗試從各種常見欄位擷取地標名稱
  String _extractLandmark(dynamic json) {
    if (json == null) return '';
    if (json is Map<String, dynamic>) {
      for (final key in const ['landmark', 'result', 'name', 'title']) {
        final v = json[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      // 深入一層（容錯）
      for (final entry in json.entries) {
        final got = _extractLandmark(entry.value);
        if (got.isNotEmpty) return got;
      }
    } else if (json is List) {
      for (final item in json) {
        final got = _extractLandmark(item);
        if (got.isNotEmpty) return got;
      }
    } else if (json is String) {
      return json.trim();
    }
    return '';
  }
}