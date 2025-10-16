// lib/pages/create_travel_article_page.dart (修改部分)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // 引入 LatLng
import '../models/travel_article_data.dart';
import '../services/openai_service.dart';
import '../services/location_service.dart'; // 引入 LocationService
import 'ai_edit_travel_article_page.dart';

class CreateTravelArticlePage extends StatefulWidget {
  const CreateTravelArticlePage({super.key});

  @override
  State<CreateTravelArticlePage> createState() => _CreateTravelArticlePageState();
}

class _CreateTravelArticlePageState extends State<CreateTravelArticlePage> {
  int _currentStep = 0;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TravelArticleData _articleData = TravelArticleData(
    userDescription: '',
  );

  final TextEditingController _placeNameInputController = TextEditingController(); // 用於地名輸入
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isGeneratingAIContent = false;
  bool _isSearchingPlace = false; // 新增：表示是否正在搜索地點

  XFile? _thumbnailImageFile;
  List<XFile> _materialImageFiles = [];

  @override
  void initState() {
    super.initState();
    // 確保 LocationService 在這裡被初始化，以防萬一
    // 更好的做法是在 main.dart 中應用啟動時初始化一次
    LocationService.initialize();
  }

  @override
  void dispose() {
    _placeNameInputController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    // ... (保持不變) ...
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final storageRef = FirebaseStorage.instance.ref().child('travel_article_images/$fileName');
      final uploadTask = await storageRef.putFile(File(imageFile.path));
      final imageUrl = await uploadTask.ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('圖片上傳失敗: $e')),
      );
      return null;
    }
  }

  // 修改：根據地名搜索地點並更新 _articleData
  Future<void> _searchPlace() async {
    if (_placeNameInputController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入地名')),
      );
      return;
    }

    setState(() {
      _isSearchingPlace = true;
    });

    try {
      final Map<String, dynamic>? result =
      await LocationService.searchPlaceByName(_placeNameInputController.text);

      if (result != null) {
        setState(() {
          _articleData.placeName = result['placeName'];
          _articleData.address = result['address'];
          // 注意：Firestore 的 GeoPoint 類型與 google_maps_flutter 的 LatLng 不同，需要轉換
          final LatLng latLng = result['location'];
          _articleData.location = GeoPoint(latLng.latitude, latLng.longitude);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地點已載入：${_articleData.placeName}')),
        );
      } else {
        setState(() {
          _articleData.placeName = null;
          _articleData.address = null;
          _articleData.location = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未能找到該地點的資訊，請檢查地名。')),
        );
      }
    } catch (e) {
      print("Error searching place: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索地點時發生錯誤: $e')),
      );
    } finally {
      setState(() {
        _isSearchingPlace = false;
      });
    }
  }

  Future<void> _pickThumbnail() async {
    // ... (保持不變) ...
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _thumbnailImageFile = pickedFile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('縮圖已選擇')),
      );
    }
  }

  Future<void> _pickMaterialImages() async {
    // ... (保持不變) ...
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _materialImageFiles.addAll(pickedFiles);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已選擇 ${_materialImageFiles.length} 張素材圖片')),
      );
    }
  }

  Future<void> _generateAIArticle() async {
    if (!_formKey.currentState!.validate()) {
      // 如果當前步驟的表單驗證失敗，則不繼續
      return;
    }

    setState(() {
      _isGeneratingAIContent = true;
    });

    try {
      // 1. 上傳縮圖
      String? thumbnailUrl;
      if (_thumbnailImageFile != null) {
        thumbnailUrl = await _uploadImage(_thumbnailImageFile!);
        if (thumbnailUrl == null) {
          throw Exception('縮圖上傳失敗。');
        }
      }
      _articleData.thumbnailUrl = thumbnailUrl;

      // 2. 上傳素材圖片
      List<String> uploadedMaterialUrls = [];
      for (XFile imageFile in _materialImageFiles) {
        String? url = await _uploadImage(imageFile);
        if (url != null) {
          uploadedMaterialUrls.add(url);
        }
      }
      _articleData.materialImageUrls = uploadedMaterialUrls;

      // 3. 調用 OpenAI 服務生成 HTML
      final String generatedHtml = await OpenAIService.generateTravelArticleHtml(
        userDescription: _articleData.userDescription,
        placeName: _articleData.placeName ?? '未知地點',
        materialImageUrls: _articleData.materialImageUrls,
      );
      _articleData.generatedHtmlContent = generatedHtml;

      setState(() {
        _isGeneratingAIContent = false;
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AiEditTravelArticlePage(articleData: _articleData),
        ),
      );
    } catch (e) {
      print('Error generating AI article: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 生成文章失敗: $e')),
      );
      setState(() {
        _isGeneratingAIContent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('創建遊記'),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          final isLastStep = _currentStep == getSteps().length - 1;
          if (_formKey.currentState!.validate()) { // 驗證當前步驟的表單
            if (isLastStep) {
              _generateAIArticle();
            } else {
              setState(() {
                _currentStep += 1;
              });
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: <Widget>[
                if (_currentStep < getSteps().length - 1)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('下一步'),
                  ),
                if (_currentStep == getSteps().length - 1)
                  _isGeneratingAIContent
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('AI 協助編輯'),
                  ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('上一步'),
                  ),
              ],
            ),
          );
        },
        steps: getSteps(),
      ),
    );
  }

  List<Step> getSteps() => [
    Step(
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 0,
      title: const Text('選擇地點'),
      content: Form(
        key: _formKey, // 使用表單鍵來驗證
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _placeNameInputController,
              decoration: InputDecoration(
                labelText: '輸入地名',
                hintText: '例如：台中歌劇院',
                border: const OutlineInputBorder(),
                suffixIcon: _isSearchingPlace
                    ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchPlace,
                ),
              ),
              onFieldSubmitted: (_) => _searchPlace(), // 回車鍵觸發搜索
              validator: (value) {
                if (_articleData.placeName == null || _articleData.placeName!.isEmpty) {
                  return '請搜索並選擇一個地點。';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            if (_articleData.placeName != null && _articleData.placeName!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //Text('地點名稱: ${_articleData.placeName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('地址: ${_articleData.address ?? '未知'}'),
                  Text('經緯度: ${_articleData.location?.latitude.toStringAsFixed(4) ?? ''}, ${_articleData.location?.longitude.toStringAsFixed(4) ?? ''}'),
                  const SizedBox(height: 10),
                  const Text('請確認地點資訊是否正確。')
                ],
              )
            else if (!_isSearchingPlace)
              const Text('請輸入地名並點擊搜索按鈕', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
    // 其他步驟保持不變...
    Step(
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 1,
      title: const Text('選擇縮圖'),
      content: Column(
        children: [
          _thumbnailImageFile != null
              ? Image.file(File(_thumbnailImageFile!.path), height: 150)
              : Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Center(child: Text('無縮圖')),
          ),
          ElevatedButton.icon(
            onPressed: _pickThumbnail,
            icon: const Icon(Icons.image),
            label: const Text('選擇縮圖'),
          ),
        ],
      ),
    ),
    Step(
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 2,
      title: const Text('選擇素材圖片'),
      content: Column(
        children: [
          if (_materialImageFiles.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _materialImageFiles.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.file(File(_materialImageFiles[index].path), width: 80, height: 80, fit: BoxFit.cover),
                  );
                },
              ),
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(child: Text('無素材圖片')),
            ),
          ElevatedButton.icon(
            onPressed: _pickMaterialImages,
            icon: const Icon(Icons.photo_library),
            label: const Text('選擇素材圖片'),
          ),
        ],
      ),
    ),
    Step(
      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 3,
      title: const Text('描述行程'),
      content: TextFormField(
        controller: _descriptionController,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: '描述你和誰一起去了哪裡，做了什麼，感受如何...',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '請描述你的行程，這對 AI 生成文章很重要。';
          }
          return null;
        },
        onChanged: (value) {
          _articleData.userDescription = value;
        },
      ),
    ),
    Step(
      state: _currentStep > 4 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 4,
      title: const Text('AI 協助編輯'),
      content: const Text('點擊 "AI 協助編輯" 按鈕，讓 AI 為你生成遊記草稿。'),
    ),
  ];
}