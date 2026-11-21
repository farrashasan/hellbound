import 'dart:typed_data';

class Pact {
  Pact(
    this.title,
    this.description,
    this.deadline, {
    this.responsible = '',
    this.verifier = '',
    this.witnesses = const [],
    this.proof = 'Screenshot or link to the completed work.',
    this.evidenceType = 'Photo or Text',
    this.consequence = 'Private Shame Card',
    this.detail = 'I challenged my deadline. The deadline won.',
    this.audience = 'Hellbound Community',
    this.status = 'Active',
  });
  String title,
      description,
      responsible,
      verifier,
      proof,
      evidenceType,
      consequence,
      detail,
      audience,
      status;
  DateTime deadline;
  List<String> witnesses;
  String id = '', responsibleId = '', verifierId = '';
  String? photoPath;
  final Set<String> memberIds = {};
  String evidence = '', notes = '';
  Uint8List? photo;
  final Set<String> acceptedBy = {};
  Set<String> get requiredParticipants => {responsible, verifier, ...witnesses};
  final List<String> activity = ['Pact created'];
  DateTime? bannedUntil;
}
