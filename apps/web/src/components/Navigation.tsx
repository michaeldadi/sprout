import { useEffect, useRef, useState } from 'react';
export function Navigation() {
  const [open, setOpen] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const headerRef = useRef<HTMLElement>(null);
  useEffect(() => {
    if (!open) return;
    const close = (event: Event) => {
      const target = event.target as Element;
      if (event instanceof KeyboardEvent && event.key === 'Escape') {
        setOpen(false);
        buttonRef.current?.focus();
      } else if (
        event.type === 'pointerdown' &&
        !headerRef.current?.contains(target)
      ) {
        setOpen(false);
      } else if (event.type === 'click' && target.closest('a')) {
        setOpen(false);
      }
    };
    document.addEventListener('keydown', close);
    document.addEventListener('pointerdown', close);
    document.addEventListener('click', close);
    return () => {
      document.removeEventListener('keydown', close);
      document.removeEventListener('pointerdown', close);
      document.removeEventListener('click', close);
    };
  }, [open]);
  return (
    <header
      ref={headerRef}
      data-aid="nav"
      className="fixed top-6 left-0 right-0 z-50 px-4 md:px-8"
    >
      <div
        className="nav-in mx-auto max-w-page flex items-center justify-between h-14 px-3 md:px-4 rounded-2xl border border-line"
        style={
          {
            background: 'rgba(246,248,244,0.7)',
            backdropFilter: 'blur(12px)',
            WebkitBackdropFilter: 'blur(12px)',
          } as React.CSSProperties
        }
      >
        <a
          href="/"
          className="flex items-center gap-2.5"
          aria-label="sprout home"
        >
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
              fill="#fff"
              aria-hidden="true"
            >
              <path d="M62 54c-3-3-8-1-9 3C40 104 46 152 80 178c30 23 70 22 98 0-12-14-28-26-48-32-13-4-22-10-29-20 10 7 23 12 38 13 24 2 42-4 54-12 2-1 3-4 2-6-6-22-20-38-42-46-26-9-56-2-91-21z" />
              <path d="M146 150c22 12 36 26 44 38 2 3 0 7-3 8-4 1-7-1-9-4-8-13-20-25-36-34 1-3 2-5 4-8z" />
            </svg>
          </span>
          <span className="text-[19px] font-semibold tracking-[-0.02em] text-ink">
            sprout
          </span>
        </a>
        <nav className="hidden md:flex items-center gap-7 caps text-ink2">
          <a href="/#subscriptions" className="hover:text-ink">
            Subscriptions
          </a>
          <a href="/#ai" className="hover:text-ink">
            Insights
          </a>
          <a href="/#voice" className="hover:text-ink">
            Voice
          </a>
          <a href="/#security" className="hover:text-ink">
            Security
          </a>
        </nav>
        <div className="flex items-center gap-2">
          <a href="/#cta" className="btn-primary !h-10 !px-4 !text-[14px]">
            Get the app
          </a>
          <button
            className="md:hidden inline-flex w-10 h-10 items-center justify-center rounded-xl border border-line bg-white"
            aria-label="Menu"
            aria-expanded={open}
            aria-controls="mobile-navigation"
            onClick={() => setOpen(!open)}
            ref={buttonRef}
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#16271D"
              strokeWidth="2"
              strokeLinecap="round"
            >
              <path d="M4 7h16M4 12h16M4 17h16" />
            </svg>
          </button>
        </div>
      </div>
      {open && (
        <nav
          id="mobile-navigation"
          aria-label="Mobile navigation"
          className="mobile-navigation md:hidden"
        >
          <a href="/#subscriptions">Subscriptions</a>
          <a href="/#ai">Insights</a>
          <a href="/#voice">Voice</a>
          <a href="/#security">Security</a>
        </nav>
      )}
    </header>
  );
}
