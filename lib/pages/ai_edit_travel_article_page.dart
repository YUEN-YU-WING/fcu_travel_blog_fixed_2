// lib/pages/ai_edit_travel_article_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/travel_article_data.dart';
import '../services/article_service.dart'; // 假設你有一個文章服務用於保存
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
    // 嘗試從 HTML 內容中提取 H1 作為標題
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
    setState(() {
      _isSaving = true;
    });

    try {
      // 更新 articleData 的內容和標題
      widget.articleData.generatedHtmlContent = _htmlContentController.text;
      widget.articleData.title = _titleController.text;

      // 假設你有一個 ArticleService 來保存文章到 Firestore
      // 注意：這裡只保存 AI 生成的部分，如果需要保存所有步驟的數據，調整 ArticleService
      await ArticleService.saveArticle({
        'title': widget.articleData.title,
        'placeName': widget.articleData.placeName,
        'address': widget.articleData.address,
        'location': widget.articleData.location,
        'thumbnailImageUrl': widget.articleData.thumbnailUrl,
        'content': widget.articleData.generatedHtmlContent,
        'materialImageUrls': widget.articleData.materialImageUrls, // 也保存素材圖片列表
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'authorUid': 'current_user_id', // 替換為實際的用戶 UID
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文章已保存！')),
      );
      // 保存成功後，返回主頁面或文章列表
      Navigator.popUntil(context, (route) => route.isFirst); // 返回到根路由
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
            // 預覽頁面
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
                    data: _htmlContentController.text, // 顯示編輯器中的內容
                    style: {
                      "body": Style(fontSize: FontSize(16), margin: Margins.all(0)),
                      "p": Style(margin: Margins.only(bottom: 8)),
                      "img": Style(
                        width: Width(100, Unit.percent),
                        height: Height.auto(),
                        display: Display.block,
                        margin: Margins.only(top: 10, bottom: 10), // 為圖片添加一些外邊距
                      ),
                    },
                    extensions: [
                      TagExtension(
                        tagsToExtend: {"img"},
                        builder: (extensionContext) {
                          final String? imageUrl = extensionContext.attributes['src'];
                          if (imageUrl != null && imageUrl.isNotEmpty) {
                            return CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: MediaQuery.of(extensionContext.buildContext!).size.width,
                              height: null, // 讓高度自動適應
                              fit: BoxFit.contain,
                              placeholder: (ctx, url) => const CircularProgressIndicator(),
                              errorWidget: (ctx, url, error) {
                                print('Error loading image in Html preview: $url, Error: $error');
                                return Container(
                                  height: 50,
                                  width: MediaQuery.of(extensionContext.buildContext!).size.width,
                                  color: Colors.red[100],
                                  alignment: Alignment.center,
                                  child: const Text('圖片載入失敗', style: TextStyle(color: Colors.red, fontSize: 12)),
                                );
                              },
                            );
                          }
                          return const SizedBox.shrink(); // 無效圖片不顯示
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
            // 編輯 HTML 頁面
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _htmlContentController,
                maxLines: null, // 允許無限行
                expands: true, // 填滿可用空間
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