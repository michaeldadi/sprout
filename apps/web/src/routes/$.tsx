import { createFileRoute, notFound, redirect } from '@tanstack/react-router';
import { pages } from '../content/pages';
import { pageHead } from '../content/metadata';
import { ContentPage } from '../components/Pages';
import { categories } from '../components/Forms';
export const Route = createFileRoute('/$')({
  validateSearch: (search: Record<string, unknown>) => ({
    platform:
      search.platform === 'ios' || search.platform === 'android'
        ? search.platform
        : 'both',
    category: categories.find((c) => c === search.category),
  }),
  beforeLoad: ({ params }) => {
    const path = '/' + params._splat;
    if (path === '/privacy-policy')
      throw redirect({ href: '/privacy', statusCode: 301 });
    if (path === '/terms-of-service')
      throw redirect({ href: '/terms', statusCode: 301 });
    if (!pages[path]) throw notFound();
  },
  loader: ({ params }) => ({
    page: pages['/' + params._splat],
    path: '/' + params._splat,
  }),
  head: ({ loaderData }) =>
    loaderData
      ? pageHead(
          loaderData.path,
          loaderData.page.title,
          loaderData.page.description,
          loaderData.page.article
        )
      : pageHead('/404', 'Page not found', 'Find your way back to Sprout.'),
  component: PageRoute,
});
function PageRoute() {
  const { page } = Route.useLoaderData();
  const search = Route.useSearch();
  return (
    <ContentPage
      key={page.title}
      page={page}
      platform={search.platform as 'ios' | 'android' | 'both'}
      category={search.category}
    />
  );
}
