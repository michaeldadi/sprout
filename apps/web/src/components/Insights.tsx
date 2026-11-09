import { Advice } from './Advice';
export function Insights() {
  return (
    <section
      id="ai"
      data-aid="ai"
      className="bg-white border-y border-line py-24 md:py-36 overflow-hidden"
    >
      <div className="mx-auto max-w-page px-5 text-center reveal">
        <span
          className="block w-2.5 h-2.5 rounded-full bg-success mx-auto"
          style={
            {
              boxShadow: '0 0 0 6px rgba(34,112,71,0.12)',
            } as React.CSSProperties
          }
        ></span>
        <h2 className="serif text-[36px] md:text-[48px] leading-[1.05] mt-8">
          <em className="text-action">Always-on</em> advice.
        </h2>
        <p className="mt-5 text-[17px] leading-7 text-ink2 mx-auto max-w-[46ch]">
          Ask sprout anything about your money in the in-app chat, or let it
          come to you. It reads your activity and says the useful thing,
          plainly.
        </p>

        <Advice />
        <p className="mt-8 caps text-ink2">Insights · Chat · Renewal notices</p>
      </div>
    </section>
  );
}
