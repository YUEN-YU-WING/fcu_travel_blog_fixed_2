// lib/widgets/my_app_bar.dart
import 'package:flutter/material.dart';

/// 共用頂部列
class MyAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;

  // ✅ 新增：是否為手機模式 (由父層傳入)
  final bool isMobile;
  // ✅ 新增：點擊漢堡選單的回調
  final VoidCallback? onMenuTap;

  final bool isHomePage;
  final VoidCallback? onHomeNavigate;

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAvatarTap;
  final String? avatarUrl;

  final ValueChanged<String>? onSearch;
  final ValueChanged<int>? onNavIconTap;

  const MyAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.isMobile = false, // 預設 false (桌面)
    this.onMenuTap,
    this.isHomePage = false,
    this.onHomeNavigate,
    this.onNotificationsTap,
    this.onAvatarTap,
    this.avatarUrl,
    this.onSearch,
    this.onNavIconTap,
  });

  @override
  State<MyAppBar> createState() => _MyAppBarState();

  @override
  // 如果需要兩行 AppBar (例如有 TabBar)，高度需要增加 kTextTabBarHeight
  // 這裡我們預設保持標準高度，如果開啟 bottom 屬性則需要調整
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
// 若要開啟第二行 (bottom)，請改用:
// Size get preferredSize => Size.fromHeight(kToolbarHeight + (isMobile ? 0 : 0)); // 視需求調整
}

class _MyAppBarState extends State<MyAppBar> {
  late TextEditingController _searchController;

  // ✅ 手機版專用：控制搜尋框是否展開
  bool _isMobileSearchExpanded = false;

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

  void _defaultGoHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
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
          _searchController.clear();
          widget.onSearch?.call('');
          // 手機版：回到首頁時關閉搜尋框
          if (widget.isMobile) setState(() => _isMobileSearchExpanded = false);
        }
        widget.onNavIconTap?.call(0);
      },
    );
  }

  // ✅ 封裝搜尋框 Widget (共用)
  Widget _buildSearchField({bool isMobile = false}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: isMobile, // 手機版展開時自動聚焦
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // ================== 手機版佈局 (Mobile) ==================
    if (widget.isMobile) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        // 1. 左側：漢堡選單 或 返回箭頭 (如果是搜尋模式)
        leading: _isMobileSearchExpanded
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () {
            setState(() => _isMobileSearchExpanded = false);
            _searchController.clear();
            widget.onSearch?.call('');
          },
        )
            : IconButton(
          icon: const Icon(Icons.menu, color: Colors.black54), // 三條線圖示
          onPressed: widget.onMenuTap, // 開啟 Drawer
        ),

        // 2. 中間：Logo 或 搜尋框
        title: _isMobileSearchExpanded
            ? Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: _buildSearchField(isMobile: true),
        )
            : Row(
          children: [
            Text(
              'B', // Logo
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // 如果想在 Appbar 顯示兩行，可以使用 `bottom` 屬性，
            // 但在 title 這裡我們保持簡潔
          ],
        ),

        // 3. 右側：搜尋圖示(未展開時) + 頭像
        actions: [
          if (!_isMobileSearchExpanded)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black54),
              onPressed: () {
                setState(() => _isMobileSearchExpanded = true);
              },
            ),
          if (!_isMobileSearchExpanded) _buildAvatarButton(context),
          const SizedBox(width: 8),
        ],

        // ✅ 關於「Appbar 分為兩行」：
        // 你可以在這裡使用 bottom 屬性。例如放 TabBar 或分類標籤。
        // 如果要在這裡放搜尋框也可以，但會佔用垂直空間。
        // bottom: PreferredSize(
        //   preferredSize: Size.fromHeight(40),
        //   child: Container(child: Text("第二行內容")),
        // ),
      );
    }

    // ================== 桌面版佈局 (Desktop) ==================
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      titleSpacing: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：Logo 和 搜尋框
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
                Expanded(child: _buildSearchField()), // 桌面版直接顯示搜尋框
                const SizedBox(width: 8),
              ],
            ),
          ),

          // 中間：導覽圖示
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHomeMainNavItem(context),
                IconButton(
                  icon: const Icon(Icons.map_outlined),
                  color: Colors.black54,
                  onPressed: () => widget.onNavIconTap?.call(1),
                  tooltip: '行程',
                ),
              ],
            ),
          ),

          // 右側：通知和頭像
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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