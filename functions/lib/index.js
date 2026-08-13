"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onReportWrite = exports.onReportCreated = void 0;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const firestore_2 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const africastalking_1 = __importDefault(require("africastalking"));
const resend_1 = require("resend");
const axios_1 = __importDefault(require("axios"));
(0, app_1.initializeApp)();
/**
 * Reads active partner agencies from Firestore (Admin SDK — bypasses
 * rules) and returns the contact info of every partner whose configured
 * urgency levels and case types match this report, split by channel. This
 * replaces the old static *_RECIPIENTS secrets — admins manage recipients
 * from the dashboard's Partners screen instead of redeploying.
 */
async function getMatchingPartnerRecipients(urgency, caseType) {
    const snapshot = await (0, firestore_1.getFirestore)()
        .collection('partner_agencies')
        .where('isActive', '==', true)
        .get();
    const result = {
        email: [],
        sms: [],
        whatsapp: [],
        matchedNames: [],
    };
    snapshot.docs.forEach((doc) => {
        var _a, _b, _c, _d;
        const partner = doc.data();
        const urgencyLevels = (_a = partner.urgencyLevels) !== null && _a !== void 0 ? _a : [];
        const caseTypes = (_b = partner.caseTypes) !== null && _b !== void 0 ? _b : [];
        const channels = (_c = partner.channels) !== null && _c !== void 0 ? _c : [];
        const urgencyMatches = urgencyLevels.includes(urgency);
        const caseTypeMatches = caseTypes.includes('ALL') || caseTypes.includes(caseType);
        if (!urgencyMatches || !caseTypeMatches)
            return;
        result.matchedNames.push((_d = partner.organizationName) !== null && _d !== void 0 ? _d : doc.id);
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
async function sendFCMPush(payload) {
    const title = `[${payload.urgency}] New report — ${payload.jurisdiction}`;
    const body = `Case ${payload.caseId} requires immediate attention`;
    v2_1.logger.info('Sending FCM push notification', {
        caseId: payload.caseId,
        urgency: payload.urgency,
    });
    await (0, messaging_1.getMessaging)().send({
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
async function sendEmail(payload, recipients) {
    var _a;
    const apiKey = process.env.RESEND_API_KEY;
    const fromAddress = (_a = process.env.AGENCY_EMAIL_FROM) !== null && _a !== void 0 ? _a : 'alerts@safevoice.ng';
    if (!apiKey || recipients.length === 0) {
        v2_1.logger.warn('Email delivery skipped due to missing configuration', {
            caseId: payload.caseId,
        });
        return;
    }
    const resend = new resend_1.Resend(apiKey);
    const { error } = await resend.emails.send({
        to: recipients,
        from: fromAddress,
        subject: `[${payload.urgency}] SafeVoice case ${payload.caseId} — ${payload.jurisdiction}`,
        text: `A ${payload.urgency} priority ${payload.reportType} report has been submitted.\n\n` +
            `Case ID: ${payload.caseId}\n` +
            `Jurisdiction: ${payload.jurisdiction}\n\n` +
            `Log in to review: ${payload.portalLink}`,
    });
    if (error) {
        throw new Error(`Resend send failed: ${error.message}`);
    }
}
async function sendSMS(payload, recipients) {
    var _a, _b;
    const apiKey = process.env.AT_API_KEY;
    const username = process.env.AT_USERNAME;
    if (!apiKey || !username || recipients.length === 0) {
        v2_1.logger.warn('SMS delivery skipped due to missing configuration', {
            caseId: payload.caseId,
        });
        return;
    }
    const africastalkingClient = (0, africastalking_1.default)({ apiKey, username });
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
    const recipientResults = (_b = (_a = response === null || response === void 0 ? void 0 : response.SMSMessageData) === null || _a === void 0 ? void 0 : _a.Recipients) !== null && _b !== void 0 ? _b : [];
    const failed = recipientResults.filter((r) => r.status !== 'Success');
    if (failed.length > 0) {
        v2_1.logger.error('SMS rejected for one or more recipients', {
            caseId: payload.caseId,
            failed,
        });
    }
    else if (recipientResults.length === 0) {
        v2_1.logger.warn('SMS send returned no recipient results', {
            caseId: payload.caseId,
            response,
        });
    }
}
async function sendWhatsApp(payload, recipients) {
    const token = process.env.WHATSAPP_TOKEN;
    const phoneId = process.env.WHATSAPP_PHONE_ID;
    if (!token || !phoneId || recipients.length === 0) {
        v2_1.logger.warn('WhatsApp delivery skipped due to missing configuration', {
            caseId: payload.caseId,
        });
        return;
    }
    const url = `https://graph.facebook.com/v18.0/${phoneId}/messages`;
    await Promise.all(recipients.map(async (recipient) => {
        var _a;
        try {
            await axios_1.default.post(url, {
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
            }, { headers: { Authorization: `Bearer ${token}` } });
        }
        catch (error) {
            v2_1.logger.error('WhatsApp send failed for one recipient', {
                caseId: payload.caseId,
                recipient,
                error: axios_1.default.isAxiosError(error) ? (_a = error.response) === null || _a === void 0 ? void 0 : _a.data : error,
            });
        }
    }));
}
exports.onReportCreated = (0, firestore_2.onDocumentCreated)({
    document: 'reports/{caseId}',
    secrets: [
        'AT_API_KEY',
        'AT_USERNAME',
        'RESEND_API_KEY',
        'AGENCY_EMAIL_FROM',
        'WHATSAPP_TOKEN',
        'WHATSAPP_PHONE_ID',
    ],
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const data = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data()) !== null && _b !== void 0 ? _b : {};
    const caseId = (_c = event.params.caseId) !== null && _c !== void 0 ? _c : 'unknown';
    const urgency = String((_d = data.urgency) !== null && _d !== void 0 ? _d : 'LOW').toUpperCase();
    const jurisdiction = String((_e = data.jurisdiction) !== null && _e !== void 0 ? _e : 'Unknown LGA');
    const reportType = String((_f = data.type) !== null && _f !== void 0 ? _f : 'unknown');
    const caseType = String((_h = (_g = data.caseType) !== null && _g !== void 0 ? _g : data.case_type) !== null && _h !== void 0 ? _h : 'FGM').toUpperCase();
    const payload = {
        caseId,
        urgency,
        jurisdiction,
        reportType,
        caseType,
        portalLink: `https://safe-voice-app.web.app/cases/${caseId}`,
    };
    v2_1.logger.info('Dispatching notification pipeline', payload);
    const partners = await getMatchingPartnerRecipients(urgency, caseType);
    v2_1.logger.info('Matched partner agencies', {
        caseId,
        matchedNames: partners.matchedNames,
        emailCount: partners.email.length,
        smsCount: partners.sms.length,
        whatsappCount: partners.whatsapp.length,
    });
    // FCM push to the admin dashboard is independent of partner routing —
    // it's the in-app notification for SafeVoice's own officers, not an
    // external agency channel.
    const tasks = [
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
            v2_1.logger.error(`Notification channel '${tasks[i].channel}' failed`, {
                caseId,
                reason: result.reason instanceof Error
                    ? result.reason.message
                    : result.reason,
            });
        }
    });
    await ((_j = event.data) === null || _j === void 0 ? void 0 : _j.ref.update({
        notifiedAt: firestore_1.FieldValue.serverTimestamp(),
        auditLog: firestore_1.FieldValue.arrayUnion({
            action: 'notification_dispatched',
            urgency,
            matchedPartners: partners.matchedNames,
            timestamp: new Date().toISOString(),
        }),
    }));
    return null;
});
/**
 * Mirrors only the fields safe for an unauthenticated reporter to see into
 * report_status/{caseId}. Firestore security rules can't redact individual
 * fields on a single-document read, so the full `reports` doc must stay
 * admin/officer-only and this denormalized copy is what the anonymous
 * case-status screen reads instead.
 */
exports.onReportWrite = (0, firestore_2.onDocumentWritten)('reports/{caseId}', async (event) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const caseId = event.params.caseId;
    const after = (_a = event.data) === null || _a === void 0 ? void 0 : _a.after;
    if (!(after === null || after === void 0 ? void 0 : after.exists)) {
        await (0, firestore_1.getFirestore)().collection('report_status').doc(caseId).delete();
        return null;
    }
    const data = (_b = after.data()) !== null && _b !== void 0 ? _b : {};
    await (0, firestore_1.getFirestore)().collection('report_status').doc(caseId).set({
        caseId,
        status: (_c = data.status) !== null && _c !== void 0 ? _c : 'submitted',
        statusMessage: (_d = data.statusMessage) !== null && _d !== void 0 ? _d : null,
        estimatedResolution: (_e = data.estimatedResolution) !== null && _e !== void 0 ? _e : null,
        type: (_f = data.type) !== null && _f !== void 0 ? _f : 'unknown',
        submittedAt: (_g = data.submittedAt) !== null && _g !== void 0 ? _g : null,
        lastUpdated: firestore_1.FieldValue.serverTimestamp(),
    });
    return null;
});
//# sourceMappingURL=index.js.map