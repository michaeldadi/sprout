export function Steps() {
  return (
    <section data-aid="steps" className="bg-canvas py-20 md:py-32">
      <div className="mx-auto max-w-page px-5 md:px-8">
        <div className="reveal max-w-[60ch]">
          <p className="caps text-action">How it starts</p>
          <h2 className="serif text-[36px] md:text-[48px] leading-[1.05] mt-4">
            Ten minutes, <em className="text-action">then</em> it runs itself.
          </h2>
        </div>
        <div className="mt-12 md:mt-16 grid grid-cols-1 md:grid-cols-3 gap-10 md:gap-8">
          <div className="reveal border-t border-line pt-6">
            <p className="serif text-[56px] md:text-[64px] leading-none text-action">
              01
            </p>
            <h3 className="mt-6 text-[20px] font-semibold">Download</h3>
            <p className="mt-2 text-[16px] leading-6 text-ink2">
              Free on the App Store and Google Play. Sign in with email, Apple
              or Google.
            </p>
          </div>
          <div
            className="reveal border-t border-line pt-6"
            style={{ transitionDelay: '100ms' } as React.CSSProperties}
          >
            <p className="serif text-[56px] md:text-[64px] leading-none text-action">
              02
            </p>
            <h3 className="mt-6 text-[20px] font-semibold">
              Link your accounts
            </h3>
            <p className="mt-2 text-[16px] leading-6 text-ink2">
              Checking, savings and cards through Plaid. Read-only, and you can
              unlink any time.
            </p>
          </div>
          <div
            className="reveal border-t border-line pt-6"
            style={{ transitionDelay: '200ms' } as React.CSSProperties}
          >
            <p className="serif text-[56px] md:text-[64px] leading-none text-action">
              03
            </p>
            <h3 className="mt-6 text-[20px] font-semibold">
              Let sprout sort it
            </h3>
            <p className="mt-2 text-[16px] leading-6 text-ink2">
              Categories, budgets, subscriptions and a safe-to-spend number,
              kept current while you get on with your week.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
