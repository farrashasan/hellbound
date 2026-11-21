part of '../hellbound.dart';

extension _EvidenceScreen on _HellboundState {
  Widget submitEvidence() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title('Prove it, Mortal.'),
      panel([
        Text(selected!.title),
        const SizedBox(height: 12),
        Text(selected!.proof),
      ]),
      if (selected!.evidenceType != 'Text') ...[
        if (pendingPhoto != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(pendingPhoto!, height: 200, fit: BoxFit.cover),
          ),
        button(
          pendingPhoto == null ? 'Upload photo' : 'Change photo',
          pickPhoto,
          secondary: true,
        ),
      ],
      if (selected!.evidenceType != 'Photo')
        field('Text evidence', evidence, lines: 5),
      button('Submit Evidence', () {
        if (selected!.evidenceType == 'Photo'
            ? pendingPhoto == null
            : selected!.evidenceType == 'Text'
            ? evidence.text.trim().isEmpty
            : pendingPhoto == null && evidence.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add your evidence first.')),
          );
          return;
        }
        updateStatus('Under Verification');
      }),
    ],
  );
}
