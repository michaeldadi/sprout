import { useEffect, useRef, useState } from 'react';
export function Advice() {
  const [index, setIndex] = useState(0),
    [paused, setPaused] = useState(false),
    [hovered, setHovered] = useState(false),
    [focused, setFocused] = useState(false),
    [visible, setVisible] = useState(false),
    [hidden, setHidden] = useState(false),
    [reduce, setReduce] = useState(true);
  const containerRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const query = matchMedia('(prefers-reduced-motion: reduce)');
    const change = () => setReduce(query.matches);
    change();
    query.addEventListener('change', change);
    const visibility = () => setHidden(document.hidden);
    visibility();
    document.addEventListener('visibilitychange', visibility);
    const observer = new IntersectionObserver(([entry]) =>
      setVisible(entry.isIntersecting)
    );
    if (containerRef.current) observer.observe(containerRef.current);
    return () => {
      query.removeEventListener('change', change);
      document.removeEventListener('visibilitychange', visibility);
      observer.disconnect();
    };
  }, []);
  useEffect(() => {
    if (paused || hovered || focused || !visible || hidden || reduce) return;
    const timer = setInterval(() => setIndex((i) => (i + 1) % 3), 3000);
    return () => clearInterval(timer);
  }, [paused, hovered, focused, visible, hidden, reduce]);
  return (
    <>
      {' '}
      <div
        ref={containerRef}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        onFocusCapture={() => setFocused(true)}
        onBlurCapture={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget))
            setFocused(false);
        }}
        className="relative mx-auto mt-12 max-w-[720px] h-[150px] sm:h-[96px]"
      >
        <div
          className="pill pill-ghost mx-auto w-[88%]"
          style={
            {
              transform: 'translateY(-36px) scale(.88)',
              opacity: '.25',
            } as React.CSSProperties
          }
        ></div>
        <div
          className="pill pill-ghost mx-auto w-[94%]"
          style={
            {
              transform: 'translateY(-18px) scale(.94)',
              opacity: '.5',
            } as React.CSSProperties
          }
        ></div>
        <div
          className="pill relative h-full text-left"
          id="pillStack"
          role="region"
          aria-label="Money insights"
          aria-roledescription="carousel"
        >
          <div
            className={index === 0 ? 'msg on' : 'msg'}
            aria-hidden={index !== 0}
            inert={index !== 0}
          >
            <span className="shrink-0 w-10 h-10 rounded-full bg-actionSubtle text-action flex items-center justify-center">
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
                <rect x="2" y="7" width="20" height="15" rx="2" />
                <path d="M17 2l-5 5-5-5" />
              </svg>
            </span>
            <p className="flex-1 text-[14px] md:text-[15px] leading-6 text-ink">
              You've paid for Paramount+ three months without watching.{' '}
              <a href="/#subscriptions" className="font-bold text-ink">
                Cancel before Nov 18?
              </a>
            </p>
            <span className="shrink-0 text-[12px] text-ink2 self-start sm:self-center pt-1 sm:pt-0">
              2m ago
            </span>
          </div>
          <div
            className={index === 1 ? 'msg on' : 'msg'}
            aria-hidden={index !== 1}
            inert={index !== 1}
          >
            <span className="shrink-0 w-10 h-10 rounded-full bg-actionSubtle text-action flex items-center justify-center">
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
                <path d="M21.21 15.89A10 10 0 1 1 8 2.83" />
                <path d="M22 12A10 10 0 0 0 12 2v10z" />
              </svg>
            </span>
            <p className="flex-1 text-[14px] md:text-[15px] leading-6 text-ink">
              Food is at $412 of $600 with 21 days left. Around $9 a day keeps
              you under.{' '}
              <a href="/product/budget" className="font-bold text-ink">
                See the plan
              </a>
            </p>
            <span className="shrink-0 text-[12px] text-ink2 self-start sm:self-center pt-1 sm:pt-0">
              1h ago
            </span>
          </div>
          <div
            className={index === 2 ? 'msg on' : 'msg'}
            aria-hidden={index !== 2}
            inert={index !== 2}
          >
            <span className="shrink-0 w-10 h-10 rounded-full bg-actionSubtle text-action flex items-center justify-center">
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
                <path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z" />
              </svg>
            </span>
            <p className="flex-1 text-[14px] md:text-[15px] leading-6 text-ink">
              Con Edison was $118.40, up 31% from October. Usually a seasonal
              jump.{' '}
              <a href="/product/activity" className="font-bold text-ink">
                Compare months
              </a>
            </p>
            <span className="shrink-0 text-[12px] text-ink2 self-start sm:self-center pt-1 sm:pt-0">
              Yesterday
            </span>
          </div>
        </div>
      </div>
      <div className="advice-controls" aria-label="Insight controls">
        {[0, 1, 2].map((n) => (
          <button
            key={n}
            type="button"
            aria-label={`Show insight ${n + 1}`}
            aria-pressed={index === n}
            onClick={() => {
              setIndex(n);
              setPaused(true);
            }}
          >
            <span className={index === n ? 'active' : ''} />
          </button>
        ))}
        {!reduce && (
          <button
            type="button"
            className="advice-pause"
            onClick={() => setPaused(!paused)}
            aria-label={paused ? 'Resume insights' : 'Pause insights'}
          >
            {paused ? 'Play' : 'Pause'}
          </button>
        )}
      </div>
    </>
  );
}
