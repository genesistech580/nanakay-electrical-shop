import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/stock_purchase_service.dart';

class _PurchaseDraft {
  _PurchaseDraft(this.id);
  String? id;
  final quantity = TextEditingController();
  final amount = TextEditingController();
  void dispose() {
    quantity.dispose();
    amount.dispose();
  }
}

class StockPurchaseDialog extends StatefulWidget {
  const StockPurchaseDialog({
    super.key,
    required this.products,
    this.initialProduct,
  });
  final List<Product> products;
  final Product? initialProduct;
  @override
  State<StockPurchaseDialog> createState() => _StockPurchaseDialogState();
}

class _StockPurchaseDialogState extends State<StockPurchaseDialog> {
  final _supplier = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _rows = <_PurchaseDraft>[];
  final _removedRows = <_PurchaseDraft>[];
  DateTime _date = DateTime.now();
  bool _busy = false;
  bool _updateCost = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _rows.add(
      _PurchaseDraft(widget.initialProduct?.id ?? widget.products.first.id),
    );
  }

  @override
  void dispose() {
    _supplier.dispose();
    for (final row in [..._rows, ..._removedRows]) {
      row.dispose();
    }
    super.dispose();
  }

  double get _total => _rows.fold<double>(0, (total, row) {
    final amount = double.tryParse(row.amount.text) ?? 0;
    return total + (amount.isFinite ? amount : 0);
  });
  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await recordStockPurchase(
        lines: _rows
            .map(
              (row) => PurchaseLine(
                productId: row.id!,
                quantity: int.parse(row.quantity.text.trim()),
                amount: double.parse(row.amount.text.trim()),
              ),
            )
            .toList(),
        date: _date,
        supplier: _supplier.text.trim(),
        updateCost: _updateCost,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is StateError
              ? error.message
              : 'Could not save this delivery. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: const Text('New stock purchase'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Record all the goods in one delivery. Inventory increases together; this purchase does not reduce estimated profit.',
                style: TextStyle(color: Color(0xFF68736D), height: 1.5),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _supplier,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Supplier / delivery note (optional)',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null && mounted) {
                          setState(() => _date = date);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  'Purchase date: ${_date.day}/${_date.month}/${_date.year}',
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _rows.length; i++) _line(_rows[i], i),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _rows.add(_PurchaseDraft(null))),
                icon: const Icon(Icons.add),
                label: const Text('Add another product'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _updateCost,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _updateCost = value ?? true),
                title: const Text('Update average cost prices'),
                subtitle: const Text(
                  'Combine existing stock cost with the cost of the new goods.',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EEE8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Delivery total: GHS ${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF24352F),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving delivery...' : 'Save purchase'),
        ),
      ],
    ),
  );
  Widget _line(_PurchaseDraft row, int index) => Card(
    key: ObjectKey(row),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PRODUCT ${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  tooltip: 'Remove product ${index + 1}',
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _rows.remove(row);
                          _removedRows.add(row);
                        }),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: row.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Select product'),
            items: widget.products
                .map(
                  (product) => DropdownMenuItem(
                    value: product.id,
                    child: Text(
                      '${product.name} (${product.quantity} in stock)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy ? null : (value) => setState(() => row.id = value),
            validator: (value) => value == null
                ? 'Select a product.'
                : _rows.where((other) => other.id == value).length > 1
                ? 'Use one row per product.'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.quantity,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity purchased',
                  ),
                  validator: (value) {
                    final qty = int.tryParse(value?.trim() ?? '');
                    return qty == null || qty <= 0
                        ? 'Enter a positive quantity.'
                        : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: row.amount,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Total amount spent (GHS)',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || !amount.isFinite || amount < 0
                        ? 'Enter a valid amount.'
                        : null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
