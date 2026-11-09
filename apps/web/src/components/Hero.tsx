import { StoreLink } from './StoreLink';
import { PhoneIllustration } from './PhoneIllustration';
export function Hero() {
  return (
    <section
      data-aid="hero"
      className="hero-field relative overflow-hidden flex flex-col min-h-[760px] md:min-h-[860px] pt-36 md:pt-44"
    >
      <div className="relative z-10 mx-auto max-w-page px-5 text-center">
        <p
          className="hero-block caps text-action mb-6"
          style={{ animationDelay: '0ms' } as React.CSSProperties}
        >
          Personal finance · iOS &amp; Android
        </p>
        <h1
          data-aid="hero-title"
          className="serif text-[44px] md:text-[64px] lg:text-[72px] leading-[1.02] text-ink mx-auto max-w-[14ch]"
        >
          <span className="w" style={{ '--i': '0' } as React.CSSProperties}>
            Money
          </span>{' '}
          <span className="w" style={{ '--i': '1' } as React.CSSProperties}>
            that
          </span>{' '}
          <span className="w" style={{ '--i': '2' } as React.CSSProperties}>
            finally
          </span>
          <br />
          <em
            className="w text-action not-italic"
            style={{ '--i': '3', fontStyle: 'italic' } as React.CSSProperties}
          >
            explains
          </em>{' '}
          <em
            className="w text-action"
            style={{ '--i': '4', fontStyle: 'italic' } as React.CSSProperties}
          >
            itself.
          </em>
        </h1>
        <div className="hero-block">
          <p className="mt-6 text-[17px] md:text-[18px] leading-7 text-ink2 mx-auto max-w-[48ch]">
            Link your accounts once. sprout sorts every charge, spots the
            subscriptions you forgot, and tells you what's safe to spend.
          </p>
          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
            <StoreLink
              href="/waitlist?platform=ios&amp;placement=hero"
              data-store-platform="ios"
              data-store-placement="hero"
              className="store"
              aria-label="Download on the App Store"
            >
              <svg
                width="22"
                height="22"
                viewBox="0 0 24 24"
                fill="#fff"
                aria-hidden="true"
              >
                <path d="M16.37 12.63c-.03-2.6 2.13-3.86 2.22-3.92-1.21-1.77-3.09-2.01-3.76-2.04-1.6-.16-3.12.94-3.93.94-.81 0-2.06-.92-3.39-.9-1.74.03-3.35 1.01-4.25 2.57-1.81 3.14-.46 7.79 1.3 10.34.86 1.25 1.89 2.65 3.24 2.6 1.3-.05 1.79-.84 3.36-.84 1.57 0 2.01.84 3.39.81 1.4-.02 2.29-1.27 3.14-2.52.99-1.45 1.4-2.85 1.42-2.92-.03-.01-2.72-1.04-2.74-4.12zM13.8 4.97c.72-.87 1.2-2.08 1.07-3.29-1.03.04-2.29.69-3.03 1.56-.66.77-1.25 2-1.09 3.18 1.15.09 2.33-.58 3.05-1.45z" />
              </svg>
              <span>
                <small>Download on the</small>
                <b>App Store</b>
              </span>
            </StoreLink>
            <StoreLink
              href="/waitlist?platform=android&amp;placement=hero"
              data-store-platform="android"
              data-store-placement="hero"
              className="store"
              aria-label="Get it on Google Play"
            >
              <svg
                width="22"
                height="22"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  d="M3.6 2.4c-.3.3-.5.8-.5 1.4v16.4c0 .6.2 1.1.5 1.4L12.7 12 3.6 2.4z"
                  fill="#34A853"
                />
                <path
                  d="M15.8 15.1L12.7 12l-9.1 9.6c.4.4 1 .4 1.7 0l10.5-6.5z"
                  fill="#EA4335"
                />
                <path
                  d="M15.8 8.9L5.3 2.4c-.7-.4-1.3-.4-1.7 0L12.7 12l3.1-3.1z"
                  fill="#FBBC04"
                />
                <path
                  d="M15.8 8.9L12.7 12l3.1 3.1 3.7-2.1c1-.6 1-1.5 0-2.1l-3.7-2z"
                  fill="#4285F4"
                />
              </svg>
              <span>
                <small>Get it on</small>
                <b>Google Play</b>
              </span>
            </StoreLink>
          </div>
          <p className="mt-5 text-[13px] text-ink2">
            Free to download. Read-only bank connection via Plaid.
          </p>
        </div>
      </div>

      <PhoneIllustration />
    </section>
  );
}
