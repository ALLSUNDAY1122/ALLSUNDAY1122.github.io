import React, { useRef, useState } from 'react';
import { Linking, Pressable, SafeAreaView, StyleSheet, Text, View } from 'react-native';
import { WebView } from 'react-native-webview';

const HOME_URL = 'https://allsunday1122.github.io/touroku-hanbaisha-sprint/';
const ALLOWED_ORIGIN = 'https://allsunday1122.github.io';

export default function App() {
  const webRef = useRef(null);
  const [failed, setFailed] = useState(false);

  const reload = () => {
    setFailed(false);
    requestAnimationFrame(() => webRef.current?.reload());
  };

  const shouldStart = request => {
    const url = request?.url || '';
    if (url === 'about:blank' || url.startsWith(ALLOWED_ORIGIN)) return true;
    if (/^https?:\/\//i.test(url)) Linking.openURL(url).catch(() => {});
    return false;
  };

  if (failed) {
    return (
      <SafeAreaView style={styles.safe}>
        <View style={styles.errorCard}>
          <Text style={styles.title}>ページを読み込めませんでした</Text>
          <Text style={styles.body}>通信状態を確認して、もう一度お試しください。学習記録はWebView内の端末保存領域に保持されます。</Text>
          <Pressable accessibilityRole="button" onPress={reload} style={styles.button}>
            <Text style={styles.buttonText}>再読み込み</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safe}>
      <WebView
        ref={webRef}
        source={{ uri: HOME_URL }}
        style={styles.web}
        originWhitelist={['https://*']}
        onShouldStartLoadWithRequest={shouldStart}
        onError={() => setFailed(true)}
        onHttpError={event => {
          if ((event?.nativeEvent?.statusCode || 0) >= 400) setFailed(true);
        }}
        javaScriptEnabled
        domStorageEnabled
        allowsBackForwardNavigationGestures={false}
        setSupportMultipleWindows={false}
        sharedCookiesEnabled={false}
        thirdPartyCookiesEnabled={false}
        pullToRefreshEnabled
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#FDF6EF' },
  web: { flex: 1, backgroundColor: '#FDF6EF' },
  errorCard: {
    flex: 1,
    margin: 24,
    justifyContent: 'center',
    alignItems: 'stretch',
  },
  title: { fontSize: 22, fontWeight: '800', color: '#231F1A', marginBottom: 12 },
  body: { fontSize: 15, lineHeight: 23, color: '#726B60', marginBottom: 20 },
  button: { backgroundColor: '#A8481C', paddingVertical: 14, borderRadius: 14, alignItems: 'center' },
  buttonText: { color: '#FFFFFF', fontSize: 16, fontWeight: '800' },
});
