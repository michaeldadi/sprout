import { createHash } from "node:crypto";
import { captureRules } from "../contracts/capture-rules";
import { AppError, date, type Transaction, type Budget } from "../contracts";

export function parseUSD(input: string): number {
  const raw = input.trim().replace(/^\$/, "");
  if (raw.includes(",") && !/^-?\d{1,3}(,\d{3})+(\.\d{1,2})?$/.test(raw))
    throw new AppError("INVALID_MONEY", "Review the amount separators.");
  const value = raw.replace(/,/g, "");
  if (!/^-?\d+(\.\d{1,2})?$/.test(value))
    throw new AppError(
      "INVALID_MONEY",
      "Enter a USD amount with at most two decimal places.",
    );
  const negative = value.startsWith("-");
  const [whole, fraction = ""] = value.replace("-", "").split(".");
  const result = Number(whole) * 100 + Number(fraction.padEnd(2, "0"));
  if (!Number.isSafeInteger(result))
    throw new AppError("INVALID_MONEY", "Amount exceeds supported precision.");
  return negative ? -result : result;
}
export function formatUSD(minor: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(minor / 100);
}
export function checkedSum(values: number[]): number {
  return values.reduce((a, b) => {
    const n = a + b;
    if (!Number.isSafeInteger(n))
      throw new AppError(
        "MONEY_OVERFLOW",
        "Financial total exceeds supported precision.",
      );
    return n;
  }, 0);
}
/** Round a positive cadence ratio to the nearest cent without a floating-point intermediate. */
export function normalizedMinor(
  minor: number,
  numerator: number,
  denominator: number,
): number {
  if (
    !Number.isSafeInteger(minor) ||
    minor < 0 ||
    !Number.isSafeInteger(numerator) ||
    numerator < 0 ||
    !Number.isSafeInteger(denominator) ||
    denominator <= 0
  )
    throw new AppError("INVALID_MONEY", "Invalid cadence amount.");
  const result =
    (BigInt(minor) * BigInt(numerator) + BigInt(Math.floor(denominator / 2))) /
    BigInt(denominator);
  if (result > BigInt(Number.MAX_SAFE_INTEGER))
    throw new AppError(
      "MONEY_OVERFLOW",
      "Recurring total exceeds supported precision.",
    );
  return Number(result);
}
export const fingerprint = (value: unknown): string =>
  createHash("sha256").update(JSON.stringify(value)).digest("hex");
const day = 86_400_000;
const midnight = (value: string) => Date.parse(`${value}T00:00:00Z`);
const median = (v: number[]): number => {
  const s = [...v].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)] ?? 0;
};
export interface RecurringStream {
  id: string;
  merchant: string;
  accountId: string;
  amountMinor: number;
  cadence: "weekly" | "biweekly" | "monthly" | "annual";
  monthlyMinor: number;
  nextDate: string;
  confidence: "inferred";
  evidenceIds: string[];
  charges: { date: string; minor: number }[];
  evidenceHash: string;
}
export function detectRecurring(
  transactions: Transaction[],
): RecurringStream[] {
  const groups = new Map<string, Transaction[]>();
  for (const t of transactions.filter(
    (t) =>
      t.type === "expense" &&
      !t.pending &&
      !t.excluded &&
      t.amount.minor < 0 &&
      t.merchant.trim(),
  )) {
    const key = `${t.accountId}:${t.merchant.toLowerCase().trim().replace(/\s+/g, " ")}`;
    groups.set(key, [...(groups.get(key) ?? []), t]);
  }
  const result: RecurringStream[] = [];
  for (const [key, values] of groups) {
    const sorted = values.sort((a, b) => a.date.localeCompare(b.date));
    if (sorted.length < 3) continue;
    const gaps = sorted
      .slice(1)
      .map((t, i) => (midnight(t.date) - midnight(sorted[i].date)) / day);
    const gap = median(gaps);
    const spec = [
      { cadence: "weekly", days: 7, tolerance: 2, annual: 52 },
      { cadence: "biweekly", days: 14, tolerance: 3, annual: 26 },
      { cadence: "monthly", days: 30.44, tolerance: 5, annual: 12 },
      { cadence: "annual", days: 365.25, tolerance: 10, annual: 1 },
    ] as const;
    const match = spec.find(
      (s) =>
        Math.abs(gap - s.days) <= s.tolerance &&
        gaps.every((g) => Math.abs(g - s.days) <= s.tolerance),
    );
    const amounts = sorted.map((t) => Math.abs(t.amount.minor));
    const typical = median(amounts);
    if (
      !match ||
      amounts.some((n) => Math.abs(n - typical) > Math.max(100, typical * 0.25))
    )
      continue;
    const last = sorted[sorted.length - 1];
    const next = new Date(midnight(last.date));
    if (match.cadence === "monthly") {
      const dom = next.getUTCDate();
      next.setUTCDate(1);
      next.setUTCMonth(next.getUTCMonth() + 1);
      const end = new Date(
        Date.UTC(next.getUTCFullYear(), next.getUTCMonth() + 1, 0),
      ).getUTCDate();
      next.setUTCDate(Math.min(dom, end));
    } else if (match.cadence === "annual")
      next.setUTCFullYear(next.getUTCFullYear() + 1);
    else next.setUTCDate(next.getUTCDate() + match.days);
    const charges = sorted.map((t) => ({
      date: t.date,
      minor: Math.abs(t.amount.minor),
    }));
    result.push({
      id: fingerprint(key).slice(0, 32),
      merchant: last.merchant,
      accountId: last.accountId,
      amountMinor: Math.abs(last.amount.minor),
      cadence: match.cadence,
      monthlyMinor: normalizedMinor(
        Math.abs(last.amount.minor),
        match.annual,
        12,
      ),
      nextDate: next.toISOString().slice(0, 10),
      confidence: "inferred",
      evidenceIds: sorted.map((t) => t.id),
      charges,
      evidenceHash: fingerprint({
        merchant: last.merchant,
        accountId: last.accountId,
        charges,
        evidenceIds: sorted.map((t) => t.id),
      }),
    });
  }
  return result.sort((a, b) => a.nextDate.localeCompare(b.nextDate));
}
export const categoryKey = (value: string) =>
  value.normalize("NFKC").trim().toLowerCase();
