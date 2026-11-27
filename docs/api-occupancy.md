# Occupancy API
GET /api/occupancy?date=2026-11-27&period=day
GET /api/occupancy?date=2026-11-27&period=week

Employee session required: anonymous 401, other roles 403.
`date` is a real YYYY-MM-DD date; `period` is day (default) or week.
Week means the ISO week containing date, Monday to next Monday.
All boundaries are Europe/Rome local date-times. Filter slot start in [from,to).
Unknown query fields, repeated parameters, impossible dates and invalid periods: 400.

Example day response (illustrative independent slots):
```json
{"period":"day","from":"2026-11-27 00:00","to":"2026-11-28 00:00","slots":[
 {"tsID":1,"start_time":"2026-11-27 12:00","end_time":"2026-11-27 13:00","total_capacity":20,"booked_seats":8,"remaining_seats":12},
 {"tsID":2,"start_time":"2026-11-27 13:00","end_time":"2026-11-27 14:00","total_capacity":20,"booked_seats":20,"remaining_seats":0},
 {"tsID":3,"start_time":"2026-11-27 19:00","end_time":"2026-11-27 20:00","total_capacity":0,"booked_seats":0,"remaining_seats":0}
]}
```
An empty day returns the same envelope with slots: []. A week response for
2026-11-27 has from=2026-11-23 00:00 and to=2026-11-30 00:00.
Zero capacity means unconfigured, not fully booked. Counts are seats, not bookings.
Cancellation releases booking allocations, so subsequent reads reflect released seats.
Invalid example: date=2026-02-30 or period=month returns:
```json
{"error":{"code":"VALIDATION_ERROR","message":"Invalid date"}}
```
The actual message depends on the invalid field. Other errors use the project's error envelope.