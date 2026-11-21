part of '../hellbound.dart';

extension _VerificationScreen on _HellboundState {
  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title(
        'Judgement Chamber',
        'A mortal has submitted their proof. Is it convincing?',
      ),
      panel([
        label('SUBMITTED EVIDENCE'),
        if (selected!.photo != null)
          Image.memory(selected!.photo!, height: 200, fit: BoxFit.contain),
        Text(selected!.evidence),
        label('REQUIREMENTS'),
        Text(selected!.proof),
      ]),
      field("Demon’s Review Notes", notes, lines: 4),
      button('Approve Evidence', () {
        updateStatus('Completed');
      }),
      button('Reject Evidence', () {
        updateStatus('Breached');
      }, secondary: true),
    ],
  );
}
