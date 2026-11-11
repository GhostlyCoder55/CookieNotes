import React, { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import { Nunito_400Regular } from '@expo-google-fonts/nunito/400Regular';
import { Nunito_600SemiBold } from '@expo-google-fonts/nunito/600SemiBold';
import { Nunito_700Bold } from '@expo-google-fonts/nunito/700Bold';
import { Nunito_800ExtraBold } from '@expo-google-fonts/nunito/800ExtraBold';
import { useFonts } from '@expo-google-fonts/nunito/useFonts';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppTheme } from './src/constants/theme';
import { AppStateProvider, useAppState } from './src/context/AppStateContext';
import { LanguageProvider } from './src/localization/LanguageContext';
import { RootNavigator } from './src/navigation/RootNavigator';

void SplashScreen.preventAutoHideAsync().catch(() => {});

function AppContent({ fontsSettled }: { fontsSettled: boolean }) {
  const { isReady } = useAppState();

  useEffect(() => {
    if (fontsSettled && isReady) {
      void SplashScreen.hideAsync().catch(() => {});
    }
  }, [fontsSettled, isReady]);

  return (
    <View style={styles.root}>
      <StatusBar style="light" />
      <RootNavigator />
    </View>
  );
}

export default function App() {
  const [fontsLoaded, fontError] = useFonts({
    Nunito_400Regular,
    Nunito_600SemiBold,
    Nunito_700Bold,
    Nunito_800ExtraBold,
  });

  const fontsSettled = fontsLoaded || Boolean(fontError);

  return (
    <View style={styles.root}>
      <SafeAreaProvider>
        <LanguageProvider>
          <AppStateProvider>
            <AppContent fontsSettled={fontsSettled} />
          </AppStateProvider>
        </LanguageProvider>
      </SafeAreaProvider>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
});
