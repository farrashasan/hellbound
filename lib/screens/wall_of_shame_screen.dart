part of '../hellbound.dart';

extension _WallOfShameScreen on _HellboundState {
  Widget wall() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title('Wall of Shame', 'Where broken promises become legends.'),
      Center(child: mascot('grin')),
      if (community.isEmpty) const Text('No broken promises to share.'),
      ...community.map(
        (p) => panel([
          Text(
            '${p['username']} Broke a Pact!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(p['title']),
          const SizedBox(height: 12),
          Text('“${p['announcement']}”'),
        ]),
      ),
      const Text(
        'Only announcements every participant agreed to share with the community appear here.',
      ),
    ],
  );
}