export function budgetSummary(
  transactions: Transaction[],
  budgets: Budget[],
  today: string,
) {
  const month = today.slice(0, 7);
  const now = new Date(`${today}T12:00:00Z`);
  const totalDays = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0),
  ).getUTCDate();
  const daysLeft = totalDays - now.getUTCDate() + 1;
  const expenses = transactions.filter(
    (t) =>
      t.date.startsWith(month) &&
      (t.type === "expense" || t.type === "refund") &&
      !t.excluded &&
      !t.pending,
  );
  const categories = budgets
    .filter((b) => b.month === month)
    .map((b) => {
      const spentMinor =
        0 -
        checkedSum(
          expenses
            .filter((t) => categoryKey(t.category) === categoryKey(b.category))
            .map((t) => t.amount.minor),
        );
      const remainingMinor = checkedSum([b.limit.minor, -spentMinor]);
      return {
        id: b.id,
        category: b.category,
        spentMinor,
        plannedMinor: b.limit.minor,
        remainingMinor,
        dailyMinor: Math.floor(Math.max(0, remainingMinor) / daysLeft),
        aheadOfPace:
          BigInt(spentMinor) * BigInt(totalDays) >
          BigInt(b.limit.minor) * BigInt(now.getUTCDate()),
      };
    });
  return {
    month,
    daysLeft,
    spentMinor: 0 - checkedSum(expenses.map((t) => t.amount.minor)),
    plannedMinor: checkedSum(categories.map((c) => c.plannedMinor)),
    categories,
  };
}
export function forecast(input: {
  balanceMinor: number;
  balanceAsOf: string;
  /** Server observation time, distinct from the account's local calendar date. */
  asOf: string;
  today: string;
  coverageComplete: boolean;
  /** Verified continuous ingestion coverage, never inferred from first/last charges.
   * accountIds contains only the USD cash accounts represented in balanceMinor. */
  historyCoverage?: { fromDate: string; throughDate: string; accountIds: string[] };
  transactions: Transaction[];
  commitments: {
    date: string;
    minor: number;
    historicalEvidenceIds?: string[];
  }[];
  horizon: 7 | 14 | 30;
}) {
  const unavailable = (reason: string) => ({ eligible: false as const, reason });
  const observation = (value: string, allowDate = false) =>
    (allowDate && date.safeParse(value).success) ||
    (typeof value === "string" &&
      /^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,9})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$/.test(value) &&
      date.safeParse(value.slice(0, 10)).success && Number.isFinite(Date.parse(value)));
  const asOf = Date.parse(input.asOf), balanceAsOf = Date.parse(input.balanceAsOf);
  if (
    !date.safeParse(input.today).success ||
    !observation(input.asOf) || !observation(input.balanceAsOf, true) ||
    !Number.isFinite(asOf) || !Number.isFinite(balanceAsOf) ||
    Math.abs(midnight(input.today) - asOf) > 2 * day ||
    balanceAsOf > asOf || asOf - balanceAsOf > day ||
    !Number.isSafeInteger(input.balanceMinor) ||
    ![7, 14, 30].includes(input.horizon)
  ) return unavailable("A valid current cash balance and observation time are required.");
  if (
    !input.coverageComplete
  )
    return unavailable("Current balances and complete account coverage are required.");
  const start = midnight(input.today), coverage = input.historyCoverage;
  if (
    !coverage || !date.safeParse(coverage.fromDate).success ||
    !date.safeParse(coverage.throughDate).success ||
    midnight(coverage.fromDate) > start - 56 * day ||
    midnight(coverage.throughDate) < start - day ||
    midnight(coverage.throughDate) > start ||
    !coverage.accountIds.length || coverage.accountIds.some(id => !id.trim()) ||
    new Set(coverage.accountIds).size !== coverage.accountIds.length
  ) return unavailable("Eight weeks of verified continuous cash-account coverage are required.");
  if (
    input.transactions.some(t => !date.safeParse(t.date).success || !Number.isSafeInteger(t.amount.minor)) ||
    input.commitments.some(c => !date.safeParse(c.date).success || !Number.isSafeInteger(c.minor))
  ) return unavailable("Financial dates and amounts need review before a projection is available.");
  const scheduledEvidence = new Set(
    input.commitments.flatMap((c) => c.historicalEvidenceIds ?? []),
  );
  const past = input.transactions.filter(
    (t) =>
      coverage.accountIds.includes(t.accountId) &&
      t.type === "expense" &&
      !scheduledEvidence.has(t.id) &&
      !t.pending &&
      !t.excluded &&
      midnight(t.date) < start &&
      midnight(t.date) >= start - 56 * day,
  );
  const daily = Array.from(
    { length: 56 },
    (_, i) =>
      -checkedSum(
        past
          .filter((t) => midnight(t.date) === start - (i + 1) * day)
          .map((t) => t.amount.minor),
      ),
  );
  // Weekly blocks retain infrequent spending; daily medians can incorrectly become zero.
  const weekly = Array.from({ length: 8 }, (_, i) =>
    checkedSum(daily.slice(i * 7, i * 7 + 7)),
  );
  const dailyMedian = Math.round(median(weekly) / 7);
  const deviations = weekly.map((n) => Math.abs(n - dailyMedian * 7));
  const spread = Math.round(median(deviations) / Math.sqrt(7));
  const scheduledMinor = checkedSum(
    input.commitments
      .filter(
        (c) =>
          midnight(c.date) >= start &&
          midnight(c.date) < start + input.horizon * day,
      )
      .map((c) => c.minor),
  );
  const expectedMinor = checkedSum([
    input.balanceMinor,
    scheduledMinor,
    -normalizedMinor(dailyMedian, input.horizon, 1),
  ]);
  const width = Math.round(1.65 * spread * Math.sqrt(input.horizon));
  return {
    eligible: true as const,
    modelVersion: "robust-cash-baseline-v2",
    horizon: input.horizon,
    asOf: input.asOf,
    balanceAsOf: input.balanceAsOf,
    accountIds: [...coverage.accountIds],
    historyFromDate: coverage.fromDate,
    historyThroughDate: coverage.throughDate,
    expectedMinor,
    lowMinor: checkedSum([expectedMinor, -width]),
    highMinor: checkedSum([expectedMinor, width]),
    assumptions: [
      "Historical median weekly cash-account spending",
      "Credit purchases are excluded; supplied card-payment commitments affect cash once",
      "Only supplied commitments and confirmed income",
      "Illustrative range; calibration must pass before public availability",
    ],
  };
}
export function explicitExpenseAmounts(text: string): number[] {
  if (
    text.length > 4000 ||
    new RegExp(captureRules.corrections, "i").test(text) ||
    new RegExp(captureRules.unsupportedCurrency, "i").test(text)
  )
    return [];
  const pattern = new RegExp(captureRules.amounts, "gi");
  const matches = [...text.matchAll(pattern)];
  if (
    new RegExp(captureRules.unparsedMinorUnits, "i").test(
      text.replace(pattern, " "),
    )
  )
    return [];
  const amounts: number[] = [];
  for (const match of matches) {
    let minor: number;
    try {
      if (match[4] !== undefined) minor = Number(match[4]);
      else {
        let value = (match[1] ?? match[3]).replace(/,/g, "");
        if (match[2] !== undefined) {
          if (value.includes(".")) return [];
          value += "." + match[2].padStart(2, "0");
        }
        minor = parseUSD(value);
      }
    } catch {
      return [];
    }
    if (
      !Number.isSafeInteger(minor) ||
      minor <= 0 ||
      minor > 9_007_199_254_740_900
    )
      return [];
    amounts.push(minor);
  }
  return amounts;
}

export function parseExpenseText(text: string) {
  const amounts = explicitExpenseAmounts(text);
  const category = /lunch|dinner|coffee|grocery/i.test(text)
    ? "Food"
    : /train|taxi|uber|gas/i.test(text)
      ? "Transport"
      : "Other";
  return {
    amountMinor: amounts.length === 1 ? amounts[0] : null,
    category,
    requiresReview: true,
    ambiguity:
      amounts.length === 1
        ? null
        : "Select the expense total; the text does not identify one unambiguous amount.",
  };
}
