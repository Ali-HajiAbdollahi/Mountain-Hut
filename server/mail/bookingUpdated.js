const escapeHtml=value=>String(value).replace(/[&<>"']/g,c=>({
  '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

// Email sent after a successful change of a booking (MH-06): unlike the MH-03 confirmation,
// it says that an existing reservation was updated and lists the new details.
export function bookingUpdated(b) {
  const tables=b.tables.length
    ? b.tables.map(t=>`Table ${t.table_no} (${t.seats} ${t.seats === 1 ? 'seat' : 'seats'})`).join(', ')
    : 'Not assigned';
  const requirements=b.requirements.length ? b.requirements.map(r=>
    `${r.allergy ? 'ALLERGY — ' : ''}${r.n_people == null ? 'People: not specified' : `People: ${r.n_people}`}: ${r.description}`)
    : ['No requirements specified'];
  const lines=[
    'Your reservation has been successfully updated. Here are your new booking details:',
    `Reference: ${b.reference}`,
    `Date: ${b.start_time.slice(0,10)}`,
    `Time slot: ${b.start_time.slice(11,16)} - ${b.end_time.slice(11,16)} (Europe/Rome)`,
    `Party size: ${b.n_people}`,
    `Assigned tables: ${tables}`,
    'Party requirements:',...requirements,
  ];
  return {
    subject:`Mountain Hut: Your Booking has been Updated (Ref: ${b.reference})`,
    text:lines.join('\n'),
    html:`<!doctype html><html lang="en"><body>${lines.map(line=>`<p>${escapeHtml(line)}</p>`).join('')}</body></html>`,
  };
}
