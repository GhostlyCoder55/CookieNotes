import React, { useEffect, useState } from 'react';
import {
  FlatList,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppTheme, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';

interface Props {
  visible: boolean;
  photoUris: string[];
  initialIndex?: number;
  onClose: () => void;
}

export function PhotoViewerModal({
  visible,
  photoUris,
  initialIndex = 0,
  onClose,
}: Props) {
  const { t } = useLanguage();
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();

  const [currentIndex, setCurrentIndex] = useState(initialIndex);
  const [zoomed, setZoomed] = useState(false);

  useEffect(() => {
    if (visible) {
      setCurrentIndex(
        Math.max(0, Math.min(initialIndex, Math.max(0, photoUris.length - 1)))
      );
      setZoomed(false);
    }
  }, [visible, initialIndex, photoUris.length]);

  if (!visible || photoUris.length === 0) return null;

  return (
    <Modal
      visible={visible}
      animationType="fade"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View style={styles.screen}>
        <FlatList
          data={photoUris}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          initialScrollIndex={Math.max(
            0,
            Math.min(initialIndex, photoUris.length - 1)
          )}
          getItemLayout={(_, index) => ({
            length: width,
            offset: width * index,
            index,
          })}
          keyExtractor={(uri, idx) => `${idx}-${uri}`}
          onMomentumScrollEnd={(e) => {
            const idx = Math.round(
              e.nativeEvent.contentOffset.x / Math.max(width, 1)
            );
            setCurrentIndex(idx);
            setZoomed(false);
          }}
          renderItem={({ item: uri }) => (
            <Pressable
              onPress={() => setZoomed((z) => !z)}
              style={[styles.page, { width, height }]}
            >
              <Image
                source={{ uri }}
                style={{
                  width: zoomed ? width * 1.6 : width,
                  height: zoomed ? height * 1.15 : height * 0.8,
                }}
                contentFit="contain"
              />
            </Pressable>
          )}
        />

        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('Close')}
          onPress={onClose}
          style={[styles.closeBtn, { top: insets.top + 12 }]}
        >
          <Ionicons name="close-circle" size={34} color={AppTheme.white} />
        </Pressable>

        {photoUris.length > 1 && (
          <View
            style={[styles.counterPill, { bottom: Math.max(insets.bottom, 20) }]}
          >
            <Text style={styles.counterText}>
              {currentIndex + 1} / {photoUris.length}
            </Text>
          </View>
        )}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#000000',
  },
  page: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeBtn: {
    position: 'absolute',
    right: 16,
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  counterPill: {
    position: 'absolute',
    alignSelf: 'center',
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: 'rgba(23, 20, 18, 0.78)',
  },
  counterText: {
    ...Typography.smallCaption,
    color: AppTheme.white,
  },
});
