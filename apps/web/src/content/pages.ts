import type { Category } from '../components/Forms';
export type Section = { title: string; paragraphs: string[]; list?: string[] };
export type Page = {
  title: string;
  eyebrow: string;
  description: string;
  sections: Section[];
  kind?:
    | 'home'
    | 'budget'
    | 'activity'
    | 'blog'
    | 'help'
    | 'press'
    | 'waitlist';
  form?: Category;
  article?: boolean;
};
export const articles = {
  '/blog/understanding-recurring-spending': {
    title: 'A clearer view of recurring spending',
    eyebrow: 'The Sprout journal · Money habits',
    description:
      'A subscription is a small decision that repeats. Give those decisions a regular place in your money routine.',
    article: true,
    sections: [
      {
        title: 'Start with the commitments, not the categories',
        paragraphs: [
          'A monthly spending total tells you where money went. A recurring-spending list tells you which decisions are likely to happen again. Both views matter, but they answer different questions.',
          'Start by collecting the services and memberships you pay for regularly. Include annual renewals, free trials approaching their end, and services billed through an app store. Note the amount, the billing interval, and where the subscription is managed.',
        ],
      },
      {
        title: 'Give every renewal a date',
        paragraphs: [
          'A subscription becomes easier to decide on when its next renewal has a place on the calendar. A reminder before the charge gives you time to check whether you still want the service.',
          'Annual plans deserve particular attention. Divide the annual price by twelve when comparing costs, but keep the full renewal amount and actual renewal date visible. A monthly equivalent is useful for planning; it does not change what will leave your account.',
        ],
      },
      {
        title: 'Ask what you would choose today',
        paragraphs: [
          'A service can be useful without being useful to you right now. Look at whether you use it, whether it duplicates another service, and whether it fits the month ahead. The question is not whether the original purchase was sensible. It is whether you would make the same purchase today.',
          'When you decide to cancel, follow the provider’s process and keep the confirmation. Removing an app or setting a reminder does not end the subscription. Check the next statement if you are unsure whether a cancellation took effect.',
        ],
      },
      {
        title: 'Make it a small recurring habit',
        paragraphs: [
          'Choose a regular moment to look at the list: the start of a month, payday, or the week before an annual renewal. Keep a note of anything you want to revisit.',
          'The aim is a clear picture of your commitments. You do not need to eliminate every small pleasure or optimize every charge. You need enough visibility to choose what stays.',
        ],
      },
    ],
  },
  '/blog/tracking-manual-expenses': {
    title: 'Make room for the spending a bank feed misses',
    eyebrow: 'The Sprout journal · Everyday spending',
    description:
      'Cash, shared bills, and quick repayments are part of your financial picture. A simple record helps them stay in view.',
    article: true,
    sections: [
      {
        title: 'Record the moment while it is fresh',
        paragraphs: [
          'A coffee paid in cash, lunch split with a friend, a small purchase at a market: these are easy to remember in the moment and easy to lose by the end of the week.',
          'A useful manual record needs only a few facts: amount, currency, date, and a short description. Add a category if it helps you find the expense again. Keep the process short enough that you will actually use it.',
        ],
      },
      {
        title: 'Separate your spending from money passing through',
        paragraphs: [
          'If you pay a restaurant bill for a group, the full charge and your share are different things. Record enough context to distinguish the payment from the repayments you expect.',
          'A transfer between your own accounts is different again. Moving money does not necessarily mean spending it. Clear descriptions make later review easier and reduce the chance of counting the same movement twice.',
        ],
      },
      {
        title: 'Check for a matching bank transaction',
        paragraphs: [
          'A manual entry can overlap with a charge that arrives later through a connected account. When reviewing activity, look for the same amount, date, and merchant before treating both records as separate spending.',
          'Pending and posted amounts can differ. Keep the original context until you can identify the settled transaction. If the records disagree, use the merchant receipt and bank statement to understand what happened.',
        ],
      },
      {
        title: 'Build a routine around clarity',
        paragraphs: [
          'Review manual entries alongside your other activity once a week. Correct a category, add a missing note, or resolve a shared bill while the details are still familiar.',
          'The value is not a perfect diary of every penny. It is a more complete account of the decisions that matter to you, with enough context to recognize them later.',
        ],
      },
    ],
  },
} satisfies Record<string, Page>;
export const pages: Record<string, Page> = {
  '/product/home': {
    title: 'Start with a clear picture.',
    eyebrow: 'Product · Home',
    description:
      'One place to understand your accounts, your month, and what comes next.',
    kind: 'home',
    sections: [
      {
        title: 'Your money, in context',
        paragraphs: [
          'Home brings account balances and everyday spending into one calm view. See the figure, understand what it represents, and move into the details when you need them.',
          'A safe-to-spend view gives your month a practical starting point alongside the commitments and budgets you are keeping in mind.',
        ],
      },
      {
        title: 'A useful next step',
        paragraphs: [
          'Move from Home into Activity to look at a charge, check a category, or add context. Your overview and your records belong to the same picture.',
        ],
      },
      {
        title: 'A little less checking',
        paragraphs: [
          'Sprout is designed for a quick look that tells you something useful. Open it, get oriented, and get on with your day.',
        ],
      },
    ],
  },
  '/product/budget': {
    title: 'A month you can make sense of.',
    eyebrow: 'Product · Budget',
    description:
      'Give everyday spending a plan, then keep the numbers close enough to use.',
    kind: 'budget',
    sections: [
      {
        title: 'Start with the categories that matter',
        paragraphs: [
          'Food, bills, shopping, and the things you choose to make room for. A budget is most useful when its categories reflect the way you actually spend.',
          'See spending beside its budget, with readable amounts and a simple progress bar. The point is to understand where you stand before the month is over.',
        ],
      },
      {
        title: 'Make adjustments with context',
        paragraphs: [
          'A quieter week and an unusually expensive one can fit into the same month. Look at what has happened, what is still ahead, and which commitments you want to protect.',
        ],
      },
      {
        title: 'Keep the details within reach',
        paragraphs: [
          'Activity gives you the records behind the bigger picture. Review a charge and its category so your plan stays connected to the decisions that produced it.',
        ],
      },
    ],
  },
  '/product/activity': {
    title: 'Everyday spending, clearly recorded.',
    eyebrow: 'Product · Activity',
    description:
      'Find a transaction, understand the details, and keep the spending outside your bank feed in view.',
    kind: 'activity',
    sections: [
      {
        title: 'Follow the record',
        paragraphs: [
          'Browse recent activity, search for a charge, and narrow your view to the records you need. Descriptions, amounts, and dates stay readable together.',
          'Open a record for its category, payment details, and notes. A clear record makes an unfamiliar charge easier to recognize.',
        ],
      },
      {
        title: 'Bring cash and shared bills into view',
        paragraphs: [
          'Manual entries help capture the purchases that never arrive in a bank feed. Add the amount and context while you remember them.',
        ],
      },
      {
        title: 'Make your review a small habit',
        paragraphs: [
          'A few minutes spent reviewing recent activity can answer the questions that otherwise pile up at the end of the month. Start with the latest record and follow what needs your attention.',
        ],
      },
    ],
  },
  '/about': {
    title: 'A calmer relationship with money.',
    eyebrow: 'About Sprout',
    description:
      'Sprout brings personal finance and subscription management into one clear experience on your phone.',
    sections: [
      {
        title: 'Clarity before complexity',
        paragraphs: [
          'Money apps should help you understand your life, not give you another dashboard to manage. Sprout starts with a clear overview, readable records, and useful explanations.',
          'We are building around everyday questions: What was that charge? What renews next? How is this month going? The answers should be easy to find.',
        ],
      },
      {
        title: 'Made for the way a day unfolds',
        paragraphs: [
          'Your finances move between accounts, subscriptions, cash, and shared expenses. Sprout gives those pieces a common home, with voice entry for the moments when typing gets in the way.',
        ],
      },
      {
        title: 'Care in the details',
        paragraphs: [
          'Sprout’s visual language is quiet by design. Thoughtful spacing, clear labels, and familiar navigation help the information do the talking. Made in New York, for everyday life wherever you are.',
        ],
      },
    ],
  },
  '/careers': {
    title: 'Build something people can breathe around.',
    eyebrow: 'Working with Sprout',
    description:
      'We care about clear thinking, careful engineering, and products that make everyday decisions feel more manageable.',
    form: 'careers',
    sections: [
      {
        title: 'The work we value',
        paragraphs: [
          'Good product work starts by understanding a real question. We value people who can make complicated systems understandable, who test their assumptions, and who follow a detail all the way through.',
        ],
      },
      {
        title: 'Care is a practical skill',
        paragraphs: [
          'Financial information deserves precision. So does the experience around it: the words, the failure states, the accessible controls, and the way a screen responds when someone needs help.',
        ],
      },
      {
        title: 'Tell us what you would bring',
        paragraphs: [
          'Share the kind of work you want to do, a link to something you are proud of, and why Sprout interests you. Use the form below to introduce yourself.',
        ],
      },
    ],
  },
  '/press': {
    title: 'Sprout, at a glance.',
    eyebrow: 'Press and brand',
    description:
      'Product background, brand assets, and a direct way to reach the team.',
    kind: 'press',
    form: 'press',
    sections: [
      {
        title: 'The short description',
        paragraphs: [
          'Sprout is a personal finance and subscription management app for iPhone and Android. It brings account activity, budgets, recurring charges, and useful insights into a calm mobile experience.',
        ],
      },
      {
        title: 'Brand assets',
        paragraphs: [
          'Use the Sprout name and leaf mark to identify the product accurately. Keep the mark’s proportions and colors intact, give it breathing room, and avoid suggesting an endorsement or partnership.',
        ],
      },
      {
        title: 'Press inquiries',
        paragraphs: [
          'For product background, interviews, or asset questions, send the context of your story and your deadline through the form below.',
        ],
      },
    ],
  },
  '/help': {
    title: 'A little help, clearly explained.',
    eyebrow: 'Sprout help centre',
    description:
      'Find an answer about your account, your activity, or the way Sprout handles your information.',
    kind: 'help',
    sections: [],
  },
  '/help/in-app-support': {
    title: 'A conversation when you need it.',
    eyebrow: 'Help · In-app support',
    description: 'Keep a question close to the activity you are looking at.',
    form: 'support',
    sections: [
      {
        title: 'Find support in Sprout',
        paragraphs: [
          'Open Profile and choose Support to start a conversation. Describe what you were trying to do and what happened instead. If your question concerns a charge, use its date and a general description rather than sharing full account details.',
        ],
      },
      {
        title: 'Share useful context',
        paragraphs: [
          'Your phone type, app version, and the steps that led to a problem help us understand it. Never share a password, sign-in code, bank credential, or a full payment-card number.',
        ],
      },
      {
        title: 'Contact us from the web',
        paragraphs: [
          'You can also use the form below. Include the email associated with your Sprout account when your question concerns that account.',
        ],
      },
    ],
  },
  '/status': {
    title: 'Updates from Sprout.',
    eyebrow: 'Release and service updates',
    description:
      'A clear record of product milestones and notices from the team.',
    sections: [
      {
        title: 'November 9, 2026 · Clear sky',
        paragraphs: [
          'The Clear sky website design was selected for Sprout’s product introduction. Its light sage canvas, forest-green details, and editorial typography establish a common home for the product story, journal, and support resources.',
        ],
      },
      {
        title: 'Stay in the loop',
        paragraphs: [
          'Join the launch list for news about Sprout on iPhone and Android. For an account or product question, contact the team through the help centre.',
        ],
      },
    ],
  },
  '/privacy': {
    title: 'Your information deserves care.',
    eyebrow: 'Privacy policy · November 9, 2026',
    description:
      'How Sprout handles information on this website and in its personal finance services.',
    form: 'privacy',
    sections: [
      {
        title: 'Who this policy covers',
        paragraphs: [
          'This policy covers the Sprout website, launch waitlist, support inquiries, and Sprout mobile services. References to “Sprout,” “we,” and “our” mean the team operating those services. Contact us using the privacy form at the end of this page.',
        ],
      },
      {
        title: 'Information you give us',
        paragraphs: [
          'When you join the waitlist, we collect your email address, phone-platform preference, where you signed up, and a record of your launch-update consent.',
          'When you contact us, we collect the email, optional name, category, and message you provide. Please do not include passwords, bank credentials, payment-card numbers, or financial documents in a website inquiry.',
          'In the app, account information and financial records can include your sign-in details, preferences, transactions, categories, notes, budgets, and information you choose to connect or enter. A connected-bank flow explains the information requested before you authorize it.',
        ],
      },
      {
        title: 'Why we use it',
        paragraphs: [
          'We use information to provide and secure the service, handle inquiries and rights requests, maintain financial records you choose to keep in Sprout, and send launch updates where you have consented.',
          'We do not sell your personal information. Waitlist consent is for Sprout launch news, not unrelated promotions.',
        ],
      },
      {
        title: 'Service providers and connected accounts',
        paragraphs: [
          'Appwrite hosts the website and stores website form submissions. Hosting systems process technical request information for delivery, security, troubleshooting, and abuse prevention.',
          'Plaid supports bank connections when you choose to link an account. Review the permissions and Plaid’s privacy information during that process. Other app services may process information needed for sign-in, customer support, notifications, or purchases. We share information for those purposes, not as a substitute for your authorization.',
        ],
      },
      {
        title: 'Storage, access, and retention',
        paragraphs: [
          'Website submissions are private to authorized service operators. We keep waitlist details for launch communications and retain inquiries while needed to resolve them, maintain appropriate records, and meet legal obligations.',
          'You can ask to withdraw waitlist consent, access information, correct it, or delete it using this form. Account-related requests may require identity verification. We retain information only where there is an applicable operational or legal reason to do so.',
        ],
      },
      {
        title: 'Your choices',
        paragraphs: [
          'You decide whether to join the waitlist, contact the team, link a financial account, or provide optional information. You may have rights to access, correction, deletion, portability, restriction, or objection depending on where you live.',
          'Use the Delete your data page for a deletion request. We will review requests and respond under applicable requirements. You can also contact your local privacy regulator if you believe your information has been handled improperly.',
        ],
      },
      {
        title: 'Website storage and communications',
        paragraphs: [
          'The website does not require an account or use advertising trackers to accept a waitlist signup or inquiry. Essential hosting and security processing still occurs when you visit.',
          'Website forms display a receipt after saving. They do not send an automatic confirmation email. A member of the team may contact you to handle an inquiry or identity-verification request.',
        ],
      },
      {
        title: 'Children and policy changes',
        paragraphs: [
          'Sprout is intended for adults. Do not submit information about a child through these forms. If you believe a child has provided personal information, contact us so we can review it.',
          'We update this page when practices change and show the policy date above. Material changes will be communicated where appropriate.',
        ],
      },
    ],
  },
  '/terms': {
    title: 'The terms, plainly stated.',
    eyebrow: 'Terms of service · November 9, 2026',
    description:
      'The terms for using Sprout’s website, launch list, and personal finance services.',
    sections: [
      {
        title: 'Using Sprout',
        paragraphs: [
          'By using Sprout, you agree to these terms and our privacy policy. You must be an adult and legally able to enter into an agreement. If you do not agree, do not use the service.',
          'Use the website and app lawfully. Do not attempt to access someone else’s data, interfere with the service, abuse its forms, or submit malicious material.',
        ],
      },
      {
        title: 'Your account and information',
        paragraphs: [
          'Provide accurate account information and protect your sign-in credentials. You are responsible for activity you authorize through your account. Contact support promptly if you suspect unauthorized access.',
          'Only connect accounts you are authorized to use. Permissions and third-party terms apply to connected financial services, app stores, and identity providers.',
        ],
      },
      {
        title: 'Financial information and decisions',
        paragraphs: [
          'Sprout helps organize and explain information. It is not a bank, broker, investment adviser, or financial adviser. Information in Sprout does not replace your bank statement, a provider’s billing records, or qualified professional advice.',
          'Amounts, categories, estimates, and insights can depend on source data and update timing. Review important decisions against the original records. You remain responsible for payments, account balances, subscription changes, taxes, and financial choices.',
        ],
      },
      {
        title: 'Subscriptions and purchases',
        paragraphs: [
          'A reminder does not cancel a merchant subscription. Follow the merchant’s or app store’s cancellation process and retain its confirmation.',
          'If you purchase a Sprout plan, the price and applicable payment terms are shown before purchase. App-store purchase, renewal, refund, and cancellation rules apply where an app store processes the transaction.',
        ],
      },
      {
        title: 'Waitlist and inquiries',
        paragraphs: [
          'Joining the launch list records your interest and consent to launch updates. It does not create a paid subscription, reserve a particular release date, or establish a financial account.',
          'Use inquiry forms for their stated purpose and avoid sending sensitive financial credentials. A saved inquiry is a request for review, not authorization to change someone else’s account.',
        ],
      },
      {
        title: 'Content and intellectual property',
        paragraphs: [
          'Sprout’s name, branding, interface, and original content belong to their respective rights holders. You may use the service for its intended purpose and share links to public pages. Do not misrepresent ownership or imply a partnership.',
          'You retain rights in information you submit. You grant the permissions reasonably needed to store, process, and display it to provide the service and handle your requests. Open-source components remain subject to their own licenses.',
        ],
      },
      {
        title: 'Availability and responsibility',
        paragraphs: [
          'We work to keep Sprout useful and secure, but access can be interrupted and information can contain errors. To the extent permitted by law, the service is provided without warranties of uninterrupted access or fitness for a particular financial decision.',
          'To the extent permitted by law, Sprout is not responsible for indirect losses or losses caused by third-party services, unauthorized use outside our control, or decisions made without checking original records. These terms do not exclude rights or liabilities that cannot lawfully be excluded.',
        ],
      },
      {
        title: 'Changes, closure, and questions',
        paragraphs: [
          'We may update the service or these terms. The date above identifies this version. We may restrict misuse of the service and will handle account closure and data requests according to applicable obligations.',
          'For questions about these terms, contact Sprout through the website contact form. You can request deletion using the Delete your data page.',
        ],
      },
    ],
  },
  '/delete-data': {
    title: 'Your data. Your choice.',
    eyebrow: 'Privacy · Data deletion',
    description:
      'Request deletion of your Sprout account information or website submissions.',
    form: 'deletion',
    sections: [
      {
        title: 'Delete from the app',
        paragraphs: [
          'Open Profile, choose Settings, and select Delete account. Read the confirmation carefully and follow the identity-verification steps shown. Deleting an account affects the records associated with it.',
        ],
      },
      {
        title: 'Send a deletion request',
        paragraphs: [
          'Use the form below with the email associated with your account or website submission. Tell us whether your request concerns your app account, waitlist signup, or an earlier inquiry.',
          'We verify that a request comes from the person entitled to make it before changing account data. Do not include a password, verification code, bank credential, or financial document.',
        ],
      },
      {
        title: 'What to keep in mind',
        paragraphs: [
          'Deleting Sprout data does not close a bank account or cancel a subscription with another company. Keep any records you need before completing deletion. Some information may need to be retained to meet legal obligations or resolve an existing issue.',
        ],
      },
    ],
  },
  '/licenses': {
    title: 'Built with good foundations.',
    eyebrow: 'Licenses and acknowledgments',
    description:
      'The open-source software, fonts, and artwork used in the Sprout website.',
    sections: [
      {
        title: 'Typefaces',
        paragraphs: [
          'Inter, Fraunces, and JetBrains Mono are distributed under the SIL Open Font License 1.1. The website self-hosts its font files. Original copyright and license notices are provided with the downloads below.',
        ],
      },
      {
        title: 'Software',
        paragraphs: [
          'This website uses React, TanStack Start and Router, Tailwind CSS, Vite, Nitro, and the Appwrite server SDK. Their copyright and license notices are included in the software notice file.',
        ],
      },
      {
        title: 'Brand and product names',
        paragraphs: [
          'The Sprout leaf and app icon identify Sprout. Apple, App Store, Siri, Google Play, Google Assistant, Plaid, and the services shown in product illustrations belong to their respective owners. References identify the relevant platform or service and do not imply an endorsement.',
        ],
      },
    ],
  },
  '/contact': {
    title: 'Let’s make it clear.',
    eyebrow: 'Contact Sprout',
    description:
      'A question, an idea, or something that needs a closer look. Send it to the team.',
    form: 'support',
    sections: [
      {
        title: 'Start with the context',
        paragraphs: [
          'Choose a topic and tell us what you need. For a product question, include the phone platform and the steps that led to it. For press or partnership inquiries, share a little background and any relevant timing.',
        ],
      },
    ],
  },
  '/waitlist': {
    title: 'Start your next chapter with money.',
    eyebrow: 'Sprout · Launch updates',
    description: 'Join the list for Sprout launch news on iPhone and Android.',
    kind: 'waitlist',
    sections: [],
  },
  '/blog': {
    title: 'A little more clarity.',
    eyebrow: 'The Sprout journal',
    description:
      'Thoughtful, practical notes on everyday spending and a calmer money routine.',
    kind: 'blog',
    sections: [],
  },
  ...articles,
};
export const helpEntries = [
  {
    title: 'How do I create a Sprout account?',
    body: 'Choose Sign up in the app and follow the email or supported sign-in flow. Use an email address you can access, and complete any verification steps. Keep your sign-in codes private.',
  },
  {
    title: 'How do bank connections work?',
    body: 'Choose the account-linking option and follow the Plaid flow. Check the permissions and select the accounts you want to connect. Sprout uses a read-only connection to help organize your information; it does not move money.',
  },
  {
    title: 'How do I find a transaction?',
    body: 'Open Activity and search for its description or use the available filters. Open a record to review its date, amount, category, and notes. Check your bank or merchant record if you need to confirm a settled charge.',
  },
  {
    title: 'What should I know about manual entries?',
    body: 'Manual entries help record cash and other spending outside a connected bank feed. Include the amount, date, and a useful description. Check for a matching bank transaction later so the same expense is not counted twice.',
  },
  {
    title: 'Does a reminder cancel a subscription?',
    body: 'No. A reminder helps you decide before a renewal. Complete cancellation through the merchant or app store and keep its confirmation. Removing an app does not cancel its subscription.',
  },
  {
    title: 'How do I contact support?',
    body: 'Open Profile and choose Support in the app, or use the website contact form. Describe the issue without including passwords, sign-in codes, full account numbers, or financial documents.',
  },
  {
    title: 'How do I request data deletion?',
    body: 'Use Delete account in app settings or the Delete your data page on this website. We verify account-related requests before processing them. Account deletion does not cancel subscriptions held with other companies.',
  },
];
