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
  final TextEditingController _newAlbumNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  void dispose() {
    _newAlbumNameController.dispose();
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
      });

      _newAlbumNameController.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
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
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newAlbumNameController.clear();
                Navigator.of(context).pop();
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

  // 刪除選取的相簿及其所有照片
  Future<void> _deleteSelectedAlbumsConfirmed(List<QueryDocumentSnapshot> allAlbums) async {
    final user = _currentUser;
    if (user == null) return;

    // 篩選出目前選中的相簿文檔
    final albumsToDelete = allAlbums.where((doc) => _selectedAlbumIds.contains(doc.id)).toList();

    if (albumsToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有選取任何相簿')),
      );
      return;
    }

    final isConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除相簿'),
        content: Text('確定要刪除選取的 ${_selectedAlbumIds.length} 個相簿及其所有照片嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (isConfirm != true) {
      return; // 如果取消刪除，則直接返回
    }

    try {
      for (final albumDoc in albumsToDelete) {
        final albumId = albumDoc.id;

        // 1. 刪除相簿底下所有照片（Firestore 與 Storage）
        final photosSnap = await FirebaseFirestore.instance
            .collection('photos')
            .where('albumId', isEqualTo: albumId)
            .where('ownerUid', isEqualTo: user.uid)
            .get();

        for (final photoDoc in photosSnap.docs) {
          final data = photoDoc.data();
          final storagePath = data['storagePath'] as String?;
          try {
            if (storagePath != null && storagePath.isNotEmpty) {
              final storageRef = FirebaseStorage.instance.ref().child(storagePath);
              await storageRef.delete();
            }
          } catch (e) {
            // 如果 Storage 中沒有檔案，FirebaseStorage 會拋出異常，這裡捕獲並忽略
            // print('刪除 Storage 檔案失敗或檔案不存在: ${e.toString()}');
          }
          await FirebaseFirestore.instance.collection('photos').doc(photoDoc.id).delete();
        }

        // 2. 刪除相簿本身
        await FirebaseFirestore.instance.collection('albums').doc(albumId).delete();
      }

      setState(() {
        _selectedAlbumIds.clear(); // 清空選取狀態
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已刪除 ${albumsToDelete.length} 個相簿及其所有照片')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗: $e')),
      );
    }
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
          if (!widget.isPickingImage) ...[
            // 刪除按鈕只在有選取相簿時顯示
            if (_selectedAlbumIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red), // 使用紅色強調刪除
                tooltip: '刪除選取的相簿',
                onPressed: () async {
                  // 在這裡需要傳入 albums 列表，所以不能直接呼叫 _deleteSelectedAlbumsConfirmed
                  // 我們會通過 StreamBuilder 獲取最新的 albums 列表，然後傳遞給它
                  // 由於這個是 AppBar 的按鈕，我們需要稍微調整
                  // 我們讓它觸發一個標記，然後在 StreamBuilder 裡判斷並執行
                  // 為了簡化，直接在按鈕點擊時獲取當前數據快照
                  final currentSnapshot = await FirebaseFirestore.instance
                      .collection('albums')
                      .where('ownerUid', isEqualTo: _currentUser!.uid)
                      .get();
                  await _deleteSelectedAlbumsConfirmed(currentSnapshot.docs);
                },
              ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新增相簿',
              onPressed: _showCreateAlbumDialog,
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
                  if (!widget.isPickingImage)
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
                  if (_selectedAlbumIds.isNotEmpty) { // 如果已經進入選取模式，則點擊切換選取狀態
                    setState(() {
                      if (isSelected) {
                        _selectedAlbumIds.remove(albumId);
                      } else {
                        _selectedAlbumIds.add(albumId);
                      }
                      if (_selectedAlbumIds.isEmpty) { // 如果全部取消選取，則退出選取模式
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      }
                    });
                  } else if (widget.isPickingImage) { // 如果是選擇模式，且沒有選取任何相簿，則導航到相簿
                    _navigateToAlbumAndPick(albumId, albumTitle);
                  } else { // 正常模式，且沒有選取任何相簿，則導航到相簿
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