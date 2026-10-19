export function extractErrorText(error) {
  if (!error) return '';
  if (typeof error === 'string') return error;

  const parts = [];

  if (error.message) parts.push(String(error.message));
  if (error.code) parts.push(String(error.code));
  if (error.status) parts.push(String(error.status));
  if (error.statusCode) parts.push(String(error.statusCode));

  const responseData = error.response?.data;
  if (responseData) {
    if (typeof responseData === 'string') parts.push(responseData);
    else {
      try {
        parts.push(JSON.stringify(responseData));
      } catch (_) {
        // Ignore serialization issues and continue with what we have.
      }
    }
  }

  if (error.cause) {
    const causeText = extractErrorText(error.cause);
    if (causeText) parts.push(causeText);
  }

  if (parts.length === 0) {
    try {
      parts.push(JSON.stringify(error));
    } catch (_) {
      parts.push(String(error));
    }
  }

  return parts.join(' | ');
}

export function classifyRetryableWriteError(error) {
  const text = extractErrorText(error).toLowerCase();
  const statusTextMatch = text.match(/\b(502|503|504|520|522|524)\b/);
  const statusFromText = statusTextMatch ? Number(statusTextMatch[1]) : null;
  const statusFromError = Number(error?.status || error?.statusCode || NaN);
  const status = Number.isFinite(statusFromError) ? statusFromError : statusFromText;

  const isTimeoutLike =
    text.includes('statement timeout') ||
    text.includes('canceling statement') ||
    text.includes('deadlock') ||
    text.includes('could not serialize') ||
    text.includes('lock timeout');

  const isGatewayLike =
    [502, 503, 504, 520, 522, 524].includes(status) ||
    text.includes('bad gateway') ||
    text.includes('gateway timeout') ||
    (text.includes('cloudflare') && (text.includes('502') || text.includes('503') || text.includes('504'))) ||
    (text.includes('<html') && (text.includes('502') || text.includes('503') || text.includes('504')));

  const isNetworkLike =
    text.includes('fetch failed') ||
    text.includes('network') ||
    text.includes('socket hang up') ||
    text.includes('ecconnreset') ||
    text.includes('econnreset') ||
    text.includes('etimedout') ||
    text.includes('connection terminated unexpectedly') ||
    text.includes('connection reset');

  if (isTimeoutLike) {
    return { retryable: true, splitPreferred: true, reason: 'timeout/lock contention' };
  }
  if (isGatewayLike) {
    return { retryable: true, splitPreferred: false, reason: 'upstream gateway' };
  }
  if (isNetworkLike) {
    return { retryable: true, splitPreferred: false, reason: 'network/transient transport' };
  }

  return { retryable: false, splitPreferred: false, reason: 'non-retryable' };
}

export function computeRetryBackoffMs(attempt, { baseMs = 300, capMs = 8000 } = {}) {
  const exp = Math.min(capMs, baseMs * (2 ** Math.max(0, attempt - 1)));
  const jitter = Math.floor(Math.random() * 250);
  return exp + jitter;
}

// Use only for idempotent writes, creating a fresh query builder on each attempt.
export async function retryPsnWrite(operation, {
  label,
  maxAttempts = 6,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  onRetry = ({ attempt, reason }) => console.warn(`[PSN] ${label}: retrying after attempt ${attempt} (${reason})`),
} = {}) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    let result;
    let error;
    try {
      result = await operation();
      error = result?.error;
    } catch (caught) {
      error = caught;
    }
    if (!error) return result;
    const classification = classifyRetryableWriteError(error);
    if (!classification.retryable || attempt === maxAttempts) {
      throw new Error(`${label}: ${extractErrorText(error)}`, { cause: error });
    }
    onRetry({ attempt, reason: classification.reason });
    await sleep(computeRetryBackoffMs(attempt));
  }
}
