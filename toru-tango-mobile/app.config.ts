import type { ExpoConfig, ConfigContext } from 'expo/config';

// Build 9: real-device QA fixes from 2026-08-21 video review.
export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: '撮る単語帳',
  slug: 'toru-tango',
  owner: 'allsunday1122',
  version: '1.0.0',
  orientation: 'portrait',
  scheme: 'torutango',
  icon: './assets/icon-appstore.png',
  userInterfaceStyle: 'light',
  ios: {
    supportsTablet: false,
    bundleIdentifier: 'com.allsunday1122.torutango',
    buildNumber: '9',
    icon: './assets/icon-appstore.png',
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
      'expo-splash-screen',
      {
        backgroundColor: '#14a9bf',
        image: './assets/icon-appstore.png',
        imageWidth: 200,
        resizeMode: 'contain'
      }
    ],
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
    supportUrl: 'https://allsunday1122.github.io/toru-tango/',
    eas: {
      projectId: '96443b56-fef4-4a25-b5e9-831eaa4ec854'
    }
  }
});