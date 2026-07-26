import type { ExpoConfig, ConfigContext } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: '撮る単語帳',
  slug: 'toru-tango',
  version: '1.0.0',
  orientation: 'portrait',
  scheme: 'torutango',
  userInterfaceStyle: 'light',
  newArchEnabled: true,
  ios: {
    supportsTablet: false,
    bundleIdentifier: 'com.allsunday1122.torutango',
    buildNumber: '1',
    infoPlist: {
      NSCameraUsageDescription: '教材を撮影して単語カード作成に利用します。',
      NSPhotoLibraryUsageDescription: '教材写真を選択して単語カード作成に利用します。',
      ITSAppUsesNonExemptEncryption: false
    }
  },
  android: {
    package: 'com.allsunday1122.torutango'
  },
  plugins: [
    'expo-router',
    [
      'expo-image-picker',
      {
        photosPermission: '教材写真を選択して単語カード作成に利用します。',
        cameraPermission: '教材を撮影して単語カード作成に利用します。',
        microphonePermission: false
      }
    ]
  ],
  experiments: {
    typedRoutes: true
  },
  extra: {
    privacyPolicyUrl: 'https://allsunday1122.github.io/toru-tango/privacy-policy.html',
    supportUrl: 'https://allsunday1122.github.io/toru-tango/'
  }
});
