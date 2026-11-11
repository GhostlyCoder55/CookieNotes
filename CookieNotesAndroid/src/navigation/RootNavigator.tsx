import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { DarkTheme, NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppUpdateModal } from '../components/modals/AppUpdateModal';
import { PrivacyChoicesModal } from '../components/modals/PrivacyChoicesModal';
import { WelcomeBackModal } from '../components/modals/WelcomeBackModal';
import { AppTheme, FontFamily } from '../constants/theme';
import { useAppState } from '../context/AppStateContext';
import { useLanguage } from '../localization/LanguageContext';
import { AboutScreen } from '../screens/about/AboutScreen';
import { DiscoverDetailScreen } from '../screens/discover/DiscoverDetailScreen';
import { DiscoverScreen } from '../screens/discover/DiscoverScreen';
import { GroceryListScreen } from '../screens/grocery/GroceryListScreen';
import { RecipeDetailScreen } from '../screens/library/RecipeDetailScreen';
import { RecipeListScreen } from '../screens/library/RecipeListScreen';
import { TutorialScreen } from '../screens/onboarding/TutorialScreen';
import type {
  DiscoverStackParamList,
  LibraryStackParamList,
  MainTabParamList,
} from '../types/models';

const LibraryStack = createNativeStackNavigator<LibraryStackParamList>();
const DiscoverStack = createNativeStackNavigator<DiscoverStackParamList>();
const Tab = createBottomTabNavigator<MainTabParamList>();

const COOKIENOTES_NAV_THEME = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: AppTheme.burntOrange,
    background: AppTheme.background,
    card: AppTheme.background,
    text: AppTheme.primaryText,
    border: AppTheme.separator,
    notification: AppTheme.burntOrange,
  },
};

function LibraryStackNavigator() {
  return (
    <LibraryStack.Navigator
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: AppTheme.background },
        animation: 'slide_from_right',
      }}
    >
      <LibraryStack.Screen name="RecipeList" component={RecipeListScreen} />
      <LibraryStack.Screen name="RecipeDetail" component={RecipeDetailScreen} />
    </LibraryStack.Navigator>
  );
}

function DiscoverStackNavigator() {
  return (
    <DiscoverStack.Navigator
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: AppTheme.background },
        animation: 'slide_from_right',
      }}
    >
      <DiscoverStack.Screen name="DiscoverHome" component={DiscoverScreen} />
      <DiscoverStack.Screen name="DiscoverDetail" component={DiscoverDetailScreen} />
    </DiscoverStack.Navigator>
  );
}

export function RootNavigator() {
  const { t } = useLanguage();
  const insets = useSafeAreaInsets();
  const {
    isReady,
    hasSelectedInitialLanguage,
    hasCompletedTutorial,
    welcomeBackVisible,
    lastLoginDate,
    startCookingFromWelcome,
    dismissWelcomeBack,
    updateInfo,
    performAppUpdate,
    dismissAppUpdate,
    adConsentChoice,
    adState,
    applyAdConsentChoice,
    closePrivacySheet,
  } = useAppState();

  if (!isReady) {
    return <View style={styles.bootScreen} />;
  }

  const shouldShowOnboarding =
    !hasSelectedInitialLanguage || !hasCompletedTutorial;

  if (shouldShowOnboarding) {
    return (
      <View style={styles.bootScreen}>
        <TutorialScreen />
      </View>
    );
  }

  const bottomPadding = Math.max(insets.bottom, 6);

  return (
    <View style={styles.bootScreen}>
      <NavigationContainer theme={COOKIENOTES_NAV_THEME}>
        <Tab.Navigator
          screenOptions={({ route }) => ({
            headerShown: false,
            tabBarActiveTintColor: AppTheme.burntOrange,
            tabBarInactiveTintColor: AppTheme.tertiaryText,
            tabBarHideOnKeyboard: true,
            tabBarLabelStyle: {
              fontFamily: FontFamily.semiBold,
              fontSize: 12,
              marginBottom: 2,
            },
            tabBarStyle: {
              backgroundColor: AppTheme.tabBarBackground,
              borderTopColor: AppTheme.separator,
              borderTopWidth: StyleSheet.hairlineWidth,
              height: 58 + bottomPadding,
              paddingBottom: bottomPadding,
              paddingTop: 6,
            },
            tabBarIcon: ({ focused, color, size }) => {
              let iconName: keyof typeof Ionicons.glyphMap;
              switch (route.name) {
                case 'LibraryTab':
                  iconName = focused ? 'book' : 'book-outline';
                  break;
                case 'DiscoverTab':
                  iconName = focused ? 'globe' : 'globe-outline';
                  break;
                case 'ListTab':
                  iconName = focused ? 'checkbox' : 'checkbox-outline';
                  break;
                case 'AboutTab':
                  iconName = focused
                    ? 'information-circle'
                    : 'information-circle-outline';
                  break;
              }
              return <Ionicons name={iconName} size={size} color={color} />;
            },
          })}
        >
          <Tab.Screen
            name="LibraryTab"
            component={LibraryStackNavigator}
            options={{ tabBarLabel: t('Library') }}
          />
          <Tab.Screen
            name="DiscoverTab"
            component={DiscoverStackNavigator}
            options={{ tabBarLabel: t('Discover') }}
          />
          <Tab.Screen
            name="ListTab"
            component={GroceryListScreen}
            options={{ tabBarLabel: t('List') }}
          />
          <Tab.Screen
            name="AboutTab"
            component={AboutScreen}
            options={{ tabBarLabel: t('About') }}
          />
        </Tab.Navigator>
      </NavigationContainer>

      <WelcomeBackModal
        visible={welcomeBackVisible}
        lastLoginDate={lastLoginDate}
        onStartCooking={() => void startCookingFromWelcome()}
        onDismiss={() => void dismissWelcomeBack()}
      />

      <AppUpdateModal
        updateInfo={updateInfo}
        onUpdate={() => void performAppUpdate()}
        onDismiss={() => void dismissAppUpdate()}
      />

      <PrivacyChoicesModal
        visible={adState.presentPrivacySheet}
        mode={adState.privacySheetMode}
        currentChoice={adConsentChoice}
        onSelectChoice={(choice) => void applyAdConsentChoice(choice)}
        onDismiss={closePrivacySheet}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  bootScreen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
});
