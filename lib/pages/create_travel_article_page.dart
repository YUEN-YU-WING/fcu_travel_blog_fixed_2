import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/travel_article_data.dart';
import '../services/openai_service.dart'; // 確保 OpenAIService 有更新以接收新參數
import '../services/location_service.dart';
import 'ai_edit_travel_article_page.dart';
import '../album_folder_page.dart';

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
  bool _isDetectingLandmark = false; // 用於縮圖識別
  bool _isDetectingMaterialImages = false; // 新增：用於素材圖片識別

  String? _selectedThumbnailUrl;
  List<String> _selectedMaterialImageUrls = [];
  Map<String, String> _materialImageDescriptions = {}; // 新增：儲存素材圖片的識別內容

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
    final userInputPlaceName = _placeNameInputController.text.trim();

    if (userInputPlaceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入地名')),
      );
      setState(() {
        _articleData.placeName = null;
        _articleData.address = null;
        _articleData.location = null;
      });
      return;
    }

    setState(() {
      _articleData.placeName = userInputPlaceName;
      _isSearchingPlace = true;
    });

    try {
      final Map<String, dynamic>? result =
      await LocationService.searchPlaceByName(userInputPlaceName);

      if (result != null) {
        setState(() {
          _articleData.address = result['address'];
          final LatLng latLng = result['location'];
          _articleData.location = GeoPoint(latLng.latitude, latLng.longitude);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('地點資訊已載入：${result['address']}')),
        );
      } else {
        setState(() {
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
      _formKey.currentState?.validate();
    }
  }

  // 稍微修改這個函數，讓它可以處理任何類型的圖片識別，並返回一個通用的描述字串
  // 假設後端服務會根據圖片內容返回最相關的描述
  Future<String?> _callImageDetectionService(String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/landmark'), // 後端服務路徑不變，但內部邏輯可能要調整
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 假設後端會返回一個更通用的 'description' 或 'label' 字段
        // 如果後端仍然返回 'landmark'，這裡會保持不變
        final String? detectedContent = data['landmark'] as String?;
        if (detectedContent != null && detectedContent.isNotEmpty) {
          return detectedContent;
        } else {
          return null;
        }
      } else {
        print('Error calling image detection service: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception calling image detection service: $e');
      return null;
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
      final String? pickedImageUrl = result['imageUrl'] as String?;
      setState(() {
        _selectedThumbnailUrl = pickedImageUrl;
        _placeNameInputController.text = '';
        _articleData.placeName = null;
        _articleData.address = null;
        _articleData.location = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('縮圖已選擇')),
      );

      if (pickedImageUrl != null) {
        setState(() {
          _isDetectingLandmark = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在識別圖片中的地標...')),
        );
        final String? landmark = await _callImageDetectionService(pickedImageUrl); // 使用通用的識別服務
        setState(() {
          _isDetectingLandmark = false;
        });

        if (landmark != null && landmark.isNotEmpty) {
          setState(() {
            _placeNameInputController.text = landmark;
            _articleData.placeName = landmark;
          });
          _searchPlace();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已識別到地標：$landmark，正在自動搜索地點資訊。')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未能識別到圖片中的地標，請手動輸入地名。')),
          );
        }
      }
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

    List<String> newSelectedUrls = [];
    if (result != null) {
      if (result is List<Map<String, dynamic>>) {
        newSelectedUrls = result.map((item) => item['imageUrl'] as String).toList();
      } else if (result is Map<String, dynamic>) {
        newSelectedUrls = [result['imageUrl'] as String];
      }
    }

    if (newSelectedUrls.isNotEmpty) {
      setState(() {
        _selectedMaterialImageUrls = newSelectedUrls;
        _isDetectingMaterialImages = true; // 開始識別素材圖片
        _materialImageDescriptions.clear(); // 清空之前的識別結果
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已選擇 ${_selectedMaterialImageUrls.length} 張素材圖片，正在識別內容...')),
      );

      // 逐一識別素材圖片
      for (String imageUrl in _selectedMaterialImageUrls) {
        final String? description = await _callImageDetectionService(imageUrl);
        if (description != null && description.isNotEmpty) {
          setState(() {
            _materialImageDescriptions[imageUrl] = description;
          });
          print('圖片 $imageUrl 識別結果: $description'); // 為了調試
        }
      }

      setState(() {
        _isDetectingMaterialImages = false; // 識別完成
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('素材圖片識別完成！共識別出 ${_materialImageDescriptions.length} 張圖片的內容。')),
      );
    } else {
      setState(() {
        _selectedMaterialImageUrls = [];
        _materialImageDescriptions.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未選擇任何素材圖片。')),
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

      // 將素材圖片的識別結果轉換成一個列表，以便傳遞給 OpenAI 服務
      final List<String> materialImageDescriptionsList = _selectedMaterialImageUrls.map((url) {
        return _materialImageDescriptions[url] ?? ''; // 如果沒有識別到，就傳空字串
      }).where((desc) => desc.isNotEmpty).toList(); // 只傳遞有內容的描述

      // 確保 OpenAIService.generateTravelArticleHtml 接收這個新參數
      final String generatedHtml = await OpenAIService.generateTravelArticleHtml(
        userDescription: _articleData.userDescription,
        placeName: _articleData.placeName ?? _placeNameInputController.text.trim(),
        materialImageUrls: _articleData.materialImageUrls,
        materialImageDescriptions: materialImageDescriptionsList, // 新增：傳遞素材圖片的識別內容
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
          if (_currentStep == 0) { // 如果是第一步（選擇縮圖），且縮圖是可選的，直接下一步
            setState(() {
              _currentStep += 1;
            });
          } else if (_formKey.currentState?.validate() ?? true) {
            final isLastStep = _currentStep == getSteps().length - 1;
            if (isLastStep) {
              _generateAIArticle();
            } else {
              setState(() {
                _currentStep += 1;
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('請完成當前步驟的必填項目')),
            );
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
      title: const Text('選擇縮圖（選填，可自動識別地點）'),
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
          if (_isDetectingLandmark)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_isDetectingLandmark)
            const Text('正在識別圖片中的地標...', style: TextStyle(color: Colors.blue)),
          const SizedBox(height: 10),
          const Text('選擇縮圖後，AI 會嘗試自動識別地標並填入下一步驟的地名。'),
        ],
      ),
    ),
    Step(
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 1,
      title: const Text('確認或輸入地點'),
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
                setState(() {
                  _articleData.placeName = value.trim();
                  _articleData.address = null;
                  _articleData.location = null;
                });
                _formKey.currentState?.validate();
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入一個地名。';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
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
              const Text('請輸入地名並點擊搜索按鈕以獲取額外資訊。', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
    Step(
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      isActive: _currentStep >= 2,
      title: const Text('選擇素材圖片（AI會分析圖片內容）'), // 更改標題
      content: Column(
        children: [
          if (_selectedMaterialImageUrls.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMaterialImageUrls.length,
                itemBuilder: (context, index) {
                  final String imageUrl = _selectedMaterialImageUrls[index];
                  final String? description = _materialImageDescriptions[imageUrl];
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 80, height: 80, fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[300]),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                        if (description != null && description.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
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
          if (_isDetectingMaterialImages) // 素材圖片識別時顯示進度指示器
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_isDetectingMaterialImages)
            const Text('正在識別素材圖片內容...', style: TextStyle(color: Colors.blue)),
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