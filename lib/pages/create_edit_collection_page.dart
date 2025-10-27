// lib/pages/create_edit_collection_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/travel_article_data.dart';
import '../models/travel_route_collection.dart';
import '../article_detail_page.dart'; // 引入文章詳情頁面，可以在點擊時跳轉

class CreateEditCollectionPage extends StatefulWidget {
  final TravelRouteCollection? collection; // 如果傳入 collection，表示編輯模式

  const CreateEditCollectionPage({super.key, this.collection});

  @override
  State<CreateEditCollectionPage> createState() => _CreateEditCollectionPageState();
}

class _CreateEditCollectionPageState extends State<CreateEditCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<TravelArticleData> _allUserArticles = [];
  // _selectedArticleIds 的順序將決定顯示的數字順序
  List<String> _selectedArticleIds = [];
  bool _isLoadingArticles = true;

  @override
  void initState() {
    super.initState();
    if (widget.collection != null) {
      _nameController.text = widget.collection!.name;
      // 初始化時，如果編輯現有集合，直接從集合中獲取已選中的 ID
      _selectedArticleIds = List.from(widget.collection!.articleIds);
    }
    _loadAllUserArticles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUserArticles() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoadingArticles = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能管理遊記。')),
      );
      return;
    }

    try {
      final querySnapshot = await _firestore.collection('articles')
          .where('authorUid', isEqualTo: currentUser.uid) // 只查詢當前用戶的文章
          .orderBy('updatedAt', descending: true)
          .get();
      setState(() {
        _allUserArticles = querySnapshot.docs.map((doc) => TravelArticleData.fromFirestore(doc)).toList();
        _isLoadingArticles = false;
      });
    } catch (e) {
      print("Error loading all user articles: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入您的遊記失敗: $e')),
      );
      setState(() {
        _isLoadingArticles = false;
      });
    }
  }

  Future<void> _saveCollection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能保存行程集合。')),
      );
      return;
    }

    final String name = _nameController.text.trim();

    try {
      if (widget.collection == null) {
        // 創建新集合
        final newCollection = TravelRouteCollection(
          name: name,
          articleIds: _selectedArticleIds, // 使用 _selectedArticleIds 的順序
          ownerUid: currentUser.uid,
        );
        await _firestore.collection('travelRouteCollections').add(newCollection.toFirestore());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行程集合 "$name" 已創建。')),
        );
      } else {
        // 編輯現有集合
        widget.collection!.name = name;
        widget.collection!.articleIds = _selectedArticleIds; // 使用 _selectedArticleIds 的順序
        widget.collection!.updatedAt = DateTime.now();
        await _firestore.collection('travelRouteCollections').doc(widget.collection!.id).update(widget.collection!.toFirestore());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行程集合 "$name" 已更新。')),
        );
      }
      Navigator.of(context).pop(true); // 返回 true 表示操作成功
    } catch (e) {
      print("Error saving collection: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存行程集合失敗: $e')),
      );
    }
  }

  // 點擊遊記卡片時的處理邏輯
  void _toggleArticleSelection(TravelArticleData article) {
    if (article.id == null) return;

    setState(() {
      final isSelected = _selectedArticleIds.contains(article.id!);
      if (isSelected) {
        // 如果已經選中，則移除
        _selectedArticleIds.remove(article.id!);
      } else {
        // 如果未選中，則添加
        _selectedArticleIds.add(article.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection == null ? '創建新行程集合' : '編輯行程集合'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCollection,
            tooltip: '保存行程集合',
          ),
        ],
      ),
      body: _isLoadingArticles
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '行程集合名稱',
                  border: OutlineInputBorder(),
                  hintText: '例如：台中三天兩夜美食之旅',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '行程集合名稱不能為空';
                  }
                  return null;
                },
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '選擇遊記 (${_selectedArticleIds.length} 篇)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _allUserArticles.isEmpty
                ? const Center(child: Text('您目前沒有任何遊記可供選擇。'))
                : ListView.builder(
              itemCount: _allUserArticles.length,
              itemBuilder: (context, index) {
                final article = _allUserArticles[index];
                final bool isSelected = _selectedArticleIds.contains(article.id);
                // 獲取選中順序的索引，如果未選中則為 -1
                final int selectedOrder = isSelected ? _selectedArticleIds.indexOf(article.id!) + 1 : -1;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: isSelected ? 4 : 1, // 選中時提高陰影
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected ? const BorderSide(color: Colors.blueAccent, width: 2) : BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => _toggleArticleSelection(article), // 點擊卡片切換選中狀態
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 顯示縮略圖或默認圖標
                          if (article.thumbnailUrl != null && article.thumbnailUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: article.thumbnailUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image, size: 30, color: Colors.grey),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.title ?? article.placeName ?? '無標題遊記',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (article.placeName != null && article.placeName!.isNotEmpty)
                                  Text(
                                    article.placeName!,
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // 顯示順序數字標籤
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$selectedOrder',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          // Checkbox 保持不變，用於視覺確認
                          Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              _toggleArticleSelection(article); // 調用統一的切換方法
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}