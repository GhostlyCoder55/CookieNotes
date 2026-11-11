import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import {
  useNavigation,
  useRoute,
  type RouteProp,
} from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { mealDBClient } from '../../api/mealDBClient';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { inferredLegacyCatalogID } from '../../database/catalogIdentity';
import { getRecipeAttribution } from '../../database/recipeAttribution';
import { useLanguage } from '../../localization/LanguageContext';
import type {
  DiscoverStackParamList,
  DiscoveredRecipeDetail,
} from '../../types/models';
import { findMatchingIconID } from '../../utils/ingredientCatalog';
import { canonicalRecipeID } from '../../utils/mealIdentity';
import { cleanInstructions } from '../../utils/recipeSanitizer';
import { estimateRecipeTime } from '../../utils/recipeTimeEstimator';
import {
  EmptyState,
  PrimaryButton,
  SectionSurface,
  TimeInfoView,
} from '../../components/common/AppComponents';
import { FoodIconView } from '../../components/common/FoodIconView';

type DetailRoute = RouteProp<DiscoverStackParamList, 'DiscoverDetail'>;
type NavProp = NativeStackNavigationProp<DiscoverStackParamList, 'DiscoverDetail'>;

export function DiscoverDetailScreen() {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<NavProp>();
  const route = useRoute<DetailRoute>();
  const {
    recipes,
    saveDiscoveredRecipe,
    showToast,
    showRecipeAddedToast,
  } = useAppState();

  const { mealID } = route.params;

  const [detail, setDetail] = useState<DiscoveredRecipeDetail | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [heroImageError, setHeroImageError] = useState(false);

  const loadDetail = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage(null);
    setHeroImageError(false);
    try {
      const loaded = await mealDBClient.lookup(mealID, language);
      setDetail(loaded);
    } catch (err) {
      setDetail(null);
      setErrorMessage(
        err instanceof Error && err.message
          ? err.message
          : t('Try another result.')
      );
    } finally {
      setIsLoading(false);
    }
  }, [mealID, language, t]);

  useEffect(() => {
    void loadDetail();
  }, [loadDetail]);

  const times = useMemo(() => {
    if (!detail) return { prep: 0, cook: 0 };
    return estimateRecipeTime(
      detail.instructions,
      detail.ingredients.length,
      detail.category
    );
  }, [detail]);

  const ingredientIcons = useMemo(() => {
    if (!detail) return [];
    return detail.ingredients.map(
      (line) => findMatchingIconID(line, language) ?? ''
    );
  }, [detail, language]);

  const instructionSteps = useMemo(() => {
    if (!detail) return [];
    return cleanInstructions(detail.instructions, detail.name);
  }, [detail]);

  const alreadySaved = useMemo(() => {
    const canonical = canonicalRecipeID(detail?.id ?? mealID);
    return recipes.some(
      (r) =>
        (r.catalogRecipeID.length > 0 &&
          canonicalRecipeID(r.catalogRecipeID) === canonical) ||
        (r.catalogRecipeID.length === 0 &&
          r.isImported &&
          inferredLegacyCatalogID(r) === canonical)
    );
  }, [detail?.id, mealID, recipes]);

  const attributionText = useMemo(() => {
    if (!detail) return '';
    return getRecipeAttribution(detail, language);
  }, [detail, language]);

  const handleSave = async () => {
    if (!detail || isSaving) return;
    setIsSaving(true);
    try {
      const englishCounterpart =
        language !== 'en'
          ? mealDBClient.getCachedEnglishDetail(detail.id)
          : null;

      const outcome = await saveDiscoveredRecipe(detail, {
        englishDetail: englishCounterpart,
        ingredientIcons,
      });

      navigation.goBack();
      setTimeout(() => {
        if (outcome === 'inserted') {
          showRecipeAddedToast();
        } else {
          showToast(t('Already in Library'));
        }
      }, 240);
    } catch {
      setErrorMessage(t('Couldn’t save this recipe. Try again.'));
    } finally {
      setIsSaving(false);
    }
  };

  const buttonTitle = isSaving
    ? t('Saving…')
    : alreadySaved
      ? t('Saved in My Recipes')
      : t('Save to My Recipes');

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.navBar}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('Discover')}
          onPress={() => navigation.goBack()}
          style={styles.backBtn}
        >
          <Ionicons name="arrow-back" size={24} color={AppTheme.primaryText} />
        </Pressable>
        <Text style={styles.navTitle} numberOfLines={1}>
          {t('Preview')}
        </Text>
        <View style={styles.navSpacer} />
      </View>

      {isLoading ? (
        <View style={styles.centerState}>
          <ActivityIndicator size="large" color={AppTheme.burntOrange} />
          <Text style={styles.centerLabel}>{t('Loading recipe…')}</Text>
        </View>
      ) : detail ? (
        <ScrollView
          contentContainerStyle={[
            styles.scrollContent,
            { paddingBottom: 28 + insets.bottom },
          ]}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.heroWrap}>
            {detail.thumbnailURL && !heroImageError ? (
              <Image
                source={{ uri: detail.thumbnailURL }}
                style={StyleSheet.absoluteFill}
                contentFit="cover"
                transition={150}
                cachePolicy="memory-disk"
                onError={() => setHeroImageError(true)}
              />
            ) : (
              <FoodIconView
                iconID={detail.illustrationIconID || 'salad_bowl'}
                size={104}
              />
            )}
          </View>

          <Text accessibilityRole="header" style={styles.title}>
            {detail.name}
          </Text>

          <Text style={styles.attribution}>{attributionText}</Text>

          <View style={styles.timeSection}>
            <View style={styles.timeRow}>
              <TimeInfoView title={t('Prep')} time={times.prep} />
              <TimeInfoView title={t('Cook')} time={times.cook} />
              <TimeInfoView
                title={t('Total')}
                time={times.prep + times.cook}
              />
            </View>
            <Text style={styles.timeFootnote}>
              {t('Estimated from the recipe steps')}
            </Text>
          </View>

          <SectionSurface>
            <Text accessibilityRole="header" style={styles.sectionTitle}>
              {t('Ingredients')}
            </Text>
            <View style={styles.sectionBody}>
              {detail.ingredients.map((line, index) => (
                <View key={`ing-${index}`} style={styles.ingredientRow}>
                  <FoodIconView
                    iconID={ingredientIcons[index] ?? ''}
                    size={36}
                  />
                  <Text style={styles.ingredientText}>{line}</Text>
                </View>
              ))}
            </View>
          </SectionSurface>

          <SectionSurface>
            <Text accessibilityRole="header" style={styles.sectionTitle}>
              {t('Instructions')}
            </Text>
            <View style={styles.sectionBody}>
              {instructionSteps.map((step, index) => (
                <View
                  key={`step-${index}`}
                  style={styles.stepRow}
                  accessible
                  accessibilityLabel={`${index + 1}. ${step}`}
                >
                  <View style={styles.stepBadge}>
                    <Text style={styles.stepBadgeText}>{index + 1}</Text>
                  </View>
                  <Text style={styles.stepText}>{step}</Text>
                </View>
              ))}
            </View>
          </SectionSurface>

          <PrimaryButton
            testID="save-discovered-recipe-button"
            title={buttonTitle}
            iconName={alreadySaved ? 'checkmark-circle' : 'bookmark'}
            disabled={isSaving}
            onPress={() => void handleSave()}
          />
        </ScrollView>
      ) : (
        <EmptyState
          illustration="soup_bowl"
          title={t('Recipe unavailable')}
          message={errorMessage ?? t('Try another result.')}
          actionTitle={t('Try again')}
          onAction={() => void loadDetail()}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  navBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 8,
  },
  backBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  navTitle: {
    ...Typography.headline,
    color: AppTheme.primaryText,
    flex: 1,
    textAlign: 'center',
  },
  navSpacer: {
    width: 44,
  },
  centerState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  centerLabel: {
    ...Typography.caption,
    color: AppTheme.secondaryText,
  },
  scrollContent: {
    padding: AppTheme.paddingMedium,
    gap: AppTheme.paddingLarge,
  },
  heroWrap: {
    width: '100%',
    height: 220,
    borderRadius: AppTheme.cornerRadiusMedium,
    backgroundColor: AppTheme.parchment,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    ...Typography.largeTitle,
    color: AppTheme.primaryText,
  },
  attribution: {
    ...Typography.caption,
    color: AppTheme.secondaryText,
  },
  timeSection: {
    gap: 6,
  },
  timeRow: {
    flexDirection: 'row',
    gap: 8,
  },
  timeFootnote: {
    ...Typography.smallCaption,
    color: AppTheme.tertiaryText,
  },
  sectionTitle: {
    ...Typography.sectionLabel,
    color: AppTheme.burntOrange,
    marginBottom: 12,
  },
  sectionBody: {
    gap: 12,
  },
  ingredientRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  ingredientText: {
    ...Typography.body,
    color: AppTheme.primaryText,
    flex: 1,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  stepBadge: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: AppTheme.coral,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 2,
  },
  stepBadgeText: {
    ...Typography.smallCaption,
    fontFamily: FontFamily.bold,
    color: AppTheme.white,
  },
  stepText: {
    ...Typography.body,
    color: AppTheme.primaryText,
    flex: 1,
  },
});
