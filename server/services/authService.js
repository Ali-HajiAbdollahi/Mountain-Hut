// used for scrypt hashing, random salts and constant-time comparison
import crypto from 'node:crypto';
// custom errors the routes layer can map to HTTP status codes
import { AuthenticationError, ConflictError, ValidationError } from '../errors.js';

// shortest password accepted at registration
const MIN_PASSWORD_LENGTH = 8;
// Length in bytes of the derived scrypt key (stored as 128 hex characters)
const KEY_LENGTH = 64;
// SQLite extended result code for "UNIQUE constraint failed"
const SQLITE_CONSTRAINT_UNIQUE = 2067;
// longest valid email address (RFC 5321); also bounds the work done by the regex
const MAX_EMAIL_LENGTH = 254;
// email shape check: something@label.label, no spaces; domain labels cannot contain '.', so the
// parts never overlap and matching stays linear (no backtracking)
const EMAIL_RE = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;
const isValidEmail = email => email.length <= MAX_EMAIL_LENGTH && EMAIL_RE.test(email);

// derives the password hash (hex) from the password and the salt (hex)
const hashPassword = (password, salt) =>
  // scrypt is a deliberately slow, memory-hard hash; the salt is decoded from hex into bytes first
  crypto.scryptSync(password, Buffer.from(salt, 'hex'), KEY_LENGTH).toString('hex');

// fixed random salt generated once at startup, used when no real salt is available
const DUMMY_SALT = crypto.randomBytes(16).toString('hex');

// strips password and salt so they never leave the service
const publicUser = ({ uID, name, email, phone, role, must_change_password }) =>
  ({ uID, name, email, phone, role, must_change_password: must_change_password === 1 });

// password reset links stay valid for 24 hours
const RESET_TOKEN_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_PASSWORD_LENGTH = 128;
// only the hash of a reset token is stored, so a database leak does not expose usable tokens
const hashToken = token => crypto.createHash('sha256').update(token).digest('hex');
const iso = ms => new Date(ms).toISOString();

function newPassword(value) {
  if (typeof value !== 'string' || value.length < MIN_PASSWORD_LENGTH || value.length > MAX_PASSWORD_LENGTH)
    throw new ValidationError(
      `Password must be between ${MIN_PASSWORD_LENGTH} and ${MAX_PASSWORD_LENGTH} characters`);
  return value;
}

// true when the password matches the stored hash (constant-time comparison)
function passwordMatches(user, password) {
  const hasPassword = user?.password && user?.salt;
  // hash even for unknown users (with the dummy salt) to keep timing similar
  const candidate = hashPassword(String(password ?? ''), hasPassword ? user.salt : DUMMY_SALT);
  return Boolean(hasPassword) &&
    crypto.timingSafeEqual(Buffer.from(candidate, 'hex'), Buffer.from(user.password, 'hex'));
}

// builds the auth service on top of a user DAO
export function createAuthService(userDao) {
  return {
    // REGISTRATION: always creates a 'hiker' (employees are not self-registerable).
    // mustChangePassword is set for accounts created by an employee (MH-07).
    register({ name, email, phone, password, mustChangePassword = false }) {
      // trim the name -> stays undefined if it was not provided
      name = name?.trim();
      // trim and lowercase the email -> the same address is always stored the same way
      email = email?.trim().toLowerCase();
      // trim the phone -> an empty or missing phone becomes NULL
      phone = phone?.trim() || null;

      // name is mandatory
      if (!name) throw new ValidationError('Name is required');
      // email must be present and "look like an email"
      if (!email || !isValidEmail(email)) throw new ValidationError('A valid email is required');
      // password must be a string of at least MIN_PASSWORD_LENGTH characters
      if (typeof password !== 'string' || password.length < MIN_PASSWORD_LENGTH)
        throw new ValidationError(`Password must be at least ${MIN_PASSWORD_LENGTH} characters`);

      // A fresh random 16-byte salt for this user, as hex (32 characters)
      const salt = crypto.randomBytes(16).toString('hex');
      // The insert can fail on a duplicate email, so it is wrapped in try/catch
      try {
        // insert the user and keep the generated uID
        const uID = userDao.insert({
          // Role is fixed to 'hiker'; only the hash and the salt are stored, never the password
          name, email, phone, role: 'hiker', password: hashPassword(password, salt), salt, mustChangePassword,
        });
        // read the row back and return it without password and salt
        return publicUser(userDao.findById(uID));
      } catch (err) {
        // duplicate email
        if (err.errcode === SQLITE_CONSTRAINT_UNIQUE) throw new ConflictError('Email already registered');
        throw err;
      }
    },

    // LOGIN: same generic error for unknown email, wrong password, or a profile without a password
    // (created by an employee) so that accounts cannot be enumerated.
    login({ email, password }) {
      // Look the user up by normalized email; a non-string email means no user
      const user = typeof email === 'string' ? userDao.findByEmail(email.trim().toLowerCase()) : undefined;
      // reject: there is no usable password, or the hashes differ; same message for every failure case
      if (!passwordMatches(user, password)) throw new AuthenticationError('Invalid email or password');
      // success: return the user without password and salt
      return publicUser(user);
    },

    // Changes the password of the logged-in user and clears the "must change" flag.
    changePassword(uID, { current_password, new_password }) {
      const user = userDao.findById(uID);
      if (!user || !passwordMatches(user, current_password))
        throw new ValidationError('Current password is not correct');
      newPassword(new_password);
      if (new_password === current_password)
        throw new ValidationError('The new password must be different from the current one');
      const salt = crypto.randomBytes(16).toString('hex');
      userDao.setPassword(uID, hashPassword(new_password, salt), salt, false);
      return publicUser(userDao.findById(uID));
    },

    // Issues a reset token for the email. Returns { token, user } or null when the email is unknown:
    // the caller must answer in the same way in both cases.
    requestPasswordReset(email, now = Date.now()) {
      const user = typeof email === 'string' ? userDao.findByEmail(email.trim().toLowerCase()) : undefined;
      if (!user) return null;
      const token = crypto.randomBytes(32).toString('base64url');
      userDao.issueResetToken({
        tokenHash: hashToken(token), uID: user.uID, expiresAt: iso(now + RESET_TOKEN_TTL_MS), now: iso(now),
      });
      return { token, user: publicUser(user) };
    },

    // Sets a new password with a valid, unused, unexpired token. The token is accepted only once.
    resetPassword(token, password, now = Date.now()) {
      newPassword(password);
      if (typeof token !== 'string' || !token) throw new ValidationError('Invalid or expired reset link');
      userDao.atomic(() => {
        const uID = userDao.consumeResetToken(hashToken(token), iso(now));
        if (!uID) throw new ValidationError('Invalid or expired reset link');
        const salt = crypto.randomBytes(16).toString('hex');
        userDao.setPassword(uID, hashPassword(password, salt), salt, false);
      });
    },
  };
}
