import { createFileRoute } from '@tanstack/react-router';
import { canIndexRequest } from '../server/indexing';
export const Route = createFileRoute('/robots.txt')({
  server: {
    handlers: {
      GET: ({ request }) => {
        const origin = (
          process.env.SPROUT_SITE_ORIGIN ||
          process.env.VITE_SITE_ORIGIN ||
          ''
        ).replace(/\/$/, '');
        const indexable = canIndexRequest(request);
        return new Response(
          indexable
            ? `User-agent: *\nAllow: /\nDisallow: /api/\n${origin ? `Sitemap: ${origin}/sitemap.xml\n` : ''}`
            : 'User-agent: *\nDisallow: /\n',
          { headers: { 'Content-Type': 'text/plain; charset=utf-8' } }
        );
      },
    },
  },
});
