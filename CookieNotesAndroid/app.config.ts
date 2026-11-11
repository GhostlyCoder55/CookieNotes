import type { ConfigContext, ExpoConfig } from 'expo/config';

const ANDROID_TEST_ADMOB_APP_ID = 'ca-app-pub-3940256099942544~3347511713';
const IOS_PLACEHOLDER_ADMOB_APP_ID = 'ca-app-pub-3940256099942544~1458002511';

export default ({ config }: ConfigContext): ExpoConfig => {
  const androidAppId =
    process.env.EXPO_PUBLIC_ADMOB_ANDROID_APP_ID?.trim() || ANDROID_TEST_ADMOB_APP_ID;

  return {
    ...config,
    name: 'CookieNotes',
    slug: 'cookienotes',
    scheme: 'cookienotes',
    version: '1.0.0',
    orientation: 'portrait',
    icon: './assets/branding/icon.png',
    userInterfaceStyle: 'dark',
    backgroundColor: '#171412',
    android: {
      package: 'com.gc.cookienotes',
      versionCode: 1,
      adaptiveIcon: {
        backgroundColor: '#CD9035',
        foregroundImage: './assets/branding/adaptive-icon-foreground.png',
        monochromeImage: './assets/branding/adaptive-icon-monochrome.png',
      },
      predictiveBackGestureEnabled: false,
      permissions: ['android.permission.POST_NOTIFICATIONS', 'android.permission.INTERNET'],
      blockedPermissions: ['android.permission.RECORD_AUDIO'],
    },
    web: {
      favicon: './assets/branding/favicon.png',
    },
    extra: {
      privacyPolicyUrl: 'https://ghostlycoder55.github.io/CookieNotes-privacy/',
      adMobPublisherId: 'pub-8075634631393674',
      eas: {
        projectId: '863acf4f-260b-4b1e-91ba-867ae4ccb546',
      },
    },
    plugins: [
      'expo-sqlite',
      'expo-font',
      'expo-image',
      [
        'expo-splash-screen',
        {
          backgroundColor: '#171412',
          image: './assets/branding/LaunchLogo.png',
          imageWidth: 160,
          resizeMode: 'contain',
          android: {
            backgroundColor: '#171412',
            image: './assets/branding/LaunchLogo.png',
            imageWidth: 160,
            resizeMode: 'contain',
          },
        },
      ],
      [
        'expo-notifications',
        {
          icon: './assets/branding/notification-icon.png',
          color: '#CD9035',
          defaultChannel: 'cookienotes-reminders',
          enableRemoteNotifications: false,
        },
      ],
      [
        'expo-image-picker',
        {
          cameraPermission: false,
          microphonePermission: false,
          photosPermission: 'Allow CookieNotes to select dish photos for your recipes.',
        },
      ],
      [
        'react-native-google-mobile-ads',
        {
          androidAppId,
          iosAppId: IOS_PLACEHOLDER_ADMOB_APP_ID,
          delayAppMeasurementInit: true,
          optimizeInitialization: true,
          optimizeAdLoading: true,
        },
      ],
      [
        'expo-share-intent',
        {
          disableIOS: true,
          androidIntentFilters: ['text/*', 'image/*'],
        },
      ],
    ],
  };
};
