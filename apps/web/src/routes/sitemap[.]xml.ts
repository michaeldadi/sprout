import { createFileRoute } from '@tanstack/react-router';
import { pages } from '../content/pages';
export const Route = createFileRoute('/sitemap.xml')({
  server: {
    handlers: {
      GET: () => {
        const origin = (
          process.env.SPROUT_SITE_ORIGIN ||
          process.env.VITE_SITE_ORIGIN ||
          ''
        ).replace(/\/$/, '');
        if (!origin) return new Response(null, { status: 503 });
        return new Response(
          `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${['/', ...Object.keys(pages)].map((path) => `<url><loc>${origin}${path}</loc></url>`).join('')}</urlset>`,
          { headers: { 'Content-Type': 'application/xml; charset=utf-8' } }
        );
      },
    },
  },
});
