import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'pdf_export.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Amount in words — Bangladeshi lakh/crore numbering, mirrors the web app's
// src/lib/amountInWords.js so both platforms print identical vouchers.
// ---------------------------------------------------------------------------
const _ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

String _twoDigits(int n) {
  if (n < 20) return _ones[n];
  return '${_tens[n ~/ 10]}${n % 10 != 0 ? ' ${_ones[n % 10]}' : ''}'.trim();
}

String _threeDigits(int n) {
  final h = n ~/ 100;
  final rest = n % 100;
  var out = '';
  if (h != 0) out = '${_ones[h]} Hundred';
  if (rest != 0) out += '${out.isNotEmpty ? ' ' : ''}${_twoDigits(rest)}';
  return out;
}

String numberToWords(num value) {
  var n = value.abs().floor();
  if (n == 0) return 'Zero';
  final crore = n ~/ 10000000;
  final lakh = (n % 10000000) ~/ 100000;
  final thousand = (n % 100000) ~/ 1000;
  final rest = n % 1000;
  final parts = <String>[];
  if (crore != 0) parts.add('${crore > 99 ? numberToWords(crore) : _twoDigits(crore)} Crore');
  if (lakh != 0) parts.add('${_twoDigits(lakh)} Lakh');
  if (thousand != 0) parts.add('${_twoDigits(thousand)} Thousand');
  if (rest != 0) parts.add(_threeDigits(rest));
  return parts.join(' ');
}

/// "Taka Two Lakh Fifty Thousand and Paisa Fifty Only"
String amountInWords(double amount) {
  final takaPart = amount.abs().floor();
  final paisa = ((amount.abs() - takaPart) * 100).round();
  var out = 'Taka ${numberToWords(takaPart)}';
  if (paisa > 0) out += ' and Paisa ${_twoDigits(paisa)}';
  return '$out Only';
}

/// Opens the printable voucher for a transaction.
void showVoucher(BuildContext context, Tx tx, String entityName) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => VoucherScreen(tx: tx, entityName: entityName)),
  );
}

/// DEBIT (expense) / CREDIT (income) money voucher — same layout as the web
/// app's VoucherModal. The white paper area is captured as an image, so
/// Bangla descriptions and ৳ print correctly.
class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key, required this.tx, required this.entityName});
  final Tx tx;
  final String entityName;

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final _paperKey = GlobalKey();
  bool _busy = false;

  String get _voucherNo {
    final t = widget.tx;
    final datePart = DateFormat('yyyyMMdd').format(t.date);
    final idPart = t.id.length >= 4 ? t.id.substring(0, 4).toUpperCase() : t.id.toUpperCase();
    return 'VCH-$datePart-$idPart';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tx;
    final isDebit = t.type == 'expense';
    final badge = isDebit ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final money = NumberFormat('#,##0.00').format(t.amount);
    final categoryName = t.categoryName.isEmpty ? 'Other' : t.categoryName;
    final accountName = t.accountName.isEmpty ? 'On Credit (Baki)' : t.accountName;

    // Fixed "paper" colors — the voucher stays black-on-white in dark mode.
    const ink = Color(0xFF111827);
    const inkSoft = Color(0xFF6B7280);
    const line = Color(0xFF64748B);

    TableRow cellRow(Widget left, Widget right) => TableRow(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: left),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: right),
        ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Voucher', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _paperKey,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF374151), width: 2)),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 2))),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Text(widget.entityName.isEmpty ? 'TakaKhata' : widget.entityName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ink)),
                        const Text('Personal Finance Manager',
                            style: TextStyle(fontSize: 10, color: inkSoft)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(4)),
                          child: Text(isDebit ? 'DEBIT VOUCHER' : 'CREDIT VOUCHER',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Voucher no + date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Voucher No: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: _voucherNo),
                      ]), style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                      Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: DateFormat('dd MMM yyyy').format(t.date)),
                      ]), style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Particulars table
                  Table(
                    border: TableBorder.all(color: line),
                    columnWidths: const {0: FlexColumnWidth(), 1: FixedColumnWidth(110)},
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text('Particulars',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ink)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text('Amount (৳)',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ink)),
                          ),
                        ],
                      ),
                      cellRow(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.description.isEmpty ? categoryName : t.description,
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600, color: ink)),
                            const SizedBox(height: 4),
                            Text('Category: $categoryName',
                                style: const TextStyle(fontSize: 10.5, color: inkSoft)),
                            Text('${isDebit ? 'Paid From' : 'Received In'}: $accountName',
                                style: const TextStyle(fontSize: 10.5, color: inkSoft)),
                          ],
                        ),
                        Text(money,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.bold, color: ink)),
                      ),
                      cellRow(
                        const Text('Total',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ink)),
                        Text(money,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.bold, color: ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: 'In Words: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: amountInWords(t.amount)),
                  ]), style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF374151))),
                  const SizedBox(height: 56),
                  // Signatures
                  Row(
                    children: ['Prepared By', 'Checked By', isDebit ? 'Received By' : 'Deposited By']
                        .map((label) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Container(
                                  decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: Color(0xFF4B5563)))),
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(label,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563))),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCyan,
                    side: const BorderSide(color: kCyan),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _busy ? null : () => _run(() => exportBoundaryAsPdf(_paperKey, '$_voucherNo.pdf')),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _busy ? null : () => _run(() => printBoundary(_paperKey, _voucherNo)),
                    icon: _busy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print, size: 18),
                    label: const Text('Print', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
