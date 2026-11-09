export function Voice() {
  return (
    <section id="voice" data-aid="voice" className="bg-subtle py-20 md:py-28">
      <div className="mx-auto max-w-page px-5 md:px-8 grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-16 items-center">
        <div className="lg:col-span-7 reveal">
          <p className="caps text-action">Voice entry</p>
          <blockquote
            className="serif mt-5 text-[28px] md:text-[32px] lg:text-[36px] leading-[1.25] text-ink"
            style={{ fontStyle: 'italic' } as React.CSSProperties}
          >
            “Hey Siri, add a $14 lunch to sprout.”
          </blockquote>
          <p className="mt-5 text-[17px] leading-7 text-ink2 max-w-[48ch]">
            Cash and split bills never show up in a bank feed. Say them out loud
            and they land in Activity, categorised, before you've put your phone
            away.
          </p>
        </div>
        <div
          className="lg:col-span-5 reveal"
          style={{ transitionDelay: '120ms' } as React.CSSProperties}
        >
          <div className="bg-white border border-line rounded-2xl divide-y divide-line">
            <div className="flex items-center gap-4 p-5">
              <span className="w-11 h-11 rounded-xl bg-subtle flex items-center justify-center text-ink">
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                  <path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v3" />
                </svg>
              </span>
              <span className="flex-1">
                <span className="block text-[16px] font-medium">
                  Siri Shortcuts
                </span>
                <span className="block text-[14px] text-ink2">
                  iPhone, Apple Watch, CarPlay
                </span>
              </span>
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
            </div>
            <div className="flex items-center gap-4 p-5">
              <span className="w-11 h-11 rounded-xl bg-subtle flex items-center justify-center text-ink">
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                  <path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v3" />
                </svg>
              </span>
              <span className="flex-1">
                <span className="block text-[16px] font-medium">
                  Google Assistant
                </span>
                <span className="block text-[14px] text-ink2">
                  Android phones, Wear OS
                </span>
              </span>
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
            </div>
            <div className="p-5 flex items-center gap-3 text-[14px] text-ink2">
              <span className="caps text-action">Added</span>
              <span className="flex-1 text-ink font-medium">Lunch · Food</span>
              <span className="font-semibold tnum text-ink">−$14.00</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
