part of '../hellbound.dart';

extension _PactsScreen on _HellboundState {
  Widget pactList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title('My Pacts', 'Your promises, under surveillance.'),
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: HellboundColors.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: ['Active', 'Pending', 'History']
              .map(
                (s) => Expanded(
                  child: Semantics(
                    selected: filter == s,
                    child: TextButton(
                      onPressed: () => refresh(() => filter = s),
                      style: TextButton.styleFrom(
                        backgroundColor: filter == s
                            ? HellboundColors.accent
                            : Colors.transparent,
                        foregroundColor: filter == s
                            ? HellboundColors.text
                            : HellboundColors.muted,
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(s),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 20),
      ...pacts
          .where(
            (p) => filter == 'Pending'
                ? p.status == 'Awaiting Acceptance'
                : filter == 'History'
                ? ['Completed', 'Breached', 'Declined'].contains(p.status)
                : ['Active', 'Under Verification'].contains(p.status),
          )
          .map(pactCard),
      button('+ Summon a Pact', create, secondary: true),
    ],
  );
}
