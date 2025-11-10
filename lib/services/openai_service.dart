// lib/services/openai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static final String? _apiKey = dotenv.env['OPENAI_API_KEY'];
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<String> generateTravelArticleHtml({
    required String placeName,
    required List<String> materialImageUrls,
    List<String> materialImageDescriptions = const [],
    // 移除 userDescription，新增結構化參數
    String? companions,
    String? activities,
    String? moodOrPurpose,
  }) async {
    if (_apiKey == null) {
      throw Exception('OPENAI_API_KEY is not set in .env file');
    }

    String imageUrlsAndDescriptionsPrompt = '';
    if (materialImageUrls.isNotEmpty) {
      imageUrlsAndDescriptionsPrompt = '\n\n以下是您選擇的素材圖片資訊，請在文章中適當位置插入這些圖片的`<img>`標籤：\n';
      imageUrlsAndDescriptionsPrompt += '對於每張圖片，外層要有`<p>`。請務必使用完整的 `<img>` 標籤，並在 `src` 屬性中填入圖片的 URL，**在 `alt` 屬性中提供這張圖片的詳細中文描述**。圖片描述應與圖片內容和文章上下文緊密相關。\n';
      imageUrlsAndDescriptionsPrompt += '請特別注意，您可以參考每張圖片的「內容識別」資訊，來更好地撰寫 `alt` 描述和將圖片內容融入文章。\n\n';

      for (int i = 0; i < materialImageUrls.length; i++) {
        final String description = materialImageDescriptions.length > i && materialImageDescriptions[i].isNotEmpty
            ? '（內容識別：${materialImageDescriptions[i]}）'
            : '';
        imageUrlsAndDescriptionsPrompt += '圖片${i + 1} URL: ${materialImageUrls[i]} ${description}\n';
      }
    }

    // 根據結構化輸入構建用戶行程描述
    String structuredDescription = '';
    if (companions != null && companions.isNotEmpty) {
      structuredDescription += '同行者: $companions\n';
    }
    if (activities != null && activities.isNotEmpty) {
      structuredDescription += '活動或體驗: $activities\n';
    }
    if (moodOrPurpose != null && moodOrPurpose.isNotEmpty) {
      structuredDescription += '旅程心情或目的: $moodOrPurpose\n';
    }
    if (structuredDescription.isEmpty) {
      structuredDescription = '無詳細行程描述。請AI根據地點和圖片自由發揮。';
    } else {
      structuredDescription = '以下是用戶提供的旅程細節：\n' + structuredDescription;
    }


    final String prompt = '''
你是一位經驗豐富的旅遊作家與內容編輯，擅長以真實情感與生動細節撰寫 HTML 格式的旅遊文章。請根據以下資訊生成一篇自然、有故事感的遊記文章。

文章要求：
1.  使用 HTML 格式撰寫，包含：
    *   一個吸引人的 <h1> 標題。
    *   多個 <p> 段落與必要的 <h2> 或 <h3> 標題。
2.  文章結構建議：
    *   開頭：描寫出發動機或同行者氛圍（例如情侶、家人、朋友、獨旅）。
    *   中段：詳細描寫活動過程、看到的風景、氣味、聲音、食物與人文互動。
    *   結尾：分享心情變化、旅程意義或給未來旅人建議。
3.  插入圖片時，請：
    *   在自然語意中插入，外層使用 <p> 包裹。
    *   使用完整的 <img> 標籤，`src` 為圖片 URL，`alt` 為該圖片的具體中文敘述。
    *   讓圖片描述自然融入上下文。
4.  文字語氣：
    *   溫暖、生動、真實，有「我真的去過」的感覺。
    *   避免誇張形容詞與重複句。
5.  內容應豐富具體，避免過於概括或重複。

**用戶提供的資訊：**
地點名稱: ${placeName}
${structuredDescription} // 這裡使用組裝好的結構化描述
${imageUrlsAndDescriptionsPrompt}

請直接返回 HTML 格式的完整文章內容，不要使用 Markdown，也不要添加其他解釋。
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-turbo-preview',
          'messages': [
            {'role': 'system', 'content': '你是一個專業的旅遊作家和編輯，專門撰寫引人入勝的 HTML 格式旅遊文章。'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.8,
          'max_tokens': 4000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String htmlContent = data['choices'][0]['message']['content'];

        final RegExp htmlOnlyRegExp = RegExp(r'```html\n(.*)\n```', dotAll: true);
        final Match? match = htmlOnlyRegExp.firstMatch(htmlContent);
        if (match != null) {
          return match.group(1)!.trim();
        }
        return htmlContent.trim();
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception('Failed to generate AI article: ${response.statusCode} - ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('OpenAI API request failed: $e');
    }
  }
}