import 'package:flutter/material.dart';

import '../models/pact.dart';
import '../widgets/user_search_field.dart';
import '../services/hellbound_repository.dart';

class CreatePact extends StatefulWidget {
  const CreatePact({
    super.key,
    required this.users,
    required this.currentUserId,
    required this.repository,
  });
  final List<Map<String, dynamic>> users;
  final String currentUserId;
  final HellboundRepository repository;
  @override
  State<CreatePact> createState() => _CreatePactState();
}

class _CreatePactState extends State<CreatePact> {
  final key = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      proof = TextEditingController(),
      forfeit = TextEditingController(),
      announcement = TextEditingController();
  String responsible = '',
      verifier = '',
      type = 'Photo or Text',
      consequence = 'Funny Forfeit',
      appName = 'Instagram',
      audience = 'Pact Members Only';
  bool saving = false;
  String verifiedName = '';
  final selectedNames = <String, String>{};
  String get detail => consequence == 'Funny Forfeit'
      ? forfeit.text.trim()
      : consequence == 'Private Shame Card'
      ? announcement.text.trim()
      : appName;

  String person(String id) =>
      selectedNames[id] ??
      widget.users.firstWhere((u) => u['id'] == id)['username'] as String;
  @override
  void initState() {
    super.initState();
    responsible = widget.currentUserId;
  }

  DateTime? deadline;
  final witnesses = <String>[];
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    proof.dispose();
    forfeit.dispose();
    announcement.dispose();
    super.dispose();
  }

  Widget input(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: c,
      validator: (v) => (v ?? '').trim().isEmpty ? '$label is required' : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget choice(
    String label,
    String current,
    List<String> values,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label$current'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(s, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (s) => setState(() => change(s!)),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Make a Deal.')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: key,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('What foolish promise are we making today?'),
              const SizedBox(height: 24),
              input('Pact Title', title),
              input('Description', description),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  deadline == null
                      ? 'Deadline date and time'
                      : deadline.toString().substring(0, 16),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d == null || !context.mounted) return;
                  final t = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 18, minute: 0),
                  );
                  if (t != null) {
                    setState(
                      () => deadline = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextFormField(
                  initialValue: person(responsible),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Responsible Person',
                  ),
                ),
              ),
              UserSearchField(
                label: 'Verifier / Supervisor',
                search: widget.repository.searchUsers,
                excludedIds: {responsible, ...witnesses},
                enabled: !saving,
                validator: (_) => verifier.isEmpty
                    ? 'Select a verifier from the search results'
                    : null,
                onEdited: () => setState(() {
                  verifier = '';
                  verifiedName = '';
                }),
                onSelected: (user) => setState(() {
                  verifier = user['id'] as String;
                  verifiedName = user['username'] as String;
                  selectedNames[verifier] = verifiedName;
                }),
              ),
              const SizedBox(height: 24),
              UserSearchField(
                label: 'Additional Witnesses (optional)',
                search: widget.repository.searchUsers,
                excludedIds: {responsible, verifier, ...witnesses},
                enabled: !saving,
                clearAfterSelection: true,
                onSelected: (user) => setState(() {
                  final id = user['id'] as String;
                  selectedNames[id] = user['username'] as String;
                  witnesses.add(id);
                }),
              ),
              if (witnesses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: witnesses
                        .map(
                          (id) => InputChip(
                            label: Text(person(id)),
                            onDeleted: saving
                                ? null
                                : () => setState(() => witnesses.remove(id)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 24),
              choice('Evidence Type', type, [
                'Photo',
                'Text',
                'Photo or Text',
              ], (v) => type = v),
              input('What counts as valid proof?', proof),
              choice(
                'Consequence',
                consequence,
                ['Funny Forfeit', 'Private Shame Card', '24-Hour App Ban'],
                (v) {
                  consequence = v;
                },
              ),
              if (consequence == 'Funny Forfeit')
                input('Agreed forfeit', forfeit),
              if (consequence == 'Private Shame Card') ...[
                input('Announcement', announcement),
                choice('Visible to', audience, [
                  'Pact Members Only',
                  'Hellbound Community',
                ], (v) => audience = v),
                const Text(
                  'Every required party must accept this exact text and audience. Nothing is posted to external social media.',
                ),
              ],
              if (consequence == '24-Hour App Ban') ...[
                choice('Select Application', appName, [
                  'Instagram',
                  'TikTok',
                  'YouTube',
                ], (v) => appName = v),
                const Text(
                  'Restriction Duration: 24 Hours\nA simulated restriction inside Hellbound. Nothing is blocked on your phone.',
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : prepare,
                child: Text(saving ? 'Sending…' : 'Prepare the Pact'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> prepare() async {
    if (saving) return;
    if (!key.currentState!.validate()) return;
    if (deadline == null ||
        !deadline!.isAfter(DateTime.now()) ||
        responsible == verifier) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a future deadline and a different verifier.'),
        ),
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Review the Pact'),
        content: SingleChildScrollView(
          child: Text(
            '${title.text}\n\nResponsible: ${person(responsible)}\nVerifier: $verifiedName\nWitnesses: ${witnesses.map(person).join(', ')}\nDeadline: $deadline\nEvidence: ${proof.text}\nConsequence: $consequence\n$detail${consequence == 'Private Shame Card' ? '\nAudience: $audience' : ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send Invitations'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() => saving = true);
      try {
        final id = await widget.repository.create(
          Pact(
            title.text.trim(),
            description.text.trim(),
            deadline!,
            responsible: responsible,
            verifier: verifier,
            witnesses: List.of(witnesses),
            proof: proof.text.trim(),
            evidenceType: type,
            consequence: consequence,
            detail: detail,
            audience: audience,
            status: 'Awaiting Acceptance',
          ),
        );
        if (mounted) Navigator.pop(context, id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not send invitations. Check your connection and database setup.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }
  }
}
