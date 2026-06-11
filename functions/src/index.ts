import { initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import Africastalking from 'africastalking';

initializeApp();

interface NotificationPayload {
  caseId: string;
  urgency: string;
  jurisdiction: string;
  reportType: string;
  portalLink: string;
}

async function sendFCMPush(payload: NotificationPayload): Promise<void> {
  const title = `[${payload.urgency}] New report — ${payload.jurisdiction}`;
  const body = `Case ${payload.caseId} requires immediate attention`;

  logger.info('Sending FCM push notification', {
    caseId: payload.caseId,
    urgency: payload.urgency,
  });

  await getMessaging().send({
    topic: 'agency_officers',
    notification: { title, body },
    data: {
      caseId: payload.caseId,
      urgency: payload.urgency,
      portalLink: payload.portalLink,
    },
    webpush: {
      fcmOptions: {
        link: payload.portalLink,
      },
    },
  });
}

async function sendEmail(payload: NotificationPayload): Promise<void> {
  logger.info('Email channel disabled — skipping', { caseId: payload.caseId });
  return;
}

async function sendSMS(payload: NotificationPayload): Promise<void> {
  const apiKey = process.env.AT_API_KEY;
  const username = process.env.AT_USERNAME;
  const recipients = (process.env.AT_SMS_RECIPIENTS ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  if (!apiKey || !username || recipients.length === 0) {
    logger.warn('SMS delivery skipped due to missing configuration', {
      caseId: payload.caseId,
    });
    return;
  }

  const africastalkingClient = Africastalking({ apiKey, username });
  await africastalkingClient.SMS.send({
    to: recipients,
    from: 'SafeVoice',
    message: `CRITICAL SafeVoice alert. Case ${payload.caseId} in ${payload.jurisdiction}. Log in: ${payload.portalLink}`,
  });
}

async function sendWhatsApp(payload: NotificationPayload): Promise<void> {
  logger.info('WhatsApp not yet configured — skipping', { caseId: payload.caseId });
  // TODO: activate when WHATSAPP_TOKEN is available
  return;
}

export const onReportCreated = onDocumentCreated(
  {
    document: 'reports/{caseId}',
    secrets: ['AT_API_KEY', 'AT_USERNAME', 'AT_SMS_RECIPIENTS'],
  },
  async (event) => {
    const data = event.data?.data() ?? {};
    const caseId = event.params.caseId ?? 'unknown';
    const urgency = String(data.urgency ?? 'LOW').toUpperCase();
    const jurisdiction = String(data.jurisdiction ?? 'Unknown LGA');
    const reportType = String(data.type ?? data.caseType ?? 'unknown');

    const payload: NotificationPayload = {
      caseId,
      urgency,
      jurisdiction,
      reportType,
      portalLink: `https://safe-voice-app.web.app/cases/${caseId}`,
    };

    logger.info('Dispatching notification pipeline', payload);

    const tasks = [sendFCMPush(payload)];

    if (urgency === 'CRITICAL' || urgency === 'HIGH') {
      tasks.push(sendEmail(payload));
    }

    if (urgency === 'CRITICAL') {
      tasks.push(sendSMS(payload));
      tasks.push(sendWhatsApp(payload));
    } else if (urgency === 'MEDIUM') {
      tasks.push(sendEmail(payload));
    }

    await Promise.allSettled(tasks);

    await event.data?.ref.update({
      notifiedAt: FieldValue.serverTimestamp(),
      auditLog: FieldValue.arrayUnion({
        action: 'notification_dispatched',
        urgency,
        timestamp: new Date().toISOString(),
      }),
    });

    return null;
  },
);
