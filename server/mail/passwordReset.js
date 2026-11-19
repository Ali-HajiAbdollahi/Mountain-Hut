const escapeHtml=value=>String(value).replace(/[&<>"']/g,c=>({
  '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

// The app has no deep links: the email carries both the link and the token to paste in the app.
export function passwordReset({ name, token, resetUrl }) {
  const link=`${resetUrl}${resetUrl.includes('?') ? '&' : '?'}token=${encodeURIComponent(token)}`;
  const lines=[
    `Hello ${name},`,
    'We received a request to reset your Mountain Hut password.',
    `Reset link: ${link}`,
    `Reset code (to paste in the app): ${token}`,
    'The link and the code are valid for 24 hours and can be used only once.',
    'If you did not ask for this, you can ignore this email: your password is unchanged.',
  ];
  return {
    subject:'Mountain Hut — password reset',
    text:lines.join('\n'),
    html:`<!doctype html><html lang="en"><body>${lines.map(line=>`<p>${escapeHtml(line)}</p>`).join('')}</body></html>`,
  };
}
