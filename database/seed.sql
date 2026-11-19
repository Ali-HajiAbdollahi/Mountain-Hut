-- Sample data (development only). Every user with a password has the password 'password123'.
INSERT INTO users (uID, name, email, phone, role, password, salt) VALUES
  (1, 'Elena Gestore',  'elena@hut.it',  '3331110000', 'employee', '115a518dee6878560432f9e59688a704e12937496d3b097130cbfe408dd4c02ff4b8f16d935b8536e2a640a578b39ecf73a5e331a484e25af901a4bd69290f98', '492debbe54761ed01a1a0b6d15dd6490'),
  (2, 'Marco Bianchi',  'marco@mail.it', '3332220000', 'hiker',    'feb18a5cb2902701b3e36036e92807f626ec0d564e17474cf30b78af47098479da16c1214b76cab22329ed808a25937685ba75fc74513e6ad0eaa086ab0c8c78', '55d6160ebd3eb77b1b6d6bd221108476'),
  (3, 'Sara Verdi',     'sara@mail.it',  NULL,         'hiker',    '90cfad47ef45c9bfa5c2efb500e77453aa309202bfa2bdd57c095a5f8cf688cec227c5d16f4e8bf359ffcdf5ba7e486deb12fb92e722b90df64d8804af43cd21', 'cd233747eaacff2b957b8605642461bf'),
  -- profile created by an employee : no password, cannot log in yet
  (4, 'Luca Neri',      'luca@mail.it',  '3334440000', 'hiker',    NULL,        NULL);

-- Lunch in two consecutive slots (MH-02), dinner with a different layout, an empty day.
INSERT INTO timeslots (tsID, start_time, end_time) VALUES
  (1, '2026-11-01 12:00', '2026-11-01 13:00'),
  (2, '2026-11-01 13:00', '2026-11-01 14:00'),
  (3, '2026-11-01 19:00', '2026-11-01 20:30'),
  (4, '2026-11-02 12:00', '2026-11-02 13:00'),
  (5, '2026-11-04 12:00', '2026-11-04 13:00'),
  (6, '2026-11-04 19:00', '2026-11-04 20:30'),
  (7, '2026-11-05 13:00', '2026-11-05 14:00'),
  (8, '2026-11-06 12:00', '2026-11-06 13:00'),
  (9, '2026-11-07 19:00', '2026-11-07 20:30'),
  (10, '2026-11-09 12:00', '2026-11-09 13:00'),
  (11, '2026-11-09 19:00', '2026-11-09 20:30'),
  (12, '2026-11-10 12:00', '2026-11-10 13:00'),
  (13, '2026-11-10 19:00', '2026-11-10 20:30'),
  (14, '2026-11-11 12:00', '2026-11-11 13:00'),
  (15, '2026-11-11 19:00', '2026-11-11 20:30'),
  (16, '2026-11-12 12:00', '2026-11-12 13:00'),
  (17, '2026-11-12 19:00', '2026-11-12 20:30'),
  (18, '2026-11-13 12:00', '2026-11-13 13:00'),
  (19, '2026-11-13 19:00', '2026-11-13 20:30'),
  (20, '2026-11-14 12:00', '2026-11-14 13:00'),
  (21, '2026-11-14 19:00', '2026-11-14 20:30'),
  (22, '2026-11-15 12:00', '2026-11-15 13:00'),
  (23, '2026-11-15 19:00', '2026-11-15 20:30');

INSERT INTO slot_tables (tsID, table_no, seats) VALUES
  (1, 1, 2), (1, 2, 2), (1, 3, 4), (1, 4, 6),
  (2, 1, 2), (2, 2, 2), (2, 3, 4), (2, 4, 6),
  (3, 1, 4), (3, 2, 4), (3, 3, 8),
  (4, 1, 2), (4, 2, 4),
  (5, 1, 2), (5, 2, 2), (5, 3, 4), (5, 4, 6),
  (6, 1, 4), (6, 2, 4), (6, 3, 8),
  (7, 1, 2), (7, 2, 2), (7, 3, 4), (7, 4, 6),
  (8, 1, 2), (8, 2, 4), (8, 3, 6),
  (9, 1, 4), (9, 2, 4), (9, 3, 8),
  (10, 1, 2), (10, 2, 2), (10, 3, 4), (10, 4, 6),
  (11, 1, 4), (11, 2, 4), (11, 3, 8),
  (12, 1, 2), (12, 2, 2), (12, 3, 4), (12, 4, 6),
  (13, 1, 4), (13, 2, 4), (13, 3, 8),
  (14, 1, 2), (14, 2, 2), (14, 3, 4), (14, 4, 6),
  (15, 1, 4), (15, 2, 4), (15, 3, 8),
  (16, 1, 2), (16, 2, 2), (16, 3, 4), (16, 4, 6),
  (17, 1, 4), (17, 2, 4), (17, 3, 8),
  (18, 1, 2), (18, 2, 2), (18, 3, 4), (18, 4, 6),
  (19, 1, 4), (19, 2, 4), (19, 3, 8),
  (20, 1, 2), (20, 2, 2), (20, 3, 4), (20, 4, 6),
  (21, 1, 4), (21, 2, 4), (21, 3, 8),
  (22, 1, 2), (22, 2, 2), (22, 3, 4), (22, 4, 6),
  (23, 1, 4), (23, 2, 4), (23, 3, 8);

INSERT INTO bookings (bID, tsID, uID, contact_name, contact_phone, n_people, created_by) VALUES
  (1, 1, 2,    'Marco Bianchi', '3332220000', 8, NULL),  -- web, over several tables (MH-01)
  (2, 1, 3,    'Sara Verdi',    NULL,         3, NULL),  -- partially occupied table (MH-04)
  (3, 1, NULL, 'Rossi Group',  '3335550000', 2, 1),      -- temporary hiker (MH-07)
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
