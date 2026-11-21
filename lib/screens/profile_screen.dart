part of '../hellbound.dart';

extension _ProfileScreen on _HellboundState {
  Widget profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title('Mortal Profile'),
      Center(child: mascot('happy', 140)),
      Center(
        child: Text(name, style: Theme.of(context).textTheme.headlineMedium),
      ),
      Center(child: Text(email)),
      const SizedBox(height: 24),
      panel([
        Text(
          '${pacts.length} Total Pacts     ${pacts.where((p) => p.status == 'Completed').length} Completed     ${pacts.where((p) => p.status == 'Breached').length} Breached',
        ),
      ]),
      button('Edit Profile', editProfile, secondary: true),
      button('Settings', settings, secondary: true),
      button('Log Out', logout, secondary: true),
    ],
  );

  Future<void> settings() async {
    final draft = List<bool>.of(preferences);
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => SwitchListTile(
                title: Text(
                  [
                    'Deadline reminders',
                    'Pact invitations',
                    'Verification results',
                  ][i],
                ),
                value: draft[i],
                onChanged: (v) => refresh(() => draft[i] = v),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await perform(() async {
        await repository.saveSettings(draft);
        await load();
      });
    }
  }

  Future<void> editProfile() async {
    final n = TextEditingController(text: name),
        e = TextEditingController(text: email);
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [field('Username', n), field('Email', e)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (n.text.trim().isNotEmpty &&
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(e.text.trim())) {
                Navigator.pop(c, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final nextName = n.text.trim(), nextEmail = e.text.trim();
    if (saved == true && mounted) {
      await perform(() async {
        final changed = nextEmail != email;
        await repository.saveProfile(nextName, nextEmail);
        await load();
        if (changed) {
          notify('Check your email to confirm the new email address.');
        }
      });
    }
  }
}
