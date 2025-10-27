// lib/widgets/my_app_bar.dart
import 'package:flutter/material.dart';

/// 共用頂部列：首頁（房子）／通知／頭像
/// - isHomePage: 告訴 AppBar 目前是否在首頁
///   * true  => 點房子只顯示水波，不導航
///   * false => 點房子會回到首頁（pop 到根 / 呼叫 onHomeNavigate）
/// - onHomeNavigate: 若非首頁時要如何回到首頁（可自訂，預設 pop 到第一層）
/// - onNotificationsTap: 點通知要做什麼（例如 push NotificationsPage）
/// - onAvatarTap: 點頭像要做什麼（你原本是打開 bottom sheet）
/// - avatarUrl: 顯示頭像；若 null 以人像 icon 代替
/// - onSearchTap: 點擊搜尋框要做什麼（例如跳轉到搜尋頁面）
/// - onNavIconTap: 針對中間導覽圖示的通用點擊回調
class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; // 這個 title 將被應用程式 Logo 或品牌名稱取代
  final bool centerTitle; // 這個屬性在此次優化後可能不再需要，因為佈局更複雜了

  final bool isHomePage;
  final VoidCallback? onHomeNavigate;

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvatarTap;
  final String? avatarUrl;

  final VoidCallback? onSearchTap; // 新增：搜尋框點擊事件
  final ValueChanged<int>? onNavIconTap; // 新增：中間導覽圖示點擊事件

  const MyAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.isHomePage = false,
    this.onHomeNavigate,
    this.onNotificationsTap,
    this.onAvatarTap,
    this.avatarUrl,
    this.onSearchTap, // 初始化
    this.onNavIconTap, // 初始化
  });

  /// 預設的「回到首頁」行為：pop 到第一層
  void _defaultGoHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // 將 _buildHomeButton 邏輯嵌入到新的 App Bar 結構中，這裡不再單獨使用
  // Widget _buildHomeButton(BuildContext context) { ... }

  /// 通知按鈕：維持圓形 ripple（IconButton 內建）
  Widget _buildNotifyButton(BuildContext context) {
    return IconButton(
      tooltip: '通知',
      icon: const Icon(Icons.notifications_none_rounded),
      onPressed: onNotificationsTap,
      color: Colors.black54, // 調整顏色
    );
  }

  /// 頭像按鈕：改成「方形水波」以和通知圓形形成一致又有區隔
  Widget _buildAvatarButton(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        highlightShape: BoxShape.rectangle, // 關鍵：方形水波
        containedInkWell: true,
        radius: 28,
        onTap: onAvatarTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8), // 視覺為方形帶圓角
            child: SizedBox(
              width: 32,
              height: 32,
              child: avatarUrl != null
                  ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person),
              )
                  : const Icon(Icons.person),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight); // 或可以考慮稍微高一點

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white, // Facebook 通常是白色 AppBar
      elevation: 0.5, // 輕微的陰影
      titleSpacing: 0, // 移除 title 預設的左右間距
      // 由於佈局完全自定義，title 和 leading/actions 將不再直接使用
      // 而是用 Flexible 或 Row 來構建 AppBar 的內容
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：Logo 和搜尋框
          Expanded(
            flex: 2, // 佔用較小比例
            child: Row(
              children: [
                const SizedBox(width: 8),
                // Logo 或品牌名稱 (可以替換成你的 App Logo)
                Text(
                  'B', // 簡化為一個字母 Logo，可以替換為 Image.asset('assets/logo.png')
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // 搜尋框
                Expanded(
                  child: GestureDetector(
                    onTap: onSearchTap, // 點擊搜尋框區域時觸發
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '搜尋',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          // 中間：主要導覽圖示
          Expanded(
            flex: 3, // 佔用較大比例
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHomeMainNavItem(context), // 首頁按鈕
                IconButton(
                  icon: const Icon(Icons.ondemand_video_outlined),
                  color: Colors.black54,
                  onPressed: () => onNavIconTap?.call(0), // 假設索引 0 代表影片
                ),
                IconButton(
                  icon: const Icon(Icons.storefront_outlined),
                  color: Colors.black54,
                  onPressed: () => onNavIconTap?.call(1), // 假設索引 1 代表市集
                ),
                // 可以根據需要添加更多導覽圖示
              ],
            ),
          ),

          // 右側：通知和用戶頭像
          Expanded(
            flex: 2, // 佔用較小比例
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildNotifyButton(context),
                _buildAvatarButton(context),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 首頁主導覽按鈕 (與左側邊欄的首頁按鈕行為略有不同，這是主要導覽的一部分)
  Widget _buildHomeMainNavItem(BuildContext context) {
    return IconButton(
      tooltip: '首頁',
      // 如果當前頁面是 HomePage，則給予不同的視覺樣式
      icon: Icon(
        isHomePage ? Icons.home_rounded : Icons.home_outlined,
        color: isHomePage ? Colors.blue[700] : Colors.black54,
      ),
      onPressed: () {
        if (!isHomePage) {
          if (onHomeNavigate != null) {
            onHomeNavigate!();
          } else {
            _defaultGoHome(context);
          }
        }
        onNavIconTap?.call(2); // 假設索引 2 代表主要首頁導覽
      },
    );
  }
}