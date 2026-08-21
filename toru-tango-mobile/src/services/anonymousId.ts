import AsyncStorage from '@react-native-async-storage/async-storage';

const ANONYMOUS_ID_KEY = 'toru-tango-anonymous-id-v1';

function createId(): string {
  const cryptoApi = globalThis.crypto as { randomUUID?: () => string } | undefined;
  if (typeof cryptoApi?.randomUUID === 'function') return cryptoApi.randomUUID();
  return `anon-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${Math.random()
    .toString(36)
    .slice(2)}`;
}

export async function getAnonymousId(): Promise<string> {
  const stored = (await AsyncStorage.getItem(ANONYMOUS_ID_KEY))?.trim();
  if (stored && stored.length <= 128) return stored;

  const id = createId();
  await AsyncStorage.setItem(ANONYMOUS_ID_KEY, id);
  return id;
}
