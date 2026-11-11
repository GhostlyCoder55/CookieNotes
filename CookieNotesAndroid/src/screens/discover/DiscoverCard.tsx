import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { mealDBClient } from '../../api/mealDBClient';
import { AppTheme, CardElevation, FontFamily, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import type { DiscoveredRecipeSummary, RecipeTimeEstimate } from '../../types/models';
import { getCardThumbnailURL } from '../../utils/mealIdentity';
import { formatDurationShort } from '../../utils/recipeTimeEstimator';
import { FoodIconView } from '../../components/common/FoodIconView';

export function DiscoverCard({
  recipe,
  onPress,
}: {
  recipe: DiscoveredRecipeSummary;
  onPress: () => void;
}) {
  const { t, language } = useLanguage();
  const [times, setTimes] = useState<RecipeTimeEstimate | null>(null);
  const [imageError, setImageError] = useState(false);

  const thumbnailUri = getCardThumbnailURL(recipe.thumbnailURL);

  useEffect(() => {
    setImageError(false);
  }, [recipe.id, thumbnailUri]);

  useEffect(() => {
    let mounted = true;
    setTimes(null);
    void mealDBClient.timeEstimate(recipe.id, language).then((estimate) => {
      if (mounted) {
        setTimes(estimate);
      }
    });
    return () => {
      mounted = false;
    };
  }, [recipe.id, language]);

  const rawSubtitle = recipe.area ?? recipe.category;
  const subtitle = rawSubtitle ? t(rawSubtitle) : null;
  const totalMinutes = times ? times.prep + times.cook : null;
  const timeText =
    totalMinutes !== null ? formatDurationShort(totalMinutes, language) : '– min';

  return (
    <Pressable
      testID={`discover-card-${recipe.id}`}
      accessibilityRole="button"
      accessibilityLabel={[recipe.name, totalMinutes !== null ? timeText : '', subtitle ?? '']
        .filter(Boolean)
        .join(', ')}
      onPress={onPress}
      style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
    >
      <View style={styles.thumbWrap}>
        {thumbnailUri && !imageError ? (
          <Image
            source={{ uri: thumbnailUri }}
            style={StyleSheet.absoluteFill}
            contentFit="cover"
            transition={150}
            cachePolicy="memory-disk"
            onError={() => setImageError(true)}
          />
        ) : (
          <View style={styles.fallbackWrap}>
            <FoodIconView
              iconID={recipe.illustrationIconID || 'salad_bowl'}
              size={68}
            />
          </View>
        )}
      </View>

      <Text style={styles.title} numberOfLines={2}>
        {recipe.name}
      </Text>

      <View style={styles.metaRow}>
        <View style={styles.timeRow}>
          <Ionicons
            name="time-outline"
            size={13}
            color={AppTheme.accentAction}
          />
          <Text
            style={[
              styles.timeText,
              totalMinutes === null && styles.timePlaceholder,
            ]}
            numberOfLines={1}
          >
            {timeText}
          </Text>
        </View>

        {subtitle ? (
          <Text style={styles.subtitleText} numberOfLines={1}>
            {subtitle}
          </Text>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flex: 1,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    padding: 12,
    gap: 10,
    ...CardElevation,
  },
  cardPressed: {
    transform: [{ scale: 0.98 }],
    opacity: 0.95,
  },
  thumbWrap: {
    width: '100%',
    height: 120,
    borderRadius: 14,
    backgroundColor: AppTheme.parchment,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  fallbackWrap: {
    flex: 1,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: AppTheme.parchment,
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
    gap: 6,
  },
  timeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    flexShrink: 0,
  },
  timeText: {
    ...Typography.smallCaption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.accentAction,
  },
  timePlaceholder: {
    opacity: 0.55,
  },
  subtitleText: {
    ...Typography.smallCaption,
    color: AppTheme.tertiaryText,
    flexShrink: 1,
    textAlign: 'right',
  },
});
