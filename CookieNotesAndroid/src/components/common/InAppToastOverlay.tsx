import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';

export function InAppToastOverlay({
  message,
  visible,
  topOffset = 8,
}: {
  message: string | null;
  visible: boolean;
  topOffset?: number;
}) {
  const opacity = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(0.98)).current;

  useEffect(() => {
    if (visible && message) {
      Animated.parallel([
        Animated.timing(opacity, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
        Animated.timing(scale, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
      ]).start();
    } else {
      Animated.timing(opacity, {
        toValue: 0,
        duration: 180,
        useNativeDriver: true,
      }).start();
    }
  }, [visible, message, opacity, scale]);

  if (!message) return null;

  return (
    <View
      pointerEvents="none"
      style={[styles.overlayWrap, { top: topOffset }]}
    >
      <Animated.View
        testID="recipe-added-toast"
        style={[
          styles.toastCard,
          { opacity, transform: [{ scale }] },
        ]}
      >
        <Ionicons
          name="checkmark-circle"
          size={20}
          color={AppTheme.burntOrange}
        />
        <Text style={styles.toastText}>{message}</Text>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  overlayWrap: {
    position: 'absolute',
    left: AppTheme.paddingMedium,
    right: AppTheme.paddingMedium,
    zIndex: 50,
    alignItems: 'center',
  },
  toastCard: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: AppTheme.cardBackground,
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 14,
    borderRadius: AppTheme.cornerRadiusMedium,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.38)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.45,
    shadowRadius: 12,
    elevation: 8,
  },
  toastText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.primaryText,
    flex: 1,
  },
});
