import { StoreLink } from './StoreLink';
export function Footer() {
  return (
    <footer data-aid="footer" className="bg-ink text-dtext">
      <div className="mx-auto max-w-page px-5 md:px-8 py-16">
        <div className="grid grid-cols-2 md:grid-cols-6 gap-10">
          <div className="col-span-2">
            <a href="/" className="flex items-center gap-2.5">
              <span
                className="inline-flex w-8 h-8 rounded-[10px] items-center justify-center"
                style={
                  {
                    background: 'linear-gradient(135deg,#8BDD9D,#6FCF8A)',
                  } as React.CSSProperties
                }
              >
                <svg
                  viewBox="0 0 256 256"
                  className="w-5 h-5"
                  fill="#101B16"
                  aria-hidden="true"
                >
                  <path d="M62 54c-3-3-8-1-9 3C40 104 46 152 80 178c30 23 70 22 98 0-12-14-28-26-48-32-13-4-22-10-29-20 10 7 23 12 38 13 24 2 42-4 54-12 2-1 3-4 2-6-6-22-20-38-42-46-26-9-56-2-91-21z" />
                  <path d="M146 150c22 12 36 26 44 38 2 3 0 7-3 8-4 1-7-1-9-4-8-13-20-25-36-34 1-3 2-5 4-8z" />
                </svg>
              </span>
              <span className="text-[19px] font-semibold tracking-[-0.02em] text-[#F0F6EF]">
                sprout
              </span>
            </a>
            <p className="mt-4 text-[14px] leading-6 max-w-[30ch]">
              A calm view of your money, on your phone. Made in New York.
            </p>
            <div className="mt-6 flex flex-wrap gap-2">
              <StoreLink
                href="/waitlist?platform=ios&amp;placement=footer"
                data-store-platform="ios"
                data-store-placement="footer"
                className="inline-flex items-center gap-2 h-10 px-3 rounded-xl border border-dline text-[13px] font-medium text-[#F0F6EF] hover:bg-dsurface"
              >
                <svg
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                >
                  <path d="M16.37 12.63c-.03-2.6 2.13-3.86 2.22-3.92-1.21-1.77-3.09-2.01-3.76-2.04-1.6-.16-3.12.94-3.93.94-.81 0-2.06-.92-3.39-.9-1.74.03-3.35 1.01-4.25 2.57-1.81 3.14-.46 7.79 1.3 10.34.86 1.25 1.89 2.65 3.24 2.6 1.3-.05 1.79-.84 3.36-.84 1.57 0 2.01.84 3.39.81 1.4-.02 2.29-1.27 3.14-2.52.99-1.45 1.4-2.85 1.42-2.92-.03-.01-2.72-1.04-2.74-4.12zM13.8 4.97c.72-.87 1.2-2.08 1.07-3.29-1.03.04-2.29.69-3.03 1.56-.66.77-1.25 2-1.09 3.18 1.15.09 2.33-.58 3.05-1.45z" />
                </svg>
                App Store
              </StoreLink>
              <StoreLink
                href="/waitlist?platform=android&amp;placement=footer"
                data-store-platform="android"
                data-store-placement="footer"
                className="inline-flex items-center gap-2 h-10 px-3 rounded-xl border border-dline text-[13px] font-medium text-[#F0F6EF] hover:bg-dsurface"
              >
                <svg
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                >
                  <path d="M3.6 2.4c-.3.3-.5.8-.5 1.4v16.4c0 .6.2 1.1.5 1.4L12.7 12 3.6 2.4zm12.2 12.7L12.7 12l-9.1 9.6c.4.4 1 .4 1.7 0l10.5-6.5zm0-6.2L5.3 2.4c-.7-.4-1.3-.4-1.7 0L12.7 12l3.1-3.1zm0 0L12.7 12l3.1 3.1 3.7-2.1c1-.6 1-1.5 0-2.1l-3.7-2z" />
                </svg>
                Google Play
              </StoreLink>
            </div>
          </div>
          <div>
            <p className="caps text-[#F0F6EF]">Product</p>
            <ul className="mt-4 space-y-3 text-[14px]">
              <li>
                <a href="/product/home" className="hover:text-[#F0F6EF]">
                  Home
                </a>
              </li>
              <li>
                <a href="/product/budget" className="hover:text-[#F0F6EF]">
                  Budget
                </a>
              </li>
              <li>
                <a href="/product/activity" className="hover:text-[#F0F6EF]">
                  Activity
                </a>
              </li>
              <li>
                <a href="/#subscriptions" className="hover:text-[#F0F6EF]">
                  Subscriptions
                </a>
              </li>
              <li>
                <a href="/#voice" className="hover:text-[#F0F6EF]">
                  Voice entry
                </a>
              </li>
            </ul>
          </div>
          <div>
            <p className="caps text-[#F0F6EF]">Company</p>
            <ul className="mt-4 space-y-3 text-[14px]">
              <li>
                <a href="/about" className="hover:text-[#F0F6EF]">
                  About
                </a>
              </li>
              <li>
                <a href="/blog" className="hover:text-[#F0F6EF]">
                  Blog
                </a>
              </li>
              <li>
                <a href="/careers" className="hover:text-[#F0F6EF]">
                  Careers
                </a>
              </li>
              <li>
                <a href="/press" className="hover:text-[#F0F6EF]">
                  Press
                </a>
              </li>
            </ul>
          </div>
          <div>
            <p className="caps text-[#F0F6EF]">Support</p>
            <ul className="mt-4 space-y-3 text-[14px]">
              <li>
                <a href="/help" className="hover:text-[#F0F6EF]">
                  Help centre
                </a>
              </li>
              <li>
                <a href="/help/in-app-support" className="hover:text-[#F0F6EF]">
                  Chat in app
                </a>
              </li>
              <li>
                <a href="/#security" className="hover:text-[#F0F6EF]">
                  Security
                </a>
              </li>
              <li>
                <a href="/status" className="hover:text-[#F0F6EF]">
                  Status
                </a>
              </li>
            </ul>
          </div>
          <div>
            <p className="caps text-[#F0F6EF]">Legal</p>
            <ul className="mt-4 space-y-3 text-[14px]">
              <li>
                <a href="/privacy" className="hover:text-[#F0F6EF]">
                  Privacy
                </a>
              </li>
              <li>
                <a href="/terms" className="hover:text-[#F0F6EF]">
                  Terms
                </a>
              </li>
              <li>
                <a href="/delete-data" className="hover:text-[#F0F6EF]">
                  Delete your data
                </a>
              </li>
              <li>
                <a href="/licenses" className="hover:text-[#F0F6EF]">
                  Licences
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div className="mt-14 pt-6 border-t border-dline flex flex-col md:flex-row gap-3 md:items-center justify-between text-[13px]">
          <p>© 2026 sprout. All rights reserved.</p>
          <p>Bank connections provided by Plaid. sprout is not a bank.</p>
        </div>
      </div>
    </footer>
  );
}
