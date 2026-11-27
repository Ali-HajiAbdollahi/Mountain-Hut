// authService.register — email validation unit tests (no database, fake DAO)
import { describe, it, expect, vi } from 'vitest';
import { createAuthService } from '../../services/authService.js';
import { ValidationError } from '../../errors.js';

function setup() {
  const userDao = {
    insert: vi.fn(() => 1),
    findById: vi.fn(() => ({ uID: 1, name: 'Sara', email: 'x', role: 'hiker', must_change_password: 0 })),
  };
  const auth = createAuthService(userDao);
  const register = email => auth.register({ name: 'Sara', email, password: 'password1' });
  return { userDao, register };
}

describe('authService.register email validation', () => {
  it.each([
    'sara@mail.it',
    'sara.verdi+hut@mail.it',
    'sara@mail.example.co.uk',
    'a@b.c',
  ])('accepts %s', email => {
    const { userDao, register } = setup();
    expect(() => register(email)).not.toThrow();
    expect(userDao.insert).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['missing domain', 'sara@'],
    ['missing local part', '@mail.it'],
    ['missing at sign', 'sara.mail.it'],
    ['no dot in the domain', 'sara@mail'],
    ['two at signs', 'sara@@mail.it'],
    ['space inside', 'sara verdi@mail.it'],
    ['trailing dot', 'sara@mail.it.'],
    ['leading dot in the domain', 'sara@.mail.it'],
    ['consecutive dots', 'sara@mail..it'],
    ['empty', ''],
  ])('rejects %s', (_label, email) => {
    const { userDao, register } = setup();
    expect(() => register(email)).toThrow(ValidationError);
    expect(userDao.insert).not.toHaveBeenCalled();
  });

  it('rejects an email longer than 254 characters', () => {
    const { userDao, register } = setup();
    const long = `${'a'.repeat(250)}@mail.it`;
    expect(() => register(long)).toThrow(ValidationError);
    expect(userDao.insert).not.toHaveBeenCalled();
  });

  it('accepts an email of exactly 254 characters', () => {
    const { register } = setup();
    const email = `${'a'.repeat(254 - '@mail.it'.length)}@mail.it`;
    expect(email).toHaveLength(254);
    expect(() => register(email)).not.toThrow();
  });

  it('rejects very long malicious input quickly (no catastrophic backtracking)', () => {
    const { register } = setup();
    const attacks = [
      `a@${'b.'.repeat(500_000)}`,
      `a@${'b'.repeat(1_000_000)}`,
      `a@${'.'.repeat(1_000_000)}`,
    ];
    const start = performance.now();
    for (const attack of attacks) expect(() => register(attack)).toThrow(ValidationError);
    expect(performance.now() - start).toBeLessThan(1000);
  });
});
