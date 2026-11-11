import React from 'react';
import {
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { AppTheme, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import { getConsentChoiceTitle } from '../../services/adConsentStore';
import type { AdConsentChoice, PrivacySheetMode } from '../../types/models';
import { TitleSubtitleBlock } from '../common/AppComponents';
import { FoodIconView } from '../common/FoodIconView';

interface Props {
  visible: boolean;
  mode: PrivacySheetMode;
  currentChoice: AdConsentChoice;
  onSelectChoice: (choice: AdConsentChoice) => void;
  onDismiss: () => void;
}

export function PrivacyChoicesModal({
  visible,
  mode,
  currentChoice,
  onSelectChoice,
  onDismiss,
}: Props) {
  const { t, language } = useLanguage();

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={() => {
        if (mode !== 'firstRun') onDismiss();
      }}
      statusBarTranslucent
    >
      <View style={styles.screen}>
        <View style={styles.content}>
          <FoodIconView iconID="honey_jar" size={72} />

          <TitleSubtitleBlock
            title={mode === 'firstRun' ? t('Keep CookieNotes free') : t('Ads')}
            subtitle={t(
              'Ads help support the app. Your recipes stay on this device.'
            )}
            styleVariant="page"
          />

          {mode === 'settings' && (
            <Text style={styles.currentChoice}>
              {t(
                'Current choice: %@',
                getConsentChoiceTitle(currentChoice, language)
              )}
            </Text>
          )}

          <View style={styles.buttons}>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Show ads')}
              onPress={() => onSelectChoice('allowed')}
              style={({ pressed }) => [
                styles.choiceBtn,
                styles.choicePrimary,
                pressed && styles.choicePressed,
              ]}
            >
              <Text style={styles.choiceText}>{t('Show ads')}</Text>
            </Pressable>

            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Don’t show ads')}
              onPress={() => onSelectChoice('declined')}
              style={({ pressed }) => [
                styles.choiceBtn,
                styles.choiceSecondary,
                pressed && styles.choicePressed,
              ]}
            >
              <Text style={styles.choiceText}>{t('Don’t show ads')}</Text>
            </Pressable>

            {mode === 'settings' && (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Close')}
                onPress={onDismiss}
                style={({ pressed }) => [
                  styles.closeLinkBtn,
                  pressed && styles.choicePressed,
                ]}
              >
                <Text style={styles.closeLinkText}>{t('Close')}</Text>
              </Pressable>
            )}
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
    alignItems: 'center',
    justifyContent: 'center',
    padding: AppTheme.paddingLarge,
  },
  content: {
    width: '100%',
    maxWidth: 400,
    alignItems: 'center',
    gap: AppTheme.paddingLarge,
  },
  currentChoice: {
    ...Typography.caption,
    color: AppTheme.tertiaryText,
    textAlign: 'center',
  },
  buttons: {
    width: '100%',
    gap: AppTheme.paddingSmall,
    marginTop: AppTheme.paddingSmall,
  },
  choiceBtn: {
    width: '100%',
    minHeight: 48,
    paddingHorizontal: AppTheme.paddingMedium,
    borderRadius: AppTheme.cornerRadiusMedium,
    alignItems: 'center',
    justifyContent: 'center',
  },
  choicePrimary: {
    backgroundColor: AppTheme.burntOrange,
  },
  choiceSecondary: {
    backgroundColor: AppTheme.surfaceBackground,
  },
  choicePressed: {
    opacity: 0.9,
    transform: [{ scale: 0.98 }],
  },
  choiceText: {
    ...Typography.headline,
    color: AppTheme.white,
  },
  closeLinkBtn: {
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  closeLinkText: {
    ...Typography.body,
    color: AppTheme.secondaryText,
    fontWeight: '600',
  },
});
