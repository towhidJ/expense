import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'theme.dart';

/// OTA updates: the admin panel (web /admin) uploads an APK and a row in
/// app_versions; the app compares its versionCode against the newest row and
/// hands the download URL to the Android side (DownloadManager + installer).
const _ota = MethodChannel('com.towhid.expense_tracker/ota');

Future<int> currentVersionCode() async => await _ota.invokeMethod<int>('getVersionCode') ?? 0;

Future<String> currentVersionName() async =>
    await _ota.invokeMethod<String>('getVersionName') ?? '?';

/// Checks app_versions for a newer release and offers to install it.
/// [manual] = user tapped "Check for Updates": also report "already latest".
Future<void> checkForUpdate(BuildContext context, {bool manual = false}) async {
  Map<String, dynamic>? latest;
  int installed;
  try {
    installed = await currentVersionCode();
    latest = await supabase
        .from('app_versions')
        .select()
        .order('version_code', ascending: false)
        .limit(1)
        .maybeSingle();
  } catch (e) {
    if (manual && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update check failed: $e')));
    }
    return;
  }
  if (!context.mounted) return;

  if (latest == null || (latest['version_code'] as num).toInt() <= installed) {
    if (manual) {
      final name = await currentVersionName();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You are on the latest version (v$name).')));
      }
    }
    return;
  }

  final versionName = latest['version_name'] as String? ?? '?';
  final notes = latest['notes'] as String? ?? '';
  final url = latest['apk_url'] as String?;
  final sizeBytes = (latest['file_size'] as num?)?.toDouble();
  if (url == null) return;

  final install = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.system_update, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Update Available', style: TextStyle(fontSize: 17))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version $versionName'
              '${sizeBytes != null ? ' • ${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: kCyan)),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(notes, style: TextStyle(fontSize: 13, color: kFg70)),
          ],
          const SizedBox(height: 10),
          Text('The APK downloads in the background — tap the notification if the installer does not open by itself.',
              style: TextStyle(fontSize: 11.5, color: kFg38)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kCyan),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Update Now'),
        ),
      ],
    ),
  );
  if (install != true || !context.mounted) return;

  try {
    await _ota.invokeMethod('downloadAndInstall', {
      'url': url,
      'fileName': 'TakaKhata-v$versionName.apk',
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading update… installer will open when done.')));
    }
  } on PlatformException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: ${e.message}')));
    }
  }
}
