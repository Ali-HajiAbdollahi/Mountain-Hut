// authService — unit tests (no database, fake user DAO)
import crypto from 'node:crypto';
import { describe, it, expect, vi } from 'vitest';
import { createAuthService } from '../../services/authService.js';
import { AuthenticationError, ConflictError, ValidationError } from '../../errors.js';

const PASSWORD = 'password1';
const NOW = Date.parse('2099-01-01T10:00:00.000Z');
const DAY_MS = 24 * 60 * 60 * 1000;

const scrypt = (password, salt) =>
  crypto.scryptSync(password, Buffer.from(salt, 'hex'), 64).toString('hex');
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');

// a user row as the DAO returns it, with a real hash for `password`
function row(overrides = {}) {
  const salt = crypto.randomBytes(16).toString('hex');
  return {
    uID: 1, name: 'Sara Verdi', email: 'sara@mail.it', phone: '333', role: 'hiker',
    password: scrypt(PASSWORD, salt), salt, must_change_password: 0, ...overrides,
  };
}

// fake DAO that keeps the rows in memory; every method is a spy
function setup(users = []) {
  const rows = new Map(users.map(u => [u.uID, u]));
  let nextId = 100;
  const userDao = {
    insert: vi.fn(u => {
      const uID = nextId++;
      rows.set(uID, { uID, ...u, must_change_password: u.mustChangePassword ? 1 : 0 });
      return uID;
    }),
    findById: vi.fn(uID => rows.get(uID)),
    findByEmail: vi.fn(email => [...rows.values()].find(u => u.email === email)),
    setPassword: vi.fn((uID, password, salt, mustChange) =>
      Object.assign(rows.get(uID), { password, salt, must_change_password: mustChange ? 1 : 0 })),
    issueResetToken: vi.fn(),
    consumeResetToken: vi.fn(),
    atomic: vi.fn(action => action()),
  };
  return { rows, userDao, auth: createAuthService(userDao) };
}

const profile = (overrides = {}) =>
  ({ name: 'Luca Neri', email: 'luca@mail.it', phone: '3334440000', password: PASSWORD, ...overrides });

