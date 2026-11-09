import { useState } from 'react';
import { articles, helpEntries } from '../content/pages';
import type { Page } from '../content/pages';
import { ContactForm, WaitlistForm } from './Forms';
import type { Category } from './Forms';
import type { Platform } from './StoreLink';
import { PhoneIllustration } from './PhoneIllustration';
export function ContentPage({
  page,
  platform = 'both',
  category,
}: {
  page: Page;
  platform?: Platform;
  category?: Category;
}) {
  return (
    <main id="main-content">
      <header className="page-intro">
        <p className="caps text-action">{page.eyebrow}</p>
        <h1 className="serif">{page.title}</h1>
        <p>{page.description}</p>
      </header>
      <div className="editorial-body">
        <div>
          {page.kind && ['home', 'budget', 'activity'].includes(page.kind) && (
            <ProductVisual kind={page.kind} />
          )}
          {page.kind === 'blog' &&
            Object.entries(articles).map(([path, article]) => (
              <a href={path} className="blog-entry" key={path}>
                <span className="caps text-action">{article.eyebrow}</span>
                <h2>{article.title}</h2>
                <p>{article.description}</p>
                <span className="text-link block mt-5">Read the article →</span>
              </a>
            ))}
          {page.kind === 'help' && <HelpSearch />}
          {page.sections.map((section) => (
            <section className="prose-section" key={section.title}>
              <h2>{section.title}</h2>
              {section.paragraphs.map((p) => (
                <p key={p}>{p}</p>
              ))}
              {section.list && (
                <ul>
                  {section.list.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              )}
              {section.title === 'Brand assets' && (
                <div className="download-list">
                  <a href="/brand/sprout-mark.svg" download>
                    Download leaf mark
                  </a>
                  <a href="/brand/sprout-app-icon.svg" download>
                    Download app icon
                  </a>
                </div>
              )}
            </section>
          ))}
          {page.title === 'Built with good foundations.' && (
            <div className="download-list">
              <a href="/licenses/font-licenses.txt">Font licenses</a>
              <a href="/licenses/software-notices.txt">Software notices</a>
            </div>
          )}
          {page.kind === 'waitlist' && (
            <WaitlistForm initialPlatform={platform} />
          )}
          {page.form && (
            <section className="prose-section" aria-label="Send an inquiry">
              <h2>
                {page.form === 'deletion' ? 'Request deletion' : 'Get in touch'}
              </h2>
              <ContactForm category={category || page.form} />
            </section>
          )}
        </div>
        <aside className="editorial-aside">
          <p className="caps text-action">A clear next step</p>
          <p>
            Bring your everyday money into focus. Join the list for Sprout on
            iPhone and Android.
          </p>
          <a href="/waitlist" className="btn-primary">
            Join the waitlist <span aria-hidden="true">↗</span>
          </a>
          <p>
            <a href="/help" className="text-link">
              Explore the help centre
            </a>
          </p>
        </aside>
      </div>
    </main>
  );
}
function HelpSearch() {
  const [query, setQuery] = useState('');
  const entries = helpEntries.filter((entry) =>
    `${entry.title} ${entry.body}`.toLowerCase().includes(query.toLowerCase())
  );
  return (
    <section aria-label="Help articles">
      <label htmlFor="help-search" className="caps text-action">
        Search help
      </label>
      <input
        id="help-search"
        className="help-search"
        type="search"
        placeholder="Try subscriptions, account, or privacy"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      <p className="form-helper" role="status">
        {entries.length} {entries.length === 1 ? 'answer' : 'answers'}
      </p>
      {entries.map((entry) => (
        <details className="help-entry" key={entry.title}>
          <summary>{entry.title}</summary>
          <p>{entry.body}</p>
        </details>
      ))}
      {entries.length === 0 && (
        <p className="mt-6 text-ink2">
          Try another word, or{' '}
          <a href="/contact" className="text-link">
            send us your question
          </a>
          .
        </p>
      )}
    </section>
  );
}
function ProductVisual({ kind }: { kind: string }) {
  if (kind === 'home')
    return (
      <div className="product-visual">
        <PhoneIllustration />
      </div>
    );
  if (kind === 'budget')
    return (
      <div className="product-visual">
        <p className="caps text-action">November budget</p>
        <p className="money tnum">A plan for your month.</p>
        {[
          { name: 'Food', used: 412, total: 600 },
          { name: 'Bills', used: 318, total: 450 },
          { name: 'Shopping', used: 96, total: 250 },
        ].map((row) => (
          <div className="py-4" key={row.name}>
            <div className="flex justify-between gap-4 mb-3">
              <span>{row.name}</span>
              <span className="tnum">
                ${row.used} / ${row.total}
              </span>
            </div>
            <div className="bar bg-white">
              <i style={{ width: `${(row.used / row.total) * 100}%` }} />
            </div>
          </div>
        ))}
      </div>
    );
  return (
    <div className="product-visual">
      <h3>Latest activity</h3>
      {[
        { name: 'Trader Joe’s', detail: 'Food · Today', amount: '−$62.18' },
        {
          name: 'Spotify',
          detail: 'Entertainment · Recurring',
          amount: '−$10.99',
        },
        { name: 'Con Edison', detail: 'Bills · Nov 6', amount: '−$118.40' },
      ].map((row) => (
        <div className="illustration-row" key={row.name}>
          <span>
            <span className="block font-medium">{row.name}</span>
            <span className="block text-sm text-ink2 mt-1">{row.detail}</span>
          </span>
          <strong className="tnum">{row.amount}</strong>
        </div>
      ))}
    </div>
  );
}
export function ErrorPage({ error = false }: { error?: boolean }) {
  return (
    <main id="main-content" className="error-page">
      <p className="caps text-action">
        {error ? 'A moment to reconnect' : '404 · A small detour'}
      </p>
      <h1 className="serif mt-6">
        {error ? 'Let’s try that again.' : 'Find your way back.'}
      </h1>
      <p>
        {error
          ? 'Something interrupted this page. Return home and try once more.'
          : 'The page you’re looking for isn’t here. A clear picture is just a click away.'}
      </p>
      <a className="btn-primary" href="/">
        Back to Sprout
      </a>
    </main>
  );
}
