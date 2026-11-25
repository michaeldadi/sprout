import { AppError } from "../contracts";

export interface CancellationCoverage {
  merchantId: string;
  supported: boolean;
  verifiedAt: string | null;
  conditions: string[];
}
export interface PartnerOutcome {
  reference: string;
  state:
    | "awaiting_partner"
    | "submitted"
    | "verifying"
    | "succeeded"
    | "failed"
    | "needs_attention";
  evidenceReference?: string;
  effectiveAt?: string;
}
export interface CancellationPartner {
  eligibility(merchant: string): Promise<CancellationCoverage>;
  createSession(input: {
    owner: string;
    actionId: string;
    idempotencyKey: string;
  }): Promise<{ url: string; expiresAt: string }>;
  reconcile(reference: string): Promise<PartnerOutcome>;
  deleteIdentity(owner: string): Promise<void>;
}
/** Deliberately closed until partner terms, SDKs and authoritative outcome semantics pass the proof. */
export class UnconfiguredCancellationPartner implements CancellationPartner {
  async eligibility(merchant: string) {
    return {
      merchantId: merchant,
      supported: false,
      verifiedAt: null,
      conditions: [
        "Cancellation coverage has not been verified for this environment.",
      ],
    };
  }
  async createSession(): Promise<never> {
    throw new AppError(
      "PARTNER_NOT_VERIFIED",
      "Cancellation coverage and partner execution have not been verified.",
      503,
    );
  }
  async reconcile(): Promise<never> {
    throw new AppError(
      "PARTNER_NOT_VERIFIED",
      "Submitted actions require operator reconciliation with the provider.",
      503,
    );
  }
  async deleteIdentity(): Promise<never> {
    throw new AppError(
      "PARTNER_NOT_VERIFIED",
      "Partner identity deletion requires verified provider access.",
      503,
    );
  }
}
export const cancellationPartner: CancellationPartner =
  new UnconfiguredCancellationPartner();
