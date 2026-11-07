import 'dart:convert';
import 'dart:io';
import 'package:electrical_shop_manager/screens/finance_screen.dart';
import 'package:electrical_shop_manager/screens/products_screen.dart';
import 'package:electrical_shop_manager/services/customer_receipt.dart';
import 'package:electrical_shop_manager/services/shop_profile.dart';
import 'package:electrical_shop_manager/services/stock_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> product(String id, String name) => {
  'id': id,
  'name': name,
  'category': 'Electrical',
  'quantity': 10,
  'costPrice': 5,
  'sellingPrice': 12,
  'lowStockLimit': 2,
};

void main() {
  test(
    'Bulk delivery updates all products and keeps spending out of expenses',
    () async {
      SharedPreferences.setMockInitialValues({
        'electrical_shop_products_v1': jsonEncode([
          product('a', 'Cable'),
          product('b', 'Socket'),
        ]),
      });
      await recordStockPurchase(
        lines: const [
          PurchaseLine(productId: 'a', quantity: 10, amount: 70),
          PurchaseLine(productId: 'b', quantity: 5, amount: 40),
        ],
        date: DateTime.now(),
        supplier: 'Wholesale delivery',
      );
      final prefs = await SharedPreferences.getInstance();
      final products =
          jsonDecode(prefs.getString('electrical_shop_products_v1')!) as List;
      expect(products[0]['quantity'], 20);
      expect(products[0]['costPrice'], 6);
      expect(products[1]['quantity'], 15);
      expect(products[1]['costPrice'], 6);
      final receipts =
          jsonDecode(prefs.getString('electrical_shop_stock_receipts_v1')!)
              as List;
      expect(receipts.length, 2);
      expect(receipts[0]['batchId'], receipts[1]['batchId']);
      expect(prefs.getString('electrical_shop_expenses_v1'), isNull);
    },
  );
  test(
    'Invalid product in a bulk delivery leaves all stock unchanged',
    () async {
      final original = jsonEncode([product('a', 'Cable')]);
      SharedPreferences.setMockInitialValues({
        'electrical_shop_products_v1': original,
      });
      await expectLater(
        recordStockPurchase(
          lines: const [
            PurchaseLine(productId: 'a', quantity: 2, amount: 10),
            PurchaseLine(productId: 'missing', quantity: 1, amount: 5),
          ],
          date: DateTime.now(),
        ),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('electrical_shop_products_v1'), original);
      expect(prefs.getString('electrical_shop_stock_receipts_v1'), isNull);
    },
  );
  testWidgets('User can enter two products in one purchase dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'electrical_shop_products_v1': jsonEncode([
        product('a', 'Cable'),
        product('b', 'Socket'),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New purchase'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantity purchased').first,
      '5',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Total amount spent (GHS)').first,
      '25',
    );
    await tester.ensureVisible(find.text('Add another product'));
    await tester.tap(find.text('Add another product'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>).last,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Socket (10 in stock)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantity purchased').last,
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Total amount spent (GHS)').last,
      '18',
    );
    await tester.tap(find.text('Save purchase'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final receipts =
        jsonDecode(prefs.getString('electrical_shop_stock_receipts_v1')!)
            as List;
    expect(receipts.length, 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Purchase history'));
    await tester.pumpAndSettle();
    expect(find.text('Stock delivery'), findsOneWidget);
    await tester.tap(find.text('Stock delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery total: GHS 43.00'), findsOneWidget);
  });
  testWidgets(
    'Expense editing preserves its date and deletion requires confirmation',
    (tester) async {
      final date = DateTime.now().toIso8601String();
      SharedPreferences.setMockInitialValues({
        'electrical_shop_expenses_v1': jsonEncode([
          {
            'id': 'e1',
            'title': 'Transport',
            'amount': 10,
            'category': 'Transport',
            'date': date,
            'note': '',
          },
        ]),
      });
      await tester.pumpWidget(const MaterialApp(home: FinanceScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expenses & profit'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Expense actions'), 300);
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit expense'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (GHS)'),
        '25',
      );
      await tester.tap(find.text('Save expense'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      var expenses =
          jsonDecode(prefs.getString('electrical_shop_expenses_v1')!) as List;
      expect(expenses.single['amount'], 25);
      expect(expenses.single['date'], date);
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expenses =
          jsonDecode(prefs.getString('electrical_shop_expenses_v1')!) as List;
      expect(expenses.length, 1);
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete expense'));
      await tester.pumpAndSettle();
      expect(
        jsonDecode(prefs.getString('electrical_shop_expenses_v1')!),
        isEmpty,
      );
    },
  );
  test('Generate customer receipt preview and paginate long orders', () async {
    final logo = await File('assets/brand/nanakay_mark_dark.png').readAsBytes();
    final regularFont = await File(
      'assets/fonts/Roboto-Regular.ttf',
    ).readAsBytes();
    final boldFont = await File('assets/fonts/Roboto-Bold.ttf').readAsBytes();
    final sale = <String, dynamic>{
      'id': '202611070012',
      'date': DateTime(2026, 11, 7, 10, 35).toIso8601String(),
      'payment': 'cash',
      'customer': 'Sample customer',
      'customerPhone': '024 000 0000',
      'total': 680,
      'items': [
        {
          'name': 'Twin & earth cable - 2.5 mm',
          'quantity': 2,
          'unitPrice': 180,
          'lineTotal': 360,
        },
        {
          'name': 'Double switched socket',
          'quantity': 4,
          'unitPrice': 55,
          'lineTotal': 220,
        },
        {
          'name': 'LED bulb - warm white, 12 W',
          'quantity': 5,
          'unitPrice': 20,
          'lineTotal': 100,
        },
      ],
    };
    final pdf = await buildCustomerReceipt(
      sale: sale,
      shop: const ShopProfile(),
      logo: logo,
      regularFont: regularFont,
      boldFont: boldFont,
    );
    await Directory('output/pdf').create(recursive: true);
    await File('output/pdf/nanakay-receipt-preview.pdf').writeAsBytes(pdf);
    expect(pdf.length, greaterThan(1000));
    final longSale = {
      ...sale,
      'items': List.generate(
        70,
        (i) => {
          'name': 'Electrical fitting ${i + 1}',
          'quantity': 1,
          'unitPrice': 10,
          'lineTotal': 10,
        },
      ),
      'total': 700,
      'payment': 'credit',
      'outstanding': 500,
    };
    final longPdf = await buildCustomerReceipt(
      sale: longSale,
      shop: const ShopProfile(),
      logo: logo,
      regularFont: regularFont,
      boldFont: boldFont,
    );
    await Directory('build/receipt-qa').create(recursive: true);
    await File('build/receipt-qa/long-order.pdf').writeAsBytes(longPdf);
  });
}
