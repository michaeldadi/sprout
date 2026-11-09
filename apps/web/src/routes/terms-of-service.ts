import { createFileRoute } from '@tanstack/react-router';
export const Route = createFileRoute('/terms-of-service')({
  server: {
    handlers: {
      GET: ({ request }) =>
        Response.redirect(new URL('/terms', request.url), 301),
    },
  },
});
