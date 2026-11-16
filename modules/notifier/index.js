const nodemailer = require('nodemailer');
module.exports = {
  async send(subject, body, level = 'info') {
    const emoji = { info: 'ℹ️', warn: '⚠️', error: '🚨', success: '✅' }[level] || 'ℹ️';
    console.log(`[notifier] ${emoji} ${subject}`);
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) return;
    try {
      const t = nodemailer.createTransport({ service: 'gmail', auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS } });
      await t.sendMail({
        from: `"CYBRA AI" <${process.env.EMAIL_USER}>`,
        to: process.env.EMAIL_TO || process.env.EMAIL_USER,
        subject: `${emoji} [CYBRA] ${subject}`,
        text: `${body}\n\n${new Date().toLocaleString('uk-UA')}`
      });
      console.log(`[notifier] 📧 Email відправлено`);
    } catch (e) { console.error(`[notifier] ❌ ${e.message}`); }
  }
};
