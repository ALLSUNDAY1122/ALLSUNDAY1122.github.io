import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

/**
 * ルートレイアウト。
 * このアプリは単一画面（app/index.tsx の WebView）のみで構成される
 * 薄いネイティブラッパーのため、ヘッダーは非表示にしている。
 */
export default function RootLayout() {
  return (
    <>
      <StatusBar style="dark" />
      <Stack
        screenOptions={{
          headerShown: false,
        }}
      />
    </>
  );
}
