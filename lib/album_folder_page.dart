import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'album_page.dart'; // 引入你的 AlbumPage

class AlbumFolderPage extends StatefulWidget {
  final bool isPickingImage; // 新增：是否處於圖片選擇模式

  const AlbumFolderPage({super.key, this.isPickingImage = false});

  @override
  State<AlbumFolderPage> createState() => _AlbumFolderPageState();
}

class _AlbumFolderPageState extends State<AlbumFolderPage> {
  Set<String> _selectedAlbumIds = {};
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
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
            final storageRef = FirebaseStorage.instance
                .ref()
                .child(storagePath);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除${albumsToDelete.length}個相簿及其相片')),
    );
  }

  // 修改：此方法現在直接導航到 AlbumPage
  // 當 AlbumPage 返回結果時，AlbumFolderPage 將其傳遞給調用者 (EditArticlePage)
  Future<void> _selectImageFromAlbum(String albumId, String albumName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumPage(
          albumId: albumId,
          albumName: albumName,
          isPickingImage: true, // 進入 AlbumPage 時也設為圖片選擇模式
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      // 如果 AlbumPage 返回了一張圖片，就將其返回給調用者 (EditArticlePage)
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isPickingImage ? '選擇圖片' : '我的相簿')),
        body: const Center(child: Text('請先登入')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPickingImage ? '選擇相簿中的圖片作為縮圖' : '我的相簿'),
        actions: [
          // 只有在非選擇模式下才顯示刪除和新增相簿按鈕
          if (!widget.isPickingImage && _selectedAlbumIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                // 需要從 StreamBuilder 獲取最新的 docs 列表
                // 目前這個 onPressed 沒有直接的 docs 參數，你可能需要將 StreamBuilder 提取或使用更高級的狀態管理
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請長按選擇相簿後，點擊刪除按鈕上方才會出現確認對話框。')),
                );
              },
              tooltip: '刪除選取的相簿',
            ),
          if (!widget.isPickingImage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // TODO: 新增相簿的邏輯
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('新增相簿功能待實現')),
                );
              },
              tooltip: '新增相簿',
            ),
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
            return const Center(child: Text('您還沒有任何相簿。'));
          }

          final albums = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1, // 正方形的網格
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumDoc = albums[index];
              final albumId = albumDoc.id;
              final data = albumDoc.data() as Map<String, dynamic>;
              final albumTitle = data['title'] ?? '無標題相簿';
              final coverPhotoUrl = data['coverUrl'] ?? ''; // 使用 coverUrl 字段
              final isSelected = _selectedAlbumIds.contains(albumId);

              return GestureDetector(
                onTap: () {
                  if (widget.isPickingImage) {
                    _selectImageFromAlbum(albumId, albumTitle); // 選擇模式下，進入相簿選擇圖片
                  } else {
                    // 非選擇模式下，進入相簿查看圖片
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumPage(
                          albumId: albumId,
                          albumName: albumTitle,
                          isPickingImage: false,
                        ),
                      ),
                    );
                  }
                },
                onLongPress: !widget.isPickingImage // 選擇模式下禁用長按
                    ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedAlbumIds.remove(albumId);
                    } else {
                      _selectedAlbumIds.add(albumId);
                    }
                  });
                  // 在長按選中相簿時，再次檢查是否有選中的相簿來顯示刪除按鈕
                  // 這是一個暫時的解決方案，更好的方式是將刪除邏輯移入 StreamBuilder 內部
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
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除')),
                                ],
                              ),
                            );
                            if (isConfirm == true) {
                              await _deleteSelectedAlbums(albums); // 傳遞完整的 albums 列表
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
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
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
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.blue,
                              size: 24,
                            ),
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