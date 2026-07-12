import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Members: pending approvals, roles, remove, leave, and the invite code.
class MealMembersScreen extends StatefulWidget {
  const MealMembersScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealMembersScreen> createState() => _MealMembersScreenState();
}

class _MealMembersScreenState extends State<MealMembersScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  MealGroup? _group;
  List<MealGroupMember>? _members;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        state.fetchMealGroup(groupId),
        state.fetchMealMembers(groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _group = results[0] as MealGroup?;
        _members = results[1] as List<MealGroupMember>;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _run(Future<void> Function() action, {String? confirmText}) async {
    if (confirmText != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(confirmText),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm', style: TextStyle(color: kRed))),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    final pending = (members ?? []).where((m) => m.status == 'pending').toList();
    final approved = (members ?? []).where((m) => m.status == 'approved').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Members', style: TextStyle(fontWeight: FontWeight.bold))),
      body: members == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_group != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.key, color: kCyan),
                      title: Text(_group!.inviteCode,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4, color: kCyan)),
                      subtitle: Text('Share this code with your mess mates',
                          style: TextStyle(fontSize: 11, color: kFg38)),
                      trailing: IconButton(
                        icon: Icon(Icons.copy, size: 18, color: kFg54),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _group!.inviteCode));
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Invite code copied!')));
                        },
                      ),
                    ),
                  ),
                if (pending.isNotEmpty && widget.isManager) ...[
                  const SizedBox(height: 16),
                  Text('PENDING REQUESTS', style: TextStyle(fontSize: 11, color: kOrange, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  ...pending.map((m) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 17,
                            backgroundColor: kOrange.withValues(alpha: 0.12),
                            child: const Icon(Icons.person_outline, size: 18, color: kOrange),
                          ),
                          title: Text(m.displayName, style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Approve',
                                icon: const Icon(Icons.check_circle, color: kEmerald),
                                onPressed: () => _run(() => state.respondMealJoinRequest(m.id, true)),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                icon: const Icon(Icons.cancel, color: kRed),
                                onPressed: () => _run(() => state.respondMealJoinRequest(m.id, false)),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 16),
                Text('MEMBERS (${approved.length})',
                    style: TextStyle(fontSize: 11, color: kFg38, letterSpacing: 1)),
                const SizedBox(height: 8),
                ...approved.map((m) {
                  final isMe = m.userId == state.uid;
                  final isMgr = m.role == 'manager';
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: isMgr ? kGradient : null,
                          color: isMgr ? null : kFg.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(isMgr ? Icons.star : Icons.person_outline,
                            size: 18, color: isMgr ? Colors.white : kFg54),
                      ),
                      title: Text(isMe ? '${m.displayName} (you)' : m.displayName,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(isMgr ? 'Manager' : 'Member',
                          style: TextStyle(fontSize: 11, color: kFg38)),
                      trailing: (widget.isManager && !isMe)
                          ? PopupMenuButton<String>(
                              color: kCard,
                              icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                              onSelected: (v) {
                                if (v == 'role') {
                                  _run(() => state.setMealMemberRole(m.id, isMgr ? 'member' : 'manager'));
                                }
                                if (v == 'remove') {
                                  _run(() => state.removeMealMember(m.id),
                                      confirmText:
                                          'Remove "${m.displayName}" from the mess? Their past records stay in old months.');
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'role',
                                    child: Text(isMgr ? '⬇️ Demote to member' : '⭐ Make manager')),
                                if (!isMgr)
                                  const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('🚫 Remove', style: TextStyle(color: kRed))),
                              ],
                            )
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: BorderSide(color: kRed.withValues(alpha: 0.4)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Leave Group'),
                  onPressed: () => _run(
                    () async {
                      await state.leaveMealGroup(groupId);
                      if (context.mounted) Navigator.pop(context);
                    },
                    confirmText: 'Leave this meal group?',
                  ),
                ),
              ],
            ),
    );
  }
}
