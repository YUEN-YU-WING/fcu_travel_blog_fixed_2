import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return '請輸入 Email';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Email 格式不正確';
    return null;
  }

  String? _validatePwd(String? v) {
    if (v == null || v.isEmpty) return '請輸入密碼';
    if (v.length < 6) return '密碼至少 6 碼';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return '請再次輸入密碼';
    if (v != pwdCtrl.text) return '兩次密碼不一致';
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: pwdCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('註冊成功')));
      // ✅ 註冊成功後回首頁（清空返回堆疊）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = e.message ?? '註冊失敗';
      if (e.code == 'email-already-in-use') msg = '此 Email 已被使用';
      if (e.code == 'weak-password') msg = '密碼強度不足（至少 6 碼）';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('註冊失敗：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    pwdCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pwdCtrl,
                decoration: const InputDecoration(labelText: '密碼'),
                obscureText: true,
                validator: _validatePwd,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                decoration: const InputDecoration(labelText: '確認密碼'),
                obscureText: true,
                validator: _validateConfirm,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('建立帳號'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
