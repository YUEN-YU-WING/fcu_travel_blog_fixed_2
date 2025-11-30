import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ 1. 引入 Firestore
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  bool _loading = false;

  // 一般 Email 登入 (保持不變)
  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: pwdCtrl.text.trim(),
      );
      if (!mounted) return;
      _navigateToHome();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? '登入失敗');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ Google 登入邏輯 (修正版)
  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      // 1. 觸發 Google 登入
      // ⚠️ 如果您是 Web 版，這裡記得要加 clientId 參數 (如上一則回答所述)
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        // clientId: 'YOUR_WEB_CLIENT_ID', // Web 版請解除註解並填入 ID
      ).signIn();

      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      // 2. 獲取認證
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. 建立 Firebase 憑證
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. 登入 Firebase，並取得 UserCredential
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      // ✅ 5. 關鍵修正：檢查並建立 Firestore 用戶資料
      if (user != null) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDocSnapshot = await userDocRef.get();

        if (!userDocSnapshot.exists) {
          // 如果是第一次登入，建立使用者文件
          await userDocRef.set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? 'Google 用戶',
            'photoURL': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'likedArticles': [],       // ✅ 初始化點讚清單，解決 not-found 錯誤
            'bookmarkedArticles': [],  // ✅ 初始化收藏清單
            'following': [],
            'followers': [],
            'bio': '這個用戶很懶，還沒寫簡介。',
          });
        }
      }

      if (!mounted) return;
      _navigateToHome();

    } on FirebaseAuthException catch (e) {
      _showError('Firebase 認證失敗: ${e.message}');
    } catch (e) {
      _showError('Google 登入錯誤: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // build 方法保持不變，與之前相同
    return Scaffold(
      appBar: AppBar(title: const Text('登入')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: pwdCtrl, decoration: const InputDecoration(labelText: '密碼'), obscureText: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('登入'),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("OR")), Expanded(child: Divider())]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _googleLogin,
                icon: const Icon(Icons.login, color: Colors.red),
                label: const Text('使用 Google 帳號登入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}