describe('authService.register', () => {
  it('creates a hiker and returns the public profile without password and salt', () => {
    const { auth, userDao } = setup();
    const user = auth.register(profile());
    expect(user).toEqual({
      uID: 100, name: 'Luca Neri', email: 'luca@mail.it', phone: '3334440000', role: 'hiker',
      must_change_password: false,
    });
    expect(user).not.toHaveProperty('password');
    expect(user).not.toHaveProperty('salt');
    expect(userDao.insert).toHaveBeenCalledTimes(1);
    expect(userDao.findById).toHaveBeenCalledWith(100);
  });

  it('stores a scrypt hash and a random salt, never the plain password', () => {
    const { auth, userDao } = setup();
    auth.register(profile());
    const stored = userDao.insert.mock.calls[0][0];
    expect(stored.password).not.toBe(PASSWORD);
    expect(stored.password).toMatch(/^[0-9a-f]{128}$/);
    expect(stored.salt).toMatch(/^[0-9a-f]{32}$/);
    expect(stored.password).toBe(scrypt(PASSWORD, stored.salt));
  });

  it('uses a different salt (and so a different hash) for every registration', () => {
    const { auth, userDao } = setup();
    auth.register(profile({ email: 'a@mail.it' }));
    auth.register(profile({ email: 'b@mail.it' }));
    const [first, second] = userDao.insert.mock.calls.map(([u]) => u);
    expect(first.salt).not.toBe(second.salt);
    expect(first.password).not.toBe(second.password);
  });

  it('ignores a role passed by the caller: self-registered accounts are always hikers', () => {
    const { auth, userDao } = setup();
    auth.register({ ...profile(), role: 'employee' });
    expect(userDao.insert.mock.calls[0][0].role).toBe('hiker');
  });

  it('trims the name and the phone, and trims and lowercases the email', () => {
    const { auth, userDao } = setup();
    auth.register(profile({ name: '  Luca Neri  ', email: '  Luca@Mail.IT ', phone: ' 333 ' }));
    expect(userDao.insert).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Luca Neri', email: 'luca@mail.it', phone: '333' }));
  });

  it.each([undefined, null, '', '   '])('stores a missing or blank phone (%j) as null', phone => {
    const { auth, userDao } = setup();
    auth.register(profile({ phone }));
    expect(userDao.insert.mock.calls[0][0].phone).toBeNull();
  });

  it('does not require the password to be changed unless asked', () => {
    const { auth, userDao } = setup();
    expect(auth.register(profile()).must_change_password).toBe(false);
    expect(userDao.insert.mock.calls[0][0].mustChangePassword).toBe(false);
  });

  it('flags accounts created by an employee as must-change-password', () => {
    const { auth, userDao } = setup();
    const user = auth.register(profile({ mustChangePassword: true }));
    expect(userDao.insert.mock.calls[0][0].mustChangePassword).toBe(true);
    expect(user.must_change_password).toBe(true);
  });

  it.each([undefined, null, '', '   '])('rejects a missing name (%j)', name => {
    const { auth, userDao } = setup();
    expect(() => auth.register(profile({ name }))).toThrow(new ValidationError('Name is required'));
    expect(userDao.insert).not.toHaveBeenCalled();
  });

  it.each([
    ['missing', undefined],
    ['empty', ''],
    ['blank', '   '],
    ['without @', 'luca.mail.it'],
    ['without domain', 'luca@'],
    ['without local part', '@mail.it'],
    ['without a dot in the domain', 'luca@mail'],
    ['with a space', 'lu ca@mail.it'],
    ['with two @', 'luca@@mail.it'],
  ])('rejects an email that is %s', (_label, email) => {
    const { auth, userDao } = setup();
    expect(() => auth.register(profile({ email }))).toThrow(new ValidationError('A valid email is required'));
    expect(userDao.insert).not.toHaveBeenCalled();
  });

  it.each(['luca@mail.it', 'luca.neri+hut@mail.example.co.uk', 'l@a.b'])('accepts the email %s', email => {
    const { auth } = setup();
    expect(() => auth.register(profile({ email }))).not.toThrow();
  });

  it.each([
    ['missing', undefined],
    ['null', null],
    ['not a string', 12345678],
    ['too short', 'short12'],
    ['empty', ''],
  ])('rejects a password that is %s', (_label, password) => {
    const { auth, userDao } = setup();
    expect(() => auth.register(profile({ password })))
      .toThrow(new ValidationError('Password must be at least 8 characters'));
    expect(userDao.insert).not.toHaveBeenCalled();
  });

  it('accepts a password of exactly 8 characters', () => {
    const { auth } = setup();
    expect(() => auth.register(profile({ password: '12345678' }))).not.toThrow();
  });

  it('validates the name before the email and the email before the password', () => {
    const { auth } = setup();
    expect(() => auth.register({ email: 'bad', password: 'x' })).toThrow('Name is required');
    expect(() => auth.register({ name: 'Luca', email: 'bad', password: 'x' })).toThrow('A valid email is required');
    expect(() => auth.register({ name: 'Luca', email: 'luca@mail.it', password: 'x' }))
      .toThrow('Password must be at least 8 characters');
  });

  it('turns a UNIQUE constraint failure (2067) into a ConflictError', () => {
    const { auth, userDao } = setup();
    userDao.insert.mockImplementation(() => { throw Object.assign(new Error('UNIQUE'), { errcode: 2067 }); });
    expect(() => auth.register(profile())).toThrow(ConflictError);
    expect(() => auth.register(profile())).toThrow('Email already registered');
  });

  it('rejects the same email registered twice (case and spaces ignored)', () => {
    const { auth, userDao } = setup();
    userDao.insert.mockImplementationOnce(() => 100)
      .mockImplementationOnce(() => { throw Object.assign(new Error('UNIQUE'), { errcode: 2067 }); });
    userDao.findById.mockReturnValueOnce(row({ uID: 100, email: 'luca@mail.it' }));
    auth.register(profile());
    expect(() => auth.register(profile({ email: ' LUCA@mail.it ' }))).toThrow(ConflictError);
    expect(userDao.insert.mock.calls[1][0].email).toBe('luca@mail.it');
  });

  it('lets any other DAO error through unchanged', () => {
    const { auth, userDao } = setup();
    const failure = Object.assign(new Error('disk I/O error'), { errcode: 10 });
    userDao.insert.mockImplementation(() => { throw failure; });
    expect(() => auth.register(profile())).toThrow(failure);
  });

  it('lets an error without an errcode through unchanged', () => {
    const { auth, userDao } = setup();
    const failure = new TypeError('boom');
    userDao.findById.mockImplementation(() => { throw failure; });
    expect(() => auth.register(profile())).toThrow(failure);
  });
});

