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
  // 移除 _thumbnailFileName，因為它對 AI 生成和保存文章不是必須的
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
    // ... (保持不變) ...
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

  // 使用你提供的 _pickThumbnail 邏輯
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
        builder: (context) => const AlbumFolderPage(isPickingImage: true, allowMultiple: false), // 傳遞 allowMultiple 為 false
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedThumbnailUrl = result['imageUrl'] as String?;
        // _thumbnailFileName = result['fileName'] as String?; // 不需要保存文件名
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('縮圖已選擇')),
      );
    }
  }

  // 為素材圖片設計的選擇邏輯，假設 AlbumFolderPage 支持多選
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
        builder: (context) => const AlbumFolderPage(isPickingImage: true, allowMultiple: true), // 傳遞 allowMultiple 為 true
      ),
    );

    // 處理 AlbumFolderPage 返回的多選結果
    if (result != null && result is List<Map<String, dynamic>>) {
      setState(() {
        _selectedMaterialImageUrls = result.map((item) => item['imageUrl'] as String).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已選擇 ${_selectedMaterialImageUrls.length} 張素材圖片')),
      );
    } else if (result != null && result is Map<String, dynamic>) {
      // 兼容 AlbumFolderPage 在某些情況下可能只返回單張圖片（如果它不是完全多選的）
      setState(() {
        _selectedMaterialImageUrls = [result['imageUrl'] as String];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已選擇 1 張素材圖片')),
      );
    }
  }


  Future<void> _generateAIArticle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 驗證圖片是否已選擇 (可選，根據你的需求)
    // if (_selectedThumbnailUrl == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('請選擇縮圖。')),
    //   );
    //   return;
    // }
    // if (_selectedMaterialImageUrls.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('請選擇至少一張素材圖片。')),
    //   );
    //   return;
    // }

    setState(() {
      _isGeneratingAIContent = true;
    });

    try {
      _articleData.thumbnailUrl = _selectedThumbnailUrl;
      _articleData.materialImageUrls = _selectedMaterialImageUrls;

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
          if (_formKey.currentState!.validate()) {
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
      content: const Text('點擊 "AI 協助編輯" 按鈕，讓 AI 為你生成遊記草稿。'),
    ),
  ];
}