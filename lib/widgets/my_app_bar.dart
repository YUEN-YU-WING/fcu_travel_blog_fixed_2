// lib/widgets/my_app_bar.dart
import 'package:flutter/material.dart';
// import '../search_page.dart'; // 如果改成直接搜尋，可能暫時不需要跳轉到搜尋頁

/// 共用頂部列
class MyAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;

  final bool isHomePage;
  final VoidCallback? onHomeNavigate;

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvatarTap;
  final String? avatarUrl;

  // ✅ 修改：從 VoidCallback 改為 ValueChanged<String>，傳回搜尋文字
  final ValueChanged<String>? onSearch;

  final ValueChanged<int>? onNavIconTap;



  const MyAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.isHomePage = false,
    this.onHomeNavigate,
    this.onNotificationsTap,
    this.onAvatarTap,
    this.avatarUrl,
    this.onSearch, // ✅ 接收搜尋回調
    this.onNavIconTap,
  });

  @override
  State<MyAppBar> createState() => _MyAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MyAppBarState extends State<MyAppBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 預設的「回到首頁」行為
  void _defaultGoHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildNotifyButton(BuildContext context) {
    return IconButton(
      tooltip: '通知',
      icon: const Icon(Icons.notifications_none_rounded),
      onPressed: widget.onNotificationsTap,
      color: Colors.black54,
    );
  }

  Widget _buildAvatarButton(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        radius: 28,
        onTap: widget.onAvatarTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 32,
              height: 32,
              child: widget.avatarUrl != null
                  ? Image.network(
                widget.avatarUrl!,
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

  Widget _buildHomeMainNavItem(BuildContext context) {
    return IconButton(
      tooltip: '首頁',
      icon: Icon(
        widget.isHomePage ? Icons.home_rounded : Icons.home_outlined,
        color: widget.isHomePage ? Colors.blue[700] : Colors.black54,
      ),
      onPressed: () {
        if (!widget.isHomePage) {
          if (widget.onHomeNavigate != null) {
            widget.onHomeNavigate!();
          } else {
            _defaultGoHome(context);
          }
        } else {
          // 如果在首頁點擊首頁，清除搜尋並重置
          _searchController.clear();
          widget.onSearch?.call('');
        }
        widget.onNavIconTap?.call(0); // ✅ 調整索引：首頁現在是索引 0
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // TextEditingController searchController = TextEditingController(); // 這裡重複定義了，應該使用 _searchController

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：Logo 和搜尋框
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  'B',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        widget.onSearch?.call(value);
                      },
                      decoration: InputDecoration(
                        hintText: '搜尋文章...',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                        border: InputBorder.none,
                        icon: const Icon(Icons.search, color: Colors.grey, size: 20),
                        contentPadding: const EdgeInsets.only(bottom: 10),
                        isDense: true,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearch?.call('');
                            setState(() {});
                          },
                        )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          // 中間：主要導覽圖示
          // ✅ 調整 flex 比例，給中間更多空間
          Expanded(
            flex: 3, // 從 2 改為 3，提供更多空間給多個圖示
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHomeMainNavItem(context), // 索引 0
                IconButton(
                  icon: const Icon(Icons.map_outlined), // 行程圖示
                  color: Colors.black54,
                  onPressed: () => widget.onNavIconTap?.call(1), // ✅ 索引 1 給行程
                  tooltip: '行程',
                ),
                // 你可以根據需要添加更多導覽圖示
                // 例如：IconButton(
                //   icon: const Icon(Icons.storefront_outlined), // 市集圖示
                //   color: Colors.black54,
                //   onPressed: () => widget.onNavIconTap?.call(3), // ✅ 索引 3 給市集
                //   tooltip: '市集',
                // ),
              ],
            ),
          ),

          // 右側：通知和用戶頭像
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // _buildNotifyButton(context),
                _buildAvatarButton(context),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}