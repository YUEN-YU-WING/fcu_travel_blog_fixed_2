import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'widgets/my_app_bar.dart';
import 'edit_article_page.dart';
import 'my_articles_page.dart';
import 'album_page.dart';
import 'album_folder_page.dart';

import 'package:firebase_auth/firebase_auth.dart';

void _goToRegister(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
}

void _goToLogin(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
}

void _goToProfile(BuildContext context) {

}

void _goToHome(BuildContext context) {
  // 跳回主頁，可用 pushReplacement 或清空 stack
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomePage()),
        (Route<dynamic> route) => false,
  );
}

void _logout(BuildContext context) {

}

class BackendHomePage extends StatefulWidget {
  const BackendHomePage({super.key});

  @override
  State<BackendHomePage> createState() => _BackendHomePageState();
}

class _BackendHomePageState extends State<BackendHomePage> {
  int _selectedIndex = 0;

  // 這裡新增你的功能頁面
  final List<Widget> _pages = [
    ProfilePage(),
    SettingsPage(),
    EditArticlePage(),
    MyArticlesPage(),
    AlbumFolderPage(),
    // 你可以繼續新增其他功能頁，例如 SettingsPage(), UserManagementPage() ...
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: const MyAppBar(title: "首頁"),
      body: Row(
        children: [
          // 側邊欄
          Container(
            width: 220,
            color: Colors.blueGrey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.white),
                  title: const Text('個人資料', style: TextStyle(color: Colors.white)),
                  selected: _selectedIndex == 0,
                  selectedTileColor: Colors.blueGrey[700],
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                //這裡可以繼續加入其他功能
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.white),
                  title: Text('設定', style: TextStyle(color: Colors.white)),
                  selected: _selectedIndex == 1,
                  selectedTileColor: Colors.blueGrey[700],
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                ListTile(
                  leading: Icon(Icons.edit, color: Colors.white),
                  title: Text('編輯文章', style: TextStyle(color: Colors.white)),
                  selected: _selectedIndex == 2,
                  selectedTileColor: Colors.blueGrey[700],
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                ListTile(
                  leading: Icon(Icons.article, color: Colors.white),
                  title: Text('我的文章', style: TextStyle(color: Colors.white)),
                  selected: _selectedIndex == 3,
                  selectedTileColor: Colors.blueGrey[700],
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                ListTile(
                  leading: Icon(Icons.photo, color: Colors.white),
                  title: Text('相簿管理', style: TextStyle(color: Colors.white)),
                  selected: _selectedIndex == 4,
                  selectedTileColor: Colors.blueGrey[700],
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
              ],
            ),
          ),
          // 右側內容區
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}