import React, { useEffect, useRef } from 'react';
import {
  Animated,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import type { AppUpdateInfo } from '../../types/models';
import { PrimaryButton } from '../common/AppComponents';

interface Props {
  updateInfo: AppUpdateInfo | null;
  onUpdate: () => void;
  onDismiss: () => void;
}

export function AppUpdateModal({ updateInfo, onUpdate, onDismiss }: Props) {
  const { t } = useLanguage();
  const pulse = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (!updateInfo) return;
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 1.08,
          duration: 1200,
          useNativeDriver: true,
        }),
        Animated.timing(pulse, {
          toValue: 1,
          duration: 1200,
          useNativeDriver: true,
        }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [updateInfo, pulse]);

  if (!updateInfo) return null;

  const trimmedNotes = (updateInfo.releaseNotes ?? '').trim();

  return (
    <Modal
      visible={Boolean(updateInfo)}
      transparent
      animationType="fade"
      onRequestClose={() => {
        if (!updateInfo.isMandatory) onDismiss();
      }}
      statusBarTranslucent
    >
      <View style={styles.backdrop}>
        <Pressable
          style={StyleSheet.absoluteFill}
          onPress={() => {
            if (!updateInfo.isMandatory) onDismiss();
          }}
        />
        <View
          style={[
            styles.card,
            {
              borderColor: updateInfo.isMandatory
                ? 'rgba(198, 93, 36, 0.45)'
                : 'rgba(198, 93, 36, 0.22)',
            },
          ]}
        >
          <View style={styles.iconCircle}>
            <Animated.View style={{ transform: [{ scale: pulse }] }}>
              <Ionicons
                name={updateInfo.isMandatory ? 'shield-checkmark' : 'sync-circle'}
                size={44}
                color={AppTheme.burntOrange}
              />
            </Animated.View>
          </View>

          <View style={styles.headerBlock}>
            <Text accessibilityRole="header" style={styles.title}>
              {updateInfo.title}
            </Text>
            <Text style={styles.message}>{updateInfo.message}</Text>
          </View>

          {trimmedNotes.length > 0 && (
            <View style={styles.notesCard}>
              <Text style={styles.notesHeader}>{t("What's New")}</Text>
              <ScrollView style={styles.notesScroll}>
                <Text style={styles.notesText}>{trimmedNotes}</Text>
              </ScrollView>
            </View>
          )}

          <View style={styles.actions}>
            <PrimaryButton
              title={t('Update Now')}
              iconName="download-outline"
              onPress={onUpdate}
              style={styles.fullWidth}
            />
            {!updateInfo.isMandatory && (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Maybe Later')}
                onPress={onDismiss}
                style={styles.laterBtn}
              >
                <Text style={styles.laterText}>{t('Maybe Later')}</Text>
              </Pressable>
            )}
          </View>
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
    padding: 24,
  },
  card: {
    width: '100%',
    maxWidth: 380,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusLarge,
    borderWidth: 1,
    padding: AppTheme.paddingLarge,
    alignItems: 'center',
    gap: AppTheme.paddingLarge,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.45,
    shadowRadius: 18,
    elevation: 12,
  },
  iconCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(198, 93, 36, 0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerBlock: {
    alignItems: 'center',
    gap: 8,
  },
  title: {
    ...Typography.title,
    color: AppTheme.primaryText,
    textAlign: 'center',
  },
  message: {
    ...Typography.caption,
    color: AppTheme.secondaryText,
    textAlign: 'center',
  },
  notesCard: {
    width: '100%',
    backgroundColor: AppTheme.surfaceBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    padding: AppTheme.paddingMedium,
    gap: 6,
  },
  notesHeader: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.primaryText,
  },
  notesScroll: {
    maxHeight: 110,
  },
  notesText: {
    ...Typography.caption,
    color: AppTheme.secondaryText,
  },
  actions: {
    width: '100%',
    gap: 10,
    alignItems: 'center',
  },
  fullWidth: {
    width: '100%',
  },
  laterBtn: {
    width: '100%',
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  laterText: {
    ...Typography.body,
    color: AppTheme.secondaryText,
  },
});
