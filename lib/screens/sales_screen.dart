import 'dart:convert';
import '../services/shop_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/customer_receipt.dart';
import '../services/shop_profile.dart';
import '../widgets/shop_profile_dialog.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../widgets/pdf_document_preview_screen.dart';
import 'products_screen.dart';

const _productsKey = 'electrical_shop_products_v1';
const _salesKey = 'electrical_shop_sales_v1';
const _navy = Color(0xFF24352F);
const _blue = Color(0xFF3D6555);

enum SalePayment { cash, momo, credit }

class _CartLine {
  _CartLine(this.product, this.quantity);
  final Product product;
  int quantity;
  double get total => product.sellingPrice * quantity;
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<Product> _products = [];
  List<Map<String, dynamic>> _history = [];
  final Map<String, _CartLine> _cart = {};
  final _searchController = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  bool _showHistory = false;
  String? _error;
  SalePayment _payment = SalePayment.cash;
  final _customerController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    productStockChanged.addListener(_refreshProducts);
    _load();
  }

  @override
  void dispose() {
    productStockChanged.removeListener(_refreshProducts);
    _searchController.dispose();
    _customerController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  void _refreshProducts() {
    _load();
  }

  Product _product(Map<String, dynamic> m) => Product(
    id: m['id'] as String,
    name: m['name'] as String,
    category: m['category'] as String,
    costPrice: (m['costPrice'] as num).toDouble(),
    sellingPrice: (m['sellingPrice'] as num).toDouble(),
    quantity: (m['quantity'] as num).toInt(),
    lowStockLimit: (m['lowStockLimit'] as num).toInt(),
  );

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_productsKey);
      final list = raw == null
          ? <Product>[]
          : (jsonDecode(raw) as List)
                .map((e) => _product(Map<String, dynamic>.from(e as Map)))
                .toList();
      final rawSales = prefs.getString(_salesKey);
      final history = rawSales == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(rawSales) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      if (mounted) {
        setState(() {
          _products
            ..clear()
            ..addAll(list);
          _history = history;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not load products. Check the Products page and try again.';
          _loading = false;
        });
      }
    }
  }

  List<Product> get _visibleProducts => _products
      .where(
        (p) =>
            p.quantity > 0 &&
            ('${p.name} ${p.category}'.toLowerCase().contains(
              _query.toLowerCase(),
            )),
      )
      .toList();
  double get _total => _cart.values.fold(0, (sum, line) => sum + line.total);
  String _money(double value) => 'GHS ${value.toStringAsFixed(2)}';
  String _saleId(Map<String, dynamic> sale) {
    final id = sale['id'] as String? ?? '';
    return id.length > 6 ? id.substring(id.length - 6) : id;
  }

  Future<void> _printReceipt(Map<String, dynamic> sale) async {
    try {
      final shop = sale['shop'] is Map
          ? ShopProfile.fromMap(Map<String, dynamic>.from(sale['shop'] as Map))
          : await ShopProfile.load();
      final logo = await rootBundle.load('assets/brand/nanakay_mark_dark.png');
      final regularFont = await rootBundle.load(
        'assets/fonts/Roboto-Regular.ttf',
      );
      final boldFont = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      if (!mounted) return;
      await showPdfDocumentPreview(
        context,
        title: 'Customer receipt',
        fileName: 'nanakay-receipt-${sale['id']}.pdf',
        buildPdf: (_) => buildCustomerReceipt(
          sale: sale,
          shop: shop,
          regularFont: regularFont.buffer.asUint8List(
            regularFont.offsetInBytes,
            regularFont.lengthInBytes,
          ),
          boldFont: boldFont.buffer.asUint8List(
            boldFont.offsetInBytes,
            boldFont.lengthInBytes,
          ),
          logo: logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not prepare this receipt. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _showReceipt(Map<String, dynamic> sale) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        icon: const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF159455),
          size: 34,
        ),
        title: Column(
          children: const [
            Text(
              'NANAKAY ELECTRICAL SHOP',
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3D6555),
              ),
            ),
            SizedBox(height: 4),
            Text('Sale recorded'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receipt #${_saleId(sale)}',
                style: const TextStyle(color: Color(0xFF68736D)),
              ),
              const SizedBox(height: 12),
              ...(sale['items'] as List<dynamic>).map((raw) {
                final item = Map<String, dynamic>.from(raw as Map);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${item['quantity']} × ${item['name']}'),
                      ),
                      Text(
                        _money((item['lineTotal'] as num).toDouble()),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _money((sale['total'] as num).toDouble()),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Receipt shop details',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: _saving ? null : () => showShopProfileDialog(context),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _printReceipt(sale);
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print receipt'),
          ),
        ],
      ),
    );
  }

  void _add(Product p) {
    setState(() {
      final line = _cart[p.id];
      if (line == null) {
        _cart[p.id] = _CartLine(p, 1);
      } else if (line.quantity < p.quantity) {
        line.quantity++;
      }
    });
  }

  Future<void> _confirmSale() async {
    if (_cart.isEmpty || _saving) return;
    if (_payment == SalePayment.credit &&
        _customerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the customer name for a credit sale.'),
        ),
      );
      return;
    }
    if (_payment == SalePayment.credit &&
        _customerPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the customer phone number for a credit sale.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final shop = await ShopProfile.load();
      final prefs = await SharedPreferences.getInstance();
      final rawProducts = prefs.getString(_productsKey);
      final stored = rawProducts == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(rawProducts) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      final byId = {for (final p in stored) p['id'] as String: p};
      for (final line in _cart.values) {
        final map = byId[line.product.id];
        if (map == null || (map['quantity'] as num).toInt() < line.quantity) {
          throw StateError(
            'Stock changed for ${line.product.name}. Refresh and review your cart.',
          );
        }
        if (map['sellingPrice'] != line.product.sellingPrice ||
            map['costPrice'] != line.product.costPrice) {
          throw StateError(
            'Prices changed for ${line.product.name}. Remove it from your cart and add it again.',
          );
        }
      }
      for (final line in _cart.values) {
        final map = byId[line.product.id]!;
        map['quantity'] = (map['quantity'] as num).toInt() - line.quantity;
      }
      final updatedProducts = stored
          .map((m) => byId[m['id'] as String]!)
          .toList();
      final existingSales = prefs.getString(_salesKey);
      final sales = existingSales == null
          ? <dynamic>[]
          : jsonDecode(existingSales) as List<dynamic>;
      final saleId = DateTime.now().microsecondsSinceEpoch.toString();
      final recordedSale = <String, dynamic>{
        'id': saleId,
        'date': DateTime.now().toIso8601String(),
        'payment': _payment.name,
        'customer': _customerController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'shop': shop.toMap(),
        'total': _total,
        'items': _cart.values
            .map(
              (l) => {
                'productId': l.product.id,
                'name': l.product.name,
                'quantity': l.quantity,
                'unitPrice': l.product.sellingPrice,
                'unitCost': l.product.costPrice,
                'lineTotal': l.total,
              },
            )
            .toList(),
      };
      sales.insert(0, recordedSale);
      await saveShopRecords(prefs, {
        _productsKey: jsonEncode(updatedProducts),
        _salesKey: jsonEncode(sales),
      });
      productStockChanged.value++;
      if (!mounted) return;
      setState(() {
        for (final p in _products) {
          final m = byId[p.id];
          if (m != null) p.quantity = (m['quantity'] as num).toInt();
        }
        _cart.clear();
        _history = sales
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _customerController.clear();
        _customerPhoneController.clear();
      });
      await _showReceipt(recordedSale);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'Could not record this sale. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showHistory ? 'Sales history' : 'Sales',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showHistory = !_showHistory),
            icon: Icon(
              _showHistory
                  ? Icons.add_shopping_cart
                  : Icons.receipt_long_outlined,
            ),
            label: Text(_showHistory ? 'New sale' : 'History'),
          ),
          IconButton(
            tooltip: 'Receipt shop details',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: _saving ? null : () => showShopProfileDialog(context),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _showHistory
          ? _historyView()
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final products = _visibleProducts;
                final picker = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _navy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFB67C3D)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.point_of_sale_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create a sale',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Choose products and confirm payment',
                                  style: TextStyle(
                                    color: Color(0xFFD7E1D9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search products',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: products.isEmpty
                          ? Center(
                              child: Text(
                                _products.isEmpty
                                    ? 'Add products before recording a sale.'
                                    : 'No matching products in stock.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final p = products[index];
                                final line = _cart[p.id];
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFE7EEE8),
                                      child: Icon(
                                        Icons.electrical_services,
                                        color: _blue,
                                      ),
                                    ),
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${p.category} · ${p.quantity} available · ${_money(p.sellingPrice)}',
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Add ${p.name}',
                                      onPressed:
                                          line != null &&
                                              line.quantity >= p.quantity
                                          ? null
                                          : () => _add(p),
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: _blue,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
                final checkout = _checkout(
                  compact: constraints.maxHeight < 520,
                );
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: picker),
                            const SizedBox(width: 20),
                            SizedBox(width: 360, child: checkout),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: picker),
                            if (_cart.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _openCheckout,
                                  icon: const Icon(Icons.shopping_bag_outlined),
                                  label: Text(
                                    'Review order · ${_money(_total)}',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                );
              },
            ),
    );
  }

  Widget _historyView() {
    if (_history.isEmpty) {
      return const Center(child: Text('No sales recorded yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final sale = _history[index];
        final date = DateTime.tryParse(
          sale['date'] as String? ?? '',
        )?.toLocal();
        final items = sale['items'] as List<dynamic>? ?? const [];
        final labels = items
            .map((e) {
              final item = Map<String, dynamic>.from(e as Map);
              return '${item['quantity']} × ${item['name']}';
            })
            .join(', ');
        final payment = (sale['payment'] as String? ?? 'cash').toUpperCase();
        final customer = (sale['customer'] as String? ?? '').trim();
        final customerPhone = (sale['customerPhone'] as String? ?? '').trim();
        return Card(
          child: ExpansionTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE7EEE8),
              child: Icon(Icons.receipt_long_outlined, color: _blue),
            ),
            title: Text(
              _money((sale['total'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
            ),
            subtitle: Text(
              '${date == null ? 'Date unavailable' : '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'} · $payment${customer.isEmpty ? '' : ' · $customer'}${customerPhone.isEmpty ? '' : ' · $customerPhone'}',
            ),
            children: [
              ListTile(
                title: Text(labels.isEmpty ? 'No item details' : labels),
                dense: true,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _printReceipt(sale),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print receipt'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCheckout() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final media = MediaQuery.of(context);
          final height =
              (media.size.height -
                      media.viewInsets.bottom -
                      media.viewPadding.top -
                      36)
                  .clamp(180.0, 760.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, media.viewInsets.bottom),
            child: SizedBox(
              height: height,
              child: _checkout(
                compact: true,
                onCartChanged: () => setSheetState(() {}),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _checkout({VoidCallback? onCartChanged, bool compact = false}) {
    final cartRows = _cart.values
        .map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${line.quantity} × ${_money(line.product.sellingPrice)}',
                        style: const TextStyle(color: Color(0xFF68736D)),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Remove one ${line.product.name}',
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  onPressed: () {
                    setState(() {
                      if (line.quantity == 1) {
                        _cart.remove(line.product.id);
                      } else {
                        line.quantity--;
                      }
                    });
                    onCartChanged?.call();
                  },
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${line.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Add one ${line.product.name}',
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  onPressed: line.quantity >= line.product.quantity
                      ? null
                      : () {
                          _add(line.product);
                          onCartChanged?.call();
                        },
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 4),
                Text(
                  _money(line.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        )
        .toList();
    final orderHeader = Row(
      children: [
        const Expanded(
          child: Text(
            'Current order',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
        ),
        Text(
          '${_cart.length} items',
          style: const TextStyle(color: Color(0xFF68736D)),
        ),
      ],
    );
    final Widget cartContents = _cart.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Add products to start an order.',
                style: TextStyle(color: Color(0xFF68736D)),
              ),
            ),
          )
        : compact
        ? Column(children: cartRows)
        : Expanded(child: ListView(children: cartRows));
    final fields = <Widget>[
      TextField(
        controller: _customerController,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: _payment == SalePayment.credit
              ? 'Customer name (required)'
              : 'Customer name (optional)',
          prefixIcon: const Icon(Icons.person_outline),
        ),
      ),
      if (_payment == SalePayment.credit) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _customerPhoneController,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Customer phone number (required)',
            hintText: '+233…',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
      ],
      const SizedBox(height: 12),
      DropdownButtonFormField<SalePayment>(
        initialValue: _payment,
        decoration: const InputDecoration(
          labelText: 'Payment method',
          prefixIcon: Icon(Icons.payment),
        ),
        items: const [
          DropdownMenuItem(value: SalePayment.cash, child: Text('Cash')),
          DropdownMenuItem(value: SalePayment.momo, child: Text('MoMo')),
          DropdownMenuItem(value: SalePayment.credit, child: Text('Credit')),
        ],
        onChanged: (value) {
          setState(() => _payment = value ?? SalePayment.cash);
          onCartChanged?.call();
        },
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          const Expanded(
            child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text(
            _money(_total),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _cart.isEmpty || _saving ? null : _confirmSale,
          icon: const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Recording…' : 'Confirm sale'),
        ),
      ),
      if (_payment == SalePayment.momo)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'MoMo is recorded as the payment method. No payment is initiated.',
            style: TextStyle(fontSize: 11, color: Color(0xFF68736D)),
          ),
        ),
    ];
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: compact
            ? SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    orderHeader,
                    const Divider(height: 24),
                    cartContents,
                    ...fields,
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  orderHeader,
                  const Divider(height: 24),
                  cartContents,
                  ...fields,
                ],
              ),
      ),
    );
  }
}
