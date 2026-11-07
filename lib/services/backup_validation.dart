/// Validate the entire backup before replacing any local records.
void validateShopBackup(dynamic backup) {
  if (backup is! Map || backup['format'] != 'electrical_shop_backup_v1') {
    throw const FormatException('This is not a supported shop backup.');
  }
  Never invalid() => throw const FormatException(
    'Backup contains missing or invalid shop records. Nothing was restored.',
  );
  bool text(dynamic value) => value is String && value.trim().isNotEmpty;
  bool number(dynamic value) => value is num && value.isFinite && value >= 0;
  bool whole(dynamic value) => number(value) && value == value.truncate();
  bool date(dynamic value) =>
      value is String && DateTime.tryParse(value) != null;
  for (final type in [
    'products',
    'sales',
    'stock_receipts',
    'expenses',
    'repayments',
  ]) {
    final rows = backup['electrical_shop_${type}_v1'];
    if (rows is! List) invalid();
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map || !text(row['id']) || !ids.add(row['id'] as String)) {
        invalid();
      }
      if (type == 'products') {
        if (!text(row['name']) ||
            !text(row['category']) ||
            !number(row['costPrice']) ||
            !number(row['sellingPrice']) ||
            !whole(row['quantity']) ||
            !whole(row['lowStockLimit'])) {
          invalid();
        }
      } else {
        if (!date(row['date'])) invalid();
        if (type == 'sales') {
          if (!number(row['total']) ||
              !['cash', 'momo', 'credit'].contains(row['payment'])) {
            invalid();
          }
          if (row['outstanding'] != null &&
              (!number(row['outstanding']) ||
                  row['outstanding'] > row['total'])) {
            invalid();
          }
          final items = row['items'];
          if (items is! List || items.isEmpty) invalid();
          for (final item in items) {
            if (item is! Map ||
                !text(item['productId']) ||
                !text(item['name']) ||
                !whole(item['quantity']) ||
                item['quantity'] == 0 ||
                !number(item['unitPrice']) ||
                !number(item['lineTotal']) ||
                (item['unitCost'] != null && !number(item['unitCost']))) {
              invalid();
            }
          }
        } else if (type == 'stock_receipts') {
          if (!text(row['productId']) ||
              !text(row['productName']) ||
              !whole(row['quantity']) ||
              row['quantity'] == 0 ||
              (row['amountSpent'] != null && !number(row['amountSpent'])) ||
              (row['unitCost'] != null && !number(row['unitCost']))) {
            invalid();
          }
        } else {
          if (!number(row['amount'])) invalid();
          if (type == 'expenses' &&
              (!text(row['title']) || !text(row['category']))) {
            invalid();
          }
          if (type == 'repayments' && !text(row['customer'])) invalid();
        }
        for (final key in ['customer', 'customerPhone', 'note']) {
          if (row[key] != null && row[key] is! String) invalid();
        }
      }
    }
  }
}
