import { createFileRoute } from '@tanstack/react-router';
export const Route = createFileRoute('/robots.txt')({
  server: {
    handlers: {
      GET: () => {
        const origin = (
          process.env.SPROUT_SITE_ORIGIN ||
          process.env.VITE_SITE_ORIGIN ||
          ''
        ).replace(/\/$/, '');
        const indexable = process.env.VITE_SITE_INDEXABLE === 'true';
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
