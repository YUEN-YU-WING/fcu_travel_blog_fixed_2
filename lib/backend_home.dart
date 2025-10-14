// lib/backend_home.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'widgets/my_app_bar.dart';

// 右側各功能頁（保持原本功能，只在頁內以 embedded 控制 back 顯示）
import 'profile_page.dart';
import 'settings_page.dart';
import 'article_interactive_editor.dart';
import 'edit_article_page.dart';
import 'my_articles_page.dart';
import 'album_folder_page.dart';
import 'MapPage.dart';

void _goToHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
  );
}

Future<void> _logout(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已登出')));
    _goToHome(context);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登出失敗：$e')));
  }
}

class BackendHomePage extends StatefulWidget {
  const BackendHomePage({super.key});

  @override
  State<BackendHomePage> createState() => _BackendHomePageState();
}

class _BackendHomePageState extends State<BackendHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 右側各功能頁：嵌入後台，僅隱藏自己的 Back（AppBar 照舊）
    final List<Widget> pages = <Widget>[
      const ProfilePage(embedded: true),
      const SettingsPage(embedded: true),
      const ArticleInteractiveEditor(embedded: true),
      const EditArticlePage(embedded: true),
      const MyArticlesPage(embedded: true),
      const AlbumFolderPage(embedded: true),
      const MapPage(embedded: true),
    ];

    return Scaffold(
      appBar: const MyAppBar(title: '後台'),
      body: Row(
        children: [
          // 左側側欄（維持原本功能，不含 Back 項目）
          Container(
            width: 220,
            color: Colors.blueGrey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                _navTile('個人資料', Icons.person, 0),
                _navTile('設定', Icons.settings, 1),
                _navTile('AI協助編輯', Icons.auto_awesome, 2),
                _navTile('編輯文章', Icons.edit, 3),
                _navTile('我的文章', Icons.article, 4),
                _navTile('相簿管理', Icons.photo, 5),
                _navTile('地圖', Icons.map, 6),
                const Spacer(),
                const Divider(color: Colors.white24, height: 1),
                if (user != null)
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white70),
                    title: const Text('登出', style: TextStyle(color: Colors.white70)),
                    onTap: () => _logout(context),
                  ),
              ],
            ),
          ),

          // 右側內容
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(String label, IconData icon, int idx) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      selected: _selectedIndex == idx,
      selectedTileColor: Colors.blueGrey[700],
      onTap: () => setState(() => _selectedIndex = idx),
    );
  }
}