describe('authService.login', () => {
  it('returns the public profile for the right credentials', () => {
    const { auth } = setup([row()]);
    const user = auth.login({ email: 'sara@mail.it', password: PASSWORD });
    expect(user).toEqual({
      uID: 1, name: 'Sara Verdi', email: 'sara@mail.it', phone: '333', role: 'hiker', must_change_password: false,
    });
    expect(user).not.toHaveProperty('password');
    expect(user).not.toHaveProperty('salt');
  });

  it('works for a user registered through the service', () => {
    const { auth } = setup();
    auth.register(profile());
    expect(auth.login({ email: 'luca@mail.it', password: PASSWORD }).name).toBe('Luca Neri');
  });

  it('normalizes the email (trim and lowercase) before the lookup', () => {
    const { auth, userDao } = setup([row()]);
    expect(auth.login({ email: '  SARA@Mail.it ', password: PASSWORD }).uID).toBe(1);
    expect(userDao.findByEmail).toHaveBeenCalledWith('sara@mail.it');
  });

  it('reports must_change_password as a boolean', () => {
    const { auth } = setup([row({ must_change_password: 1 })]);
    expect(auth.login({ email: 'sara@mail.it', password: PASSWORD }).must_change_password).toBe(true);
  });

  it('keeps the role of employees', () => {
    const { auth } = setup([row({ role: 'employee' })]);
    expect(auth.login({ email: 'sara@mail.it', password: PASSWORD }).role).toBe('employee');
  });

  it('rejects a wrong password', () => {
    const { auth } = setup([row()]);
    expect(() => auth.login({ email: 'sara@mail.it', password: 'wrong-password' }))
      .toThrow(new AuthenticationError('Invalid email or password'));
  });

  it('is case sensitive on the password', () => {
    const { auth } = setup([row()]);
    expect(() => auth.login({ email: 'sara@mail.it', password: PASSWORD.toUpperCase() }))
      .toThrow(AuthenticationError);
  });

  it('rejects an unknown email with the same error as a wrong password', () => {
    const { auth } = setup([row()]);
    expect(() => auth.login({ email: 'nobody@mail.it', password: PASSWORD }))
      .toThrow(new AuthenticationError('Invalid email or password'));
  });

  it.each([
    ['password missing', { email: 'sara@mail.it' }],
    ['password null', { email: 'sara@mail.it', password: null }],
    ['password empty', { email: 'sara@mail.it', password: '' }],
    ['email missing', { password: PASSWORD }],
    ['email null', { email: null, password: PASSWORD }],
    ['email not a string', { email: 123, password: PASSWORD }],
    ['both missing', {}],
  ])('rejects the credentials when %s', (_label, credentials) => {
    const { auth } = setup([row()]);
    expect(() => auth.login(credentials)).toThrow(new AuthenticationError('Invalid email or password'));
  });

  it('does not query the DAO when the email is not a string', () => {
    const { auth, userDao } = setup([row()]);
    expect(() => auth.login({ email: undefined, password: PASSWORD })).toThrow(AuthenticationError);
    expect(userDao.findByEmail).not.toHaveBeenCalled();
  });

  it.each([
    ['no password', { password: null }],
    ['no salt', { salt: null }],
  ])('rejects a profile created by an employee with %s', (_label, overrides) => {
    const { auth } = setup([row(overrides)]);
    expect(() => auth.login({ email: 'sara@mail.it', password: PASSWORD }))
      .toThrow(new AuthenticationError('Invalid email or password'));
    expect(() => auth.login({ email: 'sara@mail.it', password: '' })).toThrow(AuthenticationError);
  });

  it('accepts a password that is a number only through its string form (String coercion)', () => {
    const salt = crypto.randomBytes(16).toString('hex');
    const { auth } = setup([row({ password: scrypt('12345678', salt), salt })]);
    expect(auth.login({ email: 'sara@mail.it', password: 12345678 }).uID).toBe(1);
  });

  it('a hash from another user does not log in with the wrong salt', () => {
    const other = row({ uID: 2, email: 'other@mail.it' });
    const { auth } = setup([row({ password: other.password })]);
    expect(() => auth.login({ email: 'sara@mail.it', password: PASSWORD })).toThrow(AuthenticationError);
  });
});

