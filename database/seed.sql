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
  (4, '2026-11-02 12:00', '2026-11-02 13:00');

INSERT INTO slot_tables (tsID, table_no, seats) VALUES
  (1, 1, 2), (1, 2, 2), (1, 3, 4), (1, 4, 6),
  (2, 1, 2), (2, 2, 2), (2, 3, 4), (2, 4, 6),
  (3, 1, 4), (3, 2, 4), (3, 3, 8),
  (4, 1, 2), (4, 2, 4);

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
