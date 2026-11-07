import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrical_shop_manager/main.dart';
import 'package:electrical_shop_manager/services/supabase_config.dart';
import 'package:electrical_shop_manager/theme/shop_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('ShopSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseProjectUrl,
      publishableKey: supabasePublishableKey,
    );
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets('Dashboard keeps existing navigation at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'electrical_shop_products_v1': jsonEncode([
          {
            'id': 'p1',
            'name': 'LED bulb 12 W',
            'category': 'Lighting',
            'costPrice': 12,
            'sellingPrice': 20,
            'quantity': 24,
            'lowStockLimit': 5,
          },
          {
            'id': 'p2',
            'name': 'Double wall socket',
            'category': 'Accessories',
            'costPrice': 35,
            'sellingPrice': 55,
            'quantity': 16,
            'lowStockLimit': 5,
          },
        ]),
        'electrical_shop_sales_v1': jsonEncode([
          {
            'id': 's1',
            'date': DateTime.now().toIso8601String(),
            'total': 640,
            'payment': 'cash',
            'items': [
              {
                'productId': 'p1',
                'name': 'LED bulb 12 W',
                'unitCost': 12,
                'unitPrice': 20,
                'quantity': 32,
                'lineTotal': 640,
              },
            ],
          },
        ]),
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildShopTheme(),
          home: RepaintBoundary(key: boundaryKey, child: const ShopDashboard()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final asset in [
          'assets/brand/nanakay_mark_light.png',
          'assets/brand/nanakay_mark_dark.png',
        ]) {
          await precacheImage(AssetImage(asset), boundaryKey.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/design-preview').create(recursive: true);
        await File(
          'build/design-preview/dashboard-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('Open products'));
      await tester.pumpAndSettle();
      expect(find.text('Expected profit in current stock'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/design-preview/products-${width.toInt()}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
