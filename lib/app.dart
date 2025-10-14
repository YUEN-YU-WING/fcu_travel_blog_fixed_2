// lib/app.dart
import 'package:flutter/material.dart';

// === 你的頁面（依實際路徑 / 大小寫調整） ===
import 'home_page.dart';          // 首頁
import 'backend_home.dart';       // 後台主頁
import 'register_page.dart';
import 'login_page.dart';
import 'my_articles_page.dart';
import 'edit_article_page.dart';
import 'album_folder_page.dart';
import 'MapPage.dart';            // 若已改小寫請改成 'map_page.dart'
import 'PlaceSearchPage.dart';    // 若已改小寫請改成 'place_search_page.dart'

/// App 殼：主題與路由設定
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCU Travel Blog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // 首頁
      home: const HomePage(),

      // 命名路由
      routes: {
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
        '/backend': (context) => const BackendHomePage(), // ✅ 個人後台
        '/my_articles': (context) => const MyArticlesPage(),
        '/album': (context) => const AlbumFolderPage(),
        '/map': (context) => const MapPage(),
        '/search': (context) => const PlaceSearchPage(),
      },

      // 需要從 Route arguments 建構時（例如編輯文章）
      onGenerateRoute: (settings) {
        if (settings.name == '/edit_article') {
          return MaterialPageRoute(
            builder: (context) => EditArticlePage.fromRouteArguments(context),
            settings: settings,
          );
        }
        return null;
      },

      // 找不到路由時的後備頁（可選）
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('找不到頁面')),
        ),
      ),
    );
  }
}