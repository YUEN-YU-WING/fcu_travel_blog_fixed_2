// lib/search_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'article_detail_page.dart'; // 引入文章詳情頁面

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // 用於保存當前的搜尋關鍵字

  // 輔助函數：將 Timestamp 轉換為可讀的日期時間字符串
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜尋文章 (地點, 關鍵字...)',
            border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty // 只有當有輸入時才顯示清除按鈕
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            )
                : null,
          ),
          autofocus: true, // 自動獲取焦點
          onChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
          onSubmitted: (query) {
            // 當用戶提交搜尋時，可以觸發更精確的搜尋邏輯
            // 目前 onChanged 已經實時更新了 _searchQuery
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54), // 返回按鈕顏色
      ),
      body: _searchQuery.isEmpty
          ? const Center(child: Text('請輸入關鍵字進行搜尋'))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('articles')
            .where('isPublic', isEqualTo: true)
        // 這裡實現根據關鍵字搜尋的邏輯
        // 注意：Firestore 的 where 條件對於模糊匹配（包含某個子字串）是有限制的
        // 通常需要為每個關鍵字字段創建一個 arrayContains 或 arrayContainsAny 的索引
        // 或者使用第三方服務如 Algolia 或自己實現前綴匹配
        // 這裡為了演示，我們假設你可能有一個 'keywords' 數組字段或嘗試前綴匹配
        // 更常見的做法是：在後台將文章內容和關鍵字處理成一個數組，然後用 arrayContains
        // 假設我們想搜尋 title 或 content 包含關鍵字的文章
        // 這裡示範一個簡單的 startsWith 邏輯，但 Firestore 自身不支持完整的模糊搜索
        // 為了模擬，我們將查詢所有公開文章，然後在客戶端過濾 (只適用於數據量小的情況)
        // 對於實際的大數據量應用，你需要更優化的 Firestore 查詢設計。
        //
        // **更實際的 Firestore 關鍵字搜尋做法：**
        // 1. 在 Firestore 文件中添加一個 `searchKeywords` 數組字段，包含所有可搜尋的單詞。
        //    然後使用 `.where('searchKeywords', arrayContains: _searchQuery.toLowerCase())`
        // 2. 針對多個字段的模糊搜尋，通常需要像 Algolia 或 ElasticSearch 這樣的全文本搜尋服務。
        //
        // **這裡我們將使用一個簡單的 `startAt`/`endAt` 來進行前綴匹配，如果你的關鍵字是單一字段的前綴。**
        // **如果需要多字段模糊搜索，Firestore 本身比較難直接實現，可能需要上述的輔助字段或第三方服務。**
        //
        // 這裡我們先簡單示範，以 `title` 字段為例進行前綴匹配。
            .orderBy('address') // 前綴匹配需要排序字段
            .startAt([_searchQuery])
            .endAt(['$_searchQuery\uf8ff']) // \uf8ff 是一個 Unicode 字符，用於結束範圍
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('出錯了: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('沒有找到相關文章。'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot document = snapshot.data!.docs[index];
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              final String articleId = document.id;

              final String authorName = data['authorName'] ?? '匿名作者';
              final String title = data['title'] ?? '無標題';
              final String content = data['content'] ?? '沒有內容';
              final Timestamp updatedAt = data['updatedAt'] ?? Timestamp.now();
              final String thumbnailImageUrl = data['thumbnailImageUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 1.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailPage(articleId: articleId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顯示圖片 (可選)
                        if (thumbnailImageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              thumbnailImageUrl,
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                alignment: Alignment.center,
                                height: 150,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  alignment: Alignment.center,
                                  height: 150,
                                  color: Colors.grey[300],
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        if (thumbnailImageUrl.isNotEmpty) const SizedBox(height: 12.0),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '作者: $authorName • ${_formatTimestamp(updatedAt)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12.0),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          content,
                          style: const TextStyle(fontSize: 14.0),
                          maxLines: 2, // 搜尋結果顯示更簡短的內容
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}