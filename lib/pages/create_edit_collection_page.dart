// lib/pages/create_edit_collection_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/travel_article_data.dart';
import '../models/travel_route_collection.dart';
import '../article_detail_page.dart';

class CreateEditCollectionPage extends StatefulWidget {
  final TravelRouteCollection? collection;

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
  List<String> _selectedArticleIds = [];
  bool _isLoadingArticles = true;
  bool _isPublic = false;

  String _currentUserName = '未知用戶'; // 用於保存當前用戶的名稱

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile(); // 在載入文章前先載入用戶資料
    if (widget.collection != null) {
      _nameController.text = widget.collection!.name;
      _selectedArticleIds = List.from(widget.collection!.articleIds);
      _isPublic = widget.collection!.isPublic;
    }
    _loadAllUserArticles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 載入當前用戶的名稱，用於創建集合時設置 ownerName
  Future<void> _loadCurrentUserProfile() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      // 從 Firestore 的 'users' 集合中獲取用戶文檔
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        setState(() {
          // 從用戶文檔中讀取 displayName，如果不存在則使用 '未知用戶'
          _currentUserName = userDoc['displayName'] ?? '未知用戶';
        });
      } else {
        // 如果用戶文檔不存在，但有 FirebaseAuth 用戶，也可以嘗試從 FirebaseAuth 獲取
        setState(() {
          _currentUserName = currentUser.displayName ?? '未知用戶';
        });
      }
    }
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
          .where('authorUid', isEqualTo: currentUser.uid)
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
          articleIds: _selectedArticleIds,
          ownerUid: currentUser.uid,
          ownerName: _currentUserName, // 在這裡使用獲取到的用戶名稱
          isPublic: _isPublic,
        );
        await _firestore.collection('travelRouteCollections').add(newCollection.toFirestore());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行程集合 "$name" 已創建。')),
        );
      } else {
        // 編輯現有集合
        widget.collection!.name = name;
        widget.collection!.articleIds = _selectedArticleIds;
        widget.collection!.updatedAt = DateTime.now();
        widget.collection!.isPublic = _isPublic;

        await _firestore.collection('travelRouteCollections').doc(widget.collection!.id).update(widget.collection!.toFirestore());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行程集合 "$name" 已更新。')),
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      print("Error saving collection: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存行程集合失敗: $e')),
      );
    }
  }

  void _toggleArticleSelection(TravelArticleData article) {
    if (article.id == null) return;

    setState(() {
      final isSelected = _selectedArticleIds.contains(article.id!);
      if (isSelected) {
        _selectedArticleIds.remove(article.id!);
      } else {
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
              child: Column(
                children: [
                  TextFormField(
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
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('公開行程集合'),
                    subtitle: const Text('開啟後，其他讀者將能在行程瀏覽頁面看到此集合'),
                    value: _isPublic,
                    onChanged: (bool value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                    secondary: const Icon(Icons.public),
                  ),
                ],
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
                final int selectedOrder = isSelected ? _selectedArticleIds.indexOf(article.id!) + 1 : -1;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected ? const BorderSide(color: Colors.blueAccent, width: 2) : BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => _toggleArticleSelection(article),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                          Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              _toggleArticleSelection(article);
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