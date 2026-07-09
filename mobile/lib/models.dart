class Entity {
  Entity.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'personal';
  final String id;
  final String name;
  final String type;
}

class Account {
  Account.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'cash',
        currentBalance = (m['current_balance'] as num?)?.toDouble() ?? 0,
        currency = m['currency'] ?? '৳',
        accountNumber = m['account_number'] ?? '';
  final String id;
  final String name;
  final String type;
  final double currentBalance;
  final String currency;
  final String accountNumber; // bank a/c no, bKash number, etc.
}

class SavingHead {
  SavingHead.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        savingType = m['saving_type'] ?? 'general',
        institution = m['institution'] ?? '',
        accountNumber = m['account_number'] ?? '',
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String savingType;
  final String institution;
  final String accountNumber;
  final String notes;
}

class Category {
  Category.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'expense',
        icon = m['icon'] ?? '💰',
        color = m['color'] ?? '#6366f1';
  final String id;
  final String name;
  final String type; // income | expense
  final String icon;
  final String color;
}

class Tx {
  Tx.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        type = m['type'] ?? 'expense',
        categoryId = m['category_id'],
        accountId = m['account_id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        description = m['description'] ?? '',
        date = DateTime.parse(m['date']),
        categoryName = m['categories']?['name'] ?? '',
        categoryIcon = m['categories']?['icon'] ?? '💰',
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String type;
  final String? categoryId;
  final String? accountId;
  final double amount;
  final String description;
  final DateTime date;
  final String categoryName;
  final String categoryIcon;
  final String accountName;
}

class Budget {
  Budget.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        categoryId = m['category_id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        month = m['month'] ?? 1,
        year = m['year'] ?? 2026,
        categoryName = m['categories']?['name'] ?? '',
        categoryIcon = m['categories']?['icon'] ?? '💰';
  final String id;
  final String? categoryId;
  final double amount;
  final int month;
  final int year;
  final String categoryName;
  final String categoryIcon;
}

class Goal {
  Goal.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        targetAmount = (m['target_amount'] as num?)?.toDouble() ?? 0,
        savedAmount = (m['saved_amount'] as num?)?.toDouble() ?? 0,
        targetDate = m['target_date'] != null ? DateTime.parse(m['target_date']) : null,
        notes = m['notes'] ?? '';
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final String notes;
}

class Saving {
  Saving.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        type = m['type'] ?? 'deposit',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        purpose = m['purpose'] ?? '',
        notes = m['notes'] ?? '',
        savingType = m['saving_type'] ?? 'general',
        institution = m['institution'] ?? '',
        headId = m['head_id'],
        headName = m['saving_heads']?['name'] ?? '',
        accountId = m['account_id'],
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String type; // deposit | withdraw
  final double amount;
  final DateTime date;
  final String purpose;
  final String notes;
  final String savingType; // general | bank | dps | fdr | cash | other
  final String institution; // bank/place where the money is kept
  final String? headId;
  final String headName;
  final String? accountId;
  final String accountName;
}

class RecurringSaving {
  RecurringSaving.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        frequency = m['frequency'] ?? 'monthly',
        nextRunDate = DateTime.parse(m['next_run_date']),
        isActive = m['is_active'] ?? true,
        savingType = m['saving_type'] ?? 'general',
        institution = m['institution'] ?? '',
        headId = m['head_id'],
        headName = m['saving_heads']?['name'] ?? '',
        accountId = m['account_id'],
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String title;
  final double amount;
  final String frequency;
  final DateTime nextRunDate;
  final bool isActive;
  final String savingType;
  final String institution;
  final String? headId;
  final String headName;
  final String? accountId;
  final String accountName;
}

class FamilyMember {
  FamilyMember.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        relationship = m['relationship'] ?? '',
        dateOfBirth = m['date_of_birth'] != null ? DateTime.parse(m['date_of_birth']) : null,
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String relationship;
  final DateTime? dateOfBirth;
  final String notes;
}

class Asset {
  Asset.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'Other',
        purchaseValue = (m['purchase_value'] as num?)?.toDouble() ?? 0,
        currentValue = (m['current_value'] as num?)?.toDouble() ?? 0,
        depreciation = (m['depreciation'] as num?)?.toDouble() ?? 0,
        purchaseDate = m['purchase_date'] != null ? DateTime.parse(m['purchase_date']) : null,
        quantity = (m['quantity'] as num?)?.toDouble(),
        unit = m['unit'] ?? '',
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String type;
  final double purchaseValue;
  final double currentValue;
  final double depreciation;
  final DateTime? purchaseDate;
  final double? quantity; // e.g. 5.5 bhori of gold, 10 katha of land
  final String unit;
  final String notes;
}

class Investment {
  Investment.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'stocks',
        investedAmount = (m['invested_amount'] as num?)?.toDouble() ?? 0,
        currentValue = (m['current_value'] as num?)?.toDouble() ?? 0,
        roi = (m['roi'] as num?)?.toDouble() ?? 0,
        profitLoss = (m['profit_loss'] as num?)?.toDouble() ?? 0;
  final String id;
  final String name;
  final String type;
  final double investedAmount;
  final double currentValue;
  final double roi;
  final double profitLoss;
}

class Liability {
  Liability.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'loan_taken',
        principal = (m['principal'] as num?)?.toDouble() ?? 0,
        interestRate = (m['interest_rate'] as num?)?.toDouble() ?? 0,
        dueDate = m['due_date'] != null ? DateTime.parse(m['due_date']) : null,
        remainingBalance = (m['remaining_balance'] as num?)?.toDouble() ?? 0,
        phone = m['phone'] ?? '',
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String type;
  final double principal;
  final double interestRate;
  final DateTime? dueDate;
  final double remainingBalance;
  final String phone; // shop contact for type shop_due
  final String notes;

