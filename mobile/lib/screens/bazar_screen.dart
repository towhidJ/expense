import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../item_editor.dart';
import '../models.dart';
import '../theme.dart';

/// Bazar (বাজার): daily cash bazar + shop dues (বাকির খাতা).
/// Cash purchase → expense + account debited. Due purchase → expense + shop
/// due grows. Paying a shop reduces the due without double-counting expense.
class BazarScreen extends StatefulWidget {
  const BazarScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BazarScreen> createState() => _BazarScreenState();
}

class _BazarScreenState extends State<BazarScreen> {
  List<Liability>? _shops;
  List<BazarPurchase> _purchases = [];
  List<Repayment> _payments = [];
  int _historyTab = 0;
  final Set<String> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (shops, purchases, payments) = await widget.state.fetchBazar();
    if (mounted) {
      setState(() {
        _shops = shops;
        _purchases = purchases;
        _payments = payments;
      });
    }
  }

  String get _thisMonth => DateFormat('yyyy-MM').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final shops = _shops;
    final monthPurchases =
        _purchases.where((p) => DateFormat('yyyy-MM').format(p.date) == _thisMonth).toList();
    final monthTotal = monthPurchases.fold<double>(0, (s, p) => s + p.amount);
    final monthCash = monthPurchases
        .where((p) => p.paymentType == 'cash')
        .fold<double>(0, (s, p) => s + p.amount);
    final totalDue = (shops ?? []).fold<double>(0, (s, x) => s + x.remainingBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bazar (বাজার)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'New Shop',
            onPressed: () => _shopForm(),
            icon: const Icon(Icons.add_business_outlined, color: kCyan),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: shops == null ? null : _purchaseForm,
        backgroundColor: kCyan,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('New Purchase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: shops == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  FadeSlideIn(
                    index: 0,
                    child: Row(
                      children: [
                        Expanded(child: _tile('This Month', taka(monthTotal), kCyan)),
                        const SizedBox(width: 10),
                        Expanded(child: _tile('Cash (নগদ)', taka(monthCash), kEmerald)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    index: 1,
                    child: Row(
                      children: [
                        Expanded(child: _tile('On Due (বাকিতে)', taka(monthTotal - monthCash), kOrange)),
                        const SizedBox(width: 10),
                        Expanded(child: _tile('Total Shop Due', taka(totalDue), kRed)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    index: 2,
                    child: Text('Shops (দোকানের খাতা)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kFg)),
                  ),
                  const SizedBox(height: 10),
                  if (shops.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.storefront_outlined, size: 34, color: kFg24),
                            const SizedBox(height: 8),
                            Text('No shops yet. Add the shops you buy bazar\nfrom on credit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: kFg38)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...shops.asMap().entries.map((e) => FadeSlideIn(
                          index: 3 + e.key,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _shopCard(e.value),
                          ),
                        )),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    index: 5,
                    child: Row(
                      children: [
                        _historyChip('Purchases (${_purchases.length})', 0),
                        const SizedBox(width: 8),
                        _historyChip('Due Payments (${_payments.length})', 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _historyTab == 0
                        ? Column(
                            key: const ValueKey('purchases'),
                            children: _purchases.isEmpty
                                ? [_empty('No bazar purchases yet.')]
                                : _purchases.map(_purchaseRow).toList(),
                          )
                        : Column(
                            key: const ValueKey('payments'),
                            children: _payments.isEmpty
                                ? [_empty('No due payments yet.')]
                                : _payments.map(_paymentRow).toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tile(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: kFg38)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(msg, style: TextStyle(fontSize: 12, color: kFg38))),
      );

  Widget _historyChip(String label, int idx) {
    final active = _historyTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _historyTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? kCyan.withValues(alpha: 0.15) : kFg.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? kCyan.withValues(alpha: 0.4) : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? kCyan : kFg38)),
        ),
      ),
    );
  }

  Widget _shopCard(Liability shop) {
    final hasDue = shop.remainingBalance > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.storefront_outlined, color: kOrange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, color: kFg)),
                      if (shop.phone.isNotEmpty)
                        Text(shop.phone, style: TextStyle(fontSize: 11, color: kFg38)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _shopForm(shop: shop),
                  icon: Icon(Icons.edit_outlined, size: 18, color: kFg38),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteShop(shop),
                  icon: Icon(Icons.delete_outline, size: 18, color: kRed.withValues(alpha: 0.7)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Due (বাকি)', style: TextStyle(fontSize: 11, color: kFg38)),
                      Text(taka(shop.remainingBalance),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: hasDue ? kRed : kEmerald)),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: hasDue ? () => _payForm(shop) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: kEmerald.withValues(alpha: 0.15),
                    foregroundColor: kEmerald,
                  ),
                  child: const Text('Pay Due', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _purchaseRow(BazarPurchase p) {
    final isCash = p.paymentType == 'cash';
    final isOpen = _expandedItems.contains(p.id);
    final fallbackTitle =
        p.items.isNotEmpty ? p.items.map((i) => i.name).join(', ') : (isCash ? 'Cash bazar' : 'Due bazar');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            dense: true,
            onTap: p.items.isEmpty
                ? null
                : () => setState(() {
                      isOpen ? _expandedItems.remove(p.id) : _expandedItems.add(p.id);
                    }),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (isCash ? kEmerald : kOrange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isCash ? Icons.payments_outlined : Icons.handshake_outlined,
                  size: 18, color: isCash ? kEmerald : kOrange),
            ),
            title: Text(
              p.description.isEmpty ? fallbackTitle : p.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: kFg),
            ),
            subtitle: Text(
              '${DateFormat('d MMM yyyy').format(p.date)} • ${isCash ? p.accountName : (p.shopName.isEmpty ? 'Deleted shop' : p.shopName)}'
              '${p.items.isNotEmpty ? ' • ${p.items.length} item${p.items.length > 1 ? 's' : ''}' : ''}',
              style: TextStyle(fontSize: 11, color: kFg38),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(taka(p.amount),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kFg)),
                PopupMenuButton<String>(
                  color: kCard,
                  icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                  onSelected: (v) {
                    if (v == 'invoice') _viewInvoice(p);
                    if (v == 'edit') _editPurchaseForm(p);
                    if (v == 'delete') _deletePurchase(p);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'invoice', child: Text('📎 View invoice')),
                    PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                    PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                  ],
                ),
              ],
            ),
          ),
          if (isOpen && p.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: ItemListView(items: p.items),
            ),
        ],
      ),
    );
  }

  // ---- Invoice viewer ----

  Future<void> _viewInvoice(BazarPurchase p) async {
    if (p.transactionId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No invoice attached to this purchase.')));
      return;
    }
    List<AttachmentInfo> atts;
    try {
      atts = await widget.state.fetchTransactionAttachments(p.transactionId!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      return;
    }
    if (!mounted) return;
    if (atts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No invoice attached to this purchase.')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Invoice / Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...atts.map((a) => ListTile(
                  leading: Icon(a.isImage ? Icons.image_outlined : Icons.description_outlined,
                      color: kCyan),
                  title: Text(a.fileName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5)),
                  trailing: Icon(Icons.chevron_right, color: kFg24),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _viewAttachment(a);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _viewAttachment(AttachmentInfo a) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: kCard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: InteractiveViewer(
                  child: Image.network(
                    a.fileUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : const Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(color: kCyan),
                          ),
                    errorBuilder: (c, err, st) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not display "${a.fileName}" — it may not be an image.',
                          style: TextStyle(color: kFg54)),
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Edit purchase ----

  Future<void> _editPurchaseForm(BazarPurchase p) async {
    final st = widget.state;
    final isCash = p.paymentType == 'cash';
    Account? account = isCash
        ? st.accounts.where((a) => a.id == p.accountId).firstOrNull ?? st.accounts.firstOrNull
        : null;
    DateTime date = p.date;
    final amount = TextEditingController(
        text: p.amount % 1 == 0 ? p.amount.toStringAsFixed(0) : p.amount.toString());
    final desc = TextEditingController(text: p.description);
    final drafts = p.items.map(ItemDraft.new).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Bazar Purchase',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kFg)),
                const SizedBox(height: 4),
                Text(
                  isCash
                      ? 'Cash purchase — account balance adjusts automatically.'
                      : 'Due purchase — the shop\'s due (${p.shopName.isEmpty ? 'shop' : p.shopName}) adjusts automatically.',
                  style: TextStyle(fontSize: 11, color: kFg38),
                ),
                const SizedBox(height: 16),
                if (isCash)
                  DropdownButtonFormField<Account>(
                    initialValue: account,
                    decoration: const InputDecoration(labelText: 'Pay From Account'),
                    items: st.accounts
                        .map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${taka(a.currentBalance)})')))
                        .toList(),
                    onChanged: (v) => setSheet(() => account = v),
                  ),
                if (isCash) const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetCtx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035));
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('d MMM yyyy').format(date), style: TextStyle(color: kFg)),
                  ),
                ),
                const SizedBox(height: 12),
                ItemRowsEditor(drafts: drafts, onChanged: () => setSheet(() {})),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Changes',
                  onPressed: () async {
                    final amt = double.tryParse(amount.text);
                    if (amt == null || amt <= 0) return;
                    try {
                      await st.updateBazarPurchase(
                        purchase: p,
                        amount: amt,
                        date: date,
                        description: desc.text.trim(),
                        items: draftsToItems(drafts),
                        accountId: account?.id,
                      );
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      _load();
                    } catch (e) {
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e')));
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
  }

  Widget _paymentRow(Repayment r) {
    final shop = (_shops ?? []).where((s) => s.id == r.liabilityId).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kEmerald.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle_outline, size: 18, color: kEmerald),
        ),
        title: Text(shop.isEmpty ? 'Shop payment' : shop.first.name,
            style: TextStyle(fontSize: 13.5, color: kFg)),
        subtitle: Text(
          '${DateFormat('d MMM yyyy').format(r.date)} • from ${r.accountName}${r.notes.isNotEmpty ? ' • ${r.notes}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: kFg38),
        ),
        trailing: Text(taka(r.amount),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: kEmerald)),
      ),
    );
  }

  // ---------- forms ----------

  Future<void> _shopForm({Liability? shop}) async {
    final name = TextEditingController(text: shop?.name ?? '');
    final phone = TextEditingController(text: shop?.phone ?? '');
    final notes = TextEditingController(text: shop?.notes ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop == null ? 'Add Shop' : 'Edit Shop',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kFg)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Shop Name')),
            const SizedBox(height: 12),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)')),
            const SizedBox(height: 12),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 16),
            GradientButton(
              label: shop == null ? 'Add Shop' : 'Save Changes',
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                try {
                  if (shop == null) {
                    await widget.state.addShop(name: name.text.trim(), phone: phone.text.trim(), notes: notes.text.trim());
                  } else {
                    await widget.state.updateShop(id: shop.id, name: name.text.trim(), phone: phone.text.trim(), notes: notes.text.trim());
                  }
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  _load();
                } catch (e) {
                  if (sheetCtx.mounted) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteShop(Liability shop) async {
    if (shop.remainingBalance > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This shop still has due. Pay it off before deleting.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete shop?'),
        content: Text('Delete "${shop.name}"? Purchase history will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) {
      await widget.state.deleteLiability(shop.id);
      _load();
    }
  }

  Future<void> _deletePurchase(BazarPurchase p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete purchase?'),
        content: const Text('Account balance / shop due will be restored.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) {
      await widget.state.deleteBazarPurchase(p.id);
      _load();
    }
  }

  Future<void> _purchaseForm() async {
    final st = widget.state;
    final expenseCats = st.categories.where((c) => c.type == 'expense').toList();
    Category? category = expenseCats.where((c) => RegExp(r'bazar|বাজার|groc|food|খাবার', caseSensitive: false).hasMatch(c.name)).firstOrNull ?? expenseCats.firstOrNull;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create an expense category (e.g. "Bazar") first.')));
      return;
    }
    String paymentType = 'cash';
    Account? account = st.accounts.firstOrNull;
    Liability? shop = (_shops ?? []).firstOrNull;
    DateTime date = DateTime.now();
    final amount = TextEditingController();
    final desc = TextEditingController();
    final drafts = <ItemDraft>[];
    XFile? invoice;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Record a Bazar Purchase',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kFg)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _payTypeBtn(sheetCtx, 'cash', 'Cash (নগদ)', Icons.payments_outlined, kEmerald,
                        paymentType, (v) => setSheet(() => paymentType = v)),
                    const SizedBox(width: 8),
                    _payTypeBtn(sheetCtx, 'due', 'Due (বাকিতে)', Icons.handshake_outlined, kOrange,
                        paymentType, (v) => setSheet(() => paymentType = v)),
                  ],
                ),
                const SizedBox(height: 12),
                if (paymentType == 'cash')
                  DropdownButtonFormField<Account>(
                    initialValue: account,
                    decoration: const InputDecoration(labelText: 'Pay From Account'),
                    items: st.accounts
                        .map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${taka(a.currentBalance)})')))
                        .toList(),
                    onChanged: (v) => setSheet(() => account = v),
                  )
                else if ((_shops ?? []).isEmpty)
                  Text('No shops yet — add one with the shop icon on top first.',
                      style: TextStyle(fontSize: 12, color: kOrange.withValues(alpha: 0.9)))
                else
                  DropdownButtonFormField<Liability>(
                    initialValue: shop,
                    decoration: const InputDecoration(labelText: 'Shop (দোকান)'),
                    items: (_shops ?? [])
                        .map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (Due: ${taka(s.remainingBalance)})')))
                        .toList(),
                    onChanged: (v) => setSheet(() => shop = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Category>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: expenseCats
                      .map((c) => DropdownMenuItem(value: c, child: Text('${c.icon} ${c.name}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => category = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetCtx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035));
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('d MMM yyyy').format(date), style: TextStyle(color: kFg)),
                  ),
                ),
                const SizedBox(height: 12),
                ItemRowsEditor(drafts: drafts, onChanged: () => setSheet(() {})),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCyan,
                    side: BorderSide(color: kCyan.withValues(alpha: 0.4)),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(invoice != null ? 'Invoice photo selected ✓' : 'Attach invoice / receipt',
                      style: const TextStyle(fontSize: 12.5)),
                  onPressed: () async {
                    final source = await showModalBottomSheet<ImageSource>(
                      context: sheetCtx,
                      builder: (c) => SafeArea(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          ListTile(
                              leading: const Icon(Icons.photo_camera_outlined),
                              title: const Text('Camera'),
                              onTap: () => Navigator.pop(c, ImageSource.camera)),
                          ListTile(
                              leading: const Icon(Icons.photo_library_outlined),
                              title: const Text('Gallery'),
                              onTap: () => Navigator.pop(c, ImageSource.gallery)),
                        ]),
                      ),
                    );
                    if (source == null) return;
                    final img = await ImagePicker()
                        .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
                    if (img != null) setSheet(() => invoice = img);
                  },
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Purchase',
                  onPressed: () async {
                    final amt = double.tryParse(amount.text);
                    if (amt == null || amt <= 0) return;
                    if (paymentType == 'cash' && account == null) return;
                    if (paymentType == 'due' && shop == null) return;
                    try {
                      final txnId = await st.addBazarPurchase(
                        categoryId: category!.id,
                        amount: amt,
                        date: date,
                        paymentType: paymentType,
                        accountId: account?.id,
                        shopId: shop?.id,
                        description: desc.text.trim(),
                        items: draftsToItems(drafts),
                      );
                      if (invoice != null && txnId != null) {
                        final bytes = await invoice!.readAsBytes();
                        await st.uploadTransactionAttachment(
                          transactionId: txnId,
                          bytes: bytes,
                          filename: invoice!.name,
                          contentType: invoice!.mimeType ?? 'image/jpeg',
                        );
                      }
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      _load();
                    } catch (e) {
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e')));
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
  }

  Widget _payTypeBtn(BuildContext ctx, String value, String label, IconData icon, Color color,
      String current, void Function(String) onPick) {
    final active = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onPick(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.16) : kFg.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: active ? color.withValues(alpha: 0.45) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? color : kFg38),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? color : kFg38)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _payForm(Liability shop) async {
    final st = widget.state;
    Account? account = st.accounts.firstOrNull;
    final amount = TextEditingController(text: shop.remainingBalance.toStringAsFixed(0));
    final notes = TextEditingController();
    DateTime date = DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pay Due — ${shop.name}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kFg)),
              const SizedBox(height: 4),
              Text('Current due: ${taka(shop.remainingBalance)}',
                  style: TextStyle(fontSize: 12, color: kFg38)),
              const SizedBox(height: 16),
              DropdownButtonFormField<Account>(
                initialValue: account,
                decoration: const InputDecoration(labelText: 'Pay From Account'),
                items: st.accounts
                    .map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${taka(a.currentBalance)})')))
                    .toList(),
                onChanged: (v) => setSheet(() => account = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount', helperText: 'Partial payment is fine — the rest stays as due.'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                      context: sheetCtx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                  if (picked != null) setSheet(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(DateFormat('d MMM yyyy').format(date), style: TextStyle(color: kFg)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Pay',
                onPressed: () async {
                  final amt = double.tryParse(amount.text);
                  if (amt == null || amt <= 0 || account == null) return;
                  try {
                    await st.repayLiability(
                        liabilityId: shop.id, accountId: account!.id, amount: amt, date: date, notes: notes.text.trim());
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    _load();
                  } catch (e) {
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
