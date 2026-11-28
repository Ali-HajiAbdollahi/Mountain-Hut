# Hike completion storage audit
Baseline: develop a1e1601.
The hikes table already contains returned_at TEXT nullable in schema.sql and
migration 012_hikes.sql. Existing hikes remain NULL until confirmation.
The active query already filters returned_at IS NULL.
Do not add completed_at or run ALTER TABLE ADD returned_at again.
For an older database without hikes, migration 012 creates hikes and waypoints
without resetting users/bookings. If hikes exists but lacks returned_at, stop
and inspect that legacy schema: CREATE TABLE IF NOT EXISTS does not alter it.
New completion APIs use returned_at and preserve its first value on retries.