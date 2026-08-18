export function parseShareKey(href) {
  const url = new URL(href);
  const hashParams = new URLSearchParams(url.hash.startsWith('#') ? url.hash.slice(1) : url.hash);
  const id = url.searchParams.get('id');
  const legacyToken = url.searchParams.get('token');
  const fragmentToken = hashParams.get('token');
  const token = fragmentToken || legacyToken;
  return { id, token, legacyToken, fragmentToken };
}

export function normalizeShareURL(href, { id, token }) {
  const url = new URL(href);
  if (token) {
    url.searchParams.delete('token');
    url.searchParams.delete('id');
    url.hash = new URLSearchParams({ token }).toString();
  } else if (id) {
    url.searchParams.set('id', id);
    url.hash = '';
  }
  return url.toString();
}
