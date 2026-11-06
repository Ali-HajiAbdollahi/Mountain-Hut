// MH-03 Receive confirmation — unit tests (email content and mail service, no real SMTP)
import { describe, it, expect, vi, beforeEach } from 'vitest';

import { bookingConfirmation } from '../../mail/bookingConfirmation.js';
import { createMailService } from '../../services/mailService.js';

// Replace the real SMTP transport with a fake sendMail
const { sendMail } = vi.hoisted(() => ({ sendMail: vi.fn() }));
vi.mock('nodemailer', () => ({ default: { createTransport: () => ({ sendMail }) } }));

const booking = {
  reference: 'MH-12',
  contact_name: 'Marco Bianchi',
  start_time: '2026-12-01 12:00',
  end_time: '2026-12-01 13:00',
  n_people: 4,
  requirements: [
    { n_people: 1, description: 'peanut allergy', allergy: true },
    { n_people: null, description: 'vegetarian', allergy: false },
  ],
};

describe('bookingConfirmation', () => {
  it('contains every detail required by the story', () => {
    const { subject, text } = bookingConfirmation(booking);
    expect(subject).toContain('MH-12');
    expect(text).toContain('Booking confirmed: MH-12');
    expect(text).toContain('Hiker: Marco Bianchi');
    expect(text).toContain('From: 2026-12-01 12:00');
    expect(text).toContain('To: 2026-12-01 13:00');
    expect(text).toContain('Party size: 4');
  });

  it('lists the requirements and highlights allergies', () => {
    const { text } = bookingConfirmation(booking);
    expect(text).toContain('ALLERGY — People: 1: peanut allergy');
    expect(text).toContain('People: not specified: vegetarian');
  });

  it('says when there are no requirements', () => {
    expect(bookingConfirmation({ ...booking, requirements: [] }).text).toContain('No requirements specified');
  });

  it('escapes HTML coming from user input', () => {
    const { html } = bookingConfirmation({ ...booking, contact_name: '<script>x</script>' });
    expect(html).not.toContain('<script>');
    expect(html).toContain('&lt;script&gt;');
  });
});

describe('mailService', () => {
  beforeEach(() => {
    sendMail.mockReset();
  });

  const smtp = { MAIL_MODE: 'smtp', SMTP_HOST: 'smtp.test', MAIL_FROM: 'hut@test.it' };

  it('does not send anything when disabled (default)', async () => {
    expect(await createMailService({}).send('a@b.it', {})).toEqual({ status: 'disabled' });
    expect(sendMail).not.toHaveBeenCalled();
  });

  it('rejects an invalid configuration at startup', () => {
    expect(() => createMailService({ MAIL_MODE: 'pigeon' })).toThrow();
    expect(() => createMailService({ MAIL_MODE: 'smtp' })).toThrow(/SMTP_HOST/);
    expect(() => createMailService({ ...smtp, SMTP_PORT: '99999' })).toThrow(/SMTP_PORT/);
    expect(() => createMailService({ ...smtp, SMTP_USER: 'only-user' })).toThrow(/SMTP_PASS/);
    expect(() => createMailService({ ...smtp, SMTP_SECURE: 'yes' })).toThrow(/SMTP_SECURE/);
  });

  it('sends the message to the hiker from MAIL_FROM', async () => {
    sendMail.mockResolvedValue({ accepted: ['a@b.it'], rejected: [], messageId: 'm1' });
    const result = await createMailService(smtp).send('a@b.it', { subject: 'S', text: 'T' });
    expect(result).toEqual({ status: 'accepted', messageId: 'm1' });
    expect(sendMail).toHaveBeenCalledWith({ from: 'hut@test.it', to: 'a@b.it', subject: 'S', text: 'T' });
  });

  it('reports a failure instead of throwing, so the booking is not lost', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    sendMail.mockImplementation(async () => {
      throw Object.assign(new Error('down'), { code: 'ECONNREFUSED' });
    });
    expect(await createMailService(smtp).send('a@b.it', {})).toEqual({ status: 'failed' });
  });

  it('reports a failure when the recipient is rejected', async () => {
    sendMail.mockResolvedValue({ accepted: [], rejected: ['a@b.it'] });
    expect(await createMailService(smtp).send('a@b.it', {})).toEqual({ status: 'failed' });
  });
});
