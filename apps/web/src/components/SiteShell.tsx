import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { useRouterState } from '@tanstack/react-router';
import { Navigation } from './Navigation';
import { Footer } from './Footer';
import { WaitlistContext } from './StoreLink';
import type { Placement, Platform } from './StoreLink';
import { WaitlistForm } from './Forms';
export function SiteShell({ children }: { children: ReactNode }) {
  useEffect(() => {
    document.documentElement.dataset.hydrated = 'true';
    return () => {
      delete document.documentElement.dataset.hydrated;
    };
  }, []);
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const dialog = useRef<HTMLDialogElement>(null);
  const trigger = useRef<HTMLElement | null>(null);
  const [selection, setSelection] = useState<{
    platform: Platform;
    placement: Placement;
    key: number;
  }>({ platform: 'both', placement: 'waitlist-page', key: 0 });
  useEffect(() => {
    const query = matchMedia('(prefers-reduced-motion: reduce)');
    let observer: IntersectionObserver | undefined;
    const setup = () => {
      observer?.disconnect();
      const elements = document.querySelectorAll('.reveal');
      if (query.matches || !('IntersectionObserver' in window)) {
        delete document.documentElement.dataset.motionReady;
        return;
      }
      document.documentElement.dataset.motionReady = 'true';
      observer = new IntersectionObserver(
        (entries) =>
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add('in');
              observer?.unobserve(entry.target);
            }
          }),
        { rootMargin: '0px 0px -10% 0px', threshold: 0.1 }
      );
      elements.forEach((element) => observer?.observe(element));
    };
    setup();
    query.addEventListener('change', setup);
    return () => {
      observer?.disconnect();
      query.removeEventListener('change', setup);
      delete document.documentElement.dataset.motionReady;
    };
  }, [pathname]);
  function open(
    platform: Platform,
    placement: Placement,
    element: HTMLElement
  ) {
    trigger.current = element;
    setSelection((s) => ({ platform, placement, key: s.key + 1 }));
    dialog.current?.showModal();
  }
  function close() {
    dialog.current?.close();
  }
  return (
    <WaitlistContext.Provider value={open}>
      <a href="#main-content" className="skip-link">
        Skip to content
      </a>
      <Navigation />
      {children}
      <Footer />
      <dialog
        ref={dialog}
        className="waitlist-dialog"
        aria-labelledby="waitlist-title"
        onClose={() => trigger.current?.focus()}
        onClick={(event) => {
          if (event.target === event.currentTarget) {
            const rect = event.currentTarget.getBoundingClientRect();
            if (
              event.clientX < rect.left ||
              event.clientX > rect.right ||
              event.clientY < rect.top ||
              event.clientY > rect.bottom
            )
              close();
          }
        }}
      >
        <button
          type="button"
          className="dialog-close"
          onClick={close}
          aria-label="Close waitlist"
        >
          ×
        </button>
        <p className="caps text-action">Sprout · Launch updates</p>
        <h2 id="waitlist-title" className="serif text-4xl mt-4">
          Your next chapter
          <br />
          with money.
        </h2>
        <p className="text-ink2 mt-4 mb-6">
          Choose your phone and join the list for launch news.
        </p>
        <WaitlistForm
          key={selection.key}
          initialPlatform={selection.platform}
          placement={selection.placement}
        />
      </dialog>
    </WaitlistContext.Provider>
  );
}
