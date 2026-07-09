import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<FamilyMember>? _members;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await widget.state.fetchFamily();
    if (mounted) setState(() => _members = m);
  }

  Future<void> _openForm({FamilyMember? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final relationship = TextEditingController(text: edit?.relationship ?? '');
    final notes = TextEditingController(text: edit?.notes ?? '');
    DateTime? dob = edit?.dateOfBirth;

    final ok = await showModalBottomSheet<bool>(
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
                Text(edit == null ? 'Add Family Member' : 'Edit Member',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: relationship,
                    decoration: const InputDecoration(labelText: 'Relationship', hintText: 'e.g. Mother, Brother')),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: dob ?? DateTime(1990),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => dob = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date of Birth (optional)'),
                    child: Text(dob == null ? '—' : DateFormat('MMM d, yyyy').format(dob!)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
                const SizedBox(height: 20),
                GradientButton(
                  label: edit == null ? 'Add Member' : 'Save',
                  onPressed: () {
                    if (name.text.trim().isEmpty || relationship.text.trim().isEmpty) return;
                    Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.state.upsertFamilyMember(
        id: edit?.id,
        name: name.text.trim(),
        relationship: relationship.text.trim(),
        dateOfBirth: dob,
        notes: notes.text.trim(),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return Scaffold(
      appBar: AppBar(title: const Text('Family', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_alt),
      ),
      body: members == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : members.isEmpty
              ? Center(child: Text('👪  No family members yet', style: TextStyle(color: kFg.withValues(alpha: 0.35))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = members[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _openForm(edit: m),
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(gradient: kGradient, shape: BoxShape.circle),
                          child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        title: Text(m.name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '${m.relationship}${m.dateOfBirth != null ? ' • ${DateFormat('MMM d, yyyy').format(m.dateOfBirth!)}' : ''}',
                          style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                        ),
                        trailing: PopupMenuButton<String>(
                          color: kCard,
                          icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                          onSelected: (v) async {
                            if (v == 'edit') _openForm(edit: m);
                            if (v == 'delete') {
                              await widget.state.deleteFamilyMember(m.id);
                              _load();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                            PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
