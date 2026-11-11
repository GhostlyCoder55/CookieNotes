import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { AppTheme, CardElevation, FontFamily, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import type { Recipe } from '../../types/models';
import {
  getCategoryColor,
  getCategoryTitle,
  parseRecipeCategory,
  resolveRecipeCoverElements,
  resolveRecipeCoverIcon,
} from '../../utils/recipeCategory';
import {
  formatRecipeTotalTime,
  getCardThumbnailUri,
  resolveLocalizedRecipeName,
} from '../../utils/recipeLibrary';
import { RecipeThumbnail } from '../../components/common/AppComponents';

function hexToRgba(hex: string, alpha: number): string {
  const clean = hex.replace('#', '');
  if (clean.length !== 6) return `rgba(198, 93, 36, ${alpha})`;
  const r = Number.parseInt(clean.slice(0, 2), 16);
  const g = Number.parseInt(clean.slice(2, 4), 16);
  const b = Number.parseInt(clean.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

interface Props {
  recipe: Recipe;
  onPress: () => void;
}

export function RecipeCard({ recipe, onPress }: Props) {
  const { t, language } = useLanguage();
  const category = parseRecipeCategory(recipe.categoryRaw);
  const tintColor = hexToRgba(getCategoryColor(category), 0.4);
  const thumbUri = getCardThumbnailUri(recipe);
  const coverIconID = resolveRecipeCoverIcon(recipe);
  const coverElements = resolveRecipeCoverElements(recipe);
  const localizedName = resolveLocalizedRecipeName(recipe, language);
  const formattedTime = formatRecipeTotalTime(recipe, language);
  const categoryTitle = getCategoryTitle(category, language);

  return (
    <Pressable
      testID="recipe-card"
      accessibilityRole="button"
      accessibilityLabel={`${localizedName}, ${formattedTime}`}
      accessibilityHint={t('Opens the recipe')}
      onPress={onPress}
      style={({ pressed }) => [
        styles.card,
        { borderColor: tintColor },
        pressed && { opacity: 0.9, transform: [{ scale: 0.97 }] },
      ]}
    >
      <View style={styles.thumbContainer}>
        <RecipeThumbnail
          uri={thumbUri}
          iconID={coverIconID}
          iconIDs={coverElements}
          size={104}
        />
        {recipe.isFavorite && (
          <View style={styles.favBadge}>
            <Ionicons name="heart" size={16} color={AppTheme.burntOrange} />
          </View>
        )}
      </View>

      <Text style={styles.title} numberOfLines={2}>
        {localizedName}
      </Text>

      <View style={styles.metaRow}>
        <Text style={styles.timeText} numberOfLines={1}>
          {formattedTime}
        </Text>
        <Text style={styles.catText} numberOfLines={1}>
          {categoryTitle}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flex: 1,
    padding: 12,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    borderWidth: 2,
    gap: 10,
    ...CardElevation,
  },
  thumbContainer: {
    width: '100%',
    height: 148,
    borderRadius: 14,
    overflow: 'hidden',
    position: 'relative',
  },
  favBadge: {
    position: 'absolute',
    top: 8,
    right: 8,
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: 'rgba(41, 35, 31, 0.95)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    ...Typography.headline,
    color: AppTheme.primaryText,
    minHeight: 46,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 4,
  },
  timeText: {
    ...Typography.smallCaption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.accentAction,
    flexShrink: 1,
  },
  catText: {
    ...Typography.smallCaption,
    color: AppTheme.tertiaryText,
    flexShrink: 1,
  },
});
