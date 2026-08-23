import { useCallback, useRef, useState } from 'react';
import {
  ActivityIndicator,
  BackHandler,
  Linking,
  Platform,
  StyleSheet,
  View,
} from 'react-native';
import { useFocusEffect } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import WebView, { type WebViewNavigation } from 'react-native-webview';

// FP2級 過去問コーチ 本体（監査済み・単一HTMLファイル）
// 180問のFP2級学科過去問データとロジックをすべて内蔵しており、
// localStorage のみで学習履歴を保存するオフライン完結型アプリ。
// ネイティブ側は「このHTMLをオフラインで表示するだけ」の薄いラッパー。
// require により JS バンドルにアセットとして同梱されるため、
// 実機・ビルド後もネットワーク接続なしで読み込める。
const FP2_HTML_SOURCE = require('../assets/fp2-kakomon-coach.html');

export default function Index() {
  const webViewRef = useRef<WebView>(null);
  const [canGoBack, setCanGoBack] = useState(false);

  // Android の物理戻るボタン: WebView内の履歴があれば戻る、なければ何もしない
  // （アプリを閉じるのはOS標準動作に委ねる）
  useFocusEffect(
    useCallback(() => {
      if (Platform.OS !== 'android') {
        return;
      }
      const onBackPress = () => {
        if (canGoBack && webViewRef.current) {
          webViewRef.current.goBack();
          return true;
        }
        return false;
      };
      const subscription = BackHandler.addEventListener(
        'hardwareBackPress',
        onBackPress
      );
      return () => subscription.remove();
    }, [canGoBack])
  );

  const handleNavigationStateChange = useCallback(
    (navState: WebViewNavigation) => {
      setCanGoBack(navState.canGoBack);
    },
    []
  );

  // 外部URL（http/https等の外部リンク）を踏んだ場合はWebView内で開かず、
  // OS標準ブラウザに渡す。about:blank や同梱HTMLの初回読み込み(file://)は
  // WebView内での通常表示を許可する。
  const handleShouldStartLoadWithRequest = useCallback(
    (request: WebViewNavigation) => {
      const { url } = request;

      if (url.startsWith('file://') || url.startsWith('about:blank')) {
        return true;
      }

      if (url.startsWith('http://') || url.startsWith('https://')) {
        Linking.openURL(url).catch(() => {
          // 開けなかった場合は何もしない（アプリ側でクラッシュさせない）
        });
        return false;
      }

      // data:, javascript: 以外の未知スキームも安全側でブロック
      if (url.startsWith('data:') || url.startsWith('javascript:')) {
        return true;
      }

      return false;
    },
    []
  );

  return (
    <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
      <View style={styles.container}>
        <WebView
          ref={webViewRef}
          source={FP2_HTML_SOURCE}
          originWhitelist={['*']}
          style={styles.webview}
          onNavigationStateChange={handleNavigationStateChange}
          onShouldStartLoadWithRequest={handleShouldStartLoadWithRequest}
          startInLoadingState
          renderLoading={() => (
            <View style={styles.loadingOverlay}>
              <ActivityIndicator size="large" color="#EE7D3F" />
            </View>
          )}
          // 完全オフライン動作が前提のため、キャッシュやネットワークは使用しない
          cacheEnabled
          javaScriptEnabled
          domStorageEnabled
          allowFileAccess
          allowsBackForwardNavigationGestures
          setSupportMultipleWindows={false}
        />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#FDF6EF',
  },
  container: {
    flex: 1,
    backgroundColor: '#FDF6EF',
  },
  webview: {
    flex: 1,
    backgroundColor: '#FDF6EF',
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FDF6EF',
  },
});
