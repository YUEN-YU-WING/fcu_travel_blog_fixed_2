import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AlbumPage extends StatefulWidget {
  final String albumId;
  final String albumName;
  const AlbumPage({super.key, required this.albumId, required this.albumName});
  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final _picker = ImagePicker();
  bool _isUploading = false;
  Set<String> _selectedPhotoIds = {};

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    final bytes = await pickedFile.readAsBytes(); // 支援 Web
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';
    final storagePath = 'user_albums/${user.uid}/$fileName';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);

    try {
      final uploadTask = await storageRef.putData(bytes); // 取代 putFile
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 寫入 Firestore，存 storagePath 而非 url
      await FirebaseFirestore.instance.collection('photos').add({
        'storagePath': storagePath,
        'url': downloadUrl, // 仍可存 downloadUrl 供前端快取用（可選）
        'ownerUid': user.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
        'albumId': widget.albumId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片上傳成功！')),
      );

      final albumRef = FirebaseFirestore.instance.collection('albums').doc(widget.albumId);

      await albumRef.update({
        'coverUrl': downloadUrl, // 最新一張當封面
        'photoCount': FieldValue.increment(1),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteSelectedPhotos(List<QueryDocumentSnapshot> docs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final photosToDelete = docs.where((doc) => _selectedPhotoIds.contains(doc.id)).toList();

    for (final doc in photosToDelete) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final storagePath = data['storagePath'] as String?;
      try {
        if (storagePath != null) {
          final storageRef = FirebaseStorage.instance.ref().child(storagePath);
          await storageRef.delete();
        }
      } catch (_) {
        // 允許 Storage 沒有檔案
      }
      await FirebaseFirestore.instance.collection('photos').doc(doc.id).delete();
    }

    // 更新相簿照片數
    final albumRef = FirebaseFirestore.instance.collection('albums').doc(widget.albumId);
    await albumRef.update({
      'photoCount': FieldValue.increment(-photosToDelete.length),
    });

    setState(() {
      _selectedPhotoIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除${photosToDelete.length}張照片')),
    );

    await _updateAlbumCoverAfterDelete();
  }

  Future<void> _updateAlbumCoverAfterDelete() async {
    final albumRef = FirebaseFirestore.instance.collection('albums').doc(widget.albumId);
    final latestPhoto = await FirebaseFirestore.instance
        .collection('photos')
        .where('albumId', isEqualTo: widget.albumId)
        .where('ownerUid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .orderBy('uploadedAt', descending: true)
        .limit(1)
        .get();

    if (latestPhoto.docs.isEmpty) {
      // 沒有照片了，封面設為 null
      await albumRef.update({'coverUrl': null});
    } else {
      // 封面仍用 downloadUrl（可改成 storagePath 並於前端取得 downloadUrl）
      final url = latestPhoto.docs.first['url'] as String?;
      await albumRef.update({'coverUrl': url});
    }
  }

  Future<String?> _getDownloadUrl(String? storagePath, String? urlFromDB) async {
    if (urlFromDB != null && urlFromDB.isNotEmpty) return urlFromDB;
    if (storagePath == null || storagePath.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref().child(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('請先登入'));

    final photosStream = FirebaseFirestore.instance
        .collection('photos')
        .where('ownerUid', isEqualTo: user.uid)
        .where('albumId', isEqualTo: widget.albumId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: photosStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final allSelected = _selectedPhotoIds.length == docs.length && docs.isNotEmpty;
              return Row(
                children: [
                  if (_selectedPhotoIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: '刪除選取照片',
                      onPressed: () async {
                        final isConfirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('刪除照片'),
                            content: Text('確定要刪除選取的${_selectedPhotoIds.length}張照片嗎？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除')),
                            ],
                          ),
                        );
                        if (isConfirm == true) {
                          await _deleteSelectedPhotos(docs);
                        }
                      },
                    ),
                  Checkbox(
                    value: allSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedPhotoIds = docs.map((doc) => doc.id).toSet();
                        } else {
                          _selectedPhotoIds.clear();
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
        stream: photosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('此相簿尚未上傳任何照片'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final storagePath = data['storagePath'] as String?;
              final urlFromDB = data['url'] as String?;
              final isSelected = _selectedPhotoIds.contains(doc.id);

              return FutureBuilder<String?>(
                future: _getDownloadUrl(storagePath, urlFromDB),
                builder: (context, snapshot) {
                  final imageUrl = snapshot.data;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                  }
                  if (imageUrl == null) return const SizedBox();

                  return GestureDetector(
                    onLongPress: () {
                      setState(() {
                        if (isSelected) {
                          _selectedPhotoIds.remove(doc.id);
                        } else {
                          _selectedPhotoIds.add(doc.id);
                        }
                      });
                    },
                    onTap: () {
                      if (_selectedPhotoIds.isNotEmpty) {
                        setState(() {
                          if (isSelected) {
                            _selectedPhotoIds.remove(doc.id);
                          } else {
                            _selectedPhotoIds.add(doc.id);
                          }
                        });
                      } else {
                        // 預覽
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: InteractiveViewer(
                                child: Image.network(imageUrl, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        Hero(
                          tag: imageUrl,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) =>
                              progress == null ? child : const Center(child: CircularProgressIndicator()),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedPhotoIds.add(doc.id);
                                } else {
                                  _selectedPhotoIds.remove(doc.id);
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _pickAndUploadImage,
        tooltip: '新增照片',
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add_a_photo),
      ),
    );
  }
}