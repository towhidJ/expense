import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Renders the widget under [boundaryKey] (a RepaintBoundary) into a one-page
/// PDF and returns its bytes. Rendering Flutter's own paint output means
/// Bangla text and ৳ come out pixel-perfect — the pdf package's text engine
/// cannot shape Bengali script.
Future<Uint8List?> boundaryPdfBytes(GlobalKey boundaryKey) async {
  final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 2.5);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return null;
  final png = byteData.buffer.asUint8List();

  final doc = pw.Document();
  final memImage = pw.MemoryImage(png);
  // One page sized to the content (A4 width, proportional height) — avoids
  // slicing rows across page breaks.
  const pageWidth = PdfPageFormat.a4;
  final ratio = image.height / image.width;
  final format = PdfPageFormat(pageWidth.width, pageWidth.width * ratio, marginAll: 0);
  doc.addPage(pw.Page(
    pageFormat: format,
    build: (_) => pw.Image(memImage, fit: pw.BoxFit.fill),
  ));
  return doc.save();
}

/// Captures the boundary and opens the share sheet with the PDF.
Future<void> exportBoundaryAsPdf(GlobalKey boundaryKey, String fileName) async {
  final bytes = await boundaryPdfBytes(boundaryKey);
  if (bytes == null) return;
  await Printing.sharePdf(bytes: bytes, filename: fileName);
}

/// Captures the boundary and opens the Android print dialog (print to a
/// printer or save as PDF).
Future<void> printBoundary(GlobalKey boundaryKey, String jobName) async {
  final bytes = await boundaryPdfBytes(boundaryKey);
  if (bytes == null) return;
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName);
}