  /// loan_given is money owed TO the user (a receivable), not a debt.
  bool get isReceivable => type == 'loan_given';

  /// shop_due rows are the Bazar page's shop khatas.
  bool get isShop => type == 'shop_due';
}

class BazarPurchase {
  BazarPurchase.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        liabilityId = m['liability_id'],
        accountId = m['account_id'],
        transactionId = m['transaction_id'],
        paymentType = m['payment_type'] ?? 'cash',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        description = m['description'] ?? '',
        shopName = m['liabilities']?['name'] ?? '',
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String? liabilityId;
  final String? accountId;
  final String? transactionId;
  final String paymentType; // cash | due
  final double amount;
  final DateTime date;
  final String description;
  final String shopName;
  final String accountName;
}

class Repayment {
  Repayment.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        liabilityId = m['liability_id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        notes = m['notes'] ?? '',
        accountId = m['account_id'],
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String? liabilityId;
  final double amount;
  final DateTime date;
  final String notes;
  final String? accountId;
  final String accountName;
}

class Recurring {
  Recurring.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        type = m['type'] ?? 'expense',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        frequency = m['frequency'] ?? 'monthly',
        nextRunDate = DateTime.parse(m['next_run_date']),
        isActive = m['is_active'] ?? true,
        categoryId = m['category_id'],
        accountId = m['account_id'],
        categoryName = m['categories']?['name'] ?? '',
        categoryIcon = m['categories']?['icon'] ?? '💰',
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String title;
  final String type;
  final double amount;
  final String frequency;
  final DateTime nextRunDate;
  final bool isActive;
  final String? categoryId;
  final String? accountId;
  final String categoryName;
  final String categoryIcon;
  final String accountName;
}

class Transfer {
  Transfer.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        notes = m['notes'] ?? '',
        fromName = m['from_account']?['name'] ?? '?',
        toName = m['to_account']?['name'] ?? '?';
  final String id;
  final double amount;
  final DateTime date;
  final String notes;
  final String fromName;
  final String toName;
}
