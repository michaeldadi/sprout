import { describe, it, expect } from "vitest";
import {
  localInstant,
  reminderDue,
  nextAllowedDelivery,
  nextWeeklyReview,
} from "../domain/calendar";

describe("local reminder scheduling", () => {
  it("keeps nine o'clock across US spring and fall transitions", () => {
    expect(reminderDue("2026-03-09", 1, "America/New_York").toISOString()).toBe(
      "2026-03-08T13:00:00.000Z",
    );
    expect(reminderDue("2026-11-02", 1, "America/New_York").toISOString()).toBe(
      "2026-11-01T14:00:00.000Z",
    );
    expect(
      reminderDue("2026-11-02", 1, "America/Los_Angeles").toISOString(),
    ).toBe("2026-11-01T17:00:00.000Z");
  });
  it("resolves missing and repeated local minutes deterministically", () => {
    expect(
      localInstant("2026-03-08", 150, "America/New_York").toISOString(),
    ).toBe("2026-03-08T07:00:00.000Z");
    expect(
      localInstant("2026-11-01", 90, "America/New_York").toISOString(),
    ).toBe("2026-11-01T05:30:00.000Z");
  });
  it("handles month/year boundaries and rejects invalid scheduling inputs", () => {
    expect(reminderDue("2027-01-01", 1, "America/New_York").toISOString()).toBe(
      "2026-12-31T14:00:00.000Z",
    );
    expect(() => reminderDue("2026-02-30", 1, "America/New_York")).toThrow();
    expect(() => reminderDue("2026-11-10", -1, "America/New_York")).toThrow();
    expect(() => reminderDue("2026-11-10", 1, "Invalid/Timezone")).toThrow();
  });
  it("defers overnight quiet hours and preserves an already allowed instant", () => {
    expect(
      nextAllowedDelivery(
        new Date("2026-11-10T03:15:20Z"),
        "America/New_York",
      ).toISOString(),
    ).toBe("2026-11-10T13:00:00.000Z");
    const allowed = new Date("2026-11-10T16:00:33Z");
    expect(nextAllowedDelivery(allowed, "America/New_York")).toBe(allowed);
    expect(
      nextAllowedDelivery(allowed, "America/New_York", {
        enabled: true,
        startMinute: 10 * 60,
        endMinute: 12 * 60,
      }).toISOString(),
    ).toBe("2026-11-10T17:00:00.000Z");
  });
  it("honors the second repeated hour and the first real minute after a DST gap", () => {
    expect(
      nextAllowedDelivery(
        new Date("2026-11-01T06:15:00Z"),
        "America/New_York",
        { enabled: true, startMinute: 0, endMinute: 90 },
      ).toISOString(),
    ).toBe("2026-11-01T06:30:00.000Z");
    expect(
      nextAllowedDelivery(
        new Date("2026-03-08T06:45:00Z"),
        "America/New_York",
        { enabled: true, startMinute: 0, endMinute: 150 },
      ).toISOString(),
    ).toBe("2026-03-08T07:00:00.000Z");
  });
  it("validates quiet-hour inputs even when delivery is disabled", () => {
    expect(() =>
      nextAllowedDelivery(new Date(), "America/New_York", {
        enabled: false,
        startMinute: 0,
        endMinute: 0,
      }),
    ).toThrow();
    expect(() => nextAllowedDelivery(new Date(), "Invalid/Timezone")).toThrow();
    expect(() =>
      nextAllowedDelivery(new Date(NaN), "America/New_York"),
    ).toThrow();
    expect(() =>
      nextAllowedDelivery(new Date(), "America/New_York", {
        enabled: true,
        startMinute: -1,
        endMinute: 0,
      }),
    ).toThrow();
  });
  it("schedules one next weekly review across DST and skips missed weeks", () => {
    expect(
      nextWeeklyReview(
        new Date("2026-03-06T15:00:00Z"),
        "America/New_York",
      ).toISOString(),
    ).toBe("2026-03-09T13:00:00.000Z");
    expect(
      nextWeeklyReview(
        new Date("2026-11-02T14:00:00Z"),
        "America/New_York",
      ).toISOString(),
    ).toBe("2026-11-09T14:00:00.000Z");
    expect(
      nextWeeklyReview(new Date("2026-11-02T13:00:00Z"), "America/New_York", {
        enabled: true,
        startMinute: 8 * 60,
        endMinute: 10 * 60,
      }).toISOString(),
    ).toBe("2026-11-02T15:00:00.000Z");
  });
});
