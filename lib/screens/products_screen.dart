import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../widgets/stock_purchase_dialog.dart';
import '../widgets/purchase_history_dialog.dart';

const String _productsStorageKey = 'electrical_shop_products_v1';
const String _stockReceiptsStorageKey = 'electrical_shop_stock_receipts_v1';

/// Notifies the inventory screen when a sale updates saved stock quantities.
final ValueNotifier<int> productStockChanged = ValueNotifier<int>(0);

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

  final Product? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _costController;
  late final TextEditingController _sellingController;
  late final TextEditingController _quantityController;
  late final TextEditingController _limitController;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _categoryController = TextEditingController(text: product?.category ?? '');
    _costController = TextEditingController(
      text: product?.costPrice.toString() ?? '',
    );
    _sellingController = TextEditingController(
      text: product?.sellingPrice.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: product?.quantity.toString() ?? '0',
    );
    _limitController = TextEditingController(
      text: product?.lowStockLimit.toString() ?? '5',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _quantityController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final cost = double.parse(_costController.text.trim());
    final selling = double.parse(_sellingController.text.trim());
    final quantity = int.parse(_quantityController.text.trim());
    final limit = int.parse(_limitController.text.trim());

    if (cost < 0 || selling < 0 || quantity < 0 || limit < 0) {
      setState(() => _errorMessage = 'Values cannot be negative.');
      return;
    }

    if (selling < cost) {
      setState(() => _errorMessage = 'Selling price is below the cost price.');
      return;
    }

    if (name.isEmpty || category.isEmpty) {
      setState(() => _errorMessage = 'Enter a product name and category.');
      return;
    }

    final original = widget.product;

    Navigator.of(context).pop(
      Product(
        id: original?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        category: category,
        costPrice: cost,
        sellingPrice: selling,
        quantity: quantity,
        lowStockLimit: limit,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool integer = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }

          if (number) {
            final input = value.trim();
            final parsed = integer
                ? int.tryParse(input)
                : double.tryParse(input);

            if (parsed == null) {
              return integer ? 'Enter a whole number' : 'Enter a valid amount';
            }
            if (!integer && !(parsed as double).isFinite) {
              return 'Enter a finite amount';
            }
            if (parsed < 0) {
              return 'Values cannot be negative';
            }
          }

          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.product == null ? 'Add product' : 'Edit product'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_nameController, 'Product name'),
                _field(_categoryController, 'Category'),
                _field(_costController, 'Cost price (GHS)', number: true),
                _field(_sellingController, 'Selling price (GHS)', number: true),
                _field(
                  _quantityController,
                  'Quantity in stock',
                  number: true,
                  integer: true,
                ),
                _field(
                  _limitController,
                  'Low-stock limit',
                  number: true,
                  integer: true,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save product')),
      ],
    );
  }
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final List<Product> _products = [];

  String _search = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    productStockChanged.addListener(_refreshProducts);
    _loadProducts();
  }

  @override
  void dispose() {
    productStockChanged.removeListener(_refreshProducts);
    super.dispose();
  }

  void _refreshProducts() {
    if (mounted) _loadProducts();
  }

  String money(double value) => 'GHS ${value.toStringAsFixed(2)}';

  List<Product> get _filteredProducts {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) return List<Product>.from(_products);

    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();
  }

  Map<String, dynamic> _productToMap(Product product) {
    return {
      'id': product.id,
      'name': product.name,
      'category': product.category,
      'costPrice': product.costPrice,
      'sellingPrice': product.sellingPrice,
      'quantity': product.quantity,
      'lowStockLimit': product.lowStockLimit,
    };
  }

  Product _productFromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      costPrice: (map['costPrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      lowStockLimit: (map['lowStockLimit'] as num).toInt(),
    );
  }

  Future<void> _loadProducts() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedData = preferences.getString(_productsStorageKey);

      if (savedData != null) {
        final decoded = jsonDecode(savedData) as List<dynamic>;

        final loadedProducts = decoded.map((item) {
          return _productFromMap(Map<String, dynamic>.from(item as Map));
        }).toList();

        if (!mounted) return;

        setState(() {
          _products
            ..clear()
            ..addAll(loadedProducts);
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _storageError =
            'Could not load saved products. Your saved data may need checking.';
      });

      debugPrint('Error loading products: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _persistProducts() async {
    if (mounted) {
      setState(() {
        _isSaving = true;
        _storageError = null;
      });
    }

    try {
      final preferences = await SharedPreferences.getInstance();

      final encoded = jsonEncode(_products.map(_productToMap).toList());

      final success = await preferences.setString(_productsStorageKey, encoded);

      if (!success) {
        throw Exception('Storage did not confirm the save.');
      }

      productStockChanged.value++;

      return true;
    } catch (error) {
      debugPrint('Error saving products: $error');

      if (mounted) {
        setState(() {
          _storageError = 'Could not save products. Please try again.';
        });
      }

      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showProductForm({Product? product}) async {
    final savedProduct = await showDialog<Product>(
      context: context,
      builder: (_) => _ProductFormDialog(product: product),
    );

    if (savedProduct == null || !mounted || _isSaving) return;

    final previousProducts = _products.map((item) {
      return Product(
        id: item.id,
        name: item.name,
        category: item.category,
        costPrice: item.costPrice,
        sellingPrice: item.sellingPrice,
        quantity: item.quantity,
        lowStockLimit: item.lowStockLimit,
      );
    }).toList();

    setState(() {
      if (product == null) {
        _products.add(savedProduct);
      } else {
        final index = _products.indexWhere((item) => item.id == product.id);

        if (index != -1) {
          _products[index] = savedProduct;
        }
      }
    });

    final saved = await _persistProducts();

    if (!saved && mounted) {
      setState(() {
        _products
          ..clear()
          ..addAll(previousProducts);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product was not saved. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${product.name}" from this inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted || _isSaving) return;

    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) return;

    final removedProduct = _products[index];

    setState(() {
      _products.removeAt(index);
    });

    final saved = await _persistProducts();

    if (!saved && mounted) {
      setState(() {
        _products.insert(index, removedProduct);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product could not be deleted from storage. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _receiveStock(Product product) =>
      _showRecordPurchaseDialog(initialProduct: product);

  Future<void> _showRecordPurchaseDialog({Product? initialProduct}) async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add products before recording a stock delivery.'),
        ),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockPurchaseDialog(
        products: List.of(_products),
        initialProduct: initialProduct,
      ),
    );
    if (saved != true || !mounted) return;
    productStockChanged.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Stock delivery saved. Inventory and purchase history updated.',
        ),
      ),
    );
  }

  Future<void> _showPurchaseHistoryDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_stockReceiptsStorageKey);
      final receipts = raw == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(raw) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => PurchaseHistoryDialog(receipts: receipts),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load purchase history. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final lowStockCount = _products.where((p) => p.isLowStock).length;
    final expectedStockProfit = _products.fold<double>(
      0,
      (sum, product) => sum + product.profitPerItem * product.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (MediaQuery.sizeOf(context).width < 600)
            IconButton(
              tooltip: 'New purchase',
              onPressed: _isLoading || _isSaving
                  ? null
                  : () => _showRecordPurchaseDialog(),
              icon: const Icon(Icons.add_shopping_cart),
            )
          else
            FilledButton.icon(
              onPressed: _isLoading || _isSaving
                  ? null
                  : () => _showRecordPurchaseDialog(),
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('New purchase'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0879E8),
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width < 600)
            IconButton(
              tooltip: 'Add product',
              onPressed: _isLoading || _isSaving
                  ? null
                  : () => _showProductForm(),
              icon: const Icon(Icons.add),
            )
          else
            OutlinedButton.icon(
              onPressed: _isLoading || _isSaving
                  ? null
                  : () => _showProductForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add product'),
            ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Purchase history',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showPurchaseHistoryDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_storageError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.shade50,
                      child: Text(
                        _storageError!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    'Total products',
                                    '${_products.length}',
                                    Icons.inventory_2_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statCard(
                                    'Low stock',
                                    '$lowStockCount',
                                    Icons.warning_amber_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _statCard(
                              'Expected profit in current stock',
                              money(expectedStockProfit),
                              Icons.trending_up_rounded,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Search products or categories',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFFFFFF),
                              ),
                              onChanged: (value) {
                                setState(() => _search = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: products.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 48,
                                          color: Color(0xFF647891),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _search.isEmpty
                                              ? 'No products added yet'
                                              : 'No matching products found',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Add your first electrical appliance to begin.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];

                              return Card(
                                color: Colors.white,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F7EF),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.electrical_services,
                                              color: Color(0xFF0879E8),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  product.category,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showProductForm(
                                                  product: product,
                                                );
                                              } else if (value == 'receive') {
                                                _receiveStock(product);
                                              } else if (value == 'delete') {
                                                _deleteProduct(product);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'receive',
                                                child: Text('Receive stock'),
                                              ),
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Wrap(
                                        spacing: 20,
                                        runSpacing: 10,
                                        children: [
                                          _detail(
                                            'Cost',
                                            money(product.costPrice),
                                          ),
                                          _detail(
                                            'Selling',
                                            money(product.sellingPrice),
                                          ),
                                          _detail(
                                            'Profit per item',
                                            money(product.profitPerItem),
                                          ),
                                          _detail(
                                            'Profit in stock',
                                            money(
                                              product.profitPerItem *
                                                  product.quantity,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.inventory, size: 18),
                                          const SizedBox(width: 6),
                                          Text('In stock: ${product.quantity}'),
                                          const Spacer(),
                                          if (product.isLowStock)
                                            const Chip(
                                              avatar: Icon(
                                                Icons.warning_amber_rounded,
                                                size: 18,
                                              ),
                                              label: Text('Low stock'),
                                              backgroundColor: Color(
                                                0xFFFFF0D9,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF0879E8)),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
