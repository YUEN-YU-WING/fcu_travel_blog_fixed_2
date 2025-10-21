// lib/pages/ai_edit_travel_article_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- 引入 Firebase Auth
import '../models/travel_article_data.dart';
import '../services/article_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';


class AiEditTravelArticlePage extends StatefulWidget {
  final TravelArticleData articleData;

  const AiEditTravelArticlePage({super.key, required this.articleData});

  @override
  State<AiEditTravelArticlePage> createState() => _AiEditTravelArticlePageState();
}

class _AiEditTravelArticlePageState extends State<AiEditTravelArticlePage> {
  late TextEditingController _htmlContentController;
  late TextEditingController _titleController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _htmlContentController = TextEditingController(text: widget.articleData.generatedHtmlContent);
    String? suggestedTitle = _extractTitleFromHtml(widget.articleData.generatedHtmlContent);
    _titleController = TextEditingController(text: suggestedTitle ?? widget.articleData.placeName);
  }

  @override
  void dispose() {
    _htmlContentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String? _extractTitleFromHtml(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) return null;
    final RegExp titleRegExp = RegExp(r'<h1[^>]*>(.*?)<\/h1>', dotAll: true);
    final Match? match = titleRegExp.firstMatch(htmlContent);
    return match?.group(1)?.trim();
  }

  Future<void> _saveArticle() async {
    final user = FirebaseAuth.instance.currentUser; // <-- 獲取當前用戶
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能保存文章！')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      widget.articleData.generatedHtmlContent = _htmlContentController.text;
      widget.articleData.title = _titleController.text;

      await ArticleService.saveArticle({
        'title': widget.articleData.title,
        'placeName': widget.articleData.placeName,
        'address': widget.articleData.address,
        'location': widget.articleData.location,
        'thumbnailImageUrl': widget.articleData.thumbnailUrl,
        'content': widget.articleData.generatedHtmlContent,
        'materialImageUrls': widget.articleData.materialImageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'authorUid': user.uid, // <-- 使用實際的用戶 UID
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文章已保存！')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      print('Error saving article: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存文章失敗: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('編輯遊記'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '預覽'),
              Tab(text: '編輯 HTML'),
            ],
          ),
          actions: [
            _isSaving
                ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
                : IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveArticle,
              tooltip: '保存文章',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '文章標題',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Html(
                    data: _htmlContentController.text,
                    style: {
                      "body": Style(fontSize: FontSize(16), margin: Margins.all(0)),
                      "p": Style(margin: Margins.only(bottom: 8)),
                      "img": Style(
                        width: Width(100, Unit.percent),
                        height: Height.auto(),
                        display: Display.block,
                        margin: Margins.only(top: 10, bottom: 10),
                      ),
                    },
                    extensions: [
                      TagExtension(
                        tagsToExtend: {"img"},
                        builder: (extensionContext) {
                          final String? imageUrl = extensionContext.attributes['src'];
                          // 檢查 alt 屬性，如果存在，可以在這裡顯示
                          final String? altText = extensionContext.attributes['alt'];
                          print('Html preview image: $imageUrl, Alt: $altText'); // Debug 輸出

                          if (imageUrl != null && imageUrl.isNotEmpty) {
                            return Column( // 將圖片和可能的描述包裝在 Column 中
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: MediaQuery.of(extensionContext.buildContext!).size.width,
                                  height: null,
                                  fit: BoxFit.contain,
                                  placeholder: (ctx, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (ctx, url, error) {
                                    print('Error loading image in Html preview: $url, Error: $error');
                                    return Container(
                                      height: 150, // 增加高度以便錯誤信息顯示
                                      width: MediaQuery.of(extensionContext.buildContext!).size.width,
                                      color: Colors.red[100],
                                      alignment: Alignment.center,
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image, color: Colors.red, size: 30),
                                          SizedBox(height: 5),
                                          Text('圖片載入失敗', style: TextStyle(color: Colors.red, fontSize: 12)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (altText != null && altText.isNotEmpty) // 如果 alt 文本存在，顯示為圖片描述
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                    child: Text(
                                      altText,
                                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                                      textAlign: TextAlign.center, // Alt 文本居中
                                    ),
                                  ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                    onLinkTap: (url, attributes, element) async {
                      if (url != null && await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('無法打開連結: $url')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _htmlContentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '編輯 HTML 內容...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}