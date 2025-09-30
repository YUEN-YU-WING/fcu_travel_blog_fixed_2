import 'package:flutter/material.dart';
import 'package:flutter_markdown_editor/flutter_markdown_editor.dart';

/// 一個簡單的頁面：上方切換三個 Tab（垂直、內嵌、Custom）
/// - vertical(): 編輯 + 預覽左右/上下排版（依套件實作）
/// - inPlace(): 編輯與預覽在同一區域切換（套件提供）
/// - field / preview: 套件提供的可組合元件（可自訂 UI）

class MarkDownEditorPage extends StatefulWidget {
  const MarkDownEditorPage({super.key});
  @override
  State<MarkDownEditorPage> createState() => _MarkDownEditorPageState();
}

class _MarkDownEditorPageState extends State<MarkDownEditorPage> {
  // 建一個 MarkDownEditor 實例（套件內管理 editor/preview）
  // 注意：套件的 API 會把常用 widget 暴露為 markDownEditor.field / markDownEditor.preview
  final MarkDownEditor markDownEditor = MarkDownEditor();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('文章編輯器 (Markdown)'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.border_vertical), text: 'Vertical'),
              Tab(icon: Icon(Icons.switch_left), text: 'In Place'),
              Tab(icon: Icon(Icons.settings), text: 'Custom'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 套件提供的垂直布局（通常是 editor + preview）
            markDownEditor.vertical(),

            // 在地編輯（in-place 模式）
            markDownEditor.inPlace(),

            // 自訂組合：把編輯 field 與 preview 放在同一頁面（你可以自己包裝 UI）
            Column(
              children: [
                // editor field（可調高度或包 Container）
                Expanded(child: markDownEditor.field),
                const Divider(height: 1),
                // preview（實時渲染 Markdown）
                Expanded(child: markDownEditor.preview),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.save),
          label: const Text('取得內容'),
          onPressed: () async {
            // 套件的範例主要把 editor widget / preview widget 暴露出來。
            // 若你要讀出 markdown 原始字串（例如要儲存、送出），
            // 可看套件是否提供 controller 或直接用 TextEditingController 注入。
            //
            // 下面為通用示意：若套件有提供 controller 屬性，可像這樣取值：
            //
            // final raw = markDownEditor.controller.text;
            //
            // 範例套件可能把編輯框放在 markDownEditor.field；若沒有直接 controller 屬性，
            // 請參考該套件文件或 source code（github）來知道如何取值。
            //
            // 這裡先顯示一個提示（示範呼叫），你可以依需改成實際取 markdown 的程式。
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('提示'),
                content: const Text(
                  '套件的 example UI 已放入頁面。\n若要取出 markdown 原始字串，請檢查套件 API 是否提供 controller 或方法（參考 pub.dev / GitHub 範例）。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('關閉'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
