// lib/pages/browse_collections_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/travel_route_collection.dart';
import '../article_detail_page.dart'; // 可能需要導航到集合中的文章詳情頁
//import 'collection_detail_page.dart'; // 稍後創建的集合詳情頁面

class BrowseCollectionsPage extends StatefulWidget {
  const BrowseCollectionsPage({super.key});

  @override
  State<BrowseCollectionsPage> createState() => _BrowseCollectionsPageState();
}

class _BrowseCollectionsPageState extends State<BrowseCollectionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('瀏覽行程集合'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('travelRouteCollections')
            .where('isPublic', isEqualTo: true) // 只查詢公開的集合
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('載入行程集合失敗: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('目前沒有公開的行程集合。'));
          }

          final collections = snapshot.data!.docs
              .map((doc) => TravelRouteCollection.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              // 為了簡化，我們這裡只顯示集合名稱和擁有者
              // 如果要顯示集合中第一篇文章的縮圖，需要額外查詢或在 TravelRouteCollection 中保存第一篇文章的 ID 和縮圖 URL
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: InkWell(
                  onTap: () {
                    // TODO: 導航到集合詳情頁面 (CollectionDetailPage)
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => CollectionDetailPage(collectionId: collection.id!),
                    //   ),
                    // );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '由 ${collection.ownerName} 創建',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '包含 ${collection.articleIds.length} 篇遊記',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                        // 如果需要顯示集合縮圖，這裡可以加 Image.network
                        // 例如，如果 collection.articleIds 不為空，可以取第一篇遊記的縮圖
                        // 這需要你在 TravelRouteCollection 中額外存儲或在這裡進行嵌套查詢
                        // if (collection.articleIds.isNotEmpty)
                        //   FutureBuilder<DocumentSnapshot>(
                        //     future: _firestore.collection('articles').doc(collection.articleIds.first).get(),
                        //     builder: (context, articleSnapshot) {
                        //       if (articleSnapshot.hasData && articleSnapshot.data!.exists) {
                        //         final articleData = articleSnapshot.data!.data() as Map<String, dynamic>;
                        //         final thumbnailUrl = articleData['thumbnailImageUrl'] as String?;
                        //         if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                        //           return Padding(
                        //             padding: const EdgeInsets.only(top: 12.0),
                        //             child: ClipRRect(
                        //               borderRadius: BorderRadius.circular(8.0),
                        //               child: CachedNetworkImage(
                        //                 imageUrl: thumbnailUrl,
                        //                 height: 150,
                        //                 width: double.infinity,
                        //                 fit: BoxFit.cover,
                        //                 placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        //                 errorWidget: (context, url, error) => const Icon(Icons.error),
                        //               ),
                        //             ),
                        //           );
                        //         }
                        //       }
                        //       return const SizedBox.shrink();
                        //     },
                        //   ),
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