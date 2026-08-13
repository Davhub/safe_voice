import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import {
  onDocumentCreated,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import Africastalking from 'africastalking';
import { Resend } from 'resend';
import axios from 'axios';

initializeApp();

interface NotificationPayload {
  caseId: string;
  urgency: string;
  jurisdiction: string;
  reportType: string;
  caseType: string;
  portalLink: string;
}

interface PartnerRecipients {
  email: string[];
  sms: string[];
  whatsapp: string[];
  matchedNames: string[];
}

/**
 * Reads active partner agencies from Firestore (Admin SDK — bypasses
 * rules) and returns the contact info of every partner whose configured
 * urgency levels and case types match this report, split by channel. This
 * replaces the old static *_RECIPIENTS secrets — admins manage recipients
 * from the dashboard's Partners screen instead of redeploying.
 */
async function getMatchingPartnerRecipients(
  urgency: string,
  caseType: string,
): Promise<PartnerRecipients> {
  const snapshot = await getFirestore()
    .collection('partner_agencies')
    .where('isActive', '==', true)
    .get();

  const result: PartnerRecipients = {
    email: [],
    sms: [],
    whatsapp: [],
    matchedNames: [],
  };

  snapshot.docs.forEach((doc) => {
    const partner = doc.data();
    const urgencyLevels: string[] = partner.urgencyLevels ?? [];
    const caseTypes: string[] = partner.caseTypes ?? [];
    const channels: string[] = partner.channels ?? [];

    const urgencyMatches = urgencyLevels.includes(urgency);
    const caseTypeMatches =
      caseTypes.includes('ALL') || caseTypes.includes(caseType);

    if (!urgencyMatches || !caseTypeMatches) return;

    result.matchedNames.push(partner.organizationName ?? doc.id);
    if (channels.includes('email') && partner.email) {
      result.email.push(partner.email);
    }
    if (channels.includes('sms') && partner.phone) {
      result.sms.push(partner.phone);
    }
    if (channels.includes('whatsapp') && partner.phone) {
      result.whatsapp.push(partner.phone);
    }
  });

  return result;
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

async function sendEmail(
  payload: NotificationPayload,
  recipients: string[],
): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  const fromAddress = process.env.AGENCY_EMAIL_FROM ?? 'alerts@safevoice.ng';

  if (!apiKey || recipients.length === 0) {
    logger.warn('Email delivery skipped due to missing configuration', {
      caseId: payload.caseId,
    });
    return;
  }

  const resend = new Resend(apiKey);

  const { error } = await resend.emails.send({
    to: recipients,
    from: fromAddress,
    subject: `[${payload.urgency}] SafeVoice case ${payload.caseId} — ${payload.jurisdiction}`,
    text:
      `A ${payload.urgency} priority ${payload.reportType} report has been submitted.\n\n` +
      `Case ID: ${payload.caseId}\n` +
      `Jurisdiction: ${payload.jurisdiction}\n\n` +
      `Log in to review: ${payload.portalLink}`,
  });

  if (error) {
    throw new Error(`Resend send failed: ${error.message}`);
  }
}

async function sendSMS(
  payload: NotificationPayload,
  recipients: string[],
): Promise<void> {
  const apiKey = process.env.AT_API_KEY;
  const username = process.env.AT_USERNAME;

  if (!apiKey || !username || recipients.length === 0) {
    logger.warn('SMS delivery skipped due to missing configuration', {
      caseId: payload.caseId,
    });
    return;
  }

  const africastalkingClient = Africastalking({ apiKey, username });
  const response = await africastalkingClient.SMS.send({
    to: recipients,
    // A registered, transactional Sender ID is required for Nigerian
    // carriers to deliver past DND (Do Not Disturb) — omitting `from`
    // gets treated as generic/promotional traffic and gets blocked by
    // DND instead, which is worse, not better. This needs the
    // 'SafeVoice' Sender ID approved in the Africa's Talking dashboard
    // (SMS -> Sender ID) before delivery will actually work.
    from: 'SafeVoice',
    message: `CRITICAL SafeVoice alert. Case ${payload.caseId} in ${payload.jurisdiction}. Log in: ${payload.portalLink}`,
  });

  // africastalking's SMS.send() resolves even when a recipient is
  // rejected at the carrier level (e.g. unregistered sender ID) — the
  // real per-recipient outcome is only in the response body, not a thrown
  // error, so it has to be checked explicitly or failures are invisible.
  const recipientResults = response?.SMSMessageData?.Recipients ?? [];
  const failed = recipientResults.filter(
    (r: { status?: string }) => r.status !== 'Success',
  );

  if (failed.length > 0) {
    logger.error('SMS rejected for one or more recipients', {
      caseId: payload.caseId,
      failed,
    });
  } else if (recipientResults.length === 0) {
    logger.warn('SMS send returned no recipient results', {
      caseId: payload.caseId,
      response,
    });
  }
}

async function sendWhatsApp(
  payload: NotificationPayload,
  recipients: string[],
): Promise<void> {
  const token = process.env.WHATSAPP_TOKEN;
  const phoneId = process.env.WHATSAPP_PHONE_ID;

  if (!token || !phoneId || recipients.length === 0) {
    logger.warn('WhatsApp delivery skipped due to missing configuration', {
      caseId: payload.caseId,
    });
    return;
  }

  const url = `https://graph.facebook.com/v18.0/${phoneId}/messages`;

  await Promise.all(
    recipients.map(async (recipient) => {
      try {
        await axios.post(
          url,
          {
            messaging_product: 'whatsapp',
            to: recipient,
            type: 'template',
            template: {
              name: 'new_case_alert',
              language: { code: 'en' },
              components: [
                {
                  type: 'body',
                  parameters: [
                    { type: 'text', text: payload.caseId },
                    { type: 'text', text: payload.urgency },
                    { type: 'text', text: payload.jurisdiction },
                    { type: 'text', text: payload.reportType },
                    { type: 'text', text: payload.portalLink },
                  ],
                },
              ],
            },
          },
          { headers: { Authorization: `Bearer ${token}` } },
        );
      } catch (error) {
        logger.error('WhatsApp send failed for one recipient', {
          caseId: payload.caseId,
          recipient,
          error: axios.isAxiosError(error) ? error.response?.data : error,
        });
      }
    }),
  );
}

export const onReportCreated = onDocumentCreated(
  {
    document: 'reports/{caseId}',
    secrets: [
      'AT_API_KEY',
      'AT_USERNAME',
      'RESEND_API_KEY',
      'AGENCY_EMAIL_FROM',
      'WHATSAPP_TOKEN',
      'WHATSAPP_PHONE_ID',
    ],
  },
  async (event) => {
    const data = event.data?.data() ?? {};
    const caseId = event.params.caseId ?? 'unknown';
    const urgency = String(data.urgency ?? 'LOW').toUpperCase();
    const jurisdiction = String(data.jurisdiction ?? 'Unknown LGA');
    const reportType = String(data.type ?? 'unknown');
    const caseType = String(
      data.caseType ?? data.case_type ?? 'FGM',
    ).toUpperCase();

    const payload: NotificationPayload = {
      caseId,
      urgency,
      jurisdiction,
      reportType,
      caseType,
      portalLink: `https://safe-voice-app.web.app/cases/${caseId}`,
    };

    logger.info('Dispatching notification pipeline', payload);

    const partners = await getMatchingPartnerRecipients(urgency, caseType);

    logger.info('Matched partner agencies', {
      caseId,
      matchedNames: partners.matchedNames,
      emailCount: partners.email.length,
      smsCount: partners.sms.length,
      whatsappCount: partners.whatsapp.length,
    });

    // FCM push to the admin dashboard is independent of partner routing —
    // it's the in-app notification for SafeVoice's own officers, not an
    // external agency channel.
    const tasks: Array<{ channel: string; run: Promise<void> }> = [
      { channel: 'fcm', run: sendFCMPush(payload) },
    ];

    if (partners.email.length > 0) {
      tasks.push({ channel: 'email', run: sendEmail(payload, partners.email) });
    }
    if (partners.sms.length > 0) {
      tasks.push({ channel: 'sms', run: sendSMS(payload, partners.sms) });
    }
    if (partners.whatsapp.length > 0) {
      tasks.push({
        channel: 'whatsapp',
        run: sendWhatsApp(payload, partners.whatsapp),
      });
    }

    const results = await Promise.allSettled(tasks.map((t) => t.run));

    results.forEach((result, i) => {
      if (result.status === 'rejected') {
        logger.error(`Notification channel '${tasks[i].channel}' failed`, {
          caseId,
          reason:
            result.reason instanceof Error
              ? result.reason.message
              : result.reason,
        });
      }
    });

    await event.data?.ref.update({
      notifiedAt: FieldValue.serverTimestamp(),
      auditLog: FieldValue.arrayUnion({
        action: 'notification_dispatched',
        urgency,
        matchedPartners: partners.matchedNames,
        timestamp: new Date().toISOString(),
      }),
    });

    return null;
  },
);

/**
 * Mirrors only the fields safe for an unauthenticated reporter to see into
 * report_status/{caseId}. Firestore security rules can't redact individual
 * fields on a single-document read, so the full `reports` doc must stay
 * admin/officer-only and this denormalized copy is what the anonymous
 * case-status screen reads instead.
 */
export const onReportWrite = onDocumentWritten(
  'reports/{caseId}',
  async (event) => {
    const caseId = event.params.caseId;
    const after = event.data?.after;

    if (!after?.exists) {
      await getFirestore().collection('report_status').doc(caseId).delete();
      return null;
    }

    const data = after.data() ?? {};

    await getFirestore().collection('report_status').doc(caseId).set({
      caseId,
      status: data.status ?? 'submitted',
      statusMessage: data.statusMessage ?? null,
      estimatedResolution: data.estimatedResolution ?? null,
      type: data.type ?? 'unknown',
      submittedAt: data.submittedAt ?? null,
      lastUpdated: FieldValue.serverTimestamp(),
    });

    return null;
  },
);
