// lib/services/openai_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
// 引入新的數據模型

class OpenAIService {
  static Future<String> generateTravelArticleHtml({
    required String userDescription,
    required String placeName,
    List<String> materialImageUrls = const [],
  }) async {
    await dotenv.load();
    String? apiKey = dotenv.env['OPENAI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("OPENAI_API_KEY is not set in .env file.");
    }

    final prompt = buildTravelArticleHtmlPrompt(
      userDescription: userDescription,
      placeName: placeName,
      materialImageUrls: materialImageUrls,
    );

    print('Sending prompt to OpenAI:\n$prompt'); // 打印發送的 prompt

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini", // 建議使用 gpt-4o-mini 或 gpt-4o 處理更複雜的格式和圖片描述
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "max_tokens": 1500, // 增加 token 限制，因為 HTML 內容會比較多
        "temperature": 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String generatedContent = data['choices'][0]['message']['content'].trim();
      print('Received HTML content from OpenAI:\n$generatedContent'); // 打印收到的內容
      return generatedContent;
    } else {
      print("OpenAI API error: ${response.statusCode} - ${response.body}");
      throw Exception("OpenAI API error: ${response.body}");
    }
  }

  static String buildTravelArticleHtmlPrompt({
    required String userDescription,
    required String placeName,
    List<String> materialImageUrls = const [],
  }) {
    String imageHtml = '';
    if (materialImageUrls.isNotEmpty) {
      imageHtml = '\n以下是這次旅程的一些圖片素材，請將它們以 `<img>` 標籤插入到文章中適當的位置，並根據內容為圖片添加簡短描述：\n';
      for (int i = 0; i < materialImageUrls.length; i++) {
        imageHtml += '<img src="${materialImageUrls[i]}" alt="遊記圖片${i + 1}">\n';
      }
    }

    return '''
請你根據以下資訊，寫一篇繁體中文的網路遊記文章。
文章應該是友善、吸引人的，並以 HTML 格式輸出。
請確保所有的文本內容都包含在 HTML 標籤內（例如 <p>, <h2> 等）。

主要地點：$placeName
我的行程描述：$userDescription
$imageHtml

文章結構建議：
1. 一個 H1 標題作為文章標題。
2. 簡要的開頭段落（<p>）。
3. 描述行程中的亮點和感受，可以使用 H2 標題和小段落（<p>）。
4. 如果提供了圖片素材，請將 `<img>` 標籤以適當的尺寸和位置插入到文章內容中，並根據文章語境為每張圖片添加一個簡短的 `alt` 描述。
5. 一個簡短的結尾段落，總結這次體驗。
6. 請使用正確的 HTML 標籤（例如 `<p>`, `<h2>`, `<img>` 等），確保 HTML 語法完整且正確。不要包含 `<html>`, `<head>`, `<body>` 等最外層標籤。

範例圖片插入方式（請替換實際 URL 和 alt 文本）：
<p>這是我在 [地點] 拍到的美麗風景。</p>
<img src="https://example.com/image1.jpg" alt="[AI根據內容生成的圖片描述]" style="max-width:100%; height:auto;">
<p>這張照片展示了 [其他描述]。</p>

請注意 `style="max-width:100%; height:auto;"` 是為了讓圖片在網頁中響應式顯示。
''';
  }
}