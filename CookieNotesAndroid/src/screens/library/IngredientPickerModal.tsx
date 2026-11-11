import React, { useMemo, useRef, useState } from 'react';
import {
  FlatList,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppTheme, CardElevation, FontFamily, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import {
  getAllPickableIngredientIcons,
  getIngredientCatalog,
  getIngredientDisplayName,
} from '../../utils/ingredientCatalog';
import { ColorChip } from '../../components/common/AppComponents';
import { FoodIconView } from '../../components/common/FoodIconView';

interface Props {
  visible: boolean;
  onPick: (displayName: string, iconID: string) => void;
  onClose: () => void;
}

export function IngredientPickerModal({ visible, onPick, onClose }: Props) {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const listRef = useRef<FlatList<string>>(null);

  const [query, setQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const catalog = useMemo(() => getIngredientCatalog(language), [language]);
  const pickableIcons = useMemo(() => getAllPickableIngredientIcons(), []);

  const trimmedQuery = query.trim();
  const isSearching = trimmedQuery.length > 0;
  const activeCategory = isSearching ? null : selectedCategory;

  const filteredIcons = useMemo(() => {
    let matched: string[];

    if (isSearching) {
      const lowered = trimmedQuery.toLowerCase();
      const pickableSet = new Set(pickableIcons);
      const aliasHits = new Set<string>();
      if (lowered.length >= 3) {
        for (const [aliasKey, targetIcon] of Object.entries(catalog.aliases)) {
          if (aliasKey.toLowerCase().startsWith(lowered) && pickableSet.has(targetIcon)) {
            aliasHits.add(targetIcon);
          }
        }
      }

      const hits = pickableIcons.filter((icon) => {
        const displayName = getIngredientDisplayName(icon, language).toLowerCase();
        const rawWords = icon.replace(/_/g, ' ').toLowerCase();
        return (
          displayName.includes(lowered) ||
          rawWords.includes(lowered) ||
          aliasHits.has(icon)
        );
      });

      matched = [...hits].sort((lhs, rhs) => {
        const l = getIngredientDisplayName(lhs, language).toLowerCase();
        const r = getIngredientDisplayName(rhs, language).toLowerCase();
        const lRank = l === lowered ? 0 : l.startsWith(lowered) ? 1 : 2;
        const rRank = r === lowered ? 0 : r.startsWith(lowered) ? 1 : 2;
        if (lRank !== rRank) return lRank - rRank;
        return l.localeCompare(r);
      });
    } else if (selectedCategory) {
      const cat = catalog.categories.find((c) => c.id === selectedCategory);
      matched = cat ? cat.icons.filter((id) => id.trim().length > 0) : pickableIcons;
    } else {
      matched = pickableIcons;
    }

    const seenNames = new Set<string>();
    return matched.filter((icon) => {
      const key = getIngredientDisplayName(icon, language).toLowerCase();
      if (seenNames.has(key)) return false;
      seenNames.add(key);
      return true;
    });
  }, [isSearching, trimmedQuery, selectedCategory, catalog, pickableIcons, language]);

  const selectCategory = (id: string | null) => {
    setSelectedCategory(id);
    setQuery('');
    listRef.current?.scrollToOffset({ offset: 0, animated: false });
  };

  const emptyTitle = (() => {
    if (isSearching) {
      return t('No ingredients match “%@”', trimmedQuery);
    }
    if (selectedCategory) {
      const cat = catalog.categories.find((c) => c.id === selectedCategory);
      if (cat) return t('No ingredients in %@', cat.title);
    }
    return t('No ingredients found');
  })();

  return (
    <Modal
      visible={visible}
      animationType="slide"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View
        style={[
          styles.screen,
          { paddingTop: insets.top, paddingBottom: insets.bottom },
        ]}
      >
        {/* Header Bar */}
        <View style={styles.topBar}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={t('Close')}
            onPress={onClose}
            style={styles.closeBtn}
          >
            <Text style={styles.closeText}>{t('Close')}</Text>
          </Pressable>
          <Text accessibilityRole="header" style={styles.title}>
            {t('Ingredients')}
          </Text>
          <View style={styles.topSpacer} />
        </View>

        {/* Search Input */}
        <View style={styles.searchWrap}>
          <Ionicons name="search" size={18} color={AppTheme.tertiaryText} />
          <TextInput
            value={query}
            onChangeText={(txt) => {
              setQuery(txt);
              listRef.current?.scrollToOffset({ offset: 0, animated: false });
            }}
            placeholder={t('Search ingredients')}
            placeholderTextColor={AppTheme.tertiaryText}
            style={styles.searchInput}
            autoCapitalize="none"
            autoCorrect={false}
          />
          {query.length > 0 && (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Clear search')}
              onPress={() => setQuery('')}
              style={styles.clearIconBtn}
            >
              <Ionicons
                name="close-circle"
                size={18}
                color={AppTheme.tertiaryText}
              />
            </Pressable>
          )}
        </View>

        {/* Category Chips */}
        <View style={styles.chipsWrap}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.chipsContent}
          >
            <ColorChip
              title={t('All')}
              selected={activeCategory === null}
              onPress={() => selectCategory(null)}
            />
            {catalog.categories.map((cat) => (
              <ColorChip
                key={cat.id}
                title={cat.title}
                selected={activeCategory === cat.id}
                onPress={() => selectCategory(cat.id)}
              />
            ))}
          </ScrollView>
        </View>

        {/* Results Grid */}
        {filteredIcons.length === 0 ? (
          <View style={styles.emptyWrap}>
            <Ionicons
              name="search-outline"
              size={32}
              color={AppTheme.tertiaryText}
            />
            <Text style={styles.emptyText}>{emptyTitle}</Text>
            {isSearching && (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Clear search')}
                onPress={() => setQuery('')}
                style={styles.clearSearchBtn}
              >
                <Text style={styles.clearSearchText}>{t('Clear search')}</Text>
              </Pressable>
            )}
          </View>
        ) : (
          <FlatList
            ref={listRef}
            data={filteredIcons}
            keyExtractor={(icon) => icon}
            numColumns={2}
            columnWrapperStyle={styles.gridRow}
            contentContainerStyle={styles.gridContent}
            keyboardShouldPersistTaps="handled"
            renderItem={({ item: icon }) => {
              const displayName = getIngredientDisplayName(icon, language);
              return (
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={displayName}
                  onPress={() => {
                    onPick(displayName, icon);
                    onClose();
                  }}
                  style={({ pressed }) => [
                    styles.card,
                    pressed && { opacity: 0.9, transform: [{ scale: 0.97 }] },
                  ]}
                >
                  <View style={styles.iconBox}>
                    <FoodIconView iconID={icon} size={62} />
                  </View>
                  <Text style={styles.cardLabel} numberOfLines={2}>
                    {displayName}
                  </Text>
                </Pressable>
              );
            }}
          />
        )}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 8,
  },
  closeBtn: {
    minWidth: 64,
    minHeight: 44,
    justifyContent: 'center',
  },
  closeText: {
    ...Typography.body,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.secondaryText,
  },
  title: {
    ...Typography.headline,
    color: AppTheme.primaryText,
  },
  topSpacer: {
    minWidth: 64,
  },
  searchWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: AppTheme.parchment,
    borderRadius: AppTheme.cornerRadiusSmall,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.22)',
    marginHorizontal: AppTheme.paddingMedium,
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
  clearIconBtn: {
    padding: 6,
  },
  chipsWrap: {
    marginTop: 10,
    marginBottom: 8,
  },
  chipsContent: {
    paddingHorizontal: AppTheme.paddingMedium,
    gap: 8,
  },
  gridContent: {
    paddingHorizontal: AppTheme.paddingMedium,
    paddingBottom: AppTheme.paddingLarge,
    gap: 12,
  },
  gridRow: {
    gap: 12,
  },
  card: {
    flex: 1,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusSmall,
    padding: 10,
    gap: 8,
    alignItems: 'center',
    ...CardElevation,
  },
  iconBox: {
    width: '100%',
    height: 76,
    backgroundColor: AppTheme.parchment,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardLabel: {
    ...Typography.smallCaption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.primaryText,
    textAlign: 'center',
    minHeight: 34,
  },
  emptyWrap: {
    alignItems: 'center',
    paddingTop: 48,
    paddingHorizontal: AppTheme.paddingMedium,
    gap: 10,
  },
  emptyText: {
    ...Typography.body,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.primaryText,
    textAlign: 'center',
  },
  clearSearchBtn: {
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: 12,
  },
  clearSearchText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.burntOrange,
  },
});
