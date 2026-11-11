import React, { useMemo, useRef, useState } from 'react';
import {
  FlatList,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
  Pressable,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import { Image } from 'expo-image';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { useLanguage } from '../../localization/LanguageContext';
import { hapticSelection } from '../../utils/haptics';
import { PrimaryButton } from '../../components/common/AppComponents';
import { FoodIconView } from '../../components/common/FoodIconView';
import { LanguageSelectionScreen } from './LanguageSelectionScreen';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const APP_LOGO = require('../../../assets/branding/AppLogo.png');

type TutorialPage =
  | { kind: 'language'; id: string }
  | {
      kind: 'tip';
      id: string;
      title: string;
      description: string;
      artwork: { type: 'logo' } | { type: 'icon'; iconID: string };
    };

export function TutorialScreen() {
  const { t, language } = useLanguage();
  const { selectInitialLanguage, completeTutorial } = useAppState();
  const { width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const flatListRef = useRef<FlatList<TutorialPage>>(null);

  const [currentStep, setCurrentStep] = useState(0);

  const pages: TutorialPage[] = useMemo(
    () => [
      { kind: 'language', id: 'lang' },
      {
        kind: 'tip',
        id: 'tip-0',
        title: t('Welcome to CookieNotes'),
        description: t(
          'Keep recipes, discover new ones, and cook with confidence.'
        ),
        artwork: { type: 'logo' },
      },
      {
        kind: 'tip',
        id: 'tip-1',
        title: t('Library'),
        description: t(
          'Your personal cookbook lives here. Favorite recipes, filter by meal, and open cook mode when you’re ready.'
        ),
        artwork: { type: 'icon', iconID: 'salad_bowl' },
      },
      {
        kind: 'tip',
        id: 'tip-2',
        title: t('Discover'),
        description: t(
          'Search online recipes, preview ingredients and steps, then save keepers to your library.'
        ),
        artwork: { type: 'icon', iconID: 'pepperoni_pizza' },
      },
      {
        kind: 'tip',
        id: 'tip-3',
        title: t('List'),
        description: t(
          'Keep a grocery checklist, check off items as you shop, and organize what you need.'
        ),
        artwork: { type: 'icon', iconID: 'bread_loaf' },
      },
      {
        kind: 'tip',
        id: 'tip-4',
        title: t('Ingredient art'),
        description: t(
          'Browse colourful food art when adding ingredients, or type a custom item anytime.'
        ),
        artwork: { type: 'icon', iconID: 'tomatoes_vine' },
      },
      {
        kind: 'tip',
        id: 'tip-5',
        title: t('You’re all set'),
        description: t(
          'Add a recipe you know by heart, or discover something new. Happy cooking!'
        ),
        artwork: { type: 'icon', iconID: 'cupcake' },
      },
    ],
    [t]
  );

  const pageCount = pages.length;
  const isLastStep = currentStep >= pageCount - 1;

  const handleMomentumScrollEnd = (
    event: NativeSyntheticEvent<NativeScrollEvent>
  ) => {
    const offsetX = event.nativeEvent.contentOffset.x;
    const index = Math.round(offsetX / Math.max(width, 1));
    if (index !== currentStep && index >= 0 && index < pageCount) {
      setCurrentStep(index);
      void hapticSelection();
      if (index > 0) {
        void selectInitialLanguage(language);
      }
    }
  };

  const handleSkip = async () => {
    await selectInitialLanguage(language);
    await completeTutorial();
  };

  const handleAdvance = async () => {
    if (currentStep === 0) {
      await selectInitialLanguage(language);
    }
    if (isLastStep) {
      await completeTutorial();
      return;
    }
    const next = currentStep + 1;
    setCurrentStep(next);
    void hapticSelection();
    flatListRef.current?.scrollToIndex({ index: next, animated: true });
  };

  return (
    <View
      style={[
        styles.root,
        {
          paddingTop: insets.top,
          paddingBottom: Math.max(insets.bottom, 16),
        },
      ]}
    >
      <View style={styles.topBar}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('Skip')}
          onPress={() => void handleSkip()}
          style={styles.skipBtn}
        >
          <Text style={styles.skipText}>{t('Skip')}</Text>
        </Pressable>
      </View>

      <FlatList
        ref={flatListRef}
        data={pages}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        keyExtractor={(item) => item.id}
        onMomentumScrollEnd={handleMomentumScrollEnd}
        getItemLayout={(_, index) => ({
          length: width,
          offset: width * index,
          index,
        })}
        renderItem={({ item }) => {
          if (item.kind === 'language') {
            return (
              <LanguageSelectionScreen
                onSelectLanguage={(lang) => {
                  void selectInitialLanguage(lang);
                }}
              />
            );
          }

          return (
            <View style={[styles.tipPage, { width }]}>
              <View style={styles.tipContent}>
                <View style={styles.artworkArea}>
                  {item.artwork.type === 'logo' ? (
                    <Image
                      source={APP_LOGO}
                      style={styles.appLogo}
                      contentFit="contain"
                      accessibilityElementsHidden
                    />
                  ) : (
                    <View style={styles.iconCard}>
                      <FoodIconView iconID={item.artwork.iconID} size={120} />
                    </View>
                  )}
                </View>

                <View style={styles.tipTextBlock}>
                  <Text
                    accessibilityRole="header"
                    style={styles.tipTitle}
                    numberOfLines={2}
                    adjustsFontSizeToFit
                  >
                    {item.title}
                  </Text>
                  <Text style={styles.tipDescription}>{item.description}</Text>
                </View>
              </View>
            </View>
          );
        }}
      />

      <View
        style={styles.dotsRow}
        accessible
        accessibilityLabel={t('Tip %lld of %lld', currentStep + 1, pageCount)}
      >
        {pages.map((p, idx) => {
          const active = idx === currentStep;
          return (
            <View
              key={p.id}
              style={[
                styles.dot,
                {
                  width: active ? 22 : 8,
                  backgroundColor: active
                    ? AppTheme.burntOrange
                    : AppTheme.separator,
                },
              ]}
            />
          );
        })}
      </View>

      <View style={styles.footer}>
        <PrimaryButton
          title={isLastStep ? t('Get Started') : t('Continue')}
          onPress={() => void handleAdvance()}
          style={styles.continueBtn}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  topBar: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    paddingHorizontal: 12,
    paddingTop: 6,
  },
  skipBtn: {
    minHeight: 44,
    paddingHorizontal: 16,
    justifyContent: 'center',
  },
  skipText: {
    ...Typography.body,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.secondaryText,
  },
  tipPage: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: AppTheme.paddingLarge,
  },
  tipContent: {
    width: '100%',
    maxWidth: 360,
    alignItems: 'center',
    gap: 28,
  },
  artworkArea: {
    height: 168,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  appLogo: {
    width: 136,
    height: 136,
    borderRadius: 32,
  },
  iconCard: {
    padding: 20,
    backgroundColor: AppTheme.parchment,
    borderRadius: 32,
  },
  tipTextBlock: {
    alignItems: 'center',
    gap: 8,
  },
  tipTitle: {
    ...Typography.title,
    color: AppTheme.primaryText,
    textAlign: 'center',
  },
  tipDescription: {
    ...Typography.footnote,
    color: AppTheme.secondaryText,
    textAlign: 'center',
    maxWidth: 340,
    minHeight: 54,
  },
  dotsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingTop: AppTheme.paddingSmall,
    paddingBottom: 20,
  },
  dot: {
    height: 8,
    borderRadius: 4,
  },
  footer: {
    paddingHorizontal: AppTheme.paddingLarge,
    paddingBottom: 12,
  },
  continueBtn: {
    width: '100%',
  },
});
