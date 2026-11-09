import { createFileRoute } from '@tanstack/react-router';
import { Hero } from '../components/Hero';
import { Subscriptions } from '../components/Subscriptions';
import { Insights } from '../components/Insights';
import { Voice } from '../components/Voice';
import { Security } from '../components/Security';
import { Steps } from '../components/Steps';
import { FinalCta } from '../components/FinalCta';
import { pageHead } from '../content/metadata';
export const Route = createFileRoute('/')({
  head: () =>
    pageHead(
      '/',
      'Money that finally explains itself',
      'A calm view of your money. See subscriptions, understand your spending, and bring your accounts into one clear picture with Sprout.'
    ),
  component: Home,
});
function Home() {
  return (
    <main id="main-content">
      <Hero />
      <Subscriptions />
      <Insights />
      <Voice />
      <Security />
      <Steps />
      <FinalCta />
    </main>
  );
}
