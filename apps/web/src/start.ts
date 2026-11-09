import { createMiddleware, createStart } from '@tanstack/react-start';
import { setResponseHeader } from '@tanstack/react-start/server';
import { canIndexRequest } from './server/indexing';

const crawlerPolicy = createMiddleware().server(async ({ request, next }) => {
  if (!canIndexRequest(request)) {
    setResponseHeader('X-Robots-Tag', 'noindex, nofollow');
  }
  return next();
});

export const startInstance = createStart(() => ({
  requestMiddleware: [crawlerPolicy],
}));
