// lib/settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    try {
      await user?.updateDisplayName(name);
      await user?.reload();
      setState(() => _statusMsg = "名字已更新");
    } catch (e) {
      setState(() => _statusMsg = "更新失敗：$e");
    }
  }

  Future<void> _changePassword() async {
    if (_currentPwController.text.isEmpty || _newPwController.text.isEmpty) {
      setState(() => _statusMsg = "請填寫所有欄位");
      return;
    }
    try {
      // 重新驗證舊密碼
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
        // ✅ 核心：在後台嵌入時不顯示返回鍵；獨立開頁保留返回鍵
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
