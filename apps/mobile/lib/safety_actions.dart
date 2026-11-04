import 'package:flutter/material.dart';
import 'package:upendo_pamoja/connect.dart';

const _paper = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1917);
const _inkSoft = Color(0xFF44403C);
const _mute = Color(0xFFA8A29E);
const _clay = Color(0xFFE72570);
const _line = Color(0xFFE7DCCB);

const reportReasons = [
  ('harassment', 'Harassment'),
  ('scam', 'Scam or money ask'),
  ('impersonation', 'Fake or stolen photos'),
  ('outing_threat', 'Threat to expose someone'),
  ('coercion', 'Pressure or coercion'),
  ('spam', 'Spam'),
  ('other', 'Something else'),
];

/// Opens the report sheet used from Home cards and chat. Same clay/paper look as Edit Profile.
Future<bool> showReportPersonSheet(
  BuildContext context, {
  required String otherUserId,
  String? otherName,
}) async {
  final name = (otherName == null || otherName.trim().isEmpty) ? 'this person' : otherName.trim();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      String? reason;
      final details = TextEditingController();
      var sending = false;
      String? note;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: StatefulBuilder(
          builder: (context, setSheet) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Report', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Tell us what happened with $name. A report is for review. Blocking stops contact at once.',
                    style: const TextStyle(color: _inkSoft, fontSize: 14, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  for (final item in reportReasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: reason == item.$1 ? const Color(0xFFFFF0F5) : _paper,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: sending ? null : () => setSheet(() => reason = item.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: reason == item.$1 ? _clay : _line),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.$2, style: const TextStyle(color: _ink, fontSize: 16))),
                                if (reason == item.$1) const Icon(Icons.check, color: _clay, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  TextField(
                    controller: details,
                    enabled: !sending,
                    maxLength: 400,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Details (optional)',
                      counterText: '',
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Text(note!, style: const TextStyle(color: _mute, height: 1.35)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: sending
                        ? null
                        : () async {
                            final chosen = reason;
                            if (chosen == null) {
                              setSheet(() => note = 'Choose a reason first.');
                              return;
                            }
                            setSheet(() {
                              sending = true;
                              note = null;
                            });
                            final problem = await reportPerson(
                              otherUserId: otherUserId,
                              reason: chosen,
                              details: details.text.trim(),
                            );
                            if (!context.mounted) return;
                            if (problem != null) {
                              setSheet(() {
                                sending = false;
                                note = problem;
                              });
                              return;
                            }
                            Navigator.pop(context, true);
                          },
                    child: Text(sending ? 'Sending…' : 'Send report'),
                  ),
                  TextButton(
                    onPressed: sending ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
  return result == true;
}
