import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/dom.dart' as dom;
import 'package:html_unescape/html_unescape.dart';

class ArticleDetailPage extends StatefulWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  Map<String, dynamic>? _articleData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchArticleDetails();
  }

  Future<void> _fetchArticleDetails() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('articles')
          .doc(widget.articleId)
          .get();

      if (docSnapshot.exists) {
        // 暫存 Firestore 資料
        final data = docSnapshot.data();

        // 🔹 解碼 HTML (處理 &lt;img&gt;)
        final unescape = HtmlUnescape();
        final htmlContentRaw = data?['content'] ?? '';
        final htmlContent = unescape.convert(htmlContentRaw);

        print('--- HTML content after unescape ---');
        print(htmlContent);

        // 🔹 更新狀態：將 content 替換成解碼後的版本
        setState(() {
          _articleData = {...data!, 'content': htmlContent};
          _isLoading = false;
        });

        // ✅ 偵測 <img> tag（可選）
        if (htmlContent.contains('<img')) {
          RegExp imgTagRegex = RegExp(
              '<img[^>]*src=["\']?([^"\']+)["\']?[^>]*>',
              multiLine: true);
          Iterable<RegExpMatch> matches = imgTagRegex.allMatches(htmlContent);
          for (var match in matches) {
            print('🖼️ Found image src: ${match.group(1)}');
          }
        }
      } else {
        setState(() {
          _errorMessage = '文章不存在。';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '載入文章失敗: $e';
        _isLoading = false;
      });
    }
  }



  String _getGoogleMapsUrl(GeoPoint geoPoint) {
    return 'https://www.google.com/maps/search/?api=1&query=${geoPoint.latitude},${geoPoint.longitude}';
  }

  @override
  Widget build(BuildContext context) {
    // 獲取當前螢幕的寬度，作為圖片的最大寬度參考
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文章詳情'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _articleData?['title'] ?? '無標題',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _articleData?['placeName'] ?? '',
              style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
            ),
            if (_articleData?['address'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _articleData!['address'],
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            if (_articleData?['location'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.map, size: 20),
                  label: const Text('在地圖上查看'),
                  onPressed: () async {
                    final GeoPoint geoPoint = _articleData!['location'];
                    final url = _getGoogleMapsUrl(geoPoint);
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('無法打開地圖連結')),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
            if (_articleData?['thumbnailImageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: CachedNetworkImage(
                  imageUrl: _articleData!['thumbnailImageUrl'],
                  placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image, size: 100),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Html(
              data: _articleData?['content'], // ✅ 用解碼後內容
              extensions: [
                TagExtension(
                  tagsToExtend: {"p", "div"},
                  builder: (extensionContext) {
                    final element = extensionContext.element;

                    if (element == null) return const SizedBox.shrink();

                    // 取得該節點下的所有 <img>
                    final children = element.children
                        .where((child) => child.localName == 'img')
                        .toList();

                    // 🔹 沒圖片就交還原樣 HTML（這樣文字仍能顯示）
                    if (children.isEmpty) {
                      return Text(element.text ?? '',
                          style: const TextStyle(fontSize: 16, color: Colors.black87));
                    }

                    // 🔹 多張圖片 → 可橫向滑動
                    if (children.length > 1) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: children.map((child) {
                            final imageUrl = child.attributes['src'];
                            final styleAttr = child.attributes['style'] ?? '';

                            double? widthFactor;
                            double? fixedWidth;

                            final match =
                            RegExp(r'width:\s*([0-9.]+)(px|%)').firstMatch(styleAttr);
                            if (match != null) {
                              final value = double.tryParse(match.group(1)!);
                              final unit = match.group(2);
                              if (value != null) {
                                if (unit == '%') {
                                  widthFactor = value / 100;
                                } else if (unit == 'px') {
                                  fixedWidth = value;
                                }
                              }
                            }

                            final screenWidth =
                                MediaQuery.of(extensionContext.buildContext!).size.width;
                            final finalWidth = fixedWidth ??
                                (widthFactor != null ? screenWidth * widthFactor : 150);

                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl ?? '',
                                width: finalWidth.clamp(50, screenWidth - 32),
                                fit: BoxFit.contain,
                                placeholder: (ctx, url) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (ctx, url, error) =>
                                const Icon(Icons.broken_image, size: 60),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }

                    // 🔹 單張圖片 → 置中顯示
                    else {
                      final img = children.first;
                      final imageUrl = img.attributes['src'];
                      final styleAttr = img.attributes['style'] ?? '';

                      double? widthFactor;
                      double? fixedWidth;

                      final match =
                      RegExp(r'width:\s*([0-9.]+)(px|%)').firstMatch(styleAttr);
                      if (match != null) {
                        final value = double.tryParse(match.group(1)!);
                        final unit = match.group(2);
                        if (value != null) {
                          if (unit == '%') {
                            widthFactor = value / 100;
                          } else if (unit == 'px') {
                            fixedWidth = value;
                          }
                        }
                      }

                      final screenWidth =
                          MediaQuery.of(extensionContext.buildContext!).size.width;
                      final finalWidth = fixedWidth ??
                          (widthFactor != null ? screenWidth * widthFactor : screenWidth * 0.9);

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl ?? '',
                            width: finalWidth.clamp(100, screenWidth - 32),
                            fit: BoxFit.contain,
                            placeholder: (ctx, url) =>
                            const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (ctx, url, error) =>
                            const Icon(Icons.broken_image, size: 80),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],

            ),
            const SizedBox(height: 20),
            Text(
              '作者: ${_articleData?['authorUid'] ?? '未知'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '更新時間: ${(_articleData?['updatedAt'] as Timestamp?)?.toDate().toLocal().toString().split('.')[0] ?? '未知'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}