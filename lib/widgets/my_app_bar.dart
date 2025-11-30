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

  // ✅ 新增：目前選中的分頁索引 (0: 首頁, 1: 行程)
  final int currentIndex;

  const MyAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.isMobile = false,
    this.onMenuTap,
    this.isHomePage = false,
    this.onHomeNavigate,
    this.onNotificationsTap,
    this.onAvatarTap,
    this.avatarUrl,
    this.onSearch,
    this.onNavIconTap,
    this.currentIndex = 0, // 預設為 0
  });

  @override
  State<MyAppBar> createState() => _MyAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (isMobile ? 48.0 : 0.0));
}

class _MyAppBarState extends State<MyAppBar> {
  late TextEditingController _searchController;
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
    // ✅ 根據 currentIndex 判斷是否啟用
    final bool isActive = widget.isHomePage && widget.currentIndex == 0;

    return IconButton(
      tooltip: '首頁',
      icon: Icon(
        isActive ? Icons.home_rounded : Icons.home_outlined,
        color: isActive ? Colors.blue[700] : Colors.black54,
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
          if (widget.isMobile) setState(() => _isMobileSearchExpanded = false);
        }
        widget.onNavIconTap?.call(0);
      },
    );
  }

  // ✅ 抽取行程按鈕邏輯
  Widget _buildMapNavItem(BuildContext context) {
    final bool isActive = widget.isHomePage && widget.currentIndex == 1;

    return IconButton(
      icon: Icon(isActive ? Icons.map : Icons.map_outlined), // 選中時用實心圖示
      color: isActive ? Colors.blue[700] : Colors.black54,   // 選中時變色
      onPressed: () => widget.onNavIconTap?.call(1),
      tooltip: '行程',
    );
  }

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
        autofocus: isMobile,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          widget.onSearch?.call(value);
        },
        decoration: InputDecoration(
          hintText: widget.currentIndex == 1 ? '搜尋行程...' : '搜尋文章...', // 根據分頁改變提示文字
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
          icon: const Icon(Icons.menu, color: Colors.black54),
          onPressed: widget.onMenuTap,
        ),
        title: _isMobileSearchExpanded
            ? Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: _buildSearchField(isMobile: true),
        )
            : Row(
          children: [
            Text(
              'B',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            height: 48.0,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black12, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHomeMainNavItem(context),
                _buildMapNavItem(context), // 使用新的方法
              ],
            ),
          ),
        ),
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
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHomeMainNavItem(context),
                _buildMapNavItem(context), // 使用新的方法
              ],
            ),
          ),
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