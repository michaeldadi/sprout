/** Portable patterns shared with Swift and Kotlin by the contract generator. */
const number = String.raw`(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?`;
const prefix = String.raw`(?:\$|USD\s*\$?)`;
export const captureRules = {
  corrections: String.raw`\b(?:each|actually|corrected|correction|instead|sorry|not|refund(?:ed)?|credited|received|earned|income|reimbursed|reimbursement|negative|minus)\b|\b(?:make that|rather than|i mean|i meant)\b|(?:\$|USD)\s*[\d,.]+\s*(?:[-–—]|to)\s*\$?\s*\d|\d[\d,.]*\s*(?:[-–—]|to)\s*\d[\d,.]*\s*(?:dollars?|bucks?|USD)|(?<![\w])[-−]\s*(?:\$|USD\s*)?\s*\d`,
  unsupportedCurrency: String.raw`[€£¥₹]|\b(?:CAD|EUR|GBP|AUD|NZD|JPY|CNY|INR|CHF)\b`,
  amounts: String.raw`(?<![-\w.,/:])(?:${prefix}\s*)?(${number})\s*(?:USD|(?:US\s*)?(?:dollars?|bucks?))(?:\s*(?:and\s*)?(\d{1,2})\s*cents?)?\b|(?<![-\w.,/:])${prefix}\s*(${number})(?![\d,:/]|\.(?:\d|\.))|(?<![-\w.,/:])(\d+)\s*cents?\b`,
  unparsedMinorUnits: String.raw`\bcents?\b`,
} as const;
