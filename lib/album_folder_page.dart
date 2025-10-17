// lib/album_folder_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'album_page.dart'; // 引入你的 AlbumPage

class AlbumFolderPage extends StatefulWidget {
  final bool isPickingImage;   // 是否在圖片選擇模式
  final bool embedded;         // 是否嵌入後台（嵌入時不顯示返回鍵）
  final bool allowMultiple;    // 是否允許選擇多張圖片 (此參數應該主要傳遞給 AlbumPage)

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

  // 修改：選相簿 → 進入 AlbumPage 選圖片；回傳後把結果 pop 回呼叫者
  Future<void> _navigateToAlbumAndPick(String albumId, String albumName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumPage(
          albumId: albumId,
          albumName: albumName,
          isPickingImage: widget.isPickingImage, // 傳遞選擇模式
          allowMultiple: widget.allowMultiple,   // 傳遞多選模式
        ),
      ),
    );

    // 如果 AlbumPage 有返回結果，就直接將結果 pop 回去
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
            : '我的相簿'), // 根據 allowMultiple 調整標題
        automaticallyImplyLeading: !widget.embedded,
        actions: [
          // 只有在非選擇模式下才顯示新增/刪除按鈕
          if (!widget.isPickingImage && _selectedAlbumIds.isNotEmpty)
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
          if (!widget.isPickingImage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新增相簿',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('新增相簿功能待實現')),
                );
              },
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
                    // 在圖片選擇模式下，點擊相簿後進入 AlbumPage 進行圖片選擇
                    _navigateToAlbumAndPick(albumId, albumTitle);
                  } else {
                    // 非選擇模式下，正常進入 AlbumPage 瀏覽相簿
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumPage(
                          albumId: albumId,
                          albumName: albumTitle,
                          isPickingImage: false, // 瀏覽模式
                          allowMultiple: false,   // 瀏覽模式不需要多選
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