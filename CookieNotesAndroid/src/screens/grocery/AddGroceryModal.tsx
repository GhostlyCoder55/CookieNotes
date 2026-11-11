import React, { useEffect, useRef, useState, type ComponentRef } from 'react';
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import { sanitizeGroceryName } from '../../utils/groceryListLogic';

interface Props {
  visible: boolean;
  onAdd: (name: string) => Promise<boolean>;
  onClose: () => void;
}

export function AddGroceryModal({ visible, onAdd, onClose }: Props) {
  const { t } = useLanguage();
  const insets = useSafeAreaInsets();
  const inputRef = useRef<ComponentRef<typeof TextInput>>(null);

  const [itemText, setItemText] = useState('');
  const [lastAddedName, setLastAddedName] = useState<string | null>(null);

  const trimmed = sanitizeGroceryName(itemText);
  const canSubmit = trimmed.length > 0;

  useEffect(() => {
    if (visible) {
      setLastAddedName(null);
      setItemText('');
      const timer = setTimeout(() => {
        inputRef.current?.focus();
      }, 120);
      return () => clearTimeout(timer);
    }
    return undefined;
  }, [visible]);

  const submitCurrent = async () => {
    const cleaned = sanitizeGroceryName(itemText);
    if (!cleaned) return false;
    const ok = await onAdd(cleaned);
    if (ok) {
      setLastAddedName(cleaned);
      setItemText('');
    }
    return ok;
  };

  const handleKeyboardSubmit = async () => {
    if (canSubmit) {
      await submitCurrent();
      setTimeout(() => {
        inputRef.current?.focus();
      }, 40);
    } else {
      onClose();
    }
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <KeyboardAvoidingView
        style={styles.root}
        behavior={Platform.OS === 'android' ? 'height' : 'padding'}
      >
        <Pressable
          style={styles.backdrop}
          onPress={onClose}
          accessibilityLabel={t('Done')}
        />
        <View
          style={[
            styles.sheet,
            { paddingBottom: Math.max(insets.bottom, 16) + 12 },
          ]}
        >
          <View style={styles.grabber} />
          <View style={styles.header}>
            <Text accessibilityRole="header" style={styles.title}>
              {t('Add grocery')}
            </Text>
            <Pressable
              testID="add-grocery-done-button"
              accessibilityRole="button"
              accessibilityLabel={t('Done')}
              onPress={onClose}
              style={styles.doneBtn}
            >
              <Text style={styles.doneText}>{t('Done')}</Text>
            </Pressable>
          </View>

          <View style={styles.inputRow}>
            <TextInput
              ref={inputRef}
              testID="add-grocery-textfield"
              value={itemText}
              onChangeText={setItemText}
              placeholder={t('Add grocery item…')}
              placeholderTextColor={AppTheme.tertiaryText}
              style={styles.input}
              autoCapitalize="sentences"
              returnKeyType="done"
              submitBehavior="submit"
              onSubmitEditing={() => void handleKeyboardSubmit()}
            />

            <Pressable
              testID="add-grocery-submit-button"
              accessibilityRole="button"
              accessibilityLabel={t('Add item')}
              accessibilityState={{ disabled: !canSubmit }}
              disabled={!canSubmit}
              onPress={() => void submitCurrent()}
              style={({ pressed }) => [
                styles.submitBtn,
                !canSubmit && styles.submitBtnDisabled,
                pressed && canSubmit && { transform: [{ scale: 0.94 }] },
              ]}
            >
              <Ionicons name="add" size={24} color={AppTheme.white} />
            </Pressable>
          </View>

          <Text
            testID="add-grocery-feedback"
            style={[styles.feedback, { opacity: lastAddedName ? 1 : 0 }]}
            numberOfLines={1}
          >
            {lastAddedName ? t('Added %@', lastAddedName) : ' '}
          </Text>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.45)',
  },
  sheet: {
    backgroundColor: AppTheme.parchment,
    borderTopLeftRadius: AppTheme.cornerRadiusLarge,
    borderTopRightRadius: AppTheme.cornerRadiusLarge,
    paddingHorizontal: AppTheme.paddingMedium,
    paddingTop: 10,
    gap: 14,
  },
  grabber: {
    alignSelf: 'center',
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: AppTheme.separator,
    marginBottom: 2,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: {
    ...Typography.headline,
    color: AppTheme.primaryText,
  },
  doneBtn: {
    minHeight: 44,
    paddingHorizontal: 8,
    justifyContent: 'center',
  },
  doneText: {
    ...Typography.headline,
    color: AppTheme.burntOrange,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  input: {
    flex: 1,
    ...Typography.body,
    color: AppTheme.primaryText,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusSmall,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.25)',
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 12,
  },
  submitBtn: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: AppTheme.burntOrange,
    alignItems: 'center',
    justifyContent: 'center',
  },
  submitBtnDisabled: {
    opacity: 0.45,
  },
  feedback: {
    ...Typography.caption,
    color: AppTheme.secondaryText,
    fontFamily: FontFamily.semiBold,
  },
});
