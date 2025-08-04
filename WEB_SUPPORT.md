# 地標識別應用 - Web 支援實現

## 問題描述
原本的應用只能在手機模擬器上辨識地標，需要在桌面瀏覽器上也能正常運作。

## 解決方案

### 主要修改
1. **VisionService 更新** (`lib/vision_service.dart`)
   - 支援 `File` (手機) 和 `XFile` (網頁) 兩種輸入格式
   - 統一的圖片處理邏輯
   - 錯誤處理改善

2. **主應用更新** (`lib/main.dart`)
   - 平台檢測：使用 `kIsWeb` 判斷是否為網頁平台
   - 圖片預覽：網頁使用 `Image.memory()`，手機使用 `Image.file()`
   - 動態圖片儲存：根據平台選擇適當的圖片格式

### 技術實現

#### 平台檢測
```dart
_imageInput = kIsWeb ? picked : File(picked.path);
```

#### 圖片預覽邏輯
```dart
Widget _buildImagePreview() {
  if (_imageInput == null) return const Text("尚未選擇圖片");
  
  if (kIsWeb) {
    // 網頁平台 - 使用 bytes 預覽
    if (_webImageBytes != null) {
      return Image.memory(_webImageBytes!, height: 200, fit: BoxFit.contain);
    }
  } else {
    // 手機平台 - 使用 File
    return Image.file(_imageInput as File, height: 200, fit: BoxFit.contain);
  }
}
```

#### Vision Service 改善
```dart
Future<String?> detectLandmark(dynamic imageInput) async {
  Uint8List bytes;
  
  if (imageInput is File) {
    bytes = await imageInput.readAsBytes();  // 手機
  } else if (imageInput is XFile) {
    bytes = await imageInput.readAsBytes();  // 網頁
  } else {
    throw ArgumentError('Unsupported image input type');
  }
  
  // 統一的 API 呼叫邏輯...
}
```

## 改善成果
- ✅ 手機模擬器：維持原有功能
- ✅ 桌面瀏覽器：新增支援
- ✅ 圖片預覽：兩個平台都能正常顯示
- ✅ 地標辨識：使用相同的 Google Vision API

## 使用方式
1. **手機/模擬器**：正常使用圖片選擇和辨識功能
2. **桌面瀏覽器**：
   - 使用 `flutter run -d chrome` 啟動網頁版本
   - 點擊「選擇照片」按鈕
   - 從電腦檔案系統選擇圖片
   - 等待 Google Vision API 回傳辨識結果

## 測試確認
已新增相關測試確保：
- UI 元件正確載入
- Vision Service 支援兩種輸入格式
- 錯誤情況妥善處理