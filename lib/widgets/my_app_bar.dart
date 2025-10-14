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
class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;

  final bool isHomePage;
  final VoidCallback? onHomeNavigate;

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvatarTap;
  final String? avatarUrl;

  const MyAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.isHomePage = false,
    this.onHomeNavigate,
    this.onNotificationsTap,
    this.onAvatarTap,
    this.avatarUrl,
  });

  /// 預設的「回到首頁」行為：pop 到第一層
  void _defaultGoHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// 首頁（房子）按鈕：在首頁只觸發水波；非首頁才觸發導回首頁
  Widget _buildHomeButton(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        containedInkWell: true,
        radius: 24,
        onTap: () {
          if (isHomePage) {
            // 在首頁：不做導航，僅顯示 ripple（InkResponse 本身會產生）
            return;
          }
          // 非首頁：導航回首頁
          if (onHomeNavigate != null) {
            onHomeNavigate!();
          } else {
            _defaultGoHome(context);
          }
        },
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.home_rounded),
        ),
      ),
    );
  }

  /// 通知按鈕：維持圓形 ripple（IconButton 內建）
  Widget _buildNotifyButton(BuildContext context) {
    return IconButton(
      tooltip: '通知',
      icon: const Icon(Icons.notifications_none_rounded),
      onPressed: onNotificationsTap,
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      leading: _buildHomeButton(context),
      actions: [
        _buildNotifyButton(context),
        const SizedBox(width: 4),
        _buildAvatarButton(context),
        const SizedBox(width: 8),
      ],
    );
  }
}
