part of '../hellbound.dart';

extension _BanChamberScreen on _HellboundState {
  Widget ban() => Column(
    children: [
      title('Ban Chamber', 'No doomscrolling for you, mortal.'),
      mascot('happy'),
      if (!pacts.any(
        (p) =>
            p.responsibleId == uid &&
            (p.bannedUntil?.isAfter(DateTime.now()) ?? false),
      ))
        const Text('Your apps are safe. For now.'),
      ...pacts
          .where(
            (p) =>
                p.responsibleId == uid &&
                (p.bannedUntil?.isAfter(DateTime.now()) ?? false),
          )
          .map(
            (p) => panel([
              Text(p.detail, style: Theme.of(context).textTheme.titleLarge),
              Text(
                remaining(p.bannedUntil!),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text('Restricted until ${date(p.bannedUntil!)}'),
              const Text(
                'A simulated restriction inside Hellbound. Nothing is blocked on your phone.',
              ),
            ]),
          ),
    ],
  );
}
