export function Subscriptions() {
  return (
    <section
      id="subscriptions"
      data-aid="subscriptions"
      className="bg-canvas py-20 md:py-32"
    >
      <div className="mx-auto max-w-page px-5 md:px-8 grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
        <div className="lg:col-span-5 reveal">
          <p className="caps text-action">Recurring</p>
          <h2 className="serif text-[36px] md:text-[48px] leading-[1.05] mt-4">
            Every subscription, <em className="text-action">before</em> it
            renews.
          </h2>
          <p className="mt-5 text-[17px] leading-7 text-ink2 max-w-[44ch]">
            sprout finds the charges that repeat, lines them up by renewal date,
            and sends a note a few days before each one. Set a cancel reminder
            and it stays on your list until you deal with it.
          </p>
          <ul className="mt-8 space-y-3 text-[15px]">
            <li className="flex items-center gap-3">
              <span className="w-6 h-6 rounded-full bg-actionSubtle text-action flex items-center justify-center">
                <svg
                  width="13"
                  height="13"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M20 6 9 17l-5-5" />
                </svg>
              </span>
              Detects subscriptions automatically
            </li>
            <li className="flex items-center gap-3">
              <span className="w-6 h-6 rounded-full bg-actionSubtle text-action flex items-center justify-center">
                <svg
                  width="13"
                  height="13"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M20 6 9 17l-5-5" />
                </svg>
              </span>
              Notification 3 days before each renewal
            </li>
            <li className="flex items-center gap-3">
              <span className="w-6 h-6 rounded-full bg-actionSubtle text-action flex items-center justify-center">
                <svg
                  width="13"
                  height="13"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M20 6 9 17l-5-5" />
                </svg>
              </span>
              One monthly total you can actually read
            </li>
          </ul>
        </div>
        <div
          className="lg:col-span-7 reveal"
          style={{ transitionDelay: '120ms' } as React.CSSProperties}
        >
          <div className="bg-white border border-line rounded-3xl p-5 md:p-8">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-[18px] font-semibold">Upcoming renewals</p>
                <p className="text-[14px] text-ink2 mt-0.5">November 2026</p>
              </div>
              <span className="caps text-ink2 hidden sm:inline">
                5 recurring
              </span>
            </div>
            <ul className="mt-6 divide-y divide-line">
              <li className="flex items-center gap-4 py-4">
                <span className="w-10 h-10 rounded-xl bg-subtle text-ink2 flex items-center justify-center text-[14px] font-semibold">
                  N
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block text-[16px] font-medium">Netflix</span>
                  <span className="block text-[14px] text-ink2">
                    Renews Nov 14 · Monthly
                  </span>
                </span>
                <span className="text-[17px] font-semibold tnum text-right">
                  $15.49
                </span>
              </li>
              <li className="flex items-center gap-4 py-4">
                <span className="w-10 h-10 rounded-xl bg-subtle text-ink2 flex items-center justify-center text-[14px] font-semibold">
                  A
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block text-[16px] font-medium">
                    Adobe Creative Cloud
                  </span>
                  <span className="block text-[14px] text-ink2">
                    Renews Nov 21 · Monthly
                  </span>
                </span>
                <span className="text-[17px] font-semibold tnum text-right">
                  $59.99
                </span>
              </li>
              <li className="flex items-center gap-4 py-4">
                <span className="w-10 h-10 rounded-xl bg-subtle text-ink2 flex items-center justify-center text-[14px] font-semibold">
                  i
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block text-[16px] font-medium">iCloud+</span>
                  <span className="block text-[14px] text-ink2">
                    Renews Nov 12 · Monthly
                  </span>
                </span>
                <span className="text-[17px] font-semibold tnum text-right">
                  $2.99
                </span>
              </li>
              <li className="flex items-center gap-4 py-4">
                <span className="w-10 h-10 rounded-xl bg-subtle text-ink2 flex items-center justify-center text-[14px] font-semibold">
                  P
                </span>
                <span className="flex-1 min-w-0">
                  <span className="flex items-center gap-2 flex-wrap">
                    <span className="text-[16px] font-medium">Paramount+</span>
                    <span className="inline-flex items-center gap-1 h-6 px-2 rounded-full bg-actionSubtle text-action text-[12px] font-medium">
                      <svg
                        width="11"
                        height="11"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
                        <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
                      </svg>
                      Reminder set
                    </span>
                  </span>
                  <span className="block text-[14px] text-ink2">
                    Renews Nov 18 · Monthly
                  </span>
                </span>
                <span className="text-[17px] font-semibold tnum text-right">
                  $11.99
                </span>
              </li>
              <li className="flex items-center gap-4 py-4">
                <span className="w-10 h-10 rounded-xl bg-subtle text-ink2 flex items-center justify-center text-[14px] font-semibold">
                  T
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block text-[16px] font-medium">
                    The New York Times
                  </span>
                  <span className="block text-[14px] text-ink2">
                    Renews Nov 30 · Monthly
                  </span>
                </span>
                <span className="text-[17px] font-semibold tnum text-right">
                  $17.00
                </span>
              </li>
            </ul>
            <div className="mt-2 pt-5 border-t border-line flex items-center justify-between">
              <span className="text-[15px] text-ink2">
                Monthly total, 9 subscriptions
              </span>
              <span className="text-[22px] font-semibold tnum">
                $214.46
                <span className="text-[14px] text-ink2 font-medium">/mo</span>
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
