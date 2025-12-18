// lib/pages/travel_route_collection_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 記得引入這個

import '../models/travel_route_collection.dart';
import 'create_edit_collection_page.dart';
import 'travel_route_map_page.dart';

class TravelRouteCollectionPage extends StatefulWidget {
  final bool embedded;

  const TravelRouteCollectionPage({super.key, this.embedded = false});

  @override
  State<TravelRouteCollectionPage> createState() => _TravelRouteCollectionPageState();
}

class _TravelRouteCollectionPageState extends State<TravelRouteCollectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 進入創建新集合頁面
  Future<void> _navigateToCreateCollection() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能創建行程集合。')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateEditCollectionPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('行程集合')),
        body: const Center(child: Text('請登入以管理您的行程集合。')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('我的行程集合'),

        // 🔥 修改這裡：
        // 如果是嵌入模式 (embedded 為 true)，就不顯示返回鍵 (!true = false)
        // 如果不是嵌入模式 (embedded 為 false)，就自動顯示返回鍵 (!false = true)
        automaticallyImplyLeading: !widget.embedded,

        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreateCollection,
            tooltip: '創建新行程集合',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('travelRouteCollections')
            .where('ownerUid', isEqualTo: currentUser.uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('載入行程集合失敗: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<TravelRouteCollection> collections = snapshot.data!.docs
              .map((doc) => TravelRouteCollection.fromFirestore(doc))
              .toList();

          if (collections.isEmpty) {
            return const Center(child: Text('您還沒有創建任何行程集合。點擊右上角加號創建。'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return _CollectionCard(
                collection: collection,
                firestore: _firestore,
                context: context,
              );
            },
          );
        },
      ),
    );
  }
}

// 獨立出來的卡片組件，處理個別的 UI 和邏輯
class _CollectionCard extends StatelessWidget {
  final TravelRouteCollection collection;
  final FirebaseFirestore firestore;
  final BuildContext context;

  const _CollectionCard({
    required this.collection,
    required this.firestore,
    required this.context,
  });

  // 切換公開狀態
  Future<void> _togglePublicStatus(bool currentValue) async {
    try {
      await firestore
          .collection('travelRouteCollections')
          .doc(collection.id)
          .update({'isPublic': !currentValue});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentValue ? '已設為私人行程' : '已公開行程集合'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新狀態失敗: $e')),
      );
    }
  }

  // 刪除集合
  Future<void> _deleteCollection() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('您確定要刪除行程集合 "${collection.name}" 嗎？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('刪除', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestore.collection('travelRouteCollections').doc(collection.id).delete();
      } catch (e) {
        print("Error deleting collection: $e");
      }
    }
  }

  // 編輯集合
  void _navigateToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditCollectionPage(collection: collection),
      ),
    );
  }

  // 點擊卡片進入地圖
  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelRouteMapPage(initialCollectionId: collection.id),
      ),
    );
  }

  // 獲取第一篇文章的縮圖 URL
  Future<String?> _getFirstArticleThumbnail() async {
    if (collection.articleIds.isEmpty) return null;

    try {
      // 讀取集合中的第一個 article ID
      String firstArticleId = collection.articleIds.first;
      DocumentSnapshot doc = await firestore.collection('articles').doc(firstArticleId).get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['thumbnailImageUrl'] as String?;
      }
    } catch (e) {
      print("Error fetching thumbnail: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // 確保圖片切圓角
      child: InkWell(
        onTap: _navigateToMap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 圖片區域 (使用 FutureBuilder 動態加載第一張圖)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: FutureBuilder<String?>(
                future: _getFirstArticleThumbnail(),
                builder: (context, snapshot) {
                  // 背景容器樣式
                  Widget imageContainer(Widget child) {
                    return Container(
                      color: Colors.grey[300],
                      width: double.infinity,
                      height: double.infinity,
                      child: child,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return imageContainer(const Center(child: CircularProgressIndicator()));
                  }

                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: snapshot.data!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                        ),
                        // 漸層遮罩，讓文字更清晰
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        // 圖片左下角的標題
                        Positioned(
                          left: 16,
                          bottom: 12,
                          right: 16,
                          child: Text(
                            collection.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 沒有圖片或沒有文章時的默認樣式
                    return Container(
                      color: Colors.blueGrey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: Colors.blueGrey[400]),
                          const SizedBox(height: 8),
                          Text(
                            collection.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),

            // 2. 資訊與操作區域
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  // 左側資訊：文章數量
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${collection.articleIds.length} 個景點',
                    style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),

                  const Spacer(), // 撐開空間

                  // 公開開關
                  Row(
                    children: [
                      Text(
                        collection.isPublic ? "公開" : "私密",
                        style: TextStyle(
                          fontSize: 12,
                          color: collection.isPublic ? Colors.blue : Colors.grey,
                        ),
                      ),
                      Switch(
                        value: collection.isPublic,
                        onChanged: (_) => _togglePublicStatus(collection.isPublic),
                        activeColor: Colors.blueAccent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 縮小點擊區域
                      ),
                    ],
                  ),

                  // 編輯按鈕
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    color: Colors.grey[700],
                    onPressed: _navigateToEdit,
                    tooltip: '編輯集合',
                  ),

                  // 刪除按鈕
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red[300],
                    onPressed: _deleteCollection,
                    tooltip: '刪除集合',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}