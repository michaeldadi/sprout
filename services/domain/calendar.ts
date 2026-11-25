import { AppError, date as calendarDate } from "../contracts";

const minute = 60_000,
  day = 86_400_000;
const formatters = new Map<string, Intl.DateTimeFormat>();
function parts(at: number, timezone: string) {
  let formatter = formatters.get(timezone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    });
    if (formatters.size >= 128) formatters.clear();
    formatters.set(timezone, formatter);
  }
  const values = formatter.formatToParts(new Date(at));
  const value = (name: Intl.DateTimeFormatPartTypes) =>
    Number(values.find((p) => p.type === name)!.value);
  return Date.UTC(
    value("year"),
    value("month") - 1,
    value("day"),
    value("hour"),
    value("minute"),
  );
}

/** Local wall-clock time. A repeated time uses its first occurrence; a missing
 * DST minute advances to the first real local minute, with a bounded search. */
export function localInstant(
  date: string,
  minuteOfDay: number,
  timezone: string,
): Date {
  calendarDate.parse(date);
  if (!Number.isInteger(minuteOfDay) || minuteOfDay < 0 || minuteOfDay >= 1440)
    throw new AppError("INVALID_TIME", "Choose a valid local time.");
  const target = Date.parse(`${date}T00:00:00Z`) + minuteOfDay * minute;
  try {
    const offsets = [
      ...new Set(
        [-day, 0, day].map(
          (delta) => parts(target + delta, timezone) - (target + delta),
        ),
      ),
    ];
    for (let shift = 0; shift <= 180; shift++) {
      const wall = target + shift * minute;
      const matches = offsets
        .map((offset) => wall - offset)
        .filter((candidate) => parts(candidate, timezone) === wall)
        .sort((a, b) => a - b);
      if (matches.length) return new Date(matches[0]);
    }
  } catch {
    throw new AppError("INVALID_TIMEZONE", "Choose a supported timezone.");
  }
  throw new AppError("INVALID_TIME", "This local time could not be scheduled.");
}

export function reminderDue(
  renewalDate: string,
  daysBefore: number,
  timezone: string,
) {
  calendarDate.parse(renewalDate);
  if (!Number.isInteger(daysBefore) || daysBefore < 0 || daysBefore > 30)
    throw new AppError(
      "INVALID_TIME",
      "Choose a reminder within 30 days of renewal.",
    );
  const date = new Date(
    Date.parse(`${renewalDate}T00:00:00Z`) - daysBefore * day,
  )
    .toISOString()
    .slice(0, 10);
  return localInstant(date, 9 * 60, timezone);
}

export interface QuietHours {
  enabled: boolean;
  startMinute: number;
  endMinute: number;
}
export const defaultQuietHours: QuietHours = {
  enabled: true,
  startMinute: 21 * 60,
  endMinute: 8 * 60,
};

/** Walk actual minutes rather than adding wall-clock hours. This handles both
 * occurrences of a repeated DST hour and a missing quiet-hours end time. */
export function nextAllowedDelivery(
  at: Date,
  timezone: string,
  quiet: QuietHours = defaultQuietHours,
): Date {
  if (!Number.isFinite(at.getTime()))
    throw new AppError("INVALID_TIME", "Choose a valid delivery time.");
  for (const value of [quiet.startMinute, quiet.endMinute])
    if (!Number.isInteger(value) || value < 0 || value >= 1440)
      throw new AppError("INVALID_TIME", "Choose a valid quiet-hours time.");
  if (quiet.startMinute === quiet.endMinute)
    throw new AppError(
      "INVALID_TIME",
      "Quiet hours must have different start and end times.",
    );
  try {
    const isQuiet = (time: number) => {
      const wall = new Date(parts(time, timezone)),
        local = wall.getUTCHours() * 60 + wall.getUTCMinutes();
      return quiet.startMinute < quiet.endMinute
        ? local >= quiet.startMinute && local < quiet.endMinute
        : local >= quiet.startMinute || local < quiet.endMinute;
    };
    if (!quiet.enabled || !isQuiet(at.getTime())) {
      parts(at.getTime(), timezone);
      return at;
    }
    const start = Math.floor(at.getTime() / minute) * minute;
    for (let i = 1; i <= 27 * 60; i++) {
      const candidate = start + i * minute;
      if (!isQuiet(candidate)) return new Date(candidate);
    }
  } catch {
    throw new AppError("INVALID_TIMEZONE", "Choose a supported timezone.");
  }
  throw new AppError("INVALID_TIME", "Quiet hours could not be scheduled.");
}

export function localDate(at: Date, timezone: string): string {
  if (!Number.isFinite(at.getTime()))
    throw new AppError("INVALID_TIME", "Choose a valid date.");
  try {
    return new Date(parts(at.getTime(), timezone)).toISOString().slice(0, 10);
  } catch {
    throw new AppError("INVALID_TIMEZONE", "Choose a supported timezone.");
  }
}

/** The next Monday at 09:00 in the account timezone; missed weeks never fan out. */
export function nextWeeklyReview(
  after: Date,
  timezone: string,
  quiet = defaultQuietHours,
) {
  const today = localDate(after, timezone),
    base = Date.parse(today + "T00:00:00Z");
  for (let days = 0; days <= 7; days++) {
    const date = new Date(base + days * day);
    if (date.getUTCDay() !== 1) continue;
    const candidate = nextAllowedDelivery(
      localInstant(date.toISOString().slice(0, 10), 9 * 60, timezone),
      timezone,
      quiet,
    );
    if (candidate.getTime() > after.getTime()) return candidate;
  }
  throw new AppError(
    "INVALID_TIME",
    "The next weekly review could not be scheduled.",
  );
}
