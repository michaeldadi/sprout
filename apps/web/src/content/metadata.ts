export function publicOrigin() {
  return (import.meta.env.VITE_SITE_ORIGIN || '').replace(/\/$/, '');
}
export function pageHead(
  path: string,
  title: string,
  description: string,
  article = false
) {
  const origin = publicOrigin();
  const url = origin ? origin + path : undefined;
  return {
    meta: [
      { title: `${title} | sprout` },
      { name: 'description', content: description },
      { property: 'og:title', content: `${title} | sprout` },
      { property: 'og:description', content: description },
      { property: 'og:type', content: article ? 'article' : 'website' },
      { property: 'og:site_name', content: 'sprout' },
      {
        property: 'og:image',
        content: origin ? `${origin}/social.png` : '/social.png',
      },
      {
        property: 'og:image:alt',
        content: 'sprout — Money that finally explains itself.',
      },
      { name: 'twitter:card', content: 'summary_large_image' },
      ...(url ? [{ property: 'og:url', content: url }] : []),
      ...(import.meta.env.VITE_SITE_INDEXABLE === 'true'
        ? []
        : [{ name: 'robots', content: 'noindex, nofollow' }]),
    ],
    links: url ? [{ rel: 'canonical', href: url }] : [],
    scripts: [
      {
        type: 'application/ld+json',
        children: JSON.stringify(
          article
            ? {
                '@context': 'https://schema.org',
                '@type': 'Article',
                headline: title,
                description,
                ...(url ? { url } : {}),
                author: { '@type': 'Organization', name: 'Sprout' },
              }
            : {
                '@context': 'https://schema.org',
                '@type': 'WebPage',
                name: title,
                description,
                ...(url ? { url } : {}),
                isPartOf: {
                  '@type': 'WebSite',
                  name: 'Sprout',
                  ...(origin ? { url: origin } : {}),
                },
              }
        ).replaceAll('<', '\\u003c'),
      },
    ],
  };
}
