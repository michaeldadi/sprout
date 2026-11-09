import { defineConfig, devices } from '@playwright/test';
const hostedOrigin = process.env.SPROUT_TEST_ORIGIN;
export default defineConfig({
  testDir: './tests/browser',
  timeout: 60000,
  fullyParallel: true,
  workers: 3,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: hostedOrigin || 'http://127.0.0.1:3000',
    trace: 'retain-on-failure',
  },
  webServer: hostedOrigin
    ? undefined
    : {
        command: 'yarn start',
        url: 'http://127.0.0.1:3000',
        reuseExistingServer: !process.env.CI,
        timeout: 60000,
      },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
});
