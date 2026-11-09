export function Security() {
  return (
    <section
      id="security"
      data-aid="security"
      className="bg-canvas border-b border-line"
    >
      <div className="mx-auto max-w-page px-5 md:px-8 py-14 md:py-16 reveal">
        <div className="grid grid-cols-1 md:grid-cols-4 md:divide-x divide-y md:divide-y-0 divide-line">
          <div className="py-5 md:py-0 md:px-8 first:pl-0">
            <div className="flex items-center gap-2 text-action">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <rect x="3" y="11" width="18" height="11" rx="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
              <span className="caps">Encrypted</span>
            </div>
            <p className="mt-3 text-[15px] leading-6 text-ink2">
              Bank-grade encryption in transit and at rest.
            </p>
          </div>
          <div className="py-5 md:py-0 md:px-8">
            <div className="flex items-center gap-2 text-action">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z" />
                <circle cx="12" cy="12" r="3" />
              </svg>
              <span className="caps">Read-only</span>
            </div>
            <p className="mt-3 text-[15px] leading-6 text-ink2">
              Connected through Plaid. sprout can see, never move, your money.
            </p>
          </div>
          <div className="py-5 md:py-0 md:px-8">
            <div className="flex items-center gap-2 text-action">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2" />
                <path d="M9 9h.01M15 9h.01M9.5 15a3.5 3.5 0 0 0 5 0" />
              </svg>
              <span className="caps">Face ID</span>
            </div>
            <p className="mt-3 text-[15px] leading-6 text-ink2">
              Biometric lock on every open, on iPhone and Android.
            </p>
          </div>
          <div className="py-5 md:py-0 md:px-8 last:pr-0">
            <div className="flex items-center gap-2 text-action">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v6M14 11v6" />
              </svg>
              <span className="caps">Yours</span>
            </div>
            <p className="mt-3 text-[15px] leading-6 text-ink2">
              Delete your data any time from Profile. It's gone within 24 hours.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
