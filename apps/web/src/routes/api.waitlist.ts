import { createFileRoute } from '@tanstack/react-router';
import { createFormHandler } from '../server/forms';
export const Route = createFileRoute('/api/waitlist')({
  server: {
    handlers: {
      POST: ({ request }) => createFormHandler('waitlist')(request),
      ANY: ({ request }) => createFormHandler('waitlist')(request),
    },
  },
});
