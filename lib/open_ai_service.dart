import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<String> generateTravelArticleWithOpenAI(List<Map<String, String>> spots) async {
  await dotenv.load();
  String? apiKey = dotenv.env['OPENAI_API_KEY'];
  final prompt = buildTravelPrompt(spots);

  final response = await http.post(
    Uri.parse("https://api.openai.com/v1/chat/completions"),
    headers: {
      "Authorization": "Bearer $apiKey",
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "model": "gpt-3.5-turbo",
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "max_tokens": 400,
      "temperature": 0.7,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'].trim();
  } else {
    throw Exception("OpenAI API error: ${response.body}");
  }
}

String buildTravelPrompt(List<Map<String, String>> spots) {
  String spotsText = "";
  int i = 1;
  for (final spot in spots) {
    spotsText += "$i. ${spot['landmark']}：${spot['note']}\n";
    i++;
  }
  return '''
請根據下列景點及我的感受，寫一篇約200字的遊記，內容不需要太有文采，但請標註出可以加強描述情感的地方，並給提示（用[這裡可以補充你當下的感受，例如：...]的格式）：
$spotsText
請用繁體中文生成文章。
''';
}