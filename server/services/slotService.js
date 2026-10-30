import { ConflictError, NotFoundError, ValidationError } from '../errors.js';
import { onlyKeys, positiveInt } from '../domain/validation.js';
import { dateOnly, validateInterval } from '../domain/time.js';

export function createSlotService(dao) {
  function details(id) {
    const s = dao.find(id);
    if (!s) throw new NotFoundError('Slot not found');
    const tables = dao.tables(id);
    return { ...s, capacity: tables.reduce((n,t)=>n+t.seats,0),
      free_seats: tables.reduce((n,t)=>n+t.free_seats,0), tables };
  }
  function layout(body) {
    const hasTables = Object.hasOwn(body,'tables');
    const hasSource = Object.hasOwn(body,'copy_from_tsID');
    if (hasTables === hasSource)
      throw new ValidationError('Provide tables OR copy_from_tsID');
    let rows;
    if (hasSource) {
      const source = details(positiveInt(body.copy_from_tsID,'copy_from_tsID'));
      rows = source.tables.map(({table_no,seats})=>({table_no,seats}));
    } else rows = body.tables;
    if (!Array.isArray(rows)) throw new ValidationError('tables must be an array');
    const seen = new Set();
    for (const t of rows) {
      onlyKeys(t,['table_no','seats']);
      positiveInt(t.table_no,'table_no'); positiveInt(t.seats,'seats');
      if (seen.has(t.table_no)) throw new ValidationError('Duplicate table number');
      seen.add(t.table_no);
    }
    if (!Number.isSafeInteger(rows.reduce((n,t)=>n+t.seats,0)))
      throw new ValidationError('Capacity exceeds numeric representation');
    return rows;
  }
  return {
    details,
    list(date) { return dao.list(dateOnly(date)).map(s=>details(s.tsID)); },
    create(body) {
      onlyKeys(body,['start_time','end_time','tables','copy_from_tsID']);
      validateInterval(body.start_time,body.end_time);
      return dao.atomic(()=>{
        if (dao.sameInterval(body.start_time,body.end_time))
          throw new ConflictError('Slot already exists');
        const rows = layout(body);
        const id = dao.insert(body.start_time,body.end_time);
        dao.insertTables(id,rows);
        return details(id);
      });
    },
    defineTables(id,body) {
      onlyKeys(body,['tables','copy_from_tsID']);
      return dao.atomic(()=>{
        const current = details(id);
        validateInterval(current.start_time,current.end_time);
        if (current.tables.length)
          throw new ConflictError('Layout already defined: modification belongs to MH-19');
        dao.insertTables(id,layout(body));
        return details(id);
      });
    },
  };
}