import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'shop_storage.dart';

class PurchaseLine {
  const PurchaseLine({
    required this.productId,
    required this.quantity,
    required this.amount,
  });
  final String productId;
  final int quantity;
  final double amount;
}

/// A delivery is inventory, not an operating expense. Costs enter profit at sale.
Future<void> recordStockPurchase({
  required List<PurchaseLine> lines,
  required DateTime date,
  String supplier = '',
  bool updateCost = true,
}) async {
  if (lines.isEmpty ||
      lines.any(
        (line) =>
            line.quantity <= 0 || !line.amount.isFinite || line.amount < 0,
      ) ||
      lines.map((line) => line.productId).toSet().length != lines.length) {
    throw StateError(
      'Choose each product once and enter valid quantities and amounts.',
    );
  }
  final prefs = await SharedPreferences.getInstance();
  List<Map<String, dynamic>> read(String key) {
    final raw = prefs.getString(key);
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
  }

  final products = read('electrical_shop_products_v1');
  final receipts = read('electrical_shop_stock_receipts_v1');
  final batchId = DateTime.now().microsecondsSinceEpoch.toString();
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final matches = products.where((row) => row['id'] == line.productId);
    if (matches.length != 1) {
      throw StateError(
        'A selected product is no longer available. Review this purchase.',
      );
    }
    final product = matches.single;
    final oldQty = (product['quantity'] as num).toInt();
    final oldCost = (product['costPrice'] as num).toDouble();
    product['quantity'] = oldQty + line.quantity;
    if (updateCost) {
      product['costPrice'] =
          (oldQty * oldCost + line.amount) / (oldQty + line.quantity);
    }
    receipts.insert(0, {
      'id': '$batchId-$index',
      'batchId': batchId,
      'productId': line.productId,
      'productName': product['name'],
      'quantity': line.quantity,
      'amountSpent': line.amount,
      'unitCost': line.amount / line.quantity,
      'date': date.toIso8601String(),
      'note': supplier,
    });
  }
  await saveShopRecords(prefs, {
    'electrical_shop_products_v1': jsonEncode(products),
    'electrical_shop_stock_receipts_v1': jsonEncode(receipts),
  });
}
