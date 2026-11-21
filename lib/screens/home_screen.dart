part of '../hellbound.dart';

extension _HomeScreen on _HellboundState {
  Widget home() {
    final activePacts = pacts.where((p) => p.status == 'Active').toList();
    final upcoming =
        activePacts.where((p) => p.deadline.isAfter(DateTime.now())).toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final nextDeadline = upcoming.isEmpty ? null : upcoming.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: title(
                'Evening, Mortal!',
                'Survived another day of responsibilities?',
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: notifications,
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        panel([
          label('DEVIL MOOD'),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "I'm Watching You.",
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(child: mascot('watch', 150)),
            ],
          ),
          Text(
            '${pacts.where((p) => p.status == 'Active').length} active pacts. No excuses detected... yet.',
          ),
        ]),
        panel([
          label('UPCOMING DEADLINE'),
          if (nextDeadline == null)
            const Text(
              'No upcoming deadlines. The demon is giving you a breather.',
            )
          else ...[
            Text(
              nextDeadline.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(date(nextDeadline.deadline)),
            button('View Pact', () => open(nextDeadline)),
          ],
        ]),
        panel([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: label('ACTIVE PACTS')),
              TextButton(
                onPressed: () => go('pacts'),
                child: const Text('See All'),
              ),
            ],
          ),
          if (activePacts.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'No active pacts yet. Make a pact and let the challenge begin.',
            ),
          ] else
            ...activePacts.map(pactCard),
        ]),
        button('Wall of Shame', () => go('wall'), secondary: true),
        button('Ban Chamber', () => go('ban'), secondary: true),
        button('+ Summon a Pact', create),
      ],
    );
  }

  void notifications() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Notifications'),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: alerts.isEmpty
              ? [const Text('No notifications yet.')]
              : alerts
                    .map(
                      (n) => ListTile(
                        title: Text(n['message']),
                        subtitle: Text(
                          date(DateTime.parse(n['created_at']).toLocal()),
                        ),
                        onTap: () async {
                          Navigator.pop(c);
                          await perform(() async {
                            await repository.markRead(n['id']);
                            await load();
                            final found = pacts.where(
                              (p) => p.id == n['pact_id'],
                            );
                            if (found.isNotEmpty) open(found.first);
                          });
                        },
                      ),
                    )
                    .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
