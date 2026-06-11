"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onReportCreated = void 0;
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const africastalking_1 = __importDefault(require("africastalking"));
(0, app_1.initializeApp)();
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
async function sendEmail(payload) {
    v2_1.logger.info('Email channel disabled — skipping', { caseId: payload.caseId });
    return;
}
async function sendSMS(payload) {
    var _a;
    const apiKey = process.env.AT_API_KEY;
    const username = process.env.AT_USERNAME;
    const recipients = ((_a = process.env.AT_SMS_RECIPIENTS) !== null && _a !== void 0 ? _a : '')
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean);
    if (!apiKey || !username || recipients.length === 0) {
        v2_1.logger.warn('SMS delivery skipped due to missing configuration', {
            caseId: payload.caseId,
        });
        return;
    }
    const africastalkingClient = (0, africastalking_1.default)({ apiKey, username });
    await africastalkingClient.SMS.send({
        to: recipients,
        from: 'SafeVoice',
        message: `CRITICAL SafeVoice alert. Case ${payload.caseId} in ${payload.jurisdiction}. Log in: ${payload.portalLink}`,
    });
}
async function sendWhatsApp(payload) {
    v2_1.logger.info('WhatsApp not yet configured — skipping', { caseId: payload.caseId });
    // TODO: activate when WHATSAPP_TOKEN is available
    return;
}
exports.onReportCreated = (0, firestore_2.onDocumentCreated)({
    document: 'reports/{caseId}',
    secrets: ['AT_API_KEY', 'AT_USERNAME', 'AT_SMS_RECIPIENTS'],
}, async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const data = (_b = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data()) !== null && _b !== void 0 ? _b : {};
    const caseId = (_c = event.params.caseId) !== null && _c !== void 0 ? _c : 'unknown';
    const urgency = String((_d = data.urgency) !== null && _d !== void 0 ? _d : 'LOW').toUpperCase();
    const jurisdiction = String((_e = data.jurisdiction) !== null && _e !== void 0 ? _e : 'Unknown LGA');
    const reportType = String((_g = (_f = data.type) !== null && _f !== void 0 ? _f : data.caseType) !== null && _g !== void 0 ? _g : 'unknown');
    const payload = {
        caseId,
        urgency,
        jurisdiction,
        reportType,
        portalLink: `https://safe-voice-app.web.app/cases/${caseId}`,
    };
    v2_1.logger.info('Dispatching notification pipeline', payload);
    const tasks = [sendFCMPush(payload)];
    if (urgency === 'CRITICAL' || urgency === 'HIGH') {
        tasks.push(sendEmail(payload));
    }
    if (urgency === 'CRITICAL') {
        tasks.push(sendSMS(payload));
        tasks.push(sendWhatsApp(payload));
    }
    else if (urgency === 'MEDIUM') {
        tasks.push(sendEmail(payload));
    }
    await Promise.allSettled(tasks);
    await ((_h = event.data) === null || _h === void 0 ? void 0 : _h.ref.update({
        notifiedAt: firestore_1.FieldValue.serverTimestamp(),
        auditLog: firestore_1.FieldValue.arrayUnion({
            action: 'notification_dispatched',
            urgency,
            timestamp: new Date().toISOString(),
        }),
    }));
    return null;
});
//# sourceMappingURL=index.js.map