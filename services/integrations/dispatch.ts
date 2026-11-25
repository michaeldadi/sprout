/** Wake only after the job transaction commits. Acceptance never depends on
 * this best-effort signal; the persistent queue and recovery schedule remain
 * authoritative. A short timeout keeps mobile requests bounded. */
export async function wakeDispatcher(
  key: string,
  send: typeof fetch = fetch,
): Promise<boolean> {
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  const project = process.env.APPWRITE_FUNCTION_PROJECT_ID;
  if (!endpoint || !project || !key) return false;
  try {
    const response = await send(
      `${endpoint}/functions/sprout-dispatcher/executions`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-appwrite-project": project,
          "x-appwrite-key": key,
        },
        body: JSON.stringify({ async: true, body: "{}" }),
        signal: AbortSignal.timeout(1500),
      },
    );
    return response.ok;
  } catch {
    return false;
  }
}
