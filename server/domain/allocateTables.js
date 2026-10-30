import { ConflictError } from '../errors.js';
import { positiveInt } from './validation.js';

// Exact preference: minimum number of tables, then minimum free capacity used.
// States below n represent exact sums. The completed state holds the best cover.
export function allocateTables(rows,n) {
  positiveInt(n,'n_people');
  const tables=rows.filter(t=>t.free_seats>0).sort((a,b)=>a.table_no-b.table_no);
  const states=new Map([[0,{total:0,chosen:[]}]]);
  function better(a,b) {
    return !b || a.chosen.length < b.chosen.length ||
      (a.chosen.length === b.chosen.length && a.total < b.total);
  }
  for (const t of tables) {
    for (const [sum,old] of [...states]) {
      if (sum === n) continue;
      const candidate={total:old.total+t.free_seats,chosen:[...old.chosen,t]};
      const key=Math.min(n,candidate.total);
      if (better(candidate,states.get(key))) states.set(key,candidate);
    }
  }
  const best=states.get(n);
  if (!best) throw new ConflictError('Not enough free seats');
  let remaining=n;
  return [...best.chosen].sort((a,b)=>a.free_seats-b.free_seats || a.table_no-b.table_no)
    .map(t=>{const seats=Math.min(remaining,t.free_seats);remaining-=seats;
      return {table_no:t.table_no,seats};});
}