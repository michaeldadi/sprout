export function canIndexRequest(
  request: Request,
  origin = process.env.SPROUT_SITE_ORIGIN || process.env.VITE_SITE_ORIGIN,
  enabled = process.env.VITE_SITE_INDEXABLE === 'true'
) {
  if (!enabled || !origin) return false;
  try {
    return new URL(request.url).host === new URL(origin).host;
  } catch {
    return false;
  }
}
