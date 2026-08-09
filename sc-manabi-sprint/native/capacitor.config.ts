import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'jp.allsunday1122.scmanabisprint',
  appName: '情報処理安全確保支援士',
  webDir: 'www',
  server: {
    androidScheme: 'https'
  },
  ios: {
    contentInset: 'always',
    scrollEnabled: true,
    allowsLinkPreview: false,
    backgroundColor: '#F6F0E4'
  }
};

export default config;
