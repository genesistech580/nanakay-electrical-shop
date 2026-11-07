import 'dart:convert';

import 'package:electrical_shop_manager/screens/products_screen.dart';
import 'package:electrical_shop_manager/screens/finance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Profit deducts sold stock costs and operating expenses once', (
    tester,
  ) async {
    final date = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'electrical_shop_sales_v1': jsonEncode([
        {
          'id': 's1',
          'date': date,
          'total': 100,
          'payment': 'cash',
          'items': [
            {'unitCost': 4, 'unitPrice': 10, 'quantity': 10},
          ],
        },
      ]),
      'electrical_shop_expenses_v1': jsonEncode([
        {
          'id': 'e1',
          'title': 'Cable stock',
          'date': date,
          'category': 'Stock Purchase',
          'amount': 80,
        },
        {
          'id': 'e2',
          'title': 'Transport',
          'date': date,
          'category': 'Transport',
          'amount': 10,
        },
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: FinanceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses & profit'));
    await tester.pumpAndSettle();
    expect(find.text('GHS 50.00'), findsWidgets);
    expect(find.text('GHS -30.00'), findsNothing);
  });

  testWidgets('Purchase rejects invalid amounts and saves stock and expense', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'electrical_shop_products_v1': jsonEncode([
        {
          'id': 'p1',
          'name': 'Cable',
          'category': 'Wiring',
          'costPrice': 5,
          'sellingPrice': 12,
          'quantity': 10,
          'lowStockLimit': 2,
        },
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New purchase'));
    await tester.pumpAndSettle();
    final quantity = find.widgetWithText(TextFormField, 'Quantity purchased');
    final amount = find.widgetWithText(
      TextFormField,
      'Total amount spent (GHS)',
    );
    await tester.enterText(quantity, '4');
    await tester.enterText(amount, 'NaN');
    await tester.ensureVisible(find.text('Save purchase'));
    await tester.tap(find.text('Save purchase'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount.'), findsOneWidget);
    await tester.enterText(amount, '32');
    await tester.ensureVisible(find.text('Save purchase'));
    await tester.tap(find.text('Save purchase'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final products =
        jsonDecode(prefs.getString('electrical_shop_products_v1')!) as List;
    expect(products.single['quantity'], 14);
    expect(products.single['costPrice'], closeTo(82 / 14, 0.00001));
    final receipts =
        jsonDecode(prefs.getString('electrical_shop_stock_receipts_v1')!)
            as List;
    expect(receipts.single['amountSpent'], 32);
    expect(prefs.getString('electrical_shop_expenses_v1'), isNull);
  });
}
