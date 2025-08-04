// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcu_travel_blog_fixed_2/main.dart';

void main() {
  testWidgets('Landmark detection app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title and button are present.
    expect(find.text('地標辨識'), findsOneWidget);
    expect(find.text('選擇照片'), findsOneWidget);
    expect(find.text('尚未選擇圖片'), findsOneWidget);
  });

  testWidgets('Initial state shows correct UI elements', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify initial state
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('尚未選擇圖片'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
