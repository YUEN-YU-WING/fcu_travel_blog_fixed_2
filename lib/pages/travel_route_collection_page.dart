// lib/pages/travel_route_collection_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/travel_route_collection.dart';
import 'create_edit_collection_page.dart'; // 引入新的創建/編輯頁面
import 'travel_route_map_page.dart';

// 行程集合管理頁面
class TravelRouteCollectionPage extends StatefulWidget {
  const TravelRouteCollectionPage({super.key});

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

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateEditCollectionPage(), // 不傳入 collection，表示創建
      ),
    );

    // 如果 CreateEditCollectionPage 返回了 true，表示有新的集合被創建或更新，可以考慮刷新列表
    if (result == true) {
      setState(() {
        // 觸發 StreamBuilder 重新構建，或刷新狀態
      });
    }
  }

  // 進入編輯現有集合頁面
  Future<void> _navigateToEditCollection(TravelRouteCollection collection) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能編輯行程集合。')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditCollectionPage(collection: collection), // 傳入 collection，表示編輯
      ),
    );

    if (result == true) {
      setState(() {
        // 觸發 StreamBuilder 重新構建，或刷新狀態
      });
    }
  }

  Future<void> _deleteCollection(String collectionId, String collectionName) async {
    // 詢問用戶是否確認刪除
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('您確定要刪除行程集合 "$collectionName" 嗎？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('刪除', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _firestore.collection('travelRouteCollections').doc(collectionId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行程集合 "$collectionName" 已刪除。')),
        );
      } catch (e) {
        print("Error deleting collection: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除行程集合失敗: $e')),
        );
      }
    }
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
      appBar: AppBar(
        title: const Text('行程集合'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreateCollection, // 導航到創建頁面
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
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  title: Text(collection.name),
                  subtitle: Text('${collection.articleIds.length} 篇遊記'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _navigateToEditCollection(collection), // 導航到編輯頁面
                        tooltip: '編輯集合',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                        onPressed: () => _deleteCollection(collection.id!, collection.name),
                        tooltip: '刪除集合',
                      ),
                    ],
                  ),
                  onTap: () {
                    // *** 這裡進行修改 ***
                    // 直接導航到 TravelRouteMapPage，並將 collection.id 作為 initialCollectionId 傳遞
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TravelRouteMapPage(initialCollectionId: collection.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}