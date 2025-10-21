// lib/album_folder_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'album_page.dart'; // 引入你的 AlbumPage

class AlbumFolderPage extends StatefulWidget {
  final bool isPickingImage;
  final bool embedded;
  final bool allowMultiple;

  const AlbumFolderPage({
    super.key,
    this.isPickingImage = false,
    this.embedded = false,
    this.allowMultiple = false,
  });

  @override
  State<AlbumFolderPage> createState() => _AlbumFolderPageState();
}

class _AlbumFolderPageState extends State<AlbumFolderPage> {
  Set<String> _selectedAlbumIds = {};
  User? _currentUser;
  final TextEditingController _newAlbumNameController = TextEditingController(); // 新增：用於新增相簿名稱

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _newAlbumNameController.dispose(); // 釋放控制器
    super.dispose();
  }

  Future<void> _createAlbum() async {
    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能建立相簿')),
      );
      return;
    }

    final albumName = _newAlbumNameController.text.trim();
    if (albumName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相簿名稱不能為空')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('albums').add({
        'title': albumName,
        'ownerUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'photoCount': 0,
        // 'coverUrl': null, // 初始沒有封面圖，可以不設定或設為 null
      });

      _newAlbumNameController.clear(); // 清空輸入框
      if (!mounted) return;
      Navigator.of(context).pop(); // 關閉對話框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('相簿 "$albumName" 已建立！')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('建立相簿失敗: $e')),
      );
    }
  }

  // 顯示新增相簿的對話框
  void _showCreateAlbumDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增相簿'),
          content: TextField(
            controller: _newAlbumNameController,
            decoration: const InputDecoration(
              hintText: '輸入相簿名稱',
            ),
            autofocus: true, // 自動聚焦
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newAlbumNameController.clear(); // 清空輸入框
                Navigator.of(context).pop(); // 關閉對話框
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: _createAlbum,
              child: const Text('建立'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedAlbums(List<QueryDocumentSnapshot> docs) async {
    final user = _currentUser;
    if (user == null) return;

    final albumsToDelete = docs.where((doc) => _selectedAlbumIds.contains(doc.id)).toList();

    for (final albumDoc in albumsToDelete) {
      final albumId = albumDoc.id;

      // 刪除相簿底下所有照片（Firestore 與 Storage）
      final photosSnap = await FirebaseFirestore.instance
          .collection('photos')
          .where('albumId', isEqualTo: albumId)
          .where('ownerUid', isEqualTo: user.uid)
          .get();

      for (final photoDoc in photosSnap.docs) {
        final data = photoDoc.data();
        final storagePath = data['storagePath'] as String?;
        try {
          if (storagePath != null) {
            final storageRef = FirebaseStorage.instance.ref().child(storagePath);
            await storageRef.delete();
          }
        } catch (_) {
          // 允許 Storage 沒有檔案
        }
        await FirebaseFirestore.instance.collection('photos').doc(photoDoc.id).delete();
      }

      // 刪除相簿本身
      await FirebaseFirestore.instance.collection('albums').doc(albumId).delete();
    }

    setState(() {
      _selectedAlbumIds.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除${albumsToDelete.length}個相簿及其相片')),
    );
  }

  Future<void> _navigateToAlbumAndPick(String albumId, String albumName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumPage(
          albumId: albumId,
          albumName: albumName,
          isPickingImage: widget.isPickingImage,
          allowMultiple: widget.allowMultiple,
        ),
      ),
    );

    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isPickingImage ? '選擇圖片' : '我的相簿'),
          automaticallyImplyLeading: !widget.embedded,
        ),
        body: const Center(child: Text('請先登入')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPickingImage
            ? (widget.allowMultiple ? '選擇素材圖片' : '選擇縮圖')
            : '我的相簿'),
        automaticallyImplyLeading: !widget.embedded,
        actions: [
          // 只有在非選擇模式下才顯示刪除/新增按鈕
          if (!widget.isPickingImage) ...[
            if (_selectedAlbumIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: '刪除選取的相簿',
                onPressed: () {
                  // 這個 action 需要 albums 列表，實際刪除交給底下 StreamBuilder 內的浮動條來做
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('長按選擇相簿後，請在畫面下方的刪除提示中確認刪除。')),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新增相簿',
              onPressed: _showCreateAlbumDialog, // 調用新增相簿對話框
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('albums')
            .where('ownerUid', isEqualTo: _currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('載入相簿失敗: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('您還沒有任何相簿。'),
                  if (!widget.isPickingImage) // 非選擇模式下才顯示新增相簿的提示或按鈕
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: _showCreateAlbumDialog,
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text('建立第一個相簿'),
                      ),
                    ),
                ],
              ),
            );
          }

          final albums = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumDoc = albums[index];
              final albumId = albumDoc.id;
              final data = albumDoc.data() as Map<String, dynamic>;
              final albumTitle = data['title'] ?? '無標題相簿';
              final coverPhotoUrl = data['coverUrl'] ?? '';
              final isSelected = _selectedAlbumIds.contains(albumId);

              return GestureDetector(
                onTap: () {
                  if (widget.isPickingImage) {
                    _navigateToAlbumAndPick(albumId, albumTitle);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumPage(
                          albumId: albumId,
                          albumName: albumTitle,
                          isPickingImage: false,
                          allowMultiple: false,
                        ),
                      ),
                    );
                  }
                },
                onLongPress: !widget.isPickingImage
                    ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedAlbumIds.remove(albumId);
                    } else {
                      _selectedAlbumIds.add(albumId);
                    }
                  });

                  if (_selectedAlbumIds.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已選取 ${_selectedAlbumIds.length} 個相簿'),
                        action: SnackBarAction(
                          label: '刪除',
                          onPressed: () async {
                            final isConfirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('刪除相簿'),
                                content: Text('確定要刪除選取的${_selectedAlbumIds.length}個相簿及其所有照片嗎？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('刪除'),
                                  ),
                                ],
                              ),
                            );
                            if (isConfirm == true) {
                              await _deleteSelectedAlbums(albums);
                            }
                          },
                        ),
                      ),
                    );
                  }
                }
                    : null,
                child: Card(
                  elevation: isSelected ? 8 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? const BorderSide(color: Colors.blue, width: 3)
                        : BorderSide.none,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverPhotoUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: coverPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder, size: 60, color: Colors.grey),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          color: Colors.black54,
                          child: Text(
                            albumTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
                          ),
                        ),
                    ],
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