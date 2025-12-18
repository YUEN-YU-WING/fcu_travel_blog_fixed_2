// lib/settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 引入 Firestore

class SettingsPage extends StatefulWidget {
  /// 後台右側嵌入時請設為 true，如：const SettingsPage(embedded: true)
  /// 獨立開頁（一般 push）保持預設 false 會顯示系統返回鍵
  final bool embedded;

  const SettingsPage({super.key, this.embedded = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _statusMsg = "";

  User? get user => FirebaseAuth.instance.currentUser;

  // 獲取 Firestore 實例
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? "";
  }

  Future<void> _changeName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _statusMsg = "名字不能為空");
      return;
    }

    if (user == null) {
      setState(() => _statusMsg = "用戶未登入。");
      return;
    }

    try {
      // 1. 更新 Firebase Auth (保持原樣)
      await user?.updateDisplayName(name);
      await user?.reload();

      // 2. 更新 Firestore users 集合 (保持原樣)
      await _firestore.collection('users').doc(user!.uid).update({
        'displayName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. 修正：批次更新文章 (這裡要改！)
      final batch = _firestore.batch();

      final articlesSnapshot = await _firestore
          .collection('articles')
      // ❌ 原本： .where('authorUid', isEqualTo: user!.uid)
      // ✅ 修正： 改成 ownerUid 以符合你的資料庫欄位
          .where('ownerUid', isEqualTo: user!.uid)
          .get();

      // 為了安全起見，可以加一個 log 看看抓到幾篇
      print("找到 ${articlesSnapshot.docs.length} 篇需要更新的文章");

      for (var doc in articlesSnapshot.docs) {
        batch.update(doc.reference, {'authorName': name});
      }

      final routeSnapshot = await _firestore
          .collection('travelRouteCollections')
          .where('ownerUid', isEqualTo: user!.uid) // 找出我的行程
          .get();

      for (var doc in routeSnapshot.docs) {
        batch.update(doc.reference, {'ownerName': name});
      }

      await batch.commit();

      setState(() => _statusMsg = "名字已更新");
    } on FirebaseAuthException catch (e) {
      setState(() => _statusMsg = "更新 Firebase Auth 失敗：${e.message}");
    } catch (e) {
      setState(() => _statusMsg = "更新失敗：$e");
    }
  }

  Future<void> _changePassword() async {
    // ... (此方法不變)
    if (_currentPwController.text.isEmpty || _newPwController.text.isEmpty) {
      setState(() => _statusMsg = "請填寫所有欄位");
      return;
    }
    if (user == null || user!.email == null) {
      setState(() => _statusMsg = "用戶未登入或無郵箱。");
      return;
    }
    try {
      final cred = EmailAuthProvider.credential(
        email: user!.email!,
        password: _currentPwController.text,
      );
      await user!.reauthenticateWithCredential(cred);
      await user!.updatePassword(_newPwController.text);
      setState(() {
        _statusMsg = "密碼已更新";
        _currentPwController.clear();
        _newPwController.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password') {
          _statusMsg = "舊密碼錯誤";
        } else if (e.code == 'requires-recent-login') {
          _statusMsg = "此操作需要重新登入。請登出並重新登入後再試。";
        } else {
          _statusMsg = "密碼更新失敗：${e.message}";
        }
      });
    } catch (e) {
      setState(() => _statusMsg = "密碼更新失敗：$e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPwController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("設定"),
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text("更改名字", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "名字"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _changeName,
              child: const Text("更新名字"),
            ),
            const Divider(height: 40),
            const Text("更改密碼", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _currentPwController,
              decoration: const InputDecoration(labelText: "舊密碼"),
              obscureText: true,
            ),
            TextFormField(
              controller: _newPwController,
              decoration: const InputDecoration(labelText: "新密碼"),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text("更新密碼"),
            ),
            const SizedBox(height: 24),
            Text(_statusMsg, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}