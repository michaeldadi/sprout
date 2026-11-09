import { StoreLink } from './StoreLink';
export function FinalCta() {
  return (
    <section
      id="cta"
      data-aid="cta"
      className="hero-field border-t border-line py-24 md:py-36"
    >
      <div className="mx-auto max-w-page px-5 text-center reveal">
        <span
          className="inline-flex w-14 h-14 rounded-2xl items-center justify-center"
          style={
            {
              background: 'linear-gradient(135deg,#8BDD9D,#6FCF8A)',
            } as React.CSSProperties
          }
        >
          <svg
            viewBox="0 0 256 256"
            className="w-8 h-8"
            fill="#fff"
            aria-hidden="true"
          >
            <path d="M62 54c-3-3-8-1-9 3C40 104 46 152 80 178c30 23 70 22 98 0-12-14-28-26-48-32-13-4-22-10-29-20 10 7 23 12 38 13 24 2 42-4 54-12 2-1 3-4 2-6-6-22-20-38-42-46-26-9-56-2-91-21z" />
            <path d="M146 150c22 12 36 26 44 38 2 3 0 7-3 8-4 1-7-1-9-4-8-13-20-25-36-34 1-3 2-5 4-8z" />
          </svg>
        </span>
        <h2 className="serif text-[40px] md:text-[64px] leading-[1.02] mt-8 mx-auto max-w-[16ch]">
          Start with a <em className="text-action">clear</em> picture.
        </h2>
        <p className="mt-5 text-[17px] md:text-[18px] leading-7 text-ink2 mx-auto max-w-[44ch]">
          Free to download. Light and dark mode. Works on iPhone and Android.
        </p>
        <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
          <StoreLink
            href="/waitlist?platform=ios&amp;placement=final-cta"
            data-store-platform="ios"
            data-store-placement="final-cta"
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
            href="/waitlist?platform=android&amp;placement=final-cta"
            data-store-platform="android"
            data-store-placement="final-cta"
            className="store"
            aria-label="Get it on Google Play"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true">
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
      </div>
    </section>
  );
}
