import React, { useMemo, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useIsFocused, useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { useLanguage } from '../../localization/LanguageContext';
import { blocksFromSlots, browsingSlots } from '../../services/adPlacement';
import type { LibraryStackParamList, RecipeSort } from '../../types/models';
import { hapticSelection } from '../../utils/haptics';
import { RECIPE_FILTERS, getFilterTitle } from '../../utils/recipeCategory';
import {
  RECIPE_SORTS,
  getRecipeSortTitle,
  prepareLibraryRecipes,
} from '../../utils/recipeLibrary';
import { AdvertisementSlot } from '../../components/common/AdvertisementSlot';
import {
  ColorChip,
  EmptyState,
  NoticeBanner,
  PrimaryButton,
  TitleSubtitleBlock,
} from '../../components/common/AppComponents';
import { FoodIconView } from '../../components/common/FoodIconView';
import { InAppToastOverlay } from '../../components/common/InAppToastOverlay';
import { AddRecipeScreen } from './AddRecipeScreen';
import { RecipeCard } from './RecipeCard';

type NavProp = NativeStackNavigationProp<LibraryStackParamList, 'RecipeList'>;

export function RecipeListScreen() {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const isFocused = useIsFocused();
  const navigation = useNavigation<NavProp>();

  const {
    recipes,
    storageWarning,
    importBannerMessage,
    dismissImportBanner,
    recipeSort,
    recipeFilter,
    setRecipeSort,
    setRecipeFilter,
    adState,
    adsAreUnobstructed,
    toastMessage,
    toastVisible,
  } = useAppState();

  const [showingAddRecipe, setShowingAddRecipe] = useState(false);
  const [showingSortMenu, setShowingSortMenu] = useState(false);
  const [searchText, setSearchText] = useState('');

  const displayed = useMemo(
    () =>
      prepareLibraryRecipes(recipes, {
        query: searchText,
        filter: recipeFilter,
        sort: recipeSort,
        language,
      }),
    [recipes, searchText, recipeFilter, recipeSort, language]
  );

  const libraryIsEmpty =
    recipes.length === 0 && searchText.trim() === '' && recipeFilter === 'all';

  const showAds =
    adsAreUnobstructed &&
    isFocused &&
    !showingAddRecipe &&
    adState.canPresentAds;

  const feedBlocks = useMemo(
    () =>
      blocksFromSlots(browsingSlots(displayed.length, showAds)),
    [displayed.length, showAds]
  );

  const handleSortSelect = (option: RecipeSort) => {
    void hapticSelection();
    void setRecipeSort(option);
    setShowingSortMenu(false);
  };

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      {/* Header Toolbar */}
      <View style={styles.topHeader}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('Sort recipes')}
          onPress={() => setShowingSortMenu(true)}
          style={styles.headerIconBtn}
        >
          <Ionicons
            name="swap-vertical"
            size={26}
            color={AppTheme.accent}
          />
        </Pressable>

        <Text accessibilityRole="header" style={styles.headerTitle}>
          {t('Library')}
        </Text>

        <Pressable
          testID="add-recipe-button"
          accessibilityRole="button"
          accessibilityLabel={t('Add recipe')}
          onPress={() => setShowingAddRecipe(true)}
          style={styles.headerIconBtn}
        >
          <Ionicons
            name="add-circle"
            size={30}
            color={AppTheme.burntOrange}
          />
        </Pressable>
      </View>

      {/* Persistent Search Bar */}
      <View style={styles.searchContainer}>
        <View style={styles.searchBox}>
          <Ionicons name="search" size={18} color={AppTheme.tertiaryText} />
          <TextInput
            value={searchText}
            onChangeText={setSearchText}
            placeholder={t('Search your recipes')}
            placeholderTextColor={AppTheme.tertiaryText}
            style={styles.searchInput}
            returnKeyType="search"
          />
          {searchText.length > 0 && (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Clear search')}
              onPress={() => setSearchText('')}
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

        {libraryIsEmpty ? (
          <View style={styles.emptyWrap}>
            {storageWarning && <NoticeBanner message={storageWarning} />}
            {importBannerMessage && (
              <NoticeBanner
                message={importBannerMessage}
                onDismiss={dismissImportBanner}
              />
            )}
            <EmptyState
              illustration="veggie_plate"
              title={t('Your journal is empty')}
              message={t(
                'Add a recipe you love, or discover one online and save it here.'
              )}
              actionTitle={t('Add Recipe')}
              onAction={() => setShowingAddRecipe(true)}
            />
          </View>
        ) : (
          <ScrollView
            contentContainerStyle={styles.scrollContent}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={false}
          >
            {/* Hero Card */}
            <View style={styles.heroCard}>
              <FoodIconView iconID="salad_bowl" size={72} />
              <Text accessibilityRole="header" style={styles.heroTitle}>
                {t('Your cookbook')}
              </Text>
            </View>

            {/* Notices */}
            {storageWarning && (
              <NoticeBanner
                message={storageWarning}
                iconName="warning-outline"
              />
            )}
            {importBannerMessage && (
              <NoticeBanner
                message={importBannerMessage}
                iconName="download-outline"
                onDismiss={dismissImportBanner}
              />
            )}
            {adState.availabilityMessage && (
              <NoticeBanner message={adState.availabilityMessage} />
            )}

            {/* Filter Chips */}
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.filterBar}
            >
              {RECIPE_FILTERS.map((item) => (
                <ColorChip
                  key={item}
                  title={getFilterTitle(item, language)}
                  selected={recipeFilter === item}
                  onPress={() => void setRecipeFilter(item)}
                />
              ))}
            </ScrollView>

            {/* Feed or Empty Filter View */}
            {displayed.length === 0 ? (
              <View style={styles.filterEmpty}>
                <TitleSubtitleBlock
                  title={t('Nothing matches')}
                  subtitle={t(
                    'Try another meal type, or show everything in your library.'
                  )}
                  styleVariant="page"
                />
                <PrimaryButton
                  title={t('Show all recipes')}
                  onPress={() => {
                    void setRecipeFilter('all');
                    setSearchText('');
                  }}
                />
              </View>
            ) : (
              <View style={styles.feedWrap}>
                {feedBlocks.map((block) => {
                  if (block.kind === 'advertisement') {
                    return (
                      <AdvertisementSlot
                        key={`ad-${block.id}`}
                        placementID={`recipes-${displayed.length}-${block.id}`}
                        canPresentAds={adState.canPresentAds}
                        reloadToken={adState.reloadToken}
                      />
                    );
                  }

                  const rows: number[][] = [];
                  for (let i = 0; i < block.indices.length; i += 2) {
                    rows.push(block.indices.slice(i, i + 2));
                  }

                  return (
                    <View key={`blk-${block.id}`} style={styles.gridBlock}>
                      {rows.map((pair, rIdx) => (
                        <View key={`row-${block.id}-${rIdx}`} style={styles.gridRow}>
                          {pair.map((itemIndex) => {
                            const item = displayed[itemIndex];
                            if (!item) return null;
                            return (
                              <RecipeCard
                                key={item.recipeID}
                                recipe={item}
                                onPress={() =>
                                  navigation.navigate('RecipeDetail', {
                                    recipeID: item.recipeID,
                                  })
                                }
                              />
                            );
                          })}
                          {pair.length === 1 && <View style={styles.gridSpacer} />}
                        </View>
                      ))}
                    </View>
                  );
                })}
              </View>
            )}
          </ScrollView>
        )}
      </View>

      <AddRecipeScreen
        visible={showingAddRecipe}
        onClose={() => setShowingAddRecipe(false)}
      />

      {/* Sort Menu */}
      <Modal
        visible={showingSortMenu}
        transparent
        animationType="fade"
        onRequestClose={() => setShowingSortMenu(false)}
        statusBarTranslucent
      >
        <Pressable
          style={styles.dialogBackdrop}
          onPress={() => setShowingSortMenu(false)}
        >
          <Pressable style={styles.dialogCard} onPress={() => {}}>
            <Text style={styles.dialogTitle}>{t('Sort recipes')}</Text>
            {RECIPE_SORTS.map((option) => {
              const selected = recipeSort === option;
              return (
                <Pressable
                  key={option}
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                  onPress={() => handleSortSelect(option)}
                  style={styles.sortOptionRow}
                >
                  <Text
                    style={[
                      styles.sortOptionText,
                      selected && { color: AppTheme.burntOrange },
                    ]}
                  >
                    {getRecipeSortTitle(option, language)}
                  </Text>
                  {selected && (
                    <Ionicons
                      name="checkmark"
                      size={20}
                      color={AppTheme.burntOrange}
                    />
                  )}
                </Pressable>
              );
            })}
          </Pressable>
        </Pressable>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  topHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: AppTheme.paddingMedium,
    paddingTop: 10,
    paddingBottom: 6,
  },
  headerIconBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    ...Typography.title,
    fontFamily: FontFamily.extraBold,
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
  emptyWrap: {
    flex: 1,
    paddingHorizontal: AppTheme.paddingMedium,
    gap: 12,
  },
  scrollContent: {
    padding: AppTheme.paddingMedium,
    gap: AppTheme.paddingMedium,
    paddingBottom: 28,
  },
  heroCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 20,
    paddingVertical: AppTheme.paddingLarge,
    paddingHorizontal: AppTheme.paddingMedium,
    backgroundColor: AppTheme.parchment,
    borderRadius: AppTheme.cornerRadiusLarge,
    borderWidth: 1,
    borderColor: AppTheme.separator,
  },
  heroTitle: {
    ...Typography.title,
    color: AppTheme.primaryText,
    flexShrink: 1,
  },
  filterBar: {
    gap: 8,
    paddingVertical: 2,
  },
  filterEmpty: {
    alignItems: 'center',
    paddingVertical: AppTheme.paddingXLarge,
    gap: AppTheme.paddingMedium,
  },
  feedWrap: {
    gap: AppTheme.paddingLarge,
  },
  gridBlock: {
    gap: AppTheme.paddingMedium,
  },
  gridRow: {
    flexDirection: 'row',
    gap: AppTheme.paddingMedium,
  },
  gridSpacer: {
    flex: 1,
  },
  dialogBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  dialogCard: {
    width: '100%',
    maxWidth: 320,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    padding: AppTheme.paddingMedium,
    gap: 8,
  },
  dialogTitle: {
    ...Typography.headline,
    color: AppTheme.primaryText,
    marginBottom: 4,
  },
  sortOptionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    minHeight: 44,
  },
  sortOptionText: {
    ...Typography.body,
    color: AppTheme.primaryText,
  },
});
