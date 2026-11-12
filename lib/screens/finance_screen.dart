import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'products_screen.dart';
import '../widgets/pdf_document_preview_screen.dart';
import '../services/backup_validation.dart';
import '../services/shop_storage.dart';

const _salesKey = 'electrical_shop_sales_v1';
const _expensesKey = 'electrical_shop_expenses_v1';
const _repaymentsKey = 'electrical_shop_repayments_v1';
const _receiptsKey = 'electrical_shop_stock_receipts_v1';
const _productsKey = 'electrical_shop_products_v1';
const _ink = Color(0xFF142B49);
const _blue = Color(0xFF0879E8);

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _repayments = [];
  bool _loading = true;
  double _stockCostValue = 0;
  double _stockSellingValue = 0;
  bool _busy = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    productStockChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    productStockChanged.removeListener(_load);
    super.dispose();
  }

  List<Map<String, dynamic>> _decodeList(String? raw) => raw == null
      ? <Map<String, dynamic>>[]
      : (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sales = _decodeList(prefs.getString(_salesKey));
      final expenses = _decodeList(prefs.getString(_expensesKey));
      final repayments = _decodeList(prefs.getString(_repaymentsKey));
      final products = _decodeList(prefs.getString(_productsKey));
      final stockSellingValue = products.fold<double>(
        0,
        (total, product) =>
            total +
            _value(product, 'sellingPrice') * _value(product, 'quantity'),
      );
      final stockCostValue = products.fold<double>(
        0,
        (total, product) =>
            total + _value(product, 'costPrice') * _value(product, 'quantity'),
      );
      if (mounted) {
        setState(() {
          _sales = sales;
          _expenses = expenses;
          _repayments = repayments;
          _stockCostValue = stockCostValue;
          _stockSellingValue = stockSellingValue;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _value(Map<String, dynamic> map, String key) =>
      (map[key] as num?)?.toDouble() ?? 0;
  String _money(double value) => 'GHS ${value.toStringAsFixed(2)}';
  String _customer(Map<String, dynamic> sale) =>
      ((sale['customer'] as String?) ?? '').trim().isEmpty
      ? 'Customer not recorded'
      : (sale['customer'] as String).trim();
  double _balance(Map<String, dynamic> sale) => sale['outstanding'] is num
      ? _value(sale, 'outstanding')
      : (sale['payment'] == 'credit' ? _value(sale, 'total') : 0);

  double get _revenue =>
      _sales.fold(0, (sum, sale) => sum + _value(sale, 'total'));
  List<Map<String, dynamic>> get _salesWithCostSnapshots =>
      _sales.where((sale) {
        final items = sale['items'] as List<dynamic>? ?? const [];
        return items.isNotEmpty &&
            items.every((item) => item is Map && item['unitCost'] is num);
      }).toList();
  double get _profitRevenue => _salesWithCostSnapshots.fold(
    0,
    (sum, sale) => sum + _value(sale, 'total'),
  );
  double get _costOfGoods => _salesWithCostSnapshots.fold(
    0,
    (sum, sale) =>
        sum +
        ((sale['items'] as List<dynamic>? ?? const []).fold<double>(0, (
          subtotal,
          item,
        ) {
          final row = Map<String, dynamic>.from(item as Map);
          final cost = (row['unitCost'] as num?)?.toDouble() ?? 0;
          final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
          return subtotal + cost * quantity;
        })),
  );
  double get _expenseTotal =>
      _expenses.fold(0, (sum, expense) => sum + _value(expense, 'amount'));
  // Inventory purchases become a profit cost when the items are sold (COGS).
  // Keep the purchase in the expense ledger without deducting it twice.
  double get _operatingExpenseTotal => _expenses
      .where((expense) => expense['category'] != 'Stock Purchase')
      .fold(0, (sum, expense) => sum + _value(expense, 'amount'));
  double get _netProfit =>
      _profitRevenue - _costOfGoods - _operatingExpenseTotal;
  double get _creditTotal =>
      _sales.fold(0, (sum, sale) => sum + _balance(sale));

  List<Map<String, dynamic>> _salesForPeriod(DateTime start) {
    final now = DateTime.now();
    return _sales.where((sale) {
      final date = DateTime.tryParse(sale['date'] as String? ?? '')?.toLocal();
      return date != null && !date.isBefore(start) && !date.isAfter(now);
    }).toList();
  }

  List<Map<String, dynamic>> _expensesForPeriod(DateTime start) {
    final now = DateTime.now();
    return _expenses.where((expense) {
      final date = DateTime.tryParse(
        expense['date'] as String? ?? '',
      )?.toLocal();
      return date != null && !date.isBefore(start) && !date.isAfter(now);
    }).toList();
  }

  Map<String, dynamic> _periodTotals(DateTime start) {
    final sales = _salesForPeriod(start);
    final expenses = _expensesForPeriod(start);
    final grossProfit = sales.fold<double>(0, (total, sale) {
      final items = sale['items'] as List<dynamic>? ?? const [];
      return total +
          items.fold<double>(0, (subtotal, raw) {
            if (raw is! Map || raw['unitCost'] is! num) return subtotal;
            final item = Map<String, dynamic>.from(raw);
            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
            final cost = (item['unitCost'] as num).toDouble();
            return subtotal + (price - cost) * quantity;
          });
    });
    final expenseTotal = expenses.fold<double>(
      0,
      (sum, expense) => sum + _value(expense, 'amount'),
    );
    final operatingExpenses = expenses
        .where((expense) => expense['category'] != 'Stock Purchase')
        .fold<double>(0, (sum, expense) => sum + _value(expense, 'amount'));
    return {
      'salesCount': sales.length,
      'revenue': sales.fold<double>(
        0,
        (sum, sale) => sum + _value(sale, 'total'),
      ),
      'grossProfit': grossProfit,
      'expenses': expenseTotal,
      'netProfit': grossProfit - operatingExpenses,
    };
  }

  Future<double?> _askAmount({
    required String title,
    required double maximum,
  }) async {
    final controller = TextEditingController();
    String? error;
    final route = DialogRoute<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maximum: ${_money(maximum)}',
                style: const TextStyle(color: Color(0xFF647891)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (GHS)',
                  prefixText: 'GHS ',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(controller.text.trim());
                if (amount == null ||
                    !amount.isFinite ||
                    amount <= 0 ||
                    amount > maximum) {
                  refresh(
                    () => error =
                        'Enter an amount above zero and no more than ${_money(maximum)}.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, amount);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    controller.dispose();
    return result;
  }

  Future<void> _recordRepayment(
    String customer,
    List<Map<String, dynamic>> customerSales,
  ) async {
    final due = customerSales.fold<double>(
      0,
      (sum, sale) => sum + _balance(sale),
    );
    final amount = await _askAmount(
      title: 'Record repayment from $customer',
      maximum: due,
    );
    if (amount == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldSales = prefs.getString(_salesKey);
      final currentSales = _decodeList(oldSales);
      final currentCustomerSales = currentSales
          .where((sale) => _customer(sale) == customer && _balance(sale) > 0)
          .toList();
      final currentDue = currentCustomerSales.fold<double>(
        0,
        (sum, sale) => sum + _balance(sale),
      );
      if (amount > currentDue) {
        throw StateError(
          'The credit balance changed. Review it and try again.',
        );
      }
      var remaining = amount;
      // Apply payments to older sales first so each balance can be audited.
      for (final sale in currentCustomerSales.reversed) {
        final outstanding = _balance(sale);
        final applied = remaining < outstanding ? remaining : outstanding;
        sale['outstanding'] = outstanding - applied;
        remaining -= applied;
        if (remaining <= 0) break;
      }
      final repayments = _decodeList(prefs.getString(_repaymentsKey));
      repayments.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'customer': customer,
        'customerPhone': customerSales
            .map((sale) => (sale['customerPhone'] as String? ?? '').trim())
            .firstWhere((phone) => phone.isNotEmpty, orElse: () => ''),
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'saleIds': customerSales.map((s) => s['id']).toList(),
      });
      await saveShopRecords(prefs, {
        _salesKey: jsonEncode(currentSales),
        _repaymentsKey: jsonEncode(repayments),
      });
      if (mounted) {
        setState(() {
          _repayments = repayments;
        });
      }
      productStockChanged.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repayment of ${_money(amount)} recorded.')),
        );
      }
    } catch (error) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Could not record repayment.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addExpense({Map<String, dynamic>? expense}) async {
    final titleController = TextEditingController(
      text: expense?['title'] as String? ?? '',
    );
    final amountController = TextEditingController(
      text: expense == null ? '' : _value(expense, 'amount').toStringAsFixed(2),
    );
    final noteController = TextEditingController(
      text: expense?['note'] as String? ?? '',
    );
    String category = expense?['category'] as String? ?? 'Shop supplies';
    String? error;
    final route = DialogRoute<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          scrollable: true,
          title: Text(expense == null ? 'Add expense' : 'Edit expense'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Expense name',
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (GHS)',
                      prefixText: 'GHS ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items:
                        <String>{
                              category,
                              'Shop supplies',
                              'Rent',
                              'Transport',
                              'Utilities',
                              'Staff',
                              'Other',
                            }
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: expense?['category'] == 'Stock Purchase'
                        ? null
                        : (value) => refresh(() => category = value ?? 'Other'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                if (titleController.text.trim().isEmpty ||
                    amount == null ||
                    !amount.isFinite ||
                    amount <= 0) {
                  refresh(
                    () => error = 'Enter an expense name and a valid amount.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'title': titleController.text.trim(),
                  'amount': amount,
                  'category': category,
                  'note': noteController.text.trim(),
                });
              },
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
    final draft = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    if (draft == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_expensesKey);
      final expenses = _decodeList(raw);
      final updated = {
        ...?expense,
        ...draft,
        'id':
            expense?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        'date': expense?['date'] ?? DateTime.now().toIso8601String(),
      };
      if (expense == null) {
        expenses.insert(0, updated);
      } else {
        final index = expenses.indexWhere((row) => row['id'] == expense['id']);
        if (index < 0 || jsonEncode(expenses[index]) != jsonEncode(expense)) {
          throw StateError('Expense changed. Refresh and try again.');
        }
        expenses[index] = updated;
      }
      if (!await prefs.setString(_expensesKey, jsonEncode(expenses))) {
        throw StateError('Storage did not confirm the expense save.');
      }
      if (mounted) {
        setState(() => _expenses = expenses);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this expense. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'Remove "${expense['title']}" (${_money(_value(expense, 'amount'))}) from your expense records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete expense'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenses = _decodeList(prefs.getString(_expensesKey));
      final index = expenses.indexWhere((row) => row['id'] == expense['id']);
      if (index < 0 || jsonEncode(expenses[index]) != jsonEncode(expense)) {
        throw StateError('Expense changed. Refresh and try again.');
      }
      expenses.removeAt(index);
      await saveShopRecords(prefs, {_expensesKey: jsonEncode(expenses)});
      if (mounted) setState(() => _expenses = expenses);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Could not delete this expense. Please try again.',
            ),
          ),
        );
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetShopTransactions() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset shop transactions?'),
        content: const Text(
          'This clears sales history and receipts, customer credit, repayments, '
          'and expenses. Products, prices, stock quantities, and purchase history '
          'will be kept. Cloud sync can carry these deletions to other devices. '
          'To keep a copy of your records, cancel and choose Create backup first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear transactions'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await saveShopRecords(prefs, {
        _salesKey: '[]',
        _expensesKey: '[]',
        _repaymentsKey: '[]',
      });
      productStockChanged.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop transactions cleared.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Could not clear shop transactions.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backup = <String, dynamic>{
        'format': 'electrical_shop_backup_v1',
        'createdAt': DateTime.now().toIso8601String(),
      };
      for (final key in [
        _productsKey,
        _salesKey,
        _receiptsKey,
        _expensesKey,
        _repaymentsKey,
      ]) {
        final raw = prefs.getString(key);
        backup[key] = raw == null ? <dynamic>[] : jsonDecode(raw);
      }
      final now = DateTime.now();
      final file = await FilePicker.saveFile(
        dialogTitle: 'Save shop backup',
        fileName:
            'electrical-shop-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json',
        bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)),
      );
      if (file != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup saved. Keep a copy somewhere safe.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the backup file.')),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
      validateShopBackup(decoded);
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: const Text(
            'Current products, sales, repayments and expenses will be replaced by the selected backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore backup'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      setState(() => _busy = true);
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        _productsKey,
        _salesKey,
        _receiptsKey,
        _expensesKey,
        _repaymentsKey,
      ];
      final previous = {for (final key in keys) key: prefs.getString(key)};
      try {
        for (final key in keys) {
          final value = decoded[key];
          if (value is! List || value.any((item) => item is! Map)) {
            throw const FormatException(
              'Backup is missing required shop data.',
            );
          }
          if (!await prefs.setString(key, jsonEncode(value))) {
            throw StateError('Could not restore all data.');
          }
        }
      } catch (_) {
        for (final entry in previous.entries) {
          if (entry.value == null) {
            await prefs.remove(entry.key);
          } else {
            await prefs.setString(entry.key, entry.value!);
          }
        }
        rethrow;
      }
      await _load();
      productStockChanged.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Could not restore this backup.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> get _openCredits {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final sale in _sales) {
      if (sale['payment'] != 'credit' || _balance(sale) <= 0) continue;
      groups.putIfAbsent(_customer(sale), () => []).add(sale);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final openCredits = _openCredits;
    return PopScope<Object?>(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) setState(() => _tab = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _tab == 1
              ? IconButton(
                  tooltip: 'Back to customer credit',
                  onPressed: () => setState(() => _tab = 0),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: const Text(
            'Finances',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Data backup',
              enabled: !_busy,
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportBackup();
                  case 'restore':
                    _restoreBackup();
                  case 'reset':
                    _resetShopTransactions();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Create backup'),
                  ),
                ),
                PopupMenuItem(
                  value: 'restore',
                  child: ListTile(
                    leading: Icon(Icons.restore_outlined),
                    title: Text('Restore backup'),
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    leading: Icon(Icons.restart_alt),
                    title: Text('Reset shop transactions'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 440;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: Text(compact ? 'Credit' : 'Customer credit'),
                        icon: compact
                            ? null
                            : const Icon(Icons.account_balance_wallet_outlined),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text(compact ? 'Reports' : 'Expenses & profit'),
                        icon: compact
                            ? null
                            : const Icon(Icons.assessment_outlined),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (selection) =>
                        setState(() => _tab = selection.first),
                  ),
                );
              },
            ),
            Expanded(
              child: _tab == 0 ? _creditsView(openCredits) : _reportsView(),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  Widget _creditsView(
    Map<String, List<Map<String, dynamic>>> credits,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
    children: [
      _summaryCard(
        'Outstanding credit',
        _money(_creditTotal),
        '${credits.length} customers with a balance',
        Icons.account_balance_wallet_outlined,
        const Color(0xFFFFF3DF),
      ),
      const SizedBox(height: 18),
      const Text(
        'Customers who owe',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const SizedBox(height: 8),
      if (credits.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No outstanding customer credit. Credit sales will appear here.',
            ),
          ),
        ),
      ...credits.entries.map((entry) {
        final due = entry.value.fold<double>(
          0,
          (sum, sale) => sum + _balance(sale),
        );
        final customerPhone = entry.value
            .map((sale) => (sale['customerPhone'] as String? ?? '').trim())
            .firstWhere((phone) => phone.isNotEmpty, orElse: () => '');
        final mostRecent = entry.value
            .map((sale) => DateTime.tryParse(sale['date'] as String? ?? ''))
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (latest, date) =>
                  latest == null || date.isAfter(latest) ? date : latest,
            );
        final details =
            '${entry.value.length} credit ${entry.value.length == 1 ? 'sale' : 'sales'}${mostRecent == null ? '' : ' · ${mostRecent.day}/${mostRecent.month}/${mostRecent.year}'}${customerPhone.isEmpty ? '' : ' · $customerPhone'}';
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 440;
            final customer = Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE8F7EF),
                  child: Icon(Icons.person_outline, color: _blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        details,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _money(due),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            );
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          customer,
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _recordRepayment(
                                      entry.key,
                                      entry.value,
                                    ),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Record payment'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: customer),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () =>
                                      _recordRepayment(entry.key, entry.value),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record payment'),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      }),
      const SizedBox(height: 18),
      const Text(
        'Recent repayments',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const SizedBox(height: 8),
      if (_repayments.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Repayments will be listed here.'),
          ),
        ),
      ..._repayments
          .take(10)
          .map(
            (repayment) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF138A55),
                ),
                title: Text(_customer(repayment)),
                subtitle: Text(_date(repayment['date'])),
                trailing: Text(
                  _money(_value(repayment, 'amount')),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
    ],
  );

  Widget _reportsView() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
    children: [
      const Text(
        'All-time sales and profit',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _periodRow('Sales revenue', _revenue),
              _periodRow('Cost of items sold', _costOfGoods),
              _periodRow('Operating expenses', _operatingExpenseTotal),
              const Divider(),
              _periodRow('Estimated net profit', _netProfit, emphasize: true),
              if (_salesWithCostSnapshots.length != _sales.length)
                const Text(
                  'Sales without saved costs are excluded from the profit estimate.',
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Stock on hand',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _periodRow('Current stock value at cost', _stockCostValue),
              _periodRow(
                'Shop main capital',
                _stockSellingValue - _operatingExpenseTotal,
              ),
              const Text(
                'Main capital is the selling value of remaining stock minus operating expenses.',
              ),
            ],
          ),
        ),
      ),
      Card(
        child: ExpansionTile(
          title: const Text('Daily, weekly and monthly reports'),
          children: [
            _periodCard('Today', DateUtils.dateOnly(DateTime.now())),
            _periodCard(
              'This week',
              DateUtils.dateOnly(
                DateTime.now(),
              ).subtract(Duration(days: DateTime.now().weekday - 1)),
            ),
            _periodCard(
              'This month',
              DateTime(DateTime.now().year, DateTime.now().month),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Expenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _addExpense,
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _periodRow('Total recorded expenses', _expenseTotal),
      if (_expenses.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('No expenses recorded yet.'),
          ),
        ),
      ..._expenses.map(
        (expense) => Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFEAEA),
              child: Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFFB42318),
              ),
            ),
            title: Text(
              expense['title'] as String? ?? 'Expense',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${expense['category'] ?? 'Other'} · ${_date(expense['date'])}${(expense['note'] as String? ?? '').isEmpty ? '' : ' · ${expense['note']}'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _money(_value(expense, 'amount')),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Expense actions',
                  enabled: !_busy,
                  onSelected: (action) => action == 'edit'
                      ? _addExpense(expense: expense)
                      : _deleteExpense(expense),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit expense')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete expense'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
    ],
  );

  Future<void> _openPeriodReport(
    String title,
    DateTime start,
  ) => showPdfDocumentPreview(
    context,
    title: '$title report',
    fileName:
        '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-report.pdf',
    buildPdf: (_) => _buildPeriodReport(title, start),
  );

  Future<Uint8List> _buildPeriodReport(String title, DateTime start) async {
    final sales = _salesForPeriod(start);
    final expenses = _expensesForPeriod(start);
    final totals = _periodTotals(start);
    final now = DateTime.now();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'NANAKAY ELECTRICAL SHOP',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF24352F),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$title report · ${_date(start.toIso8601String())} to ${_date(now.toIso8601String())}',
            style: const pw.TextStyle(color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'FINANCIAL SUMMARY',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blueGrey100),
            children: [
              _reportTableRow(['Sales count', '${totals['salesCount']}']),
              _reportTableRow([
                'Sales revenue',
                _money(_value(totals, 'revenue')),
              ]),
              _reportTableRow([
                'Gross profit',
                _money(_value(totals, 'grossProfit')),
              ]),
              _reportTableRow(['Expenses', _money(_value(totals, 'expenses'))]),
              _reportTableRow([
                'Estimated net profit',
                _money(_value(totals, 'netProfit')),
              ]),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text('SALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (sales.isEmpty)
            pw.Text('No sales recorded for this period.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.blueGrey100),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                _reportTableRow([
                  'Date',
                  'Customer',
                  'Payment',
                  'Total',
                ], header: true),
                ...sales.map(
                  (sale) => _reportTableRow([
                    _date(sale['date']),
                    (sale['customer'] as String? ?? '').trim().isEmpty
                        ? 'Walk-in'
                        : (sale['customer'] as String).trim(),
                    (sale['payment'] as String? ?? 'cash').toUpperCase(),
                    _money(_value(sale, 'total')),
                  ]),
                ),
              ],
            ),
          pw.SizedBox(height: 22),
          pw.Text(
            'EXPENSES',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (expenses.isEmpty)
            pw.Text('No expenses recorded for this period.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.blueGrey100),
              children: [
                _reportTableRow([
                  'Date',
                  'Expense',
                  'Category',
                  'Amount',
                ], header: true),
                ...expenses.map(
                  (expense) => _reportTableRow([
                    _date(expense['date']),
                    expense['title'] as String? ?? 'Expense',
                    expense['category'] as String? ?? 'Other',
                    _money(_value(expense, 'amount')),
                  ]),
                ),
              ],
            ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Profit is estimated from sales items with saved cost prices, less operating expenses. Stock purchases are included through cost of goods sold.',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey700,
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.TableRow _reportTableRow(List<String> values, {bool header = false}) {
    return pw.TableRow(
      decoration: header
          ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F1E8))
          : null,
      children: values
          .map(
            (value) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 7,
              ),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: header
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _periodCard(String title, DateTime start) {
    final totals = _periodTotals(start);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${totals['salesCount']} sales',
                  style: const TextStyle(color: Color(0xFF647891)),
                ),
              ],
            ),
            const Divider(height: 20),
            _periodRow('Sales revenue', _value(totals, 'revenue')),
            _periodRow('Gross profit', _value(totals, 'grossProfit')),
            _periodRow('Expenses', _value(totals, 'expenses')),
            const Divider(height: 18),
            _periodRow(
              'Estimated net profit',
              _value(totals, 'netProfit'),
              emphasize: true,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openPeriodReport(title, start),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Preview / print report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodRow(String label, double amount, {bool emphasize = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: emphasize ? _ink : const Color(0xFF647891),
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              _money(amount),
              style: TextStyle(
                color: _ink,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _summaryCard(
    String title,
    String amount,
    String helper,
    IconData icon,
    Color tint,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF647891))),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                Text(
                  helper,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF647891),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  String _date(dynamic value) {
    final date = DateTime.tryParse(value as String? ?? '')?.toLocal();
    return date == null
        ? 'Date unavailable'
        : '${date.day}/${date.month}/${date.year}';
  }
}
