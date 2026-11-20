const BASE = import.meta.env.VITE_API_URL || 'http://localhost:3000';
export async function api(path, options = {}) {
  const res = await fetch(`${BASE}/api${path}`, { ...options, headers: { 'Content-Type': 'application/json', ...options.headers } });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}
export const money = cents => new Intl.NumberFormat('en-CA', { style: 'currency', currency: 'CAD' }).format(cents / 100);
