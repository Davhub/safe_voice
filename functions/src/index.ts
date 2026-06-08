import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v2/firestore';

admin.initializeApp();

export const notifyReportAlert = functions.onDocumentCreated(
  'notification_requests/{requestId}',
  async (event) => {
    const request = event.data?.data();

    if (!request) {
      return null;
    }

    const urgency = String(request.urgency ?? 'LOW');
    const report = request.payload?.report ?? {};

    const message = {
      notification: {
        title: `Safe Voice ${urgency} alert`,
        body: `Case ${report.caseId ?? 'unknown'} requires review.`,
      },
      data: {
        caseId: String(report.caseId ?? ''),
        urgency,
        reportType: String(request.reportType ?? 'unknown'),
      },
      topic: 'safe_voice_alerts',
    };

    await admin.messaging().send(message as any);

    await event.data?.ref.update({
      status: 'delivered',
      deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  },
);
