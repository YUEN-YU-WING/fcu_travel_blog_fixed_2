import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_page.dart';
import '../register_page.dart';
import '../login_page.dart';
import '../profile_page.dart';
import '../backend_home.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvatarTap;
  final String? avatarUrl;

  const MyAppBar({
    super.key,
    required this.title,
    this.onNotificationsTap,
    this.onAvatarTap,
    this.avatarUrl,
  });

  // AppBar 需要回傳固定高度
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: false,
      elevation: 0,
      actions: [
        // 通知鈴鐺（在頭像旁邊）
        IconButton(
          tooltip: '通知',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: onNotificationsTap,
        ),
        const SizedBox(width: 4),

        // 頭像（可點擊）
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: (avatarUrl == null || avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}