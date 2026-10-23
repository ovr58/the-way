/**
 * Jest — раннер тестов API (`npm test --workspace=api`).
 *
 * Запускается через `node --experimental-vm-modules …/jest.js`: NestJS 12 — ESM-пакет, а
 * песочница Jest грузит модули в своём vm-контексте, где `require(ESM)` включается только этим
 * флагом.
 *
 * `maxWorkers: 1` — все файлы одной строки делят одну базу `dev_<N>` из `DATABASE_URL`.
 */
import type { Config } from 'jest';

const config: Config = {
  rootDir: '.',
  roots: ['<rootDir>/src', '<rootDir>/test'],
  testEnvironment: 'node',
  testRegex: '.*\.(e2e-)?spec\.ts$',
  transform: {
    '^.+\.ts$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }],
  },
  maxWorkers: 1,
  testTimeout: 30_000,
};

export default config;
