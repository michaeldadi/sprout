import {
  createRootRoute,
  HeadContent,
  Outlet,
  Scripts,
} from '@tanstack/react-router';
import { SiteShell } from '../components/SiteShell';
import appCss from '../styles.css?url';
import { ErrorPage } from '../components/Pages';
export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { name: 'theme-color', content: '#F6F8F4' },
    ],
    links: [
      { rel: 'stylesheet', href: appCss },
      {
        rel: 'icon',
        type: 'image/svg+xml',
        href: '/brand/sprout-app-icon.svg',
      },
      {
        rel: 'preload',
        as: 'font',
        href: '/fonts/inter-latin-wght-normal.woff2',
        type: 'font/woff2',
        crossOrigin: 'anonymous',
      },
      {
        rel: 'preload',
        as: 'font',
        href: '/fonts/fraunces-latin-full-normal.woff2',
        type: 'font/woff2',
        crossOrigin: 'anonymous',
      },
    ],
  }),
  component: () => (
    <SiteShell>
      <Outlet />
    </SiteShell>
  ),
  notFoundComponent: () => <ErrorPage />,
  errorComponent: () => <ErrorPage error />,
  shellComponent: Document,
});
function Document({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}
