import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_html/flutter_html.dart'; // 引入 flutter_html
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // 用於處理連結點擊
import 'package:html/dom.dart' as dom; // 引入 html/dom.dart 以使用 dom.Element

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
        setState(() {
          _articleData = docSnapshot.data();
          _isLoading = false;
        });
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
      print('Error fetching article details: $e');
    }
  }

  // 輔助方法：將 GeoPoint 轉換為 Google Maps 連結
  String _getGoogleMapsUrl(GeoPoint geoPoint) {
    return 'https://www.google.com/maps/search/?api=1&query=${geoPoint.latitude},${geoPoint.longitude}';
  }

  @override
  Widget build(BuildContext context) {
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
            // --- 渲染 HTML 內容 ---
            Html(
              data: _articleData?['content'] ?? '', // 這裡傳入 HTML 字符串
              // --- 再次修正 onLinkTap 簽名 ---
              onLinkTap: (url, attributes, element) async { // 移除 renderContext
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('無法打開連結: $url')),
                  );
                }
              },
              style: {
                "body": Style(fontSize: FontSize(16)),
                "p": Style(margin: Margins.only(bottom: 8)),
                "img": Style(
                  width: Width(100, Unit.px),
                  height: Height.auto(),
                ),
              },
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