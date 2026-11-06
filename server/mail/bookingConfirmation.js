const escapeHtml=value=>String(value).replace(/[&<>"']/g,c=>({
  '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

export function bookingConfirmation(b) {
  const requirements=b.requirements.length ? b.requirements.map(r=>
    `${r.allergy ? 'ALLERGY — ' : ''}${r.n_people == null ? 'People: not specified' : `People: ${r.n_people}`}: ${r.description}`)
    : ['No requirements specified'];
  const lines=[
    `Booking confirmed: ${b.reference}`,
    `Hiker: ${b.contact_name}`,
    `From: ${b.start_time} (Europe/Rome)`,
    `To: ${b.end_time} (Europe/Rome)`,
    `Party size: ${b.n_people}`,
    'Party requirements:',...requirements,
  ];
  return {
    subject:`Mountain Hut — booking ${b.reference}`,
    text:lines.join('\n'),
    html:`<!doctype html><html lang="en"><body>${lines.map(line=>`<p>${escapeHtml(line)}</p>`).join('')}</body></html>`,
  };
}