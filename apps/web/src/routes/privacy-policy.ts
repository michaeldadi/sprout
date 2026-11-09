import { createFileRoute } from '@tanstack/react-router';
export const Route = createFileRoute('/privacy-policy')({
  server: {
    handlers: {
      GET: ({ request }) =>
        Response.redirect(new URL('/privacy', request.url), 301),
    },
  },
});
