import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'widgets/my_app_bar.dart';

// 右側各功能頁（保持原本功能，只在頁內以 embedded 控制 back 顯示）
import 'profile_page.dart';
import 'settings_page.dart';
import 'edit_article_page.dart';
import 'my_articles_page.dart';
import 'album_folder_page.dart';
import 'map_picker_page.dart';
import 'public_articles_page.dart';
import 'pages/create_travel_article_page.dart';
import 'map_selection_page.dart';

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
  // 接收一個初始選中索引
  final int initialIndex;

  const BackendHomePage({super.key, this.initialIndex = 0}); // 預設為 0

  @override
  State<BackendHomePage> createState() => _BackendHomePageState();
}

class _BackendHomePageState extends State<BackendHomePage> {
  late int _selectedIndex; // 改為 late，在 initState 中初始化

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // 使用傳入的初始索引
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    final List<Widget> pages = <Widget>[
      const ProfilePage(embedded: true),
      const SettingsPage(embedded: true),
      const CreateTravelArticlePage(),
      const EditArticlePage(embedded: true),
      const MyArticlesPage(embedded: true),
      const AlbumFolderPage(embedded: true),
      const MapSelectionPage(embedded: true),
      const PublicArticlesPage(embedded: true),
    ];

    // ✅ 手機版：用 Drawer
    if (!isWideScreen) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '後台',
            style: TextStyle(
              color: Colors.white, // ✅ 統一字體顏色
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.blueGrey[900], // ✅ 統一背景色
          iconTheme: const IconThemeData(color: Colors.white), // ✅ 讓返回與漢堡按鈕也變白
        ),
        drawer: Drawer(
          backgroundColor: Colors.blueGrey[900],
          child: _buildSidebar(user, isWideScreen: false),
        ),
        body: pages[_selectedIndex],
      );
    }

    // ✅ 桌面版：原本的側邊列 + 主內容
    return Scaffold(
      appBar: const MyAppBar(title: '後台'),
      body: Row(
        children: [
          Container(
            width: 220,
            color: Colors.blueGrey[900],
            child: _buildSidebar(user, isWideScreen: true),
          ),
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

  Widget _buildSidebar(User? user, {required bool isWideScreen}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        _navTile('個人資料', Icons.person, 0, isWideScreen),
        _navTile('設定', Icons.settings, 1, isWideScreen),
        _navTile('AI協助編輯', Icons.auto_awesome, 2, isWideScreen),
        _navTile('編輯文章', Icons.edit, 3, isWideScreen),
        _navTile('我的文章', Icons.article, 4, isWideScreen),
        _navTile('相簿管理', Icons.photo, 5, isWideScreen),
        _navTile('地圖', Icons.map, 6, isWideScreen),
        _navTile('公開文章', Icons.public, 7, isWideScreen),
        const Spacer(),
        const Divider(color: Colors.white24, height: 1),
        if (user != null)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('登出', style: TextStyle(color: Colors.white70)),
            onTap: () => _logout(context),
          ),
      ],
    );
  }

  Widget _navTile(String label, IconData icon, int idx, bool isWideScreen) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      selected: _selectedIndex == idx,
      selectedTileColor: Colors.blueGrey[700],
      onTap: () {
        setState(() => _selectedIndex = idx);
        if (!isWideScreen) Navigator.pop(context); // 關閉 Drawer
      },
    );
  }
}
