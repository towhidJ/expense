import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../ai_service.dart';
import '../app_state.dart';
import '../theme.dart';

const _violet = Color(0xFF8B5CF6);

class _ScanItem {
  _ScanItem({required this.type, required this.amount, required this.description, required this.date, this.categoryId});
  String type;
  final TextEditingController amount;
  final TextEditingController description;
  DateTime date;
  String? categoryId;
}

/// Receipt OCR: photo → gemini parse_receipt → editable rows → one
/// process_transaction per row (web /scan parity).
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _picker = ImagePicker();
  File? _preview;
  bool _scanning = false;
  bool _saving = false;
  int _savedCount = 0;
  String? _accountId;
  final List<_ScanItem> _items = [];

  String? _guessCategory(String? suggested, String type) {
    if (suggested == null || suggested.isEmpty) return null;
    final list = widget.state.categories.where((c) => c.type == type);
    for (final c in list) {
      final a = c.name.toLowerCase();
      final b = suggested.toLowerCase();
      if (a.contains(b) || b.contains(a)) return c.id;
    }
    return null;
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 82);
    if (file == null) return;
    setState(() {
      _savedCount = 0;
      _items.clear();
      _preview = File(file.path);
      _scanning = true;
    });
    try {
      final bytes = await file.readAsBytes();
      final result = await AiService.parseReceipt(base64Encode(bytes), mimeType: file.mimeType ?? 'image/jpeg');
      final items = (result['items'] as List?) ?? [];
      final parsed = items.map((raw) {
        final it = Map<String, dynamic>.from(raw as Map);
        final type = it['type'] == 'income' ? 'income' : 'expense';
        return _ScanItem(
          type: type,
          amount: TextEditingController(text: '${it['amount'] ?? ''}'),
          description: TextEditingController(text: '${it['description'] ?? ''}'),
          date: DateTime.tryParse('${it['date'] ?? ''}') ?? DateTime.now(),
          categoryId: _guessCategory(it['suggested_category'] as String?, type),
        );
      }).toList();
      if (parsed.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read any line items — try a clearer photo.')));
      }
      setState(() => _items.addAll(parsed));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _saveAll() async {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select the account these were paid from.')));
      return;
    }
    if (_items.any((it) => it.categoryId == null || double.tryParse(it.amount.text.trim()) == null)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Every row needs an amount and a category.')));
      return;
    }
    setState(() => _saving = true);
    var ok = 0;
    try {
      for (final it in _items) {
        await widget.state.addTransaction(
          accountId: _accountId!,
          categoryId: it.categoryId!,
          type: it.type,
          amount: double.parse(it.amount.text.trim()),
          date: it.date,
          description: it.description.text.trim().isEmpty ? 'Receipt scan' : it.description.text.trim(),
        );
        ok++;
      }
      setState(() {
        _savedCount = ok;
        _items.clear();
        _preview = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved $ok of ${_items.length}, then failed: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_savedCount > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: kEmerald, size: 20),
                  const SizedBox(width: 8),
                  Text('$_savedCount transaction${_savedCount > 1 ? 's' : ''} saved successfully!',
                      style: const TextStyle(fontSize: 13, color: kEmerald, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: _violet.withValues(alpha: 0.4)),
                  foregroundColor: _violet,
                ),
                onPressed: _scanning ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: _violet.withValues(alpha: 0.4)),
                  foregroundColor: _violet,
                ),
                onPressed: _scanning ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery'),
              ),
            ),
          ]),
          if (_scanning)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const CircularProgressIndicator(color: _violet),
                const SizedBox(height: 10),
                Text('Reading receipt with AI…', style: TextStyle(fontSize: 12.5, color: kFg54)),
              ]),
            ),
          if (_preview != null && !_scanning) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(_preview!, height: 160, fit: BoxFit.cover, width: double.infinity),
            ),
          ],
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              dropdownColor: kCard,
              decoration: const InputDecoration(labelText: 'Paid from account'),
              items: widget.state.accounts
                  .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 10),
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final it = entry.value;
              final cats = widget.state.categories.where((c) => c.type == it.type).toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: it.description,
                          decoration: const InputDecoration(labelText: 'Description', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: it.amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: '৳', isDense: true),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: cats.any((c) => c.id == it.categoryId) ? it.categoryId : null,
                          dropdownColor: kCard,
                          decoration: const InputDecoration(labelText: 'Category', isDense: true),
                          items: cats
                              .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}', style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setState(() => it.categoryId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: it.date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => it.date = picked);
                        },
                        child: Text(DateFormat('MMM d').format(it.date),
                            style: TextStyle(fontSize: 12, color: kCyan)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 17, color: kRed),
                        onPressed: () => setState(() => _items.removeAt(i)),
                      ),
                    ]),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Save ${_items.length} Transaction${_items.length > 1 ? 's' : ''}',
              busy: _saving,
              onPressed: _saveAll,
            ),
          ],
          if (_items.isEmpty && !_scanning && _preview == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'Take a photo of a receipt —\nAI reads the items, you confirm, it saves as transactions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kFg38, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
