import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'album_page.dart';

class AlbumFolderPage extends StatefulWidget {
  const AlbumFolderPage({super.key});
  @override
  State<AlbumFolderPage> createState() => _AlbumFolderPageState();
}

class _AlbumFolderPageState extends State<AlbumFolderPage> {
  Set<String> _selectedAlbumIds = {};

  Future<void> _deleteSelectedAlbums(List<QueryDocumentSnapshot> docs) async {
    final user = FirebaseAuth.instance.currentUser;
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
        final fileName = data['fileName'] as String?;
        try {
          if (fileName != null) {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('user_albums/${user.uid}/$fileName');
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('請先登入'));

    final albumsStream = FirebaseFirestore.instance
        .collection('albums')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('相簿管理/上傳'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: albumsStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final allSelected = _selectedAlbumIds.length == docs.length && docs.isNotEmpty;
              return Row(
                children: [
                  if (_selectedAlbumIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: '刪除選取相簿',
                      onPressed: () async {
                        final isConfirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('刪除相簿'),
                            content: Text('確定要刪除選取的${_selectedAlbumIds.length}個相簿？\n（相簿內所有照片也會一起刪除）'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除')),
                            ],
                          ),
                        );
                        if (isConfirm == true) {
                          await _deleteSelectedAlbums(docs);
                        }
                      },
                    ),
                  Checkbox(
                    value: allSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedAlbumIds = docs.map((doc) => doc.id).toSet();
                        } else {
                          _selectedAlbumIds.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: albumsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              childAspectRatio: 0.8,
            ),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // 新增相簿卡片
                return GestureDetector(
                  onTap: () async {
                    final nameController = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('新增相簿'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '相簿名稱'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('新增')),
                        ],
                      ),
                    );
                    if (ok == true && nameController.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance.collection('albums').add({
                        'name': nameController.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                        'ownerUid': user.uid,
                        'coverUrl': null,
                        'photoCount': 0,
                      });
                    }
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add, size: 60, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('新增相簿、資料夾', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final doc = docs[index - 1];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final albumId = doc.id;
              final name = data['name'] as String? ?? '';
              final coverUrl = data['coverUrl'] as String?;
              final photoCount = data['photoCount'] as int? ?? 0;
              final isSelected = _selectedAlbumIds.contains(albumId);

              return GestureDetector(
                onLongPress: () {
                  setState(() {
                    if (isSelected) {
                      _selectedAlbumIds.remove(albumId);
                    } else {
                      _selectedAlbumIds.add(albumId);
                    }
                  });
                },
                onTap: () {
                  if (_selectedAlbumIds.isNotEmpty) {
                    setState(() {
                      if (isSelected) {
                        _selectedAlbumIds.remove(albumId);
                      } else {
                        _selectedAlbumIds.add(albumId);
                      }
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AlbumPage(albumId: albumId, albumName: name)),
                    );
                  }
                },
                child: Stack(
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                image: coverUrl != null
                                    ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
                                    : null,
                                color: coverUrl == null ? Colors.grey.shade100 : null,
                              ),
                              child: coverUrl == null
                                  ? const Center(
                                child: Icon(Icons.photo_album, size: 50, color: Colors.grey),
                              )
                                  : null,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('$photoCount 張相片', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedAlbumIds.add(albumId);
                            } else {
                              _selectedAlbumIds.remove(albumId);
                            }
                          });
                        },
                        shape: const CircleBorder(),
                        side: const BorderSide(width: 1, color: Colors.grey),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}