describe('authService.changePassword', () => {
  const change = (overrides = {}) => ({ current_password: PASSWORD, new_password: 'new-password-1', ...overrides });

  it('stores a new hash and salt, clears the must-change flag and returns the public profile', () => {
    const { auth, userDao, rows } = setup([row({ must_change_password: 1 })]);
    const oldSalt = rows.get(1).salt;
    const user = auth.changePassword(1, change());
    expect(userDao.setPassword).toHaveBeenCalledTimes(1);
    const [uID, hash, salt, mustChange] = userDao.setPassword.mock.calls[0];
    expect(uID).toBe(1);
    expect(salt).toMatch(/^[0-9a-f]{32}$/);
    expect(salt).not.toBe(oldSalt);
    expect(hash).toBe(scrypt('new-password-1', salt));
    expect(mustChange).toBe(false);
    expect(user.must_change_password).toBe(false);
    expect(user).not.toHaveProperty('password');
    expect(user).not.toHaveProperty('salt');
  });

  it('lets the user log in with the new password only', () => {
    const { auth } = setup([row()]);
    auth.changePassword(1, change());
    expect(auth.login({ email: 'sara@mail.it', password: 'new-password-1' }).uID).toBe(1);
    expect(() => auth.login({ email: 'sara@mail.it', password: PASSWORD })).toThrow(AuthenticationError);
  });

  it('rejects a wrong current password', () => {
    const { auth, userDao } = setup([row()]);
    expect(() => auth.changePassword(1, change({ current_password: 'wrong-password' })))
      .toThrow(new ValidationError('Current password is not correct'));
    expect(userDao.setPassword).not.toHaveBeenCalled();
  });

  it('rejects an unknown user with the same message', () => {
    const { auth, userDao } = setup();
    expect(() => auth.changePassword(99, change())).toThrow(new ValidationError('Current password is not correct'));
    expect(userDao.setPassword).not.toHaveBeenCalled();
  });

  it('rejects a user without a password (created by an employee)', () => {
    const { auth } = setup([row({ password: null, salt: null })]);
    expect(() => auth.changePassword(1, change())).toThrow('Current password is not correct');
  });

  it('rejects a missing current password', () => {
    const { auth } = setup([row()]);
    expect(() => auth.changePassword(1, { new_password: 'new-password-1' })).toThrow('Current password is not correct');
  });

  it.each([
    ['missing', undefined],
    ['not a string', 12345678],
    ['too short', 'short12'],
    ['too long', 'x'.repeat(129)],
  ])('rejects a new password that is %s', (_label, new_password) => {
    const { auth, userDao } = setup([row()]);
    expect(() => auth.changePassword(1, change({ new_password })))
      .toThrow(new ValidationError('Password must be between 8 and 128 characters'));
    expect(userDao.setPassword).not.toHaveBeenCalled();
  });

  it.each([8, 128])('accepts a new password of %i characters', length => {
    const { auth, userDao } = setup([row()]);
    auth.changePassword(1, change({ new_password: 'n'.repeat(length) }));
    expect(userDao.setPassword).toHaveBeenCalledTimes(1);
  });

  it('rejects a new password equal to the current one', () => {
    const { auth, userDao } = setup([row()]);
    expect(() => auth.changePassword(1, change({ new_password: PASSWORD })))
      .toThrow(new ValidationError('The new password must be different from the current one'));
    expect(userDao.setPassword).not.toHaveBeenCalled();
  });

  it('checks the current password before the new one', () => {
    const { auth } = setup([row()]);
    expect(() => auth.changePassword(1, { current_password: 'wrong-password', new_password: 'x' }))
      .toThrow('Current password is not correct');
  });
});

