import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfDocumentPreviewScreen extends StatelessWidget {
  const PdfDocumentPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.buildPdf,
  });

  final String title;
  final String fileName;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: PdfPreview(
      build: buildPdf,
      initialPageFormat: PdfPageFormat.a4,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      pdfFileName: fileName,
      loadingWidget: const Center(child: CircularProgressIndicator()),
      onError: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not preview this document: $error'),
        ),
      ),
    ),
  );
}

Future<void> showPdfDocumentPreview(
  BuildContext context, {
  required String title,
  required String fileName,
  required Future<Uint8List> Function(PdfPageFormat format) buildPdf,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => PdfDocumentPreviewScreen(
      title: title,
      fileName: fileName,
      buildPdf: buildPdf,
    ),
  ),
);
