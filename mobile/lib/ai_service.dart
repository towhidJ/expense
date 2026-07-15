import 'app_state.dart' show supabase;
import 'models.dart';

/// Client for the `gemini` edge function. All AI runs server-side; the user's
/// JWT is attached automatically by the Supabase client, so no Gemini key ever
/// lives on the device.
class AiService {
  static Future<Map<String, dynamic>> _invoke(
      String action, Map<String, dynamic> payload) async {
    final res = await supabase.functions.invoke(
      'gemini',
      body: {'action': action, ...payload},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is Map && data['result'] is Map) {
      return Map<String, dynamic>.from(data['result'] as Map);
    }
    throw Exception('Unexpected AI response');
  }

  /// Free text -> {type, category_id, account_id, amount, description, date}.
  static Future<Map<String, dynamic>> parseTransaction(
    String text, {
    required List<Category> categories,
    required List<Account> accounts,
  }) {
    return _invoke('parse_transaction', {
      'text': text,
      'categories': categories
          .map((c) => {'id': c.id, 'name': c.name, 'type': c.type})
          .toList(),
      'accounts': accounts.map((a) => {'id': a.id, 'name': a.name}).toList(),
    });
  }

  /// base64 image (no data: prefix) -> {items: [...]}.
  static Future<Map<String, dynamic>> parseReceipt(
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) {
    return _invoke('parse_receipt', {'image': imageBase64, 'mimeType': mimeType});
  }

  /// Aggregated numbers + question -> {answer}.
  static Future<Map<String, dynamic>> insights(
      Map<String, dynamic> context, String question) {
    return _invoke('insights', {'context': context, 'question': question});
  }

  /// Meal RPC JSON -> {report}.
  static Future<Map<String, dynamic>> mealReport(Map<String, dynamic> summary) {
    return _invoke('meal_report', {'summary': summary});
  }
}
