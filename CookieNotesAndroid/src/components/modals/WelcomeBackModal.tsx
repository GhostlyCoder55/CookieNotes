import React, { useEffect, useRef } from 'react';
import {
  Animated,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { AppTheme, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import { getLanguageOption } from '../../localization/i18n';
import { PrimaryButton, TitleSubtitleBlock } from '../common/AppComponents';
import { FoodIconView } from '../common/FoodIconView';

interface Props {
  visible: boolean;
  lastLoginDate: string | null;
  onStartCooking: () => void;
  onDismiss: () => void;
}

export function WelcomeBackModal({
  visible,
  lastLoginDate,
  onStartCooking,
  onDismiss,
}: Props) {
  const { t, language } = useLanguage();
  const languageOption = getLanguageOption(language);
  const pulse = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (!visible) return;
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 1.05,
          duration: 1000,
          useNativeDriver: true,
        }),
        Animated.timing(pulse, {
          toValue: 1,
          duration: 1000,
          useNativeDriver: true,
        }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [visible, pulse]);

  let formattedDate: string | null = null;
  if (lastLoginDate) {
    const d = new Date(lastLoginDate);
    if (!Number.isNaN(d.getTime())) {
      formattedDate = d.toLocaleDateString(languageOption.localeIdentifier);
    }
  }

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onDismiss}
      statusBarTranslucent
    >
      <View style={styles.backdrop}>
        <Pressable
          style={StyleSheet.absoluteFill}
          onPress={onDismiss}
          accessibilityLabel={t('Maybe Later')}
        />
        <View style={styles.card}>
          <Animated.View style={{ transform: [{ scale: pulse }] }}>
            <FoodIconView iconID="cupcake" size={80} />
          </Animated.View>

          <TitleSubtitleBlock
            title={t('Welcome Back')}
            subtitle={t(
              'Your recipes are waiting. Add something new, discover online, or open a favorite.'
            )}
            styleVariant="page"
          />

          {formattedDate && (
            <Text style={styles.dateText}>
              {t('Last visit: %@', formattedDate)}
            </Text>
          )}

          <PrimaryButton
            title={t('Start Cooking')}
            iconName="restaurant-outline"
            onPress={onStartCooking}
            style={styles.fullBtn}
          />

          <Pressable
            accessibilityRole="button"
            accessibilityLabel={t('Maybe Later')}
            onPress={onDismiss}
            style={styles.laterBtn}
          >
            <Text style={styles.laterText}>{t('Maybe Later')}</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: AppTheme.paddingLarge,
  },
  card: {
    width: '100%',
    maxWidth: 380,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusLarge,
    padding: AppTheme.paddingLarge,
    alignItems: 'center',
    gap: AppTheme.paddingLarge,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.45,
    shadowRadius: 16,
    elevation: 10,
  },
  dateText: {
    ...Typography.caption,
    color: AppTheme.tertiaryText,
  },
  fullBtn: {
    width: '100%',
  },
  laterBtn: {
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  laterText: {
    ...Typography.body,
    color: AppTheme.secondaryText,
  },
});
