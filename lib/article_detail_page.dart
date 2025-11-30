import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ 1. 引入 Auth
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // ✅ 2. 新增狀態變數
  User? _currentUser;
  bool _isLiked = false;
  bool _isBookmarked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser; // 獲取當前用戶
    _fetchArticleDetails();
    _checkUserInteractionStatus(); // 檢查用戶是否已點讚或收藏
  }

  // ✅ 3. 檢查用戶互動狀態 (點讚/收藏)
  Future<void> _checkUserInteractionStatus() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final List<dynamic> likedArticles = data['likedArticles'] ?? [];
        final List<dynamic> bookmarkedArticles = data['bookmarkedArticles'] ?? [];

        if (mounted) {
          setState(() {
            _isLiked = likedArticles.contains(widget.articleId);
            _isBookmarked = bookmarkedArticles.contains(widget.articleId);
          });
        }
      }
    } catch (e) {
      print("Error checking interaction status: $e");
    }
  }

  Future<void> _fetchArticleDetails() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('articles')
          .doc(widget.articleId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();

        // 🔹 解碼 HTML
        final unescape = HtmlUnescape();
        final htmlContentRaw = data?['content'] ?? '';
        final htmlContent = unescape.convert(htmlContentRaw);

        setState(() {
          _articleData = {...data!, 'content': htmlContent};
          _likesCount = data?['likesCount'] ?? 0; // ✅ 獲取文章目前的讚數
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
    }
  }

  // ✅ 4. 實作點讚邏輯
  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能點讚')));
      return;
    }

    // 樂觀更新 UI (Optimistic UI Update)
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
    final articleRef = FirebaseFirestore.instance.collection('articles').doc(widget.articleId);

    try {
      if (_isLiked) {
        // 加讚
        await userRef.update({'likedArticles': FieldValue.arrayUnion([widget.articleId])});
        await articleRef.update({'likesCount': FieldValue.increment(1)});
      } else {
        // 收回讚
        await userRef.update({'likedArticles': FieldValue.arrayRemove([widget.articleId])});
        await articleRef.update({'likesCount': FieldValue.increment(-1)});
      }
    } catch (e) {
      // 如果失敗，回滾 UI
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
    }
  }

  // ✅ 5. 實作收藏邏輯
  Future<void> _toggleBookmark() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能收藏')));
      return;
    }

    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);

    try {
      if (_isBookmarked) {
        await userRef.update({'bookmarkedArticles': FieldValue.arrayUnion([widget.articleId])});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入收藏')));
      } else {
        await userRef.update({'bookmarkedArticles': FieldValue.arrayRemove([widget.articleId])});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消收藏')));
      }
    } catch (e) {
      setState(() {
        _isBookmarked = !_isBookmarked;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
    }
  }

  String _getGoogleMapsUrl(GeoPoint geoPoint) {
    return 'https://www.google.com/maps/search/?api=1&query=${geoPoint.latitude},${geoPoint.longitude}';
  }

  @override
  Widget build(BuildContext context) {
    // 獲取當前螢幕的寬度
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文章詳情'),
        actions: [
          // 也可以把收藏放在 AppBar 右上角
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.blue : null,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
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

            // ✅ 6. UI 更新：加入地圖按鈕與點讚按鈕的 Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  if (_articleData?['location'] != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map, size: 20),
                        label: const Text('查看地圖'),
                        onPressed: () async {
                          final GeoPoint geoPoint = _articleData!['location'];
                          final url = _getGoogleMapsUrl(geoPoint);
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                          } else {
                            if(mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('無法打開地圖連結')),
                            );
                          }
                        },
                      ),
                    ),
                  const SizedBox(width: 12),
                  // 點讚按鈕
                  InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isLiked ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _isLiked ? Colors.blue : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color: _isLiked ? Colors.blue : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_likesCount',
                            style: TextStyle(
                              color: _isLiked ? Colors.blue : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

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
              data: _articleData?['content'],
              extensions: [
                // ... (HTML extensions 保持原本的圖片處理邏輯不變)
                TagExtension(
                  tagsToExtend: {"p", "div"},
                  builder: (extensionContext) {
                    final element = extensionContext.element;

                    if (element == null) return const SizedBox.shrink();

                    final children = element.children
                        .where((child) => child.localName == 'img')
                        .toList();

                    if (children.isEmpty) {
                      return Text(element.text ?? '',
                          style: const TextStyle(fontSize: 16, color: Colors.black87));
                    }

                    // 處理圖片顯示邏輯 (與原本程式碼相同)
                    if (children.length > 1) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: children.map((child) {
                            final imageUrl = child.attributes['src'];
                            // ... (簡化，保持原本邏輯即可)
                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl ?? '',
                                width: 150, // 簡化示意，請保留原本的寬度計算
                                fit: BoxFit.contain,
                                placeholder: (ctx, url) => const CircularProgressIndicator(),
                                errorWidget: (ctx, url, error) => const Icon(Icons.broken_image),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    } else {
                      // 單張圖片邏輯
                      final img = children.first;
                      final imageUrl = img.attributes['src'];
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl ?? '',
                            fit: BoxFit.contain,
                            placeholder: (ctx, url) => const CircularProgressIndicator(),
                            errorWidget: (ctx, url, error) => const Icon(Icons.broken_image),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 底部作者資訊
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              // 如果你有作者頭像URL，可以用 CircleAvatar
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                _articleData?['authorName'] ?? _articleData?['authorUid'] ?? '未知作者', // 嘗試顯示名字
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '更新於: ${(_articleData?['updatedAt'] as Timestamp?)?.toDate().toLocal().toString().split('.')[0] ?? '未知'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}