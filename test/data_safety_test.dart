import 'dart:convert';
import 'package:electrical_shop_manager/services/backup_validation.dart';
import 'package:electrical_shop_manager/services/shop_sync_service.dart';
import 'package:electrical_shop_manager/screens/finance_screen.dart';
import 'package:electrical_shop_manager/screens/sales_screen.dart';
import 'package:electrical_shop_manager/screens/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> backup() => {
  'format': 'electrical_shop_backup_v1',
  for (final type in [
    'products',
    'sales',
    'stock_receipts',
    'expenses',
    'repayments',
  ])
    'electrical_shop_${type}_v1': <Map<String, dynamic>>[],
};

void main() {
  testWidgets('Shop reset clears transactions and keeps inventory', (
    tester,
  ) async {
    const products = 'electrical_shop_products_v1';
    const purchases = 'electrical_shop_stock_receipts_v1';
    const transactions = [
      'electrical_shop_sales_v1',
      'electrical_shop_expenses_v1',
      'electrical_shop_repayments_v1',
    ];
    const inventory =
        '[{"id":"p1","quantity":12,"costPrice":5,"sellingPrice":8}]';
    const records = '[{"id":"r1","total":10,"amount":10}]';
    SharedPreferences.setMockInitialValues({
      products: inventory,
      purchases: records,
      for (final key in transactions) key: records,
    });
    await tester.pumpWidget(const MaterialApp(home: FinanceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Data backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset shop transactions'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(transactions.first), records);
    await tester.tap(find.text('Clear transactions'));
    await tester.pumpAndSettle();
    for (final key in transactions) {
      expect(prefs.getString(key), '[]');
    }
    expect(prefs.getString(products), inventory);
    expect(prefs.getString(purchases), records);
  });
  testWidgets('A sale reduces remaining stock value and preserves history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'electrical_shop_products_v1': jsonEncode([
        {
          'id': 'p1',
          'name': 'Cable',
          'category': 'Wiring',
          'costPrice': 5,
          'sellingPrice': 12,
          'quantity': 20,
          'lowStockLimit': 2,
        },
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: SalesScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Cable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm sale'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final sales =
        jsonDecode(prefs.getString('electrical_shop_sales_v1')!) as List;
    expect(sales.single['total'], 12);
    expect(sales.single['items'].single['unitCost'], 5);
    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('GHS 95.00'), findsWidgets);
    expect(find.text('GHS 133.00'), findsWidgets);
    await prefs.setString(
      'electrical_shop_expenses_v1',
      jsonEncode([
        {
          'id': 'e1',
          'title': 'Transport',
          'category': 'Transport',
          'amount': 10,
        },
        {
          'id': 'e2',
          'title': 'Delivery',
          'category': 'Stock Purchase',
          'amount': 20,
        },
      ]),
    );
    await tester.pumpWidget(const MaterialApp(home: FinanceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses & profit'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Shop main capital'), 300);
    expect(find.text('GHS 218.00'), findsOneWidget);
  });
  testWidgets('Inventory actions fit a narrow phone screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('New purchase'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Sale rejects a price changed after adding to cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final product = {
      'id': 'p1',
      'name': 'Cable',
      'category': 'Wiring',
      'costPrice': 5,
      'sellingPrice': 10,
      'quantity': 20,
      'lowStockLimit': 2,
    };
    SharedPreferences.setMockInitialValues({
      'electrical_shop_products_v1': jsonEncode([product]),
    });
    await tester.pumpWidget(const MaterialApp(home: SalesScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Cable'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'electrical_shop_products_v1',
      jsonEncode([
        {...product, 'sellingPrice': 12},
      ]),
    );
    await tester.tap(find.text('Confirm sale'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prices changed for Cable'), findsOneWidget);
    expect(prefs.getString('electrical_shop_sales_v1'), isNull);
    expect(
      (jsonDecode(prefs.getString('electrical_shop_products_v1')!) as List)
          .single['quantity'],
      20,
    );
  });
  test('Backup rejects records that would break inventory', () {
    final data = backup();
    data['electrical_shop_products_v1'] = [
      {'id': 'broken'},
    ];
    expect(() => validateShopBackup(data), throwsFormatException);
    expect(() => validateShopBackup(backup()), returnsNormally);
  });
  test('Backup accepts legacy cost snapshots and MoMo sales', () {
    final data = backup();
    data['electrical_shop_sales_v1'] = [
      {
        'id': 's1',
        'date': DateTime.now().toIso8601String(),
        'total': 10,
        'payment': 'momo',
        'items': [
          {
            'productId': 'p1',
            'name': 'Cable',
            'quantity': 1,
            'unitPrice': 10,
            'lineTotal': 10,
          },
        ],
      },
    ];
    expect(() => validateShopBackup(data), returnsNormally);
  });
  test(
    'Sync stops on damaged records instead of treating them as deleted',
    () async {
      SharedPreferences.setMockInitialValues({
        'electrical_shop_products_v1': '{broken',
      });
      await expectLater(
        ShopSyncService.instance.pendingCount(),
        throwsA(isA<ShopSyncException>()),
      );
    },
  );
  testWidgets('Expense dialog saves safely after closing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: FinanceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses & profit'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add expense'), 300);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Expense name'),
      'Transport',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (GHS)'),
      '15',
    );
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final expenses =
        jsonDecode(prefs.getString('electrical_shop_expenses_v1')!) as List;
    expect(expenses.single['amount'], 15);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Repayment preserves sales added while the dialog is open', (
    tester,
  ) async {
    final sale = {
      'id': 's1',
      'customer': 'Ama',
      'payment': 'credit',
      'date': DateTime.now().toIso8601String(),
      'total': 100,
      'items': [],
    };
    SharedPreferences.setMockInitialValues({
      'electrical_shop_sales_v1': jsonEncode([sale]),
    });
    await tester.pumpWidget(const MaterialApp(home: FinanceScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record payment'));
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'electrical_shop_sales_v1',
      jsonEncode([
        sale,
        {...sale, 'id': 's2', 'customer': 'Kofi', 'total': 70},
      ]),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (GHS)'),
      '20',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final sales =
        jsonDecode(prefs.getString('electrical_shop_sales_v1')!) as List;
    expect(sales.length, 2);
    expect(sales.first['outstanding'], 80);
    expect(sales.last['total'], 70);
    expect(tester.takeException(), isNull);
  });
}
