/// Model for anonymous reports submitted to the system
class Report {
  final String caseId;
  final ReportType type;
  final String? content; // Text content for text reports
  final String? audioUrl; // URL for voice reports
  final String? location;
  final DateTime? incidentDate;
  final DateTime submittedAt;
  final List<String> attachments;
  final ReportStatus status;
  final bool anonymous;

  Report({
    required this.caseId,
    required this.type,
    this.content,
    this.audioUrl,
    this.location,
    this.incidentDate,
    required this.submittedAt,
    this.attachments = const [],
    this.status = ReportStatus.submitted,
    this.anonymous = true,
  });

  /// Create Report from Firestore document
  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      caseId: map['caseId'] ?? '',
      type: ReportType.fromString(map['type'] ?? 'text'),
      content: map['content'],
      audioUrl: map['audioUrl'],
      location: map['location'],
      incidentDate: map['incidentDate'] != null 
          ? DateTime.parse(map['incidentDate']) 
          : null,
      submittedAt: map['submittedAt']?.toDate() ?? DateTime.now(),
      attachments: List<String>.from(map['attachments'] ?? []),
      status: ReportStatus.fromString(map['status'] ?? 'submitted'),
      anonymous: map['anonymous'] ?? true,
    );
  }

  /// Convert Report to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'type': type.toString(),
      'content': content,
      'audioUrl': audioUrl,
      'location': location,
      'incidentDate': incidentDate?.toIso8601String(),
      'submittedAt': submittedAt,
      'attachments': attachments,
      'status': status.toString(),
      'anonymous': anonymous,
    };
  }

  /// Create a copy with updated values
  Report copyWith({
    String? caseId,
    ReportType? type,
    String? content,
    String? audioUrl,
    String? location,
    DateTime? incidentDate,
    DateTime? submittedAt,
    List<String>? attachments,
    ReportStatus? status,
    bool? anonymous,
  }) {
    return Report(
      caseId: caseId ?? this.caseId,
      type: type ?? this.type,
      content: content ?? this.content,
      audioUrl: audioUrl ?? this.audioUrl,
      location: location ?? this.location,
      incidentDate: incidentDate ?? this.incidentDate,
      submittedAt: submittedAt ?? this.submittedAt,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      anonymous: anonymous ?? this.anonymous,
    );
  }
}

/// Type of report submitted
enum ReportType {
  text,
  voice,
  mixed; // Both text and voice

  static ReportType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'text':
        return ReportType.text;
      case 'voice':
        return ReportType.voice;
      case 'mixed':
        return ReportType.mixed;
      default:
        return ReportType.text;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ReportType.text:
        return 'text';
      case ReportType.voice:
        return 'voice';
      case ReportType.mixed:
        return 'mixed';
    }
  }
}

/// Status of the report in the system
enum ReportStatus {
  submitted,
  underReview,
  reviewed,
  closed,
  requiresFollowUp;

  static ReportStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'submitted':
        return ReportStatus.submitted;
      case 'under_review':
      case 'underreview':
        return ReportStatus.underReview;
      case 'reviewed':
        return ReportStatus.reviewed;
      case 'closed':
        return ReportStatus.closed;
      case 'requires_follow_up':
      case 'requiresfollowup':
        return ReportStatus.requiresFollowUp;
      default:
        return ReportStatus.submitted;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ReportStatus.submitted:
        return 'submitted';
      case ReportStatus.underReview:
        return 'under_review';
      case ReportStatus.reviewed:
        return 'reviewed';
      case ReportStatus.closed:
        return 'closed';
      case ReportStatus.requiresFollowUp:
        return 'requires_follow_up';
    }
  }

  /// Human-readable status for UI display
  String get displayName {
    switch (this) {
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.underReview:
        return 'Under Review';
      case ReportStatus.reviewed:
        return 'Reviewed';
      case ReportStatus.closed:
        return 'Closed';
      case ReportStatus.requiresFollowUp:
        return 'Requires Follow-up';
    }
  }
}
