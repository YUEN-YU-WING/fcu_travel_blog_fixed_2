import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class VisionService {
  final String serverUrl;

  VisionService({required this.serverUrl});

  /// 使用圖片網址偵測地標
  Future<String> detectLandmarkByUrl(String imageUrl) async {
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
  }

}

