import { Client, ExecutionMethod, Functions } from "node-appwrite";
import { AppError, type ReceiptAttach } from "../contracts";

/** File operations stay in the existing server-only private-data boundary.
 * The authenticated API forwards its verified owner, never a client owner. */
export async function invokeReceiptActor(
  owner: string,
  receipt: ReceiptAttach,
  mutationId: string,
  key: string,
) {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT!)
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID!)
    .setKey(key);
  const execution = await new Functions(client).createExecution({
    functionId: "sprout-privacy",
    async: false,
    method: ExecutionMethod.POST,
    body: JSON.stringify({ owner, receipt, mutationId }),
  });
  let value: any;
  try {
    value = JSON.parse(execution.responseBody);
  } catch {
    throw new AppError(
      "RECEIPT_RETRY",
      "Your receipt is saved locally while upload progress is recovered.",
      503,
    );
  }
  if (execution.responseStatusCode < 200 || execution.responseStatusCode >= 300)
    throw new AppError(
      value.error?.code ?? "RECEIPT_RETRY",
      value.error?.message ?? "Your private upload will retry.",
      execution.responseStatusCode || 503,
    );
  return value;
}
