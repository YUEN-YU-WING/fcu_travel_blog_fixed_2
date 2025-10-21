import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 用於顯示網絡圖片
import 'package:firebase_auth/firebase_auth.dart'; // 用於檢查登入狀態

import '../models/travel_article_data.dart';
import '../services/openai_service.dart';
import '../services/location_service.dart';
import 'ai_edit_travel_article_page.dart';
import '../album_folder_page.dart'; // 引入你的 AlbumFolderPage

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

  final TextEditingController _placeNameInputController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isGeneratingAIContent = false;
  bool _isSearchingPlace = false;

  String? _selectedThumbnailUrl;
  List<String> _selectedMaterialImageUrls = [];

  @override
  void initState() {
    super.initState();
    LocationService.initialize();
  }

  @override
  void dispose() {
    _placeNameInputController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _searchPlace() async {
    final userInputPlaceName = _placeNameInputController.text.trim(); // 獲取用戶輸入並去除空白

    if (userInputPlaceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入地名')),
      );
      // 仍然需要更新 _articleData.placeName 以觸發 validator
      setState(() {
        _articleData.placeName = null;
        _articleData.address = null;
        _articleData.location = null;
      });
      return;
    }

    // 首先，直接使用用戶輸入作為 _articleData.placeName
    setState(() {
      _articleData.placeName = userInputPlaceName; // <-- 直接使用用戶輸入
      _isSearchingPlace = true; // 表示正在後台搜索地址和經緯度
    });


    try {
      final Map<String, dynamic>? result =
      await LocationService.searchPlaceByName(userInputPlaceName); // 仍然嘗試搜索以獲取地址和經緯度

      if (result != null) {
        setState(() {
          // 只更新地址和經緯度，不覆蓋用戶輸入的地名
          _articleData.address = result['address'];
          final LatLng latLng = result['location'];
          _articleData.location = GeoPoint(latLng.latitude, latLng.longitude);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地點資訊已載入：${result['address']}')),
        );
      } else {
        setState(() {
          // 如果沒有找到地點資訊，清空地址和經緯度
          _articleData.address = null;
          _articleData.location = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未能找到該地點的地址或經緯度資訊。')),
        );
      }
    } catch (e) {
      print("Error searching place: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索地點資訊時發生錯誤: $e')),
      );
    } finally {
      setState(() {
        _isSearchingPlace = false;
      });
      // 在搜索完成後，再次觸發表單驗證，確保用戶輸入的地名被正確設置
      _formKey.currentState?.validate();
    }
  }

  Future<void> _pickThumbnail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能選擇圖片')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlbumFolderPage(isPickingImage: true, allowMultiple: false),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedThumbnailUrl = result['imageUrl'] as String?;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('縮圖已選擇')),
      );
    }
  }

  Future<void> _pickMaterialImages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能選擇圖片')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlbumFolderPage(isPickingImage: true, allowMultiple: true),
      ),
    );

    if (result != null && result is List<Map<String, dynamic>>) {
      setState(() {
        _selectedMaterialImageUrls = result.map((item) => item['imageUrl'] as String).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已選擇 ${_selectedMaterialImageUrls.length} 張素材圖片')),
      );
    } else if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedMaterialImageUrls = [result['imageUrl'] as String];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已選擇 1 張素材圖片')),
      );
    }
  }


  Future<void> _generateAIArticle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isGeneratingAIContent = true;
    });

    try {
      _articleData.thumbnailUrl = _selectedThumbnailUrl;
      _articleData.materialImageUrls = _selectedMaterialImageUrls;

      // 確保這裡使用 _articleData.placeName，它現在直接來源於用戶輸入
      final String generatedHtml = await OpenAIService.generateTravelArticleHtml(
        userDescription: _articleData.userDescription,
        placeName: _articleData.placeName ?? _placeNameInputController.text.trim(), // fallback 到輸入框
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
          // 在繼續下一步之前，先觸發表單驗證
          if (_formKey.currentState!.validate()) {
            final isLastStep = _currentStep == getSteps().length - 1;
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
        key: _formKey,
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
              onFieldSubmitted: (_) => _searchPlace(),
              onChanged: (value) {
                // 當用戶輸入改變時，直接更新 _articleData.placeName
                // 並將地址和經緯度重置，等待用戶點擊搜索按鈕
                setState(() {
                  _articleData.placeName = value.trim();
                  _articleData.address = null;
                  _articleData.location = null;
                });
                _formKey.currentState?.validate(); // 實時驗證
              },
              validator: (value) {
                // 驗證器只檢查用戶輸入的地名是否為空
                if (value == null || value.trim().isEmpty) {
                  return '請輸入一個地名。';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            // 這裡顯示用戶輸入的地名，以及後台搜索到的地址和經緯度 (如果有)
            if (_articleData.placeName != null && _articleData.placeName!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('您輸入的地名: ${_articleData.placeName}'),
                  if (_articleData.address != null && _articleData.address!.isNotEmpty)
                    Text('匹配到的地址: ${_articleData.address}'),
                  if (_articleData.location != null)
                    Text('匹配到的經緯度: ${_articleData.location?.latitude.toStringAsFixed(4) ?? ''}, ${_articleData.location?.longitude.toStringAsFixed(4) ?? ''}'),
                  if (_articleData.address == null && !_isSearchingPlace)
                    const Text('未能找到該地點的地址或經緯度資訊。', style: TextStyle(color: Colors.orange)),
                  const SizedBox(height: 10),
                  const Text('此處顯示的「您輸入的地名」將用於遊記文章。'),
                ],
              )
            else if (!_isSearchingPlace)
              const Text('請輸入地名並點擊搜索按鈕以獲取額外資訊', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
    Step(
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 1,
      title: const Text('選擇縮圖'),
      content: Column(
        children: [
          _selectedThumbnailUrl != null
              ? CachedNetworkImage(
            imageUrl: _selectedThumbnailUrl!,
            height: 150,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[300], height: 150),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200], height: 150,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          )
              : Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Center(child: Text('無縮圖')),
          ),
          ElevatedButton.icon(
            onPressed: _pickThumbnail,
            icon: const Icon(Icons.image),
            label: const Text('從相簿選擇縮圖'),
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
          if (_selectedMaterialImageUrls.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMaterialImageUrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: CachedNetworkImage(
                      imageUrl: _selectedMaterialImageUrls[index],
                      width: 80, height: 80, fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
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
            label: const Text('從相簿選擇素材圖片'),
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
      content: const Text('點擊 "AI 協助編輯" 按鈕，讓 AI 為你生成遊記草稿，可能會花費數分鐘'),
    ),
  ];
}