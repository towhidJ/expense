// `hide Category`: Flutter's foundation exports a `Category` annotation that
// clashes with our model class.
import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

final supabase = Supabase.instance.client;

/// Holds the signed-in user's workspaces, accounts and categories, and wraps
/// every money movement in the balance-safe Postgres RPCs (never plain
/// inserts/updates — see the web app's hooks).
class AppState extends ChangeNotifier {
  List<Entity> entities = [];
  Entity? currentEntity;
  List<Account> accounts = [];
  List<Category> categories = [];
  bool loading = true;

  String get _uid => supabase.auth.currentUser!.id;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final rows = await supabase
        .from('entities')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: true);
    entities = rows.map<Entity>(Entity.fromMap).toList();
    if (entities.isNotEmpty &&
        (currentEntity == null || !entities.any((e) => e.id == currentEntity!.id))) {
      currentEntity = entities.first;
    }
    await _loadEntityData();
    loading = false;
    notifyListeners();
  }

  Future<void> _loadEntityData() async {
    if (currentEntity == null) {
      accounts = [];
      categories = [];
      return;
    }
    final results = await Future.wait([
      supabase.from('accounts').select().eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('created_at'),
      supabase.from('categories').select().eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('name'),
    ]);
    accounts = results[0].map<Account>(Account.fromMap).toList();
    categories = results[1].map<Category>(Category.fromMap).toList();
  }

  Future<void> switchEntity(Entity e) async {
    currentEntity = e;
    loading = true;
    notifyListeners();
    await _loadEntityData();
    loading = false;
    notifyListeners();
  }

  Future<void> refreshAccounts() async {
    if (currentEntity == null) return;
    final rows = await supabase
        .from('accounts')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at');
    accounts = rows.map<Account>(Account.fromMap).toList();
    notifyListeners();
  }

  // ---- Transactions ----

  Future<List<Tx>> fetchTransactions({DateTime? start, DateTime? end, String? type}) async {
    if (currentEntity == null) return [];
    var q = supabase
        .from('transactions')
        .select('*, categories(name, icon, color), accounts(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id);
    if (type != null) q = q.eq('type', type);
    if (start != null) q = q.gte('date', _d(start));
    if (end != null) q = q.lte('date', _d(end));
    final rows = await q.order('date', ascending: false);
    return rows.map<Tx>(Tx.fromMap).toList();
  }

  Future<void> addTransaction({
    required String accountId,
    required String categoryId,
    required String type,
    required double amount,
    required DateTime date,
    String description = '',
  }) async {
    await supabase.rpc('process_transaction', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_account_id': accountId,
      'p_category_id': categoryId,
      'p_asset_id': null,
      'p_type': type,
      'p_amount': amount,
      'p_date': _d(date),
      'p_description': description,
    });
    await refreshAccounts();
  }

  Future<void> updateTransaction({
    required String id,
    required String accountId,
    required String categoryId,
    required String type,
    required double amount,
    required DateTime date,
    String description = '',
  }) async {
    await supabase.rpc('update_transaction_with_balance', params: {
      'p_user_id': _uid,
      'p_transaction_id': id,
      'p_account_id': accountId,
      'p_category_id': categoryId,
      'p_asset_id': null,
      'p_type': type,
      'p_amount': amount,
      'p_date': _d(date),
      'p_description': description,
    });
    await refreshAccounts();
  }

  Future<void> deleteTransaction(String id) async {
    await supabase.rpc('delete_transaction_with_balance', params: {
      'p_user_id': _uid,
      'p_transaction_id': id,
    });
    await refreshAccounts();
  }

  // ---- Transfers ----

  Future<List<Transfer>> fetchTransfers() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('transfers')
        .select('*, from_account:from_account_id(name), to_account:to_account_id(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('date', ascending: false);
    return rows.map<Transfer>(Transfer.fromMap).toList();
  }

  Future<void> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String notes = '',
  }) async {
    await supabase.rpc('process_transfer', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_from_account': fromAccountId,
      'p_to_account': toAccountId,
      'p_amount': amount,
      'p_date': _d(date),
      'p_notes': notes,
    });
    await refreshAccounts();
  }

  // ---- Accounts ----

  Future<void> addAccount({
    required String name,
    required String type,
    required double openingBalance,
    String? accountNumber,
  }) async {
    await supabase.from('accounts').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'name': name,
      'type': type,
      'opening_balance': openingBalance,
      'current_balance': openingBalance,
      'account_number': (accountNumber == null || accountNumber.isEmpty) ? null : accountNumber,
    });
    await refreshAccounts();
  }

  // ---- Categories ----

  Future<void> refreshCategories() async {
    if (currentEntity == null) return;
    final rows = await supabase
        .from('categories')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('name');
    categories = rows.map<Category>(Category.fromMap).toList();
    notifyListeners();
  }

  Future<void> addCategory({required String name, required String type, required String icon, required String color}) async {
    await supabase.from('categories').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
    });
    await refreshCategories();
  }

  Future<void> updateCategory(String id, {required String name, required String icon, required String color}) async {
    await supabase.from('categories').update({'name': name, 'icon': icon, 'color': color}).eq('id', id).eq('user_id', _uid);
    await refreshCategories();
  }

  Future<void> deleteCategory(String id) async {
    await supabase.from('categories').delete().eq('id', id).eq('user_id', _uid);
    await refreshCategories();
  }

  // ---- Budgets ----

  Future<List<Budget>> fetchBudgets(int month, int year) async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('budgets')
        .select('*, categories(name, icon, color)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .eq('month', month)
        .eq('year', year);
    return rows.map<Budget>(Budget.fromMap).toList();
  }

  Future<void> addBudget({required String categoryId, required double amount, required int month, required int year}) async {
    await supabase.from('budgets').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'category_id': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
    });
  }

  Future<void> updateBudget(String id, double amount) async {
    await supabase.from('budgets').update({'amount': amount}).eq('id', id).eq('user_id', _uid);
  }

  Future<void> deleteBudget(String id) async {
    await supabase.from('budgets').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Goals ----

  Future<List<Goal>> fetchGoals() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('goals')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: false);
    return rows.map<Goal>(Goal.fromMap).toList();
  }

  Future<void> upsertGoal({String? id, required String title, required double targetAmount, required double savedAmount, DateTime? targetDate, String notes = ''}) async {
    final payload = {
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate == null ? null : _d(targetDate),
      'notes': notes,
    };
    if (id == null) {
      await supabase.from('goals').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('goals').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteGoal(String id) async {
    await supabase.from('goals').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Savings ----

  Future<List<Saving>> fetchSavings() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('savings')
        .select('*, accounts(name), saving_heads(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('date', ascending: false);
    return rows.map<Saving>(Saving.fromMap).toList();
  }

  Future<void> addSaving({String? accountId, required String type, required double amount, required DateTime date, String? purpose, String? notes, String savingType = 'general', String? institution, String? headId}) async {
    if (accountId != null) {
      // RPC inserts the entry and adjusts the account balance atomically.
      await supabase.rpc('process_saving', params: {
        'p_user_id': _uid,
        'p_entity_id': currentEntity!.id,
        'p_account_id': accountId,
        'p_type': type,
        'p_amount': amount,
        'p_date': _d(date),
        'p_purpose': purpose,
        'p_notes': notes,
        'p_saving_type': savingType,
        'p_institution': institution,
        'p_head_id': headId,
      });
      await refreshAccounts();
    } else {
      await supabase.from('savings').insert({
        'user_id': _uid,
        'entity_id': currentEntity!.id,
        'account_id': null,
        'type': type,
        'amount': amount,
        'date': _d(date),
        'purpose': purpose,
        'notes': notes,
        'saving_type': savingType,
        'institution': institution,
        'head_id': headId,
      });
    }
  }

  // ---- Saving heads ----

  Future<List<SavingHead>> fetchSavingHeads() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('saving_heads')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: true);
    return rows.map<SavingHead>(SavingHead.fromMap).toList();
  }

  Future<void> upsertSavingHead({String? id, required String name, required String savingType, String? institution, String? accountNumber, String notes = ''}) async {
    final payload = {
      'name': name,
      'saving_type': savingType,
      'institution': (institution == null || institution.isEmpty) ? null : institution,
      'account_number': (accountNumber == null || accountNumber.isEmpty) ? null : accountNumber,
      'notes': notes,
    };
    if (id == null) {
      await supabase.from('saving_heads').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('saving_heads').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteSavingHead(String id) async {
    await supabase.from('saving_heads').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Recurring savings ----

  Future<List<RecurringSaving>> fetchRecurringSavings() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('recurring_savings')
        .select('*, accounts(name), saving_heads(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('next_run_date', ascending: true);
    return rows.map<RecurringSaving>(RecurringSaving.fromMap).toList();
  }

  Future<void> addRecurringSaving({required String title, required double amount, required String frequency, required DateTime nextRunDate, String? accountId, String savingType = 'general', String? institution, String? headId}) async {
    await supabase.from('recurring_savings').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'title': title,
      'amount': amount,
      'frequency': frequency,
      'next_run_date': _d(nextRunDate),
      'account_id': accountId,
      'saving_type': savingType,
      'institution': institution,
      'head_id': headId,
    });
  }

  Future<void> setRecurringSavingActive(String id, bool active) async {
    await supabase.from('recurring_savings').update({'is_active': active}).eq('id', id).eq('user_id', _uid);
  }

  Future<void> deleteRecurringSaving(String id) async {
    await supabase.from('recurring_savings').delete().eq('id', id).eq('user_id', _uid);
  }

  /// Processes all due recurring savings (catches up missed periods); returns
  /// the number of entries created.
  Future<int> runDueRecurringSavings() async {
    final count = await supabase.rpc('run_due_recurring_savings', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
    });
    await refreshAccounts();
    return (count as num?)?.toInt() ?? 0;
  }

  Future<void> deleteSaving(String id) async {
    // RPC restores the account balance before removing the row.
    await supabase.rpc('delete_saving_with_balance', params: {'p_user_id': _uid, 'p_saving_id': id});
    await refreshAccounts();
  }

  // ---- Family ----

  Future<List<FamilyMember>> fetchFamily() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('family_members')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: false);
    return rows.map<FamilyMember>(FamilyMember.fromMap).toList();
  }

  Future<void> upsertFamilyMember({String? id, required String name, required String relationship, DateTime? dateOfBirth, String notes = ''}) async {
    final payload = {
      'name': name,
      'relationship': relationship,
      'date_of_birth': dateOfBirth == null ? null : _d(dateOfBirth),
      'notes': notes,
    };
    if (id == null) {
      await supabase.from('family_members').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('family_members').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteFamilyMember(String id) async {
    await supabase.from('family_members').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Assets ----

  Future<List<Asset>> fetchAssets() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('assets')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('purchase_date', ascending: false);
    return rows.map<Asset>(Asset.fromMap).toList();
  }

  Future<void> upsertAsset({String? id, required String name, required String type, required double purchaseValue, required double currentValue, double depreciation = 0, DateTime? purchaseDate, String notes = '', double? quantity, String? unit}) async {
    final payload = {
      'name': name,
      'type': type,
      'purchase_value': purchaseValue,
      'current_value': currentValue,
      'depreciation': depreciation,
      'value': currentValue, // kept in sync for older components (web parity)
      'purchase_date': purchaseDate == null ? null : _d(purchaseDate),
      'notes': notes,
      'quantity': quantity,
      'unit': (unit == null || unit.isEmpty) ? null : unit,
    };
    if (id == null) {
      await supabase.from('assets').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('assets').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteAsset(String id) async {
    // Unlink transactions first — the FK on transactions.asset_id blocks
    // deleting an asset that still has linked expenses.
    await supabase.from('transactions').update({'asset_id': null}).eq('asset_id', id).eq('user_id', _uid);
    await supabase.from('assets').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Investments ----

  Future<List<Investment>> fetchInvestments() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('investments')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: false);
    return rows.map<Investment>(Investment.fromMap).toList();
  }

  Future<void> upsertInvestment({String? id, required String name, required String type, required double investedAmount, required double currentValue}) async {
    final profitLoss = currentValue - investedAmount;
    final roi = investedAmount > 0 ? double.parse((profitLoss / investedAmount * 100).toStringAsFixed(2)) : 0.0;
    final payload = {
      'name': name,
      'type': type,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'profit_loss': profitLoss,
      'roi': roi,
    };
    if (id == null) {
      await supabase.from('investments').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('investments').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteInvestment(String id) async {
    await supabase.from('investments').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Recurring ----

  Future<List<Recurring>> fetchRecurring() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('recurring_transactions')
        .select('*, categories(name, icon), accounts(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('next_run_date', ascending: true);
    return rows.map<Recurring>(Recurring.fromMap).toList();
  }

  Future<void> upsertRecurring({String? id, required String title, required String type, required String categoryId, required String accountId, required double amount, required String frequency, required DateTime nextRunDate, bool isActive = true}) async {
    final payload = {
      'title': title,
      'type': type,
      'category_id': categoryId,
      'account_id': accountId,
      'amount': amount,
      'frequency': frequency,
      'next_run_date': _d(nextRunDate),
      'is_active': isActive,
    };
    if (id == null) {
      await supabase.from('recurring_transactions').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('recurring_transactions').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> setRecurringActive(String id, bool active) async {
    await supabase.from('recurring_transactions').update({'is_active': active}).eq('id', id).eq('user_id', _uid);
  }

  Future<void> deleteRecurring(String id) async {
    await supabase.from('recurring_transactions').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Liabilities ----

  Future<(List<Liability>, List<Repayment>)> fetchLiabilities() async {
    if (currentEntity == null) return (<Liability>[], <Repayment>[]);
    final results = await Future.wait([
      supabase.from('liabilities').select().eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('created_at', ascending: false),
      supabase.from('loan_repayments').select('*, accounts(name)').eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('date', ascending: false),
    ]);
    return (
      results[0].map<Liability>(Liability.fromMap).toList(),
      results[1].map<Repayment>(Repayment.fromMap).toList(),
    );
  }

  Future<void> addLiability({required String name, required String type, required double principal, double interestRate = 0, DateTime? dueDate, String notes = '', String? accountId}) async {
    if (accountId != null) {
      // Money actually arrived in an account — the RPC records the loan and
      // credits the account atomically.
      await supabase.rpc('process_new_loan', params: {
        'p_user_id': _uid,
        'p_entity_id': currentEntity!.id,
        'p_name': name,
        'p_type': type,
        'p_principal': principal,
        'p_interest_rate': interestRate,
        'p_due_date': dueDate == null ? null : _d(dueDate),
        'p_notes': notes,
        'p_account_id': accountId,
      });
      await refreshAccounts();
    } else {
      await supabase.from('liabilities').insert({
        'user_id': _uid,
        'entity_id': currentEntity!.id,
        'name': name,
        'type': type,
        'principal': principal,
        'interest_rate': interestRate,
        'due_date': dueDate == null ? null : _d(dueDate),
        'remaining_balance': principal,
        'notes': notes,
      });
    }
  }

  Future<void> repayLiability({required String liabilityId, required String accountId, required double amount, required DateTime date, String notes = ''}) async {
    await supabase.rpc('process_loan_repayment', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_liability_id': liabilityId,
      'p_account_id': accountId,
      'p_amount': amount,
      'p_date': _d(date),
      'p_notes': notes,
    });
    await refreshAccounts();
  }

  Future<void> deleteLiability(String id) async {
    await supabase.from('liabilities').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Bazar (shop credit ledger, migration v14) ----

  Future<(List<Liability>, List<BazarPurchase>, List<Repayment>)> fetchBazar() async {
    if (currentEntity == null) return (<Liability>[], <BazarPurchase>[], <Repayment>[]);
    final results = await Future.wait([
      supabase
          .from('liabilities')
          .select()
          .eq('user_id', _uid)
          .eq('entity_id', currentEntity!.id)
          .eq('type', 'shop_due')
          .order('created_at', ascending: true),
      supabase
          .from('bazar_purchases')
          .select('*, accounts(name), liabilities(name)')
          .eq('user_id', _uid)
          .eq('entity_id', currentEntity!.id)
          .order('date', ascending: false)
          .order('created_at', ascending: false),
    ]);
    final shops = results[0].map<Liability>(Liability.fromMap).toList();
    final purchases = results[1].map<BazarPurchase>(BazarPurchase.fromMap).toList();
    List<Repayment> payments = [];
    if (shops.isNotEmpty) {
      final payRows = await supabase
          .from('loan_repayments')
          .select('*, accounts(name)')
          .eq('user_id', _uid)
          .eq('entity_id', currentEntity!.id)
          .inFilter('liability_id', shops.map((s) => s.id).toList())
          .order('date', ascending: false);
      payments = payRows.map<Repayment>(Repayment.fromMap).toList();
    }
    return (shops, purchases, payments);
  }

  Future<void> addShop({required String name, String phone = '', String notes = ''}) async {
    await supabase.from('liabilities').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'name': name,
      'type': 'shop_due',
      'principal': 0,
      'remaining_balance': 0,
      'phone': phone.isEmpty ? null : phone,
      'notes': notes,
    });
  }

  Future<void> updateShop({required String id, required String name, String phone = '', String notes = ''}) async {
    await supabase.from('liabilities').update({
      'name': name,
      'phone': phone.isEmpty ? null : phone,
      'notes': notes,
    }).eq('id', id).eq('user_id', _uid);
  }

  Future<void> addBazarPurchase({
    required String categoryId,
    required double amount,
    required DateTime date,
    required String paymentType, // cash | due
    String? accountId,
    String? shopId,
    String description = '',
  }) async {
    await supabase.rpc('process_bazar_purchase', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_category_id': categoryId,
      'p_amount': amount,
      'p_date': _d(date),
      'p_description': description.isEmpty ? null : description,
      'p_payment_type': paymentType,
      'p_account_id': paymentType == 'cash' ? accountId : null,
      'p_liability_id': paymentType == 'due' ? shopId : null,
    });
    await refreshAccounts();
  }

  Future<void> deleteBazarPurchase(String id) async {
    await supabase.rpc('delete_bazar_purchase', params: {
      'p_user_id': _uid,
      'p_purchase_id': id,
    });
    await refreshAccounts();
  }

  Future<void> updateAccount({required String id, required String name, required String type, String? accountNumber, required double currentBalance}) async {
    await supabase.from('accounts').update({
      'name': name,
      'type': type,
      'account_number': (accountNumber == null || accountNumber.isEmpty) ? null : accountNumber,
      'current_balance': currentBalance,
    }).eq('id', id).eq('user_id', _uid);
    await refreshAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await supabase.from('accounts').delete().eq('id', id).eq('user_id', _uid);
    await refreshAccounts();
  }

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
