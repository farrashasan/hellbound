part of '../hellbound.dart';

extension _PactDetailScreen on _HellboundState {
  Widget detail() {
    final p = selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title('The Sacred Pact'),
        panel([
          Text(p.title, style: Theme.of(context).textTheme.titleLarge),
          label(p.status.toUpperCase()),
          Text(p.description),
        ]),
        panel([
          Text(
            'Responsible   ${p.responsible}\n\nVerifier   ${p.verifier}\n\nWitnesses   ${p.witnesses.join(', ')}\n\nDeadline   ${date(p.deadline)}\n\nRequired evidence   ${p.evidenceType}: ${p.proof}\n\nConsequence   ${p.consequence}',
          ),
          const Divider(),
          Text(p.detail),
          if (p.consequence == 'Private Shame Card')
            Text('Approved audience: ${p.audience}'),
        ]),
        label('ACTIVITY'),
        ...p.activity.map(
          (a) => ListTile(
            leading: const Icon(
              Icons.check_circle_outline,
              color: HellboundColors.accent,
            ),
            title: Text(a),
          ),
        ),
        if (p.status == 'Awaiting Acceptance') ...[
          Text(
            'Accepted: ${p.acceptedBy.length} / ${p.memberIds.length} participants',
          ),
          if (p.memberIds.contains(uid) && !p.acceptedBy.contains(uid))
            button('Accept Pact', acceptPact),
          if (p.memberIds.contains(uid) && !p.acceptedBy.contains(uid))
            button('Decline', () => updateStatus('Declined'), secondary: true),
        ],
        if (p.status == 'Active' && uid == p.responsibleId)
          button('Submit Evidence', () {
            evidence.text = p.evidence;
            pendingPhoto = p.photo;
            go('evidence');
          }),
        if (p.status == 'Under Verification' && uid == p.verifierId)
          button('Review Evidence', () => go('review')),
        if (p.notes.isNotEmpty) panel([label('REVIEW NOTES'), Text(p.notes)]),
      ],
    );
  }
}
