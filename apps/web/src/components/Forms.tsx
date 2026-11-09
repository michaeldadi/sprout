import { useId, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import type { Placement, Platform } from './StoreLink';
export const categories = [
  'support',
  'press',
  'careers',
  'privacy',
  'deletion',
] as const;
export type Category = (typeof categories)[number];
type Receipt = {
  ok?: boolean;
  message?: string;
  fields?: Record<string, string>;
};
async function send(path: string, body: unknown): Promise<Receipt> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    if (response.status === 429) {
      const seconds = Number(response.headers.get('Retry-After')) || 60;
      return { message: `Please wait ${seconds} seconds before trying again.` };
    }
    let result: Receipt;
    try {
      result = await response.json();
    } catch {
      return { message: 'We could not save your request. Please try again.' };
    }
    return response.ok ? result : { ...result, ok: false };
  } catch {
    return {
      message:
        'We could not connect. Your details are still here; please try again.',
    };
  } finally {
    clearTimeout(timeout);
  }
}
function FieldError({ id, message }: { id: string; message?: string }) {
  return message ? (
    <p id={id} className="field-error">
      {message}
    </p>
  ) : null;
}
export function WaitlistForm({
  initialPlatform = 'both',
  placement = 'waitlist-page',
}: {
  initialPlatform?: Platform;
  placement?: Placement;
}) {
  const emailId = useId();
  const emailErrorId = emailId + '-error';
  const [platform, setPlatform] = useState<Platform>(initialPlatform),
    [pending, setPending] = useState(false),
    [result, setResult] = useState<Receipt>({});
  const receiptRef = useRef<HTMLDivElement>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const data = new FormData(event.currentTarget);
    setPending(true);
    const reply = await send('/api/waitlist', {
      email: data.get('email'),
      platform,
      placement,
      consent: data.get('consent') === 'on',
      website: data.get('website'),
    });
    setResult(reply);
    setPending(false);
    if (reply.ok) requestAnimationFrame(() => receiptRef.current?.focus());
  }
  if (result.ok)
    return (
      <div
        ref={receiptRef}
        tabIndex={-1}
        className="form-receipt"
        role="status"
      >
        <span className="caps text-action">You’re on the list</span>
        <h2 className="serif text-3xl mt-3">A clearer picture is coming.</h2>
        <p>
          We’ve saved your interest. We’ll use your email for Sprout launch
          updates.
        </p>
      </div>
    );
  return (
    <form
      onSubmit={submit}
      method="post"
      action="/api/waitlist"
      className="sprout-form"
      aria-label="Join the waitlist"
    >
      <div>
        <label htmlFor={emailId}>Email address</label>
        <input
          id={emailId}
          type="email"
          name="email"
          autoComplete="email"
          maxLength={254}
          required
          aria-invalid={!!result.fields?.email}
          aria-describedby={result.fields?.email ? emailErrorId : undefined}
        />
        <FieldError id={emailErrorId} message={result.fields?.email} />
      </div>
      <fieldset>
        <legend>Your phone</legend>
        <div className="platform-options">
          {(['ios', 'android', 'both'] as const).map((value) => (
            <label key={value}>
              <input
                type="radio"
                name="platform"
                value={value}
                checked={platform === value}
                onChange={() => setPlatform(value)}
              />
              {value === 'ios'
                ? 'iPhone'
                : value === 'android'
                  ? 'Android'
                  : 'Both'}
            </label>
          ))}
        </div>
      </fieldset>
      <label className="consent">
        <input type="checkbox" name="consent" required />{' '}
        <span>
          Email me about the Sprout launch. I’ve read the{' '}
          <a href="/privacy">privacy policy</a>.
        </span>
      </label>
      <FieldError
        id={emailId + '-consent-error'}
        message={result.fields?.consent}
      />
      <Honeypot />
      <p className="form-feedback" role="alert">
        {result.message}
      </p>
      <button
        type="submit"
        className="btn-primary justify-center"
        disabled={pending}
      >
        {pending ? 'Saving your place…' : 'Join the waitlist'}
      </button>
      <p className="form-helper">
        Your email stays with Sprout. No account required.
      </p>
    </form>
  );
}
function Honeypot() {
  return (
    <div className="honeypot" aria-hidden="true">
      <label>
        Website
        <input name="website" type="text" tabIndex={-1} autoComplete="off" />
      </label>
    </div>
  );
}
export function ContactForm({ category = 'support' }: { category?: Category }) {
  const [pending, setPending] = useState(false),
    [result, setResult] = useState<Receipt>({});
  const submissionId = useRef<string | null>(null);
  const receiptRef = useRef<HTMLDivElement>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const form = new FormData(event.currentTarget);
    submissionId.current ??= crypto.randomUUID();
    setPending(true);
    const reply = await send('/api/contact', {
      submissionId: submissionId.current,
      name: form.get('name'),
      email: form.get('email'),
      category: form.get('category'),
      message: form.get('message'),
      website: form.get('website'),
    });
    setResult(reply);
    setPending(false);
    if (reply.ok) requestAnimationFrame(() => receiptRef.current?.focus());
  }
  if (result.ok)
    return (
      <div
        className="form-receipt"
        role="status"
        ref={receiptRef}
        tabIndex={-1}
      >
        <span className="caps text-action">Received</span>
        <h2 className="serif text-3xl mt-3">Thanks for getting in touch.</h2>
        <p>Your inquiry has been saved for the Sprout team to review.</p>
        <a href="/" className="text-link">
          Back to Sprout
        </a>
      </div>
    );
  return (
    <form
      className="sprout-form"
      method="post"
      action="/api/contact"
      onSubmit={submit}
      aria-label="Contact Sprout"
    >
      <div>
        <label htmlFor="contact-name">
          Name <span className="text-ink2 font-normal">(optional)</span>
        </label>
        <input
          id="contact-name"
          name="name"
          autoComplete="name"
          maxLength={100}
        />
        <FieldError id="contact-name-error" message={result.fields?.name} />
      </div>
      <div>
        <label htmlFor="contact-email">Email address</label>
        <input
          id="contact-email"
          name="email"
          type="email"
          autoComplete="email"
          maxLength={254}
          required
          aria-invalid={!!result.fields?.email}
          aria-describedby={
            result.fields?.email ? 'contact-email-error' : undefined
          }
        />
        <FieldError id="contact-email-error" message={result.fields?.email} />
      </div>
      <div>
        <label htmlFor="contact-category">What’s this about?</label>
        <select id="contact-category" name="category" defaultValue={category}>
          {categories.map((value) => (
            <option key={value} value={value}>
              {
                {
                  support: 'Product support',
                  press: 'Press and media',
                  careers: 'Working with Sprout',
                  privacy: 'Privacy question',
                  deletion: 'Delete my data',
                }[value]
              }
            </option>
          ))}
        </select>
      </div>
      <div>
        <label htmlFor="contact-message">Your message</label>
        <textarea
          id="contact-message"
          name="message"
          minLength={10}
          maxLength={5000}
          rows={6}
          required
          aria-invalid={!!result.fields?.message}
          aria-describedby="contact-message-help"
        />
        <p id="contact-message-help" className="form-helper">
          Please leave out passwords, bank details, and financial documents.
        </p>
        <FieldError
          id="contact-message-error"
          message={result.fields?.message}
        />
      </div>
      <Honeypot />
      <p role="alert" className="form-feedback">
        {result.message}
      </p>
      <button
        type="submit"
        className="btn-primary justify-center"
        disabled={pending}
      >
        {pending ? 'Sending…' : 'Send inquiry'}
      </button>
      <p className="form-helper">
        We use your details to handle your inquiry. Read our{' '}
        <a href="/privacy">privacy policy</a>.
      </p>
    </form>
  );
}
