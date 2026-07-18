import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';

const _docCats = {
  'nid': ('🪪', 'NID'),
  'tin': ('🧾', 'TIN'),
  'passport': ('📘', 'Passport'),
  'warranty': ('🛡️', 'Warranty'),
  'insurance': ('☂️', 'Insurance'),
  'other': ('📄', 'Other'),
};

/// Document Vault — mirrors web /documents. Reuses the attachments table +
/// documents bucket; on mobile a doc is captured via camera/gallery.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Map<String, dynamic>>? _docs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.state.fetchVaultDocuments();
      if (mounted) setState(() => _docs = rows);
    } catch (_) {
      if (mounted) setState(() => _docs = []);
    }
  }

  Future<void> _uploadImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 88);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    await _saveWithMetadata(bytes, picked.name, picked.mimeType ?? 'image/jpeg');
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    final ext = (file.extension ?? '').toLowerCase();
    const mimes = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
    };
    await _saveWithMetadata(file.bytes!, file.name, mimes[ext] ?? 'application/octet-stream');
  }

  Future<void> _saveWithMetadata(List<int> fileBytes, String filename, String contentType) async {
    final title = TextEditingController();
    String category = 'other';
    DateTime? expiry;
    bool busy = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Save Document', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title (e.g. My NID)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _docCats.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value.$1} ${e.value.$2}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => category = v ?? 'other'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Expiry date (optional)', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(expiry == null ? 'Not set' : DateFormat('MMM d, yyyy').format(expiry!),
                      style: TextStyle(fontSize: 13, color: expiry == null ? kFg38 : kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: expiry ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => expiry = picked);
                  },
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Upload',
                  busy: busy,
                  onPressed: () async {
                    setSheet(() => busy = true);
                    try {
                      await widget.state.uploadVaultDocument(
                        bytes: fileBytes,
                        filename: filename,
                        docCategory: category,
                        title: title.text.trim().isEmpty ? null : title.text.trim(),
                        expiryDate: expiry,
                        contentType: contentType,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  void _pickSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: kCyan),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _uploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: kPurple),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _uploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: kRed),
              title: const Text('Pick a file (PDF, etc.)'),
              onTap: () {
                Navigator.pop(sheetContext);
                _uploadFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _docs;
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Document Vault', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickSource,
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.upload_file),
      ),
      body: docs == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  if (docs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No documents yet — tap + to save NID, TIN, passport scans.',
                              textAlign: TextAlign.center, style: TextStyle(color: kFg38))),
                    ),
                  ...docs.map((d) {
                    final meta = _docCats[d['doc_category']] ?? _docCats['other']!;
                    final expiry =
                        d['expiry_date'] != null ? DateTime.parse(d['expiry_date']) : null;
                    final expired = expiry != null && expiry.isBefore(today);
                    final soon = expiry != null &&
                        !expired &&
                        expiry.isBefore(today.add(const Duration(days: 30)));
                    return Card(
                      child: ListTile(
                        leading: Text(meta.$1, style: const TextStyle(fontSize: 22)),
                        title: Text(d['title'] ?? d['file_name'] ?? '', style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '${meta.$2}'
                          '${expiry != null ? ' · ${expired ? 'EXPIRED' : soon ? 'expires' : 'valid till'} ${DateFormat('MMM d, yyyy').format(expiry)}' : ''}',
                          style: TextStyle(
                              fontSize: 11.5, color: expired ? kRed : soon ? kOrange : kFg38),
                        ),
                        trailing: PopupMenuButton<String>(
                          color: kCard,
                          icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                          onSelected: (v) async {
                            if (v == 'open') {
                              final url = d['file_url'] as String?;
                              if (url != null) {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              }
                            }
                            if (v == 'delete') {
                              try {
                                await widget.state.deleteVaultDocument(d);
                                _load();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'open', child: Text('Open')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () async {
                          final url = d['file_url'] as String?;
                          if (url != null) {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
