import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'shop_profile.dart';

Future<Uint8List> buildCustomerReceipt({
  required Map<String, dynamic> sale,
  required ShopProfile shop,
  Uint8List? logo,
  Uint8List? regularFont,
  Uint8List? boldFont,
}) async {
  const ink = PdfColor.fromInt(0xFF24352F);
  const green = PdfColor.fromInt(0xFF3D6555);
  const gold = PdfColor.fromInt(0xFFD3A15C);
  const cream = PdfColor.fromInt(0xFFF5F3EC);
  final pdf = pw.Document(title: '${shop.name} receipt', author: shop.name);
  final date = DateTime.tryParse(sale['date'] as String? ?? '')?.toLocal();
  final total = (sale['total'] as num).toDouble();
  final credit = sale['payment'] == 'credit';
  final balance = credit
      ? ((sale['outstanding'] as num?)?.toDouble() ?? total)
      : 0.0;
  String money(num value) => 'GHS ${value.toStringAsFixed(2)}';
  String pad(int value) => value.toString().padLeft(2, '0');
  final customer = (sale['customer'] as String? ?? '').trim();
  final phone = (sale['customerPhone'] as String? ?? '').trim();
  final items = (sale['items'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  pw.Widget label(String value) => pw.Text(
    value,
    style: const pw.TextStyle(fontSize: 8, letterSpacing: 1.2, color: green),
  );
  pw.Widget detail(String key, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 7),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(key, style: const pw.TextStyle(fontSize: 10, color: green)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            color: ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(
        base: regularFont == null
            ? pw.Font.helvetica()
            : pw.Font.ttf(ByteData.sublistView(regularFont)),
        bold: boldFont == null
            ? pw.Font.helveticaBold()
            : pw.Font.ttf(ByteData.sublistView(boldFont)),
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: gold, thickness: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                shop.name,
                style: const pw.TextStyle(fontSize: 8, color: green),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: green),
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Container(
                width: 64,
                height: 64,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: cream,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Image(pw.MemoryImage(logo)),
              ),
              pw.SizedBox(width: 16),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    shop.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 21,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (shop.phone.isNotEmpty)
                    pw.Text(
                      'Tel: ${shop.phone}',
                      style: const pw.TextStyle(fontSize: 10, color: green),
                    ),
                  if (shop.address.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        shop.address,
                        style: const pw.TextStyle(fontSize: 10, color: green),
                      ),
                    ),
                  if (shop.email.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        shop.email,
                        style: const pw.TextStyle(fontSize: 10, color: green),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: pw.BoxDecoration(
            color: ink,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SALES RECEIPT',
                style: pw.TextStyle(
                  fontSize: 17,
                  letterSpacing: 2,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                balance > 0 ? 'CREDIT SALE' : 'PAID',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: gold,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 22),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('CUSTOMER'),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    customer.isEmpty ? 'Walk-in customer' : customer,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: ink,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (phone.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        phone,
                        style: const pw.TextStyle(fontSize: 10, color: green),
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('RECEIPT DETAILS'),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    'NK-${sale['id']}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    date == null
                        ? 'Date unavailable'
                        : '${pad(date.day)}/${pad(date.month)}/${date.year}  ${pad(date.hour)}:${pad(date.minute)}',
                    style: const pw.TextStyle(fontSize: 10, color: green),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 26),
        pw.TableHelper.fromTextArray(
          headers: ['DESCRIPTION', 'QTY', 'UNIT PRICE', 'AMOUNT'],
          data: items
              .map(
                (item) => [
                  item['name'],
                  '${item['quantity']}',
                  money(item['unitPrice'] as num),
                  money(
                    (item['lineTotal'] as num?) ??
                        (item['unitPrice'] as num) * (item['quantity'] as num),
                  ),
                ],
              )
              .toList(),
          border: null,
          headerDecoration: const pw.BoxDecoration(color: cream),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: green,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10, color: ink),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 13,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3.6),
            1: const pw.FlexColumnWidth(.7),
            2: const pw.FlexColumnWidth(1.6),
            3: const pw.FlexColumnWidth(1.7),
          },
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          headerAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 22),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('PAYMENT METHOD'),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    (sale['payment'] as String? ?? 'cash').toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: ink,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    'Keep this receipt as your proof of purchase.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: green,
                      lineSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 30),
            pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: cream,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                children: [
                  detail('Subtotal', money(total)),
                  pw.Divider(color: gold),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: ink,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        money(total),
                        style: pw.TextStyle(
                          fontSize: 20,
                          color: ink,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 14),
                  detail('Amount paid', money(total - balance)),
                  detail('Balance due', money(balance)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 34),
        pw.Text(
          'Thank you for shopping with us.',
          style: pw.TextStyle(
            fontSize: 14,
            color: ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'We appreciate your business and look forward to serving you again.',
          style: const pw.TextStyle(fontSize: 10, color: green),
        ),
      ],
    ),
  );
  return pdf.save();
}
