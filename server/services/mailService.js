import nodemailer from 'nodemailer';

export function createMailService(env=process.env) {
  const mode=env.MAIL_MODE || 'disabled';
  if (!['disabled','smtp'].includes(mode)) throw new Error('Invalid MAIL_MODE');
  let transport;
  if (mode === 'smtp') {
    if (!env.SMTP_HOST || !env.MAIL_FROM) throw new Error('SMTP_HOST and MAIL_FROM required');
    const port=Number(env.SMTP_PORT || 587);
    if (!Number.isInteger(port) || port<1 || port>65535) throw new Error('Invalid SMTP_PORT');
    if (Boolean(env.SMTP_USER) !== Boolean(env.SMTP_PASS))
      throw new Error('Set both SMTP_USER and SMTP_PASS');
    if (env.SMTP_SECURE && !['true','false'].includes(env.SMTP_SECURE))
      throw new Error('SMTP_SECURE must be true or false');
    transport=nodemailer.createTransport({host:env.SMTP_HOST,port,
      secure:env.SMTP_SECURE === 'true',
      auth:env.SMTP_USER ? {user:env.SMTP_USER,pass:env.SMTP_PASS} : undefined,
      connectionTimeout:5000,greetingTimeout:5000,socketTimeout:10000});
  }
  return {
    async send(to,message) {
      if (!transport) return {status:'disabled'};
      try {
        const result=await transport.sendMail({from:env.MAIL_FROM,to,...message});
        if (!result.accepted?.length || result.rejected?.length) return {status:'failed'};
        return {status:'accepted',messageId:result.messageId};
      } catch (error) {
        // Avoid logging credentials or sensitive party requirements.
        console.error('Confirmation email failed',{code:error.code});
        return {status:'failed'};
      }
    },
  };
}