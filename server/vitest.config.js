import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.js'],
    environment: 'node',
    // createApp refuses to start without a long enough secret
    env: { SESSION_SECRET: 'test-secret-that-is-at-least-32-characters-long' },
  },
});
