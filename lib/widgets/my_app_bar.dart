import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_page.dart';
import '../register_page.dart';
import '../login_page.dart';
import '../profile_page.dart';
import '../backend_home.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const MyAppBar({super.key, required this.title});

  void _goToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
  }

  void _goToRegister(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("已登出")),
    );
    _goToHome(context);
  }

  void _goToProfile(BuildContext context) {
    // Replace with your actual profile navigation
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
  }

  void _goToBackendHome(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BackendHomePage()));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AppBar(
      title: GestureDetector(
        onTap: () => _goToHome(context),
        child: Row(
          children: [
            const Icon(Icons.home, color: Colors.white),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
      actions: [
        if (user == null) ...[
          TextButton(
            onPressed: () => _goToRegister(context),
            child: const Text('註冊'),
          ),
          TextButton(
            onPressed: () => _goToLogin(context),
            child: const Text('登入'),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<String>(
              tooltip: "開啟功能選單",
              offset: const Offset(0, 50),
              icon: user.photoURL != null
                  ? CircleAvatar(backgroundImage: NetworkImage(user.photoURL!))
                  : CircleAvatar(
                child: Text(
                  (user.displayName != null && user.displayName!.isNotEmpty)
                      ? user.displayName![0]
                      : user.email != null && user.email!.isNotEmpty
                      ? user.email![0]
                      : '?',
                ),
              ),
              onSelected: (value) {
                if (value == 'backendHome') {
                  _goToBackendHome(context);
                } else if (value == 'logout') {
                  _logout(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'backendHome', child: Text('個人後台')),
                const PopupMenuItem(value: 'logout', child: Text('登出')),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}