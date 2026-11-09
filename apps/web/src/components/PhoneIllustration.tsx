export function PhoneIllustration() {
  return (
    <div
      data-aid="phone"
      className="relative z-10 mx-auto mt-auto pt-12 md:pt-16 w-[300px] md:w-[320px] h-[378px] md:h-[424px] overflow-hidden"
    >
      <div className="hero-phone phone">
        <div className="screen text-ink">
          <div className="flex items-center justify-between px-6 pt-4 text-[12px] font-semibold tnum">
            <span>9:41</span>
            <span className="absolute left-1/2 -translate-x-1/2 top-3 w-[88px] h-[26px] bg-black rounded-full"></span>
            <span className="flex items-center gap-1.5">
              <svg width="16" height="11" viewBox="0 0 16 11" fill="#16271D">
                <rect x="0" y="7" width="3" height="4" rx=".6" />
                <rect x="4.3" y="5" width="3" height="6" rx=".6" />
                <rect x="8.6" y="2.5" width="3" height="8.5" rx=".6" />
                <rect x="13" y="0" width="3" height="11" rx=".6" />
              </svg>
              <svg width="24" height="11" viewBox="0 0 24 11" fill="none">
                <rect
                  x=".5"
                  y=".5"
                  width="20"
                  height="10"
                  rx="2.5"
                  stroke="#16271D"
                  opacity=".4"
                />
                <rect
                  x="2"
                  y="2"
                  width="16"
                  height="7"
                  rx="1.5"
                  fill="#16271D"
                />
                <path
                  d="M22 4v3"
                  stroke="#16271D"
                  strokeWidth="1.4"
                  opacity=".4"
                />
              </svg>
            </span>
          </div>
          <div className="px-5 pt-7">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-[13px] text-ink2">Good morning, Maya</p>
                <p className="text-[26px] font-semibold tracking-[-0.02em] leading-8 mt-0.5">
                  Home
                </p>
              </div>
              <span className="w-9 h-9 rounded-full bg-actionSubtle flex items-center justify-center text-[12px] font-semibold text-action">
                M
              </span>
            </div>
            <div className="mt-5 bg-white border border-line rounded-2xl p-4">
              <p className="text-[12px] font-medium text-ink2">Total balance</p>
              <p className="text-[36px] font-semibold tnum tracking-[-0.02em] leading-10 mt-1">
                $4,812.40
              </p>
              <div className="mt-3 flex items-center gap-2 text-[13px]">
                <span className="w-1.5 h-1.5 rounded-full bg-success"></span>
                <span className="text-ink2">Safe to spend · Nov</span>
                <span className="ml-auto font-semibold tnum text-success">
                  $1,260
                </span>
              </div>
            </div>
            <div className="mt-4 bg-white border border-line rounded-2xl p-4">
              <div className="flex items-center justify-between">
                <p className="text-[14px] font-semibold">November budget</p>
                <span className="text-[12px] text-ink2 tnum">21 days left</span>
              </div>
              <div className="mt-3 space-y-3 text-[12px]">
                <div>
                  <div className="flex justify-between mb-1.5">
                    <span className="font-medium">Food</span>
                    <span className="tnum text-ink2">$412 / $600</span>
                  </div>
                  <div className="bar">
                    <i style={{ width: '69%' } as React.CSSProperties}></i>
                  </div>
                </div>
                <div>
                  <div className="flex justify-between mb-1.5">
                    <span className="font-medium">Bills</span>
                    <span className="tnum text-ink2">$318 / $450</span>
                  </div>
                  <div className="bar">
                    <i style={{ width: '71%' } as React.CSSProperties}></i>
                  </div>
                </div>
                <div>
                  <div className="flex justify-between mb-1.5">
                    <span className="font-medium">Shopping</span>
                    <span className="tnum text-ink2">$96 / $250</span>
                  </div>
                  <div className="bar">
                    <i style={{ width: '38%' } as React.CSSProperties}></i>
                  </div>
                </div>
              </div>
            </div>
            <div className="mt-5 flex items-center justify-between">
              <p className="text-[14px] font-semibold">Latest activity</p>
              <span className="text-[12px] font-medium text-action">
                View all
              </span>
            </div>
            <ul className="mt-2 divide-y divide-line text-[13px]">
              <li className="flex items-center gap-3 py-3">
                <span className="w-9 h-9 rounded-xl bg-actionSubtle flex items-center justify-center text-action">
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <circle cx="8" cy="21" r="1" />
                    <circle cx="19" cy="21" r="1" />
                    <path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12" />
                  </svg>
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block font-medium truncate">
                    Trader Joe's
                  </span>
                  <span className="block text-[12px] text-ink2">
                    Food · Today
                  </span>
                </span>
                <span className="font-semibold tnum">−$62.18</span>
              </li>
              <li className="flex items-center gap-3 py-3">
                <span className="w-9 h-9 rounded-xl bg-actionSubtle flex items-center justify-center text-action">
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <circle cx="12" cy="12" r="10" />
                    <path d="M8 14.5c2.5-1 5.5-1 8 .5M7.5 11c3-1.2 7-1.2 10 .6M7 8c3.5-1.5 8-1.5 11.5.8" />
                  </svg>
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block font-medium truncate">Spotify</span>
                  <span className="block text-[12px] text-ink2">
                    Entertainment · Recurring
                  </span>
                </span>
                <span className="font-semibold tnum">−$10.99</span>
              </li>
              <li className="flex items-center gap-3 py-3">
                <span className="w-9 h-9 rounded-xl bg-actionSubtle flex items-center justify-center text-action">
                  <svg
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z" />
                  </svg>
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block font-medium truncate">Con Edison</span>
                  <span className="block text-[12px] text-ink2">
                    Bills · Nov 6
                  </span>
                </span>
                <span className="font-semibold tnum">−$118.40</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