describe('authService.requestPasswordReset', () => {
  it('issues a random url-safe token and stores only its SHA-256 hash', () => {
    const { auth, userDao } = setup([row()]);
    const result = auth.requestPasswordReset('sara@mail.it', NOW);
    expect(result.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(userDao.issueResetToken).toHaveBeenCalledWith({
      tokenHash: sha256(result.token), uID: 1,
      expiresAt: new Date(NOW + DAY_MS).toISOString(), now: new Date(NOW).toISOString(),
    });
    expect(JSON.stringify(userDao.issueResetToken.mock.calls)).not.toContain(result.token);
  });

  it('returns the public profile of the user', () => {
    const { auth } = setup([row()]);
    const { user } = auth.requestPasswordReset('sara@mail.it');
    expect(user).toEqual({
      uID: 1, name: 'Sara Verdi', email: 'sara@mail.it', phone: '333', role: 'hiker', must_change_password: false,
    });
    expect(user).not.toHaveProperty('password');
    expect(user).not.toHaveProperty('salt');
  });

  it('normalizes the email before the lookup', () => {
    const { auth, userDao } = setup([row()]);
    expect(auth.requestPasswordReset('  SARA@Mail.it ', NOW)).not.toBeNull();
    expect(userDao.findByEmail).toHaveBeenCalledWith('sara@mail.it');
  });

  it('issues a different token every time', () => {
    const { auth } = setup([row()]);
    const a = auth.requestPasswordReset('sara@mail.it', NOW).token;
    const b = auth.requestPasswordReset('sara@mail.it', NOW).token;
    expect(a).not.toBe(b);
  });

  it('uses the current time when none is given', () => {
    const { auth, userDao } = setup([row()]);
    const before = Date.now();
    auth.requestPasswordReset('sara@mail.it');
    const { now, expiresAt } = userDao.issueResetToken.mock.calls[0][0];
    expect(Date.parse(now)).toBeGreaterThanOrEqual(before);
    expect(Date.parse(expiresAt) - Date.parse(now)).toBe(DAY_MS);
  });

  it('returns null and issues nothing for an unknown email', () => {
    const { auth, userDao } = setup([row()]);
    expect(auth.requestPasswordReset('nobody@mail.it', NOW)).toBeNull();
    expect(userDao.issueResetToken).not.toHaveBeenCalled();
  });

  it.each([undefined, null, 123, {}])('returns null without a DAO lookup when the email is %j', email => {
    const { auth, userDao } = setup([row()]);
    expect(auth.requestPasswordReset(email, NOW)).toBeNull();
    expect(userDao.findByEmail).not.toHaveBeenCalled();
    expect(userDao.issueResetToken).not.toHaveBeenCalled();
  });
});

describe('authService.resetPassword', () => {
  it('consumes the hashed token and stores a new hash and salt, clearing the must-change flag', () => {
    const { auth, userDao } = setup([row()]);
    userDao.consumeResetToken.mockReturnValue(1);
    auth.resetPassword('some-token', 'new-password-1', NOW);
    expect(userDao.consumeResetToken).toHaveBeenCalledWith(sha256('some-token'), new Date(NOW).toISOString());
    const [uID, hash, salt, mustChange] = userDao.setPassword.mock.calls[0];
    expect(uID).toBe(1);
    expect(salt).toMatch(/^[0-9a-f]{32}$/);
    expect(hash).toBe(scrypt('new-password-1', salt));
    expect(mustChange).toBe(false);
  });

  it('runs inside one atomic block', () => {
    const { auth, userDao } = setup([row()]);
    userDao.consumeResetToken.mockReturnValue(1);
    auth.resetPassword('some-token', 'new-password-1', NOW);
    expect(userDao.atomic).toHaveBeenCalledTimes(1);
  });

  it('works end to end with a token from requestPasswordReset', () => {
    const { auth, userDao } = setup([row()]);
    const { token } = auth.requestPasswordReset('sara@mail.it', NOW);
    userDao.consumeResetToken.mockImplementation(hash =>
      hash === userDao.issueResetToken.mock.calls[0][0].tokenHash ? 1 : undefined);
    auth.resetPassword(token, 'new-password-1', NOW);
    expect(auth.login({ email: 'sara@mail.it', password: 'new-password-1' }).uID).toBe(1);
    expect(() => auth.login({ email: 'sara@mail.it', password: PASSWORD })).toThrow(AuthenticationError);
  });

  it.each([undefined, null, 0, NaN, ''])('rejects an invalid or expired token (consumeResetToken returns %j)', uID => {
    const { auth, userDao } = setup([row()]);
    userDao.consumeResetToken.mockReturnValue(uID);
    expect(() => auth.resetPassword('some-token', 'new-password-1', NOW))
      .toThrow(new ValidationError('Invalid or expired reset link'));
    expect(userDao.setPassword).not.toHaveBeenCalled();
  });

  it.each([undefined, null, '', 123, {}])('rejects a token that is %j without touching the DAO', token => {
    const { auth, userDao } = setup([row()]);
    expect(() => auth.resetPassword(token, 'new-password-1', NOW))
      .toThrow(new ValidationError('Invalid or expired reset link'));
    expect(userDao.atomic).not.toHaveBeenCalled();
    expect(userDao.consumeResetToken).not.toHaveBeenCalled();
  });

  it.each([
    ['missing', undefined],
    ['not a string', 12345678],
    ['too short', 'short12'],
    ['too long', 'x'.repeat(129)],
  ])('rejects a new password that is %s before consuming the token', (_label, password) => {
    const { auth, userDao } = setup([row()]);
    expect(() => auth.resetPassword('some-token', password, NOW))
      .toThrow(new ValidationError('Password must be between 8 and 128 characters'));
    expect(userDao.consumeResetToken).not.toHaveBeenCalled();
  });

  it.each([8, 128])('accepts a new password of %i characters', length => {
    const { auth, userDao } = setup([row()]);
    userDao.consumeResetToken.mockReturnValue(1);
    auth.resetPassword('some-token', 'n'.repeat(length), NOW);
    expect(userDao.setPassword).toHaveBeenCalledTimes(1);
  });

  it('uses the current time when none is given', () => {
    const { auth, userDao } = setup([row()]);
    userDao.consumeResetToken.mockReturnValue(1);
    const before = Date.now();
    auth.resetPassword('some-token', 'new-password-1');
    expect(Date.parse(userDao.consumeResetToken.mock.calls[0][1])).toBeGreaterThanOrEqual(before);
  });

  it('accepts a token only once', () => {
    const { auth, userDao } = setup([row()]);
    userDao.consumeResetToken.mockReturnValueOnce(1).mockReturnValue(undefined);
    auth.resetPassword('some-token', 'new-password-1', NOW);
    expect(() => auth.resetPassword('some-token', 'other-password-1', NOW)).toThrow(ValidationError);
    expect(userDao.setPassword).toHaveBeenCalledTimes(1);
  });

  it('lets a DAO failure inside the atomic block through', () => {
    const { auth, userDao } = setup([row()]);
    const failure = new Error('database is locked');
    userDao.consumeResetToken.mockImplementation(() => { throw failure; });
    expect(() => auth.resetPassword('some-token', 'new-password-1', NOW)).toThrow(failure);
  });
});
