// Generic REST client for the custom backend (ADR-0022) — replaces the old
// Supabase client. Used by apps/web (and any other JS/TS caller); the
// iOS/Watch app has its own URLSession client, not this.
//
// Auth is a single static bearer token (ADR-0022), same header on every call.

export interface ApiClient {
  get<T>(path: string): Promise<T>;
  post<T>(path: string, body?: unknown): Promise<T>;
  put<T>(path: string, body?: unknown): Promise<T>;
}

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly body: unknown,
  ) {
    super(`API ${status}`);
    this.name = "ApiError";
  }
}

export function createApiClient(baseUrl: string, apiKey: string): ApiClient {
  const base = baseUrl.replace(/\/$/, "");

  async function request<T>(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    const res = await fetch(`${base}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${apiKey}`,
        ...(body === undefined ? {} : { "content-type": "application/json" }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

    const text = await res.text();
    const parsed = text ? JSON.parse(text) : null;
    if (!res.ok) throw new ApiError(res.status, parsed);
    return parsed as T;
  }

  return {
    get<T>(path: string) {
      return request<T>("GET", path);
    },
    post<T>(path: string, body?: unknown) {
      return request<T>("POST", path, body);
    },
    put<T>(path: string, body?: unknown) {
      return request<T>("PUT", path, body);
    },
  };
}
