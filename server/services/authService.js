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
// email shape check: something@something.something, no spaces
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// derives the password hash (hex) from the password and the salt (hex)
const hashPassword = (password, salt) =>
  // scrypt is a deliberately slow, memory-hard hash; the salt is decoded from hex into bytes first
  crypto.scryptSync(password, Buffer.from(salt, 'hex'), KEY_LENGTH).toString('hex');

// fixed random salt generated once at startup, used when no real salt is available
const DUMMY_SALT = crypto.randomBytes(16).toString('hex');

// strips password and salt so they never leave the service
const publicUser = ({ uID, name, email, phone, role }) => ({ uID, name, email, phone, role });

// builds the auth service on top of a user DAO
export function createAuthService(userDao) {
  return {
    // REGISTRATION: always creates a 'hiker' (employees are not self-registerable).
    register({ name, email, phone, password }) {
      // trim the name -> stays undefined if it was not provided
      name = name?.trim();
      // trim and lowercase the email -> the same address is always stored the same way
      email = email?.trim().toLowerCase();
      // trim the phone -> an empty or missing phone becomes NULL
      phone = phone?.trim() || null;

      // name is mandatory
      if (!name) throw new ValidationError('Name is required');
      // email must be present and "look like an email"
      if (!email || !EMAIL_RE.test(email)) throw new ValidationError('A valid email is required');
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
          name, email, phone, role: 'hiker', password: hashPassword(password, salt), salt,
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
      // true only if the user exists and has both a password hash and a salt
      const hasPassword = user?.password && user?.salt;
      // hash the submitted password even for unknown users (with the dummy salt) to keep timing similar
      const candidate = hashPassword(String(password ?? ''), hasPassword ? user.salt : DUMMY_SALT);

      // reject: there is no usable password, or if the hashes differ (timingSafeEqual avoids timing leaks)
      if (!hasPassword || !crypto.timingSafeEqual(Buffer.from(candidate, 'hex'), Buffer.from(user.password, 'hex')))
        // same message for every failure case
        throw new AuthenticationError('Invalid email or password');
      // success: return the user without password and salt
      return publicUser(user);
    },
  };
}
