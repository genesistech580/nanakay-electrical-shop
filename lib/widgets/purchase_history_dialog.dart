import 'package:flutter/material.dart';

class PurchaseHistoryDialog extends StatelessWidget {
  const PurchaseHistoryDialog({super.key, required this.receipts});
  final List<Map<String, dynamic>> receipts;
  @override
  Widget build(BuildContext context) {
    final batches = <String, List<Map<String, dynamic>>>{};
    for (final receipt in receipts) {
      final key = (receipt['batchId'] ?? receipt['id']).toString();
      batches.putIfAbsent(key, () => []).add(receipt);
    }
    final deliveries = batches.values.toList();
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: Color(0xFF0879E8)),
          SizedBox(width: 10),
          Expanded(child: Text('Stock purchase history')),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 440,
        child: deliveries.isEmpty
            ? const Center(child: Text('No stock deliveries recorded yet.'))
            : ListView.separated(
                itemCount: deliveries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final lines = deliveries[index];
                  final first = lines.first;
                  final supplier = (first['note'] as String? ?? '').trim();
                  final date = DateTime.tryParse(
                    first['date'] as String? ?? '',
                  )?.toLocal();
                  final total = lines.fold<double>(
                    0,
                    (sum, row) =>
                        sum + ((row['amountSpent'] as num?)?.toDouble() ?? 0),
                  );
                  final units = lines.fold<int>(
                    0,
                    (sum, row) =>
                        sum + ((row['quantity'] as num?)?.toInt() ?? 0),
                  );
                  return ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      supplier.isEmpty ? 'Stock delivery' : supplier,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${date == null ? 'Date unavailable' : '${date.day}/${date.month}/${date.year}'} | ${lines.length} products | $units units',
                      style: const TextStyle(fontSize: 12),
                    ),
                    children: [
                      for (final row in lines)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(
                            row['productName'] as String? ?? 'Product',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text('${row['quantity']} units'),
                          trailing: Text(
                            row['amountSpent'] is num
                                ? 'GHS ${(row['amountSpent'] as num).toStringAsFixed(2)}'
                                : 'Stock added',
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7EF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Delivery total: GHS ${total.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF142B49),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
