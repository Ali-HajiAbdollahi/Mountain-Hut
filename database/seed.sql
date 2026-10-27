-- Sample data (development only). Hash/salt are fake.
INSERT INTO users (uID, name, email, phone, role, password, salt) VALUES
  (1, 'Elena Gestore',  'elena@hut.it',  '3331110000', 'employee', 'hash-fake', 'salt-fake'),
  (2, 'Marco Bianchi',  'marco@mail.it', '3332220000', 'hiker',    'hash-fake', 'salt-fake'),
  (3, 'Sara Verdi',     'sara@mail.it',  NULL,         'hiker',    'hash-fake', 'salt-fake'),
  -- profile created by an employee (MH-07): no password, cannot log in yet
  (4, 'Luca Neri',      'luca@mail.it',  '3334440000', 'hiker',    NULL,        NULL);

-- Lunch in two consecutive slots (MH-02), dinner with a different layout, an empty day.
INSERT INTO timeslots (tsID, start_time, end_time) VALUES
  (1, '2026-11-01 12:00', '2026-11-01 13:00'),
  (2, '2026-11-01 13:00', '2026-11-01 14:00'),
  (3, '2026-11-01 19:00', '2026-11-01 20:30'),
  (4, '2026-11-02 12:00', '2026-11-02 13:00');

INSERT INTO slot_tables (tsID, table_no, seats) VALUES
  (1, 1, 2), (1, 2, 2), (1, 3, 4), (1, 4, 6),
  (2, 1, 2), (2, 2, 2), (2, 3, 4), (2, 4, 6),
  (3, 1, 4), (3, 2, 4), (3, 3, 8),
  (4, 1, 2), (4, 2, 4);

INSERT INTO bookings (bID, tsID, uID, contact_name, contact_phone, n_people, created_by) VALUES
  (1, 1, 2,    'Marco Bianchi', '3332220000', 8, NULL),  -- web, over several tables (MH-01)
  (2, 1, 3,    'Sara Verdi',    NULL,         3, NULL),  -- partially occupied table (MH-04)
  (3, 1, NULL, 'Rossi Group',  '3335550000', 2, 1),     -- temporary hiker (MH-07)
  (4, 2, 4,    'Luca Neri',     '3334440000', 4, 1),     -- entered by an employee for a registered profile
  (5, 3, 2,    'Marco Bianchi', '3332220000', 6, NULL);

INSERT INTO booking_tables (bID, tsID, table_no, seats) VALUES
  (1, 1, 4, 6), (1, 1, 1, 2),
  (2, 1, 3, 3),
  (3, 1, 2, 2),
  (4, 2, 3, 4),
  (5, 3, 3, 6);

-- Requirements for subgroups (MH-05)
INSERT INTO booking_requirements (bID, n_people, description, allergy) VALUES
  (1, 2,    'Vegetarian',               0),
  (5, 1,    'Coeliac disease, no cross-contamination', 1),
  (5, NULL, 'No pork',     0);
