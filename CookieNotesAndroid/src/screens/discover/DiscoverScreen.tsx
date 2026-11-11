import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MealDBClient, mealDBClient } from '../../api/mealDBClient';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { useLanguage } from '../../localization/LanguageContext';
import type {
  CuisineRegion,
  DiscoverStackParamList,
  DiscoveredRecipeSummary,
} from '../../types/models';
import { ALL_CUISINE_REGIONS, getRegionTitle } from '../../utils/cuisineTaxonomy';
import {
  ColorChip,
  EmptyState,
  NoticeBanner,
  TitleSubtitleBlock,
} from '../../components/common/AppComponents';
import { InAppToastOverlay } from '../../components/common/InAppToastOverlay';
import { DiscoverCard } from './DiscoverCard';

type NavProp = NativeStackNavigationProp<DiscoverStackParamList, 'DiscoverHome'>;

export function DiscoverScreen() {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<NavProp>();
  const { toastMessage, toastVisible } = useAppState();

  const [query, setQuery] = useState('');
  const [selectedRegion, setSelectedRegion] = useState<CuisineRegion | null>('African');
  const [results, setResults] = useState<DiscoveredRecipeSummary[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [fromOfflineCache, setFromOfflineCache] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const searchGenRef = useRef(0);
  const debounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const resultsLenRef = useRef(0);
  resultsLenRef.current = results.length;

  const runBrowse = useCallback(
    async (regionToBrowse: CuisineRegion) => {
      const generation = ++searchGenRef.current;
      setErrorMessage(null);
      const cacheKey = `${MealDBClient.listKeyRegion(regionToBrowse)}_${language}`;
      const cached = mealDBClient.getCachedList(cacheKey);
      if (cached) {
        setResults(cached);
        setFromOfflineCache(false);
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      try {
        const outcome = await mealDBClient.filterByRegion(regionToBrowse, language);
        if (searchGenRef.current !== generation) return;
        setResults(outcome.data);
        setFromOfflineCache(outcome.fromOfflineCache);
      } catch (err) {
        if (searchGenRef.current !== generation) return;
        setResults([]);
        setFromOfflineCache(false);
        setErrorMessage(
          err instanceof Error && err.message
            ? err.message
            : t('The recipe service didn’t respond.')
        );
      } finally {
        if (searchGenRef.current === generation) {
          setIsLoading(false);
        }
      }
    },
    [language, t]
  );

  const runSearch = useCallback(
    async (rawQuery: string, fromTyping: boolean) => {
      const trimmed = rawQuery.trim();
      if (!trimmed) return;
      const generation = searchGenRef.current;
      setSelectedRegion(null);
      setErrorMessage(null);

      const cacheKey = `${MealDBClient.listKeySearch(trimmed)}_${language}`;
      const cached = mealDBClient.getCachedList(cacheKey);
      if (cached) {
        if (searchGenRef.current !== generation) return;
        setResults(cached);
        setFromOfflineCache(false);
        setIsLoading(false);
        return;
      }

      if (!fromTyping || resultsLenRef.current === 0) {
        setIsLoading(true);
      }

      try {
        const outcome = await mealDBClient.search(trimmed, language);
        if (searchGenRef.current !== generation) return;
        setResults(outcome.data);
        setFromOfflineCache(outcome.fromOfflineCache);
      } catch (err) {
        if (searchGenRef.current !== generation) return;
        setResults([]);
        setFromOfflineCache(false);
        setErrorMessage(
          err instanceof Error && err.message
            ? err.message
            : t('The recipe service didn’t respond.')
        );
      } finally {
        if (searchGenRef.current === generation) {
          setIsLoading(false);
        }
      }
    },
    [language, t]
  );

  // Sync browse or active search when language changes (and run initial African browse)
  useEffect(() => {
    const trimmed = query.trim();
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
      debounceTimerRef.current = null;
    }
    if (trimmed.length > 0) {
      searchGenRef.current += 1;
      void runSearch(trimmed, false);
    } else {
      const region = selectedRegion ?? 'African';
      if (selectedRegion === null) {
        setSelectedRegion('African');
      }
      void runBrowse(region);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [language]);

  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }
    };
  }, []);

  const handleQueryChange = (nextText: string) => {
    setQuery(nextText);
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
      debounceTimerRef.current = null;
    }
    const generation = ++searchGenRef.current;
    const trimmed = nextText.trim();

    if (!trimmed) {
      setSelectedRegion('African');
      void runBrowse('African');
      return;
    }

    debounceTimerRef.current = setTimeout(() => {
      if (searchGenRef.current !== generation) return;
      void runSearch(trimmed, true);
    }, 280);
  };

  const handleSubmitSearch = () => {
    const trimmed = query.trim();
    if (!trimmed) return;
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
      debounceTimerRef.current = null;
    }
    searchGenRef.current += 1;
    void runSearch(trimmed, false);
  };

  const handleSelectRegion = (region: CuisineRegion) => {
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
      debounceTimerRef.current = null;
    }
    setQuery('');
    setSelectedRegion(region);
    void runBrowse(region);
  };

  const handleRetry = () => {
    const trimmed = query.trim();
    if (trimmed.length > 0) {
      searchGenRef.current += 1;
      void runSearch(trimmed, false);
    } else {
      const region = selectedRegion ?? 'African';
      setSelectedRegion(region);
      void runBrowse(region);
    }
  };

  const rows = useMemo(() => {
    const pairs: DiscoveredRecipeSummary[][] = [];
    for (let i = 0; i < results.length; i += 2) {
      pairs.push(results.slice(i, i + 2));
    }
    return pairs;
  }, [results]);

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.topHeader}>
        <Text accessibilityRole="header" style={styles.headerTitle}>
          {t('Discover')}
        </Text>
      </View>

      <View style={styles.searchContainer}>
        <View style={styles.searchBox}>
          <Ionicons name="search" size={18} color={AppTheme.tertiaryText} />
          <TextInput
            testID="discover-search-input"
            value={query}
            onChangeText={handleQueryChange}
            onSubmitEditing={handleSubmitSearch}
            placeholder={t('Search recipes or countries')}
            placeholderTextColor={AppTheme.tertiaryText}
            style={styles.searchInput}
            returnKeyType="search"
            autoCapitalize="none"
            autoCorrect={false}
          />
          {query.length > 0 && (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Clear search')}
              onPress={() => handleQueryChange('')}
              style={styles.clearBtn}
            >
              <Ionicons
                name="close-circle"
                size={18}
                color={AppTheme.tertiaryText}
              />
            </Pressable>
          )}
        </View>
      </View>

      <View style={styles.bodyWrap}>
        <InAppToastOverlay message={toastMessage} visible={toastVisible} />

        <ScrollView
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <TitleSubtitleBlock
            title={t('Find something delicious')}
            styleVariant="page"
            alignment="leading"
          />

          <View style={styles.regionSection}>
            <Text accessibilityRole="header" style={styles.sectionLabel}>
              {t('Browse by Region')}
            </Text>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.regionRow}
            >
              {ALL_CUISINE_REGIONS.map((region) => (
                <ColorChip
                  key={region}
                  testID={`region-chip-${region}`}
                  title={getRegionTitle(region, language)}
                  selected={selectedRegion === region}
                  onPress={() => handleSelectRegion(region)}
                />
              ))}
            </ScrollView>
          </View>

          {fromOfflineCache && !isLoading && (
            <NoticeBanner
              message={`${t('Offline mode')} · ${t('Showing cached recipes')}`}
              iconName="cloud-offline-outline"
            />
          )}

          {isLoading ? (
            <View style={styles.loadingWrap}>
              <ActivityIndicator size="large" color={AppTheme.burntOrange} />
              <Text style={styles.loadingText}>{t('Searching…')}</Text>
            </View>
          ) : errorMessage ? (
            <View style={styles.emptyMinHeight}>
              <EmptyState
                illustration="soup_bowl"
                title={t('Couldn’t load recipes')}
                message={errorMessage}
                actionTitle={t('Try again')}
                onAction={handleRetry}
              />
            </View>
          ) : results.length === 0 ? (
            <View style={styles.emptyMinHeight}>
              <EmptyState
                illustration="pepperoni_pizza"
                title={t('Search the web of food')}
                message=""
              />
            </View>
          ) : (
            <View style={styles.gridWrap}>
              {rows.map((pair, idx) => (
                <View key={`row-${idx}`} style={styles.gridRow}>
                  {pair.map((item) => (
                    <DiscoverCard
                      key={item.id}
                      recipe={item}
                      onPress={() =>
                        navigation.navigate('DiscoverDetail', { mealID: item.id })
                      }
                    />
                  ))}
                  {pair.length === 1 && <View style={styles.gridSpacer} />}
                </View>
              ))}
            </View>
          )}
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  topHeader: {
    paddingHorizontal: AppTheme.paddingMedium,
    paddingTop: 12,
    paddingBottom: 6,
  },
  headerTitle: {
    ...Typography.largeTitle,
    color: AppTheme.primaryText,
  },
  searchContainer: {
    paddingHorizontal: AppTheme.paddingMedium,
    paddingBottom: 10,
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: AppTheme.parchment,
    borderRadius: AppTheme.cornerRadiusSmall,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.22)',
    paddingHorizontal: 12,
    minHeight: 46,
    gap: 8,
  },
  searchInput: {
    flex: 1,
    ...Typography.body,
    color: AppTheme.primaryText,
    paddingVertical: 8,
  },
  clearBtn: {
    padding: 6,
  },
  bodyWrap: {
    flex: 1,
    position: 'relative',
  },
  scrollContent: {
    padding: AppTheme.paddingMedium,
    gap: AppTheme.paddingLarge,
    paddingBottom: 28,
  },
  regionSection: {
    gap: 10,
  },
  sectionLabel: {
    ...Typography.sectionLabel,
    color: AppTheme.secondaryText,
  },
  regionRow: {
    gap: 8,
    paddingVertical: 2,
  },
  loadingWrap: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 48,
    gap: 12,
  },
  loadingText: {
    ...Typography.caption,
    color: AppTheme.secondaryText,
  },
  emptyMinHeight: {
    minHeight: 280,
  },
  gridWrap: {
    gap: 14,
  },
  gridRow: {
    flexDirection: 'row',
    gap: 14,
  },
  gridSpacer: {
    flex: 1,
  },
});
