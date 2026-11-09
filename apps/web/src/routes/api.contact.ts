import { createFileRoute } from '@tanstack/react-router';
import { createFormHandler } from '../server/forms';
export const Route = createFileRoute('/api/contact')({
  server: {
    handlers: {
      POST: ({ request }) => createFormHandler('contact')(request),
      ANY: ({ request }) => createFormHandler('contact')(request),
    },
  },
});
