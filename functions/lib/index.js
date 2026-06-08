"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notifyReportAlert = void 0;
const admin = require("firebase-admin");
const functions = require("firebase-functions/v2/firestore");
admin.initializeApp();
exports.notifyReportAlert = functions.onDocumentCreated('notification_requests/{requestId}', async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const request = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!request) {
        return null;
    }
    const urgency = String((_b = request.urgency) !== null && _b !== void 0 ? _b : 'LOW');
    const report = (_d = (_c = request.payload) === null || _c === void 0 ? void 0 : _c.report) !== null && _d !== void 0 ? _d : {};
    const message = {
        notification: {
            title: `Safe Voice ${urgency} alert`,
            body: `Case ${(_e = report.caseId) !== null && _e !== void 0 ? _e : 'unknown'} requires review.`,
        },
        data: {
            caseId: String((_f = report.caseId) !== null && _f !== void 0 ? _f : ''),
            urgency,
            reportType: String((_g = request.reportType) !== null && _g !== void 0 ? _g : 'unknown'),
        },
        topic: 'safe_voice_alerts',
    };
    await admin.messaging().send(message);
    await ((_h = event.data) === null || _h === void 0 ? void 0 : _h.ref.update({
        status: 'delivered',
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
    }));
    return null;
});
//# sourceMappingURL=index.js.map