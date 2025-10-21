// lib/services/openai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 確保你的 .env 設定正確

class OpenAIService {
  static final String? _apiKey = dotenv.env['OPENAI_API_KEY'];
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<String> generateTravelArticleHtml({
    required String userDescription,
    required String placeName,
    required List<String> materialImageUrls, // 傳遞圖片 URL 列表
  }) async {
    if (_apiKey == null) {
      throw Exception('OPENAI_API_KEY is not set in .env file');
    }

    // 將圖片 URL 列表轉換為一個易於 AI 理解的字符串
    // 每個圖片 URL 建議在 prompt 中獨立提及，以鼓勵 AI 針對每張圖片生成內容
    String imageUrlsPrompt = '';
    if (materialImageUrls.isNotEmpty) {
      imageUrlsPrompt = '\n\n以下是一些素材圖片URL，請在文章中適當位置插入這些圖片的`<img>`標籤，並為每張圖片在`alt`屬性中提供一個簡潔但具體的描述：\n';
      for (int i = 0; i < materialImageUrls.length; i++) {
        imageUrlsPrompt += '圖片${i + 1} URL: ${materialImageUrls[i]}\n';
      }
      imageUrlsPrompt += '\n對於每張圖片，外層要有`<p>`，請務必使用`<img>`標籤插入圖片，例如 `<img src="圖片URL" alt="圖片描述">`。\n';
    }

    final String prompt = '''
你是一個專業的旅遊作家和編輯。請根據以下用戶提供的地點、行程描述和素材圖片，為其生成一篇引人入勝、詳細且富有情感的旅遊文章，並以 HTML 格式輸出。

文章應包含：
1.  一個吸引人的 <h1> 標題。
2.  多個 <p> 段落，詳細描述行程，包括：
    *   開頭吸引讀者，點出旅程的獨特之處。
    *   介紹地點背景、特色和亮點。
    *   詳細描述在該地點進行的活動、看到的風景、品嚐的美食、遇到的趣事或感受。
    *   結尾總結感受，提供實用建議或展望。
3.  適當使用 <h2> 或 <h3> 標題來劃分文章結構，讓內容更易讀。
4.  在文章中適當的位置插入提供的圖片。**對於每張圖片，外層要有`<p>`，請務必使用完整的 `<img>` 標籤，並在 `src` 屬性中填入圖片的 URL，在 `alt` 屬性中提供這張圖片的詳細中文描述。** 圖片描述應與圖片內容和文章上下文緊密相關。
5.  文章語氣應積極、生動，富有感染力，彷彿親身經歷。
6.  請確保文章內容豐富、細節具體，避免空泛的陳述。

**用戶提供的資訊：**
地點名稱: ${placeName}
行程描述: ${userDescription}
${imageUrlsPrompt}

請僅返回 HTML 格式的文章內容，不要包含其他任何額外文字或解釋。
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-turbo-preview', // 你也可以嘗試 'gpt-4' 或 'gpt-4-turbo-preview' 以獲得更好的效果，但成本更高
          'messages': [
            {'role': 'system', 'content': '你是一個專業的旅遊作家和編輯，專門撰寫引人入勝的 HTML 格式旅遊文章。'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7, // 增加創造性
          'max_tokens': 4000, // 增加返回內容的最大長度
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)); // 確保正確解碼中文
        final String htmlContent = data['choices'][0]['message']['content'];

        // AI 可能會給出額外的解釋，嘗試提取純 HTML
        final RegExp htmlOnlyRegExp = RegExp(r'```html\n(.*)\n```', dotAll: true);
        final Match? match = htmlOnlyRegExp.firstMatch(htmlContent);
        if (match != null) {
          return match.group(1)!.trim();
        }
        return htmlContent.trim(); // 如果沒有```html```包裹，直接返回
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception('Failed to generate AI article: ${response.statusCode} - ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('OpenAI API request failed: $e');
    }
  }
}