// lib/widgets/my_app_bar.dart
import 'package:flutter/material.dart';

/// 共用頂部列
class MyAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;

  // 是否為手機模式 (由父層傳入)
  final bool isMobile;
  // 點擊漢堡選單的回調
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
  // ✅ 修改高度計算：如果是手機版，高度需要包含 bottom 區域 (標準高度 kToolbarHeight + 導覽列高度 48)
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (isMobile ? 48.0 : 0.0));
}

class _MyAppBarState extends State<MyAppBar> {
  late TextEditingController _searchController;

  // 手機版專用：控制搜尋框是否展開
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

  // 封裝搜尋框 Widget (共用)
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

        // 2. 第一行中間：Logo 或 搜尋框
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
          ],
        ),

        // 3. 第一行右側：搜尋圖示(未展開時) + 頭像
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

        // ✅ 核心修改：使用 bottom 屬性建立「第二行」
        // 這裡我們放入一個 PreferredSize 包裹的 Row，用來放導覽按鈕
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0), // 第二行的高度
          child: Container(
            height: 48.0,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black12, width: 0.5), // 加上一條細線分隔第一行
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 平均分配空間
              children: [
                // 導覽項目 1: 首頁
                _buildHomeMainNavItem(context),

                // 導覽項目 2: 行程地圖
                IconButton(
                  icon: const Icon(Icons.map_outlined),
                  color: Colors.black54,
                  onPressed: () => widget.onNavIconTap?.call(1),
                  tooltip: '行程',
                ),

                // 如果未來有市集或其他分頁，加在這裡即可
              ],
            ),
          ),
        ),
      );
    }

    // ================== 桌面版佈局 (Desktop) ==================
    // 桌面版保持原樣，所有東西都在同一行
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

          // 中間：導覽圖示 (桌面版顯示在中間)
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