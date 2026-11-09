import { createContext, useContext } from 'react';
import type { AnchorHTMLAttributes } from 'react';
export type Platform = 'ios' | 'android' | 'both';
export type Placement = 'hero' | 'final-cta' | 'footer' | 'waitlist-page';
export const WaitlistContext = createContext<
  (platform: Platform, placement: Placement, trigger: HTMLElement) => void
>(() => {});
type Props = AnchorHTMLAttributes<HTMLAnchorElement> & {
  'data-store-platform': Platform;
  'data-store-placement': Placement;
};
export function StoreLink(props: Props) {
  const open = useContext(WaitlistContext);
  return (
    <a
      {...props}
      onClick={(event) => {
        if (
          event.button !== 0 ||
          event.metaKey ||
          event.ctrlKey ||
          event.shiftKey ||
          event.altKey
        )
          return;
        event.preventDefault();
        open(
          props['data-store-platform'],
          props['data-store-placement'],
          event.currentTarget
        );
      }}
    />
  );
}
