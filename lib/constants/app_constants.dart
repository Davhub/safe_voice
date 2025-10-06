/// App constants for Safe Voice anonymous reporting application
class AppConstants {
  // App Information
  static const String appName = 'Safe Voice';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Anonymous reporting platform for safety concerns';
  
  // Firebase Collections
  static const String reportsCollection = 'reports';
  static const String attachmentsCollection = 'attachments';
  
  // Storage Paths
  static const String voiceRecordingsPath = 'voice_recordings';
  static const String attachmentsPath = 'attachments';
  static const String imagesPath = 'images';
  
  // Report Configuration
  static const int maxReportLength = 5000; // Maximum characters in text report
  static const int maxAttachments = 5; // Maximum number of attachments
  static const int maxVoiceRecordingDuration = 300; // 5 minutes in seconds
  static const List<String> allowedFileTypes = ['.jpg', '.jpeg', '.png', '.pdf', '.doc', '.docx'];
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB in bytes
  
  // Case ID Configuration
  static const int caseIdLength = 8; // Length of generated case IDs
  static const String caseIdPrefix = 'SV'; // Prefix for case IDs
  
  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 3);
  static const double borderRadius = 8.0;
  static const double padding = 16.0;
  static const double margin = 8.0;
  
  // Privacy and Security
  static const String privacyNotice = 'Your report is completely anonymous. We do not collect any personal information that could identify you.';
  static const String securityNotice = 'All communications are encrypted and stored securely.';
  
  // Contact Information (for emergencies)
  static const String emergencyNumber = '911';
  static const String supportEmail = 'support@safevoice.org';
  
  // Error Messages
  static const String genericErrorMessage = 'Something went wrong. Please try again.';
  static const String networkErrorMessage = 'Network error. Please check your connection and try again.';
  static const String fileUploadErrorMessage = 'Failed to upload file. Please try again.';
  static const String reportSubmissionErrorMessage = 'Failed to submit report. Please try again.';
  
  // Success Messages
  static const String reportSubmittedMessage = 'Your report has been submitted successfully.';
  static const String reportFoundMessage = 'Report status found.';
  
  // Validation Messages
  static const String requiredFieldMessage = 'This field is required.';
  static const String invalidCaseIdMessage = 'Please enter a valid case ID.';
  static const String reportTooLongMessage = 'Report exceeds maximum length.';
  static const String fileTooLargeMessage = 'File size exceeds maximum allowed size.';
  static const String invalidFileTypeMessage = 'File type not supported.';
}
