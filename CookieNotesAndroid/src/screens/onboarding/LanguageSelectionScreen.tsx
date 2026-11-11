import React from 'react';
import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { AppTheme, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import { SUPPORTED_LANGUAGES, type AppLanguage } from '../../localization/i18n';
import { hapticSelection } from '../../utils/haptics';
import { HexagonFlagBadge } from '../../components/common/HexagonFlagBadge';

interface Props {
  onSelectLanguage: (lang: AppLanguage) => void;
}

export function LanguageSelectionScreen({ onSelectLanguage }: Props) {
  const { language, t } = useLanguage();
  const { width } = useWindowDimensions();

  // Compute comfortable 3-up card size while staying clean on compact 320-360dp screens
  const maxContainerWidth = Math.min(width - AppTheme.paddingLarge * 2, 400);
  const gap = 12;
  const cardWidth = Math.floor((maxContainerWidth - gap * 2) / 3);
  const badgeScale = cardWidth < 102 ? 0.78 : 0.9;

  return (
    <View style={[styles.container, { width }]}>
      <View style={styles.inner}>
        <View style={styles.headerBlock}>
          <Text accessibilityRole="header" style={styles.title}>
            {t('Choose your language')}
          </Text>
          <Text style={styles.subtitle}>
            {t('You can change the language anytime.')}
          </Text>
        </View>

        <View style={[styles.cardsRow, { gap, width: maxContainerWidth }]}>
          {SUPPORTED_LANGUAGES.map((option) => {
            const isSelected = language === option.code;
            return (
              <Pressable
                key={option.code}
                testID={`language-option-${option.code}`}
                accessibilityRole="button"
                accessibilityLabel={option.displayName}
                accessibilityState={{ selected: isSelected }}
                onPress={() => {
                  void hapticSelection();
                  onSelectLanguage(option.code);
                }}
                style={({ pressed }) => [
                  styles.card,
                  {
                    width: cardWidth,
                    minHeight: Math.max(122, cardWidth + 14),
                    borderColor: isSelected
                      ? AppTheme.burntOrange
                      : AppTheme.separator,
                    borderWidth: isSelected ? 2.5 : 1,
                    opacity: pressed ? 0.92 : 1,
                    transform: [{ scale: pressed ? 0.97 : 1 }],
                  },
                ]}
              >
                {isSelected && (
                  <View
                    style={[
                      StyleSheet.absoluteFill,
                      { backgroundColor: 'rgba(198, 93, 36, 0.14)' },
                    ]}
                  />
                )}
                <HexagonFlagBadge
                  language={option.code}
                  width={Math.round(68 * badgeScale)}
                  height={Math.round(78 * badgeScale)}
                />
                <Text
                  style={styles.cardLabel}
                  numberOfLines={1}
                  adjustsFontSizeToFit
                >
                  {option.displayName}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: AppTheme.paddingLarge,
  },
  inner: {
    alignItems: 'center',
    gap: 28,
  },
  headerBlock: {
    alignItems: 'center',
    gap: 8,
    maxWidth: 360,
  },
  title: {
    ...Typography.title,
    color: AppTheme.primaryText,
    textAlign: 'center',
  },
  subtitle: {
    ...Typography.footnote,
    color: AppTheme.secondaryText,
    textAlign: 'center',
  },
  cardsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  card: {
    borderRadius: AppTheme.cornerRadiusMedium,
    backgroundColor: AppTheme.cardBackground,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 8,
    paddingVertical: 14,
    gap: 10,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.35,
    shadowRadius: 5,
    elevation: 4,
  },
  cardLabel: {
    ...Typography.headline,
    color: AppTheme.primaryText,
    textAlign: 'center',
  },
});
