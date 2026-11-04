
class Product {
  final String id;
  String name;
  String category;
  double costPrice;
  double sellingPrice;
  int quantity;
  int lowStockLimit;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.lowStockLimit,
  });

  bool get isLowStock => quantity <= lowStockLimit;

  double get profitPerItem => sellingPrice - costPrice;
}
