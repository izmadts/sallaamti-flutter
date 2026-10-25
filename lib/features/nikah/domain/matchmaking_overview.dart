import 'nikah_card.dart';

// Mirrors Api\V1\NikahMatchmakingController::overview()/consentRequests().
class NikahProposal {
  final int id;
  final String status;
  final String? response;
  final List<String> matchReasons;
  final NikahCard candidate;

  NikahProposal({
    required this.id,
    required this.status,
    this.response,
    required this.matchReasons,
    required this.candidate,
  });

  factory NikahProposal.fromJson(Map<String, dynamic> json) => NikahProposal(
        id: json['id'] as int,
        status: json['status'] as String,
        response: json['response'] as String?,
        matchReasons: (json['match_reasons'] as List?)?.map((e) => e.toString()).toList() ?? [],
        candidate: NikahCard.fromJson(Map<String, dynamic>.from(json['candidate'] as Map)),
      );
}

class NikahProposalBatch {
  final int id;
  final int batchNumber;
  final String status;
  final DateTime? sentAt;
  final List<NikahProposal> proposals;

  NikahProposalBatch({
    required this.id,
    required this.batchNumber,
    required this.status,
    this.sentAt,
    required this.proposals,
  });

  factory NikahProposalBatch.fromJson(Map<String, dynamic> json) => NikahProposalBatch(
        id: json['id'] as int,
        batchNumber: json['batch_number'] as int,
        status: json['status'] as String,
        sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at'] as String) : null,
        proposals: (json['proposals'] as List).map((e) => NikahProposal.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class NikahConsentRequest {
  final int id;
  final String consentType;
  final String consentLabel;
  final DateTime? requestedAt;

  NikahConsentRequest({
    required this.id,
    required this.consentType,
    required this.consentLabel,
    this.requestedAt,
  });

  factory NikahConsentRequest.fromJson(Map<String, dynamic> json) => NikahConsentRequest(
        id: json['id'] as int,
        consentType: json['consent_type'] as String,
        consentLabel: json['consent_label'] as String,
        requestedAt: json['requested_at'] != null ? DateTime.tryParse(json['requested_at'] as String) : null,
      );
}

class NikahMatchmakingOverview {
  final List<NikahProposalBatch> proposalBatches;
  final List<NikahConsentRequest> consentRequests;
  final bool isMatched;

  NikahMatchmakingOverview({
    required this.proposalBatches,
    required this.consentRequests,
    required this.isMatched,
  });

  factory NikahMatchmakingOverview.fromJson(Map<String, dynamic> json) => NikahMatchmakingOverview(
        proposalBatches: (json['proposal_batches'] as List).map((e) => NikahProposalBatch.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        consentRequests: (json['consent_requests'] as List).map((e) => NikahConsentRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        isMatched: json['is_matched'] as bool? ?? false,
      );
}
