import React, { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import { getCurrentAdSettings } from '../../services/adConfiguration';
import { loadGoogleMobileAdsModule } from '../../services/adMobController';

interface Props {
  placementID: string;
  canPresentAds: boolean;
  reloadToken: string;
}

const BANNER_WELL_HEIGHT = 60;

export function AdvertisementSlot({
  placementID,
  canPresentAds,
  reloadToken,
}: Props) {
  const { t } = useLanguage();
  const [failed, setFailed] = useState(false);

  const settings = getCurrentAdSettings();
  if (!canPresentAds || settings.mode === 'disabled' || !settings.bannerAdUnitID || failed) {
    return null;
  }

  const adsModule = loadGoogleMobileAdsModule();
  if (!adsModule) {
    return null;
  }

  const { BannerAd, BannerAdSize } = adsModule;

  return (
    <View
      testID={`advertisement-slot-${placementID}`}
      accessibilityLabel={t('Advertisement')}
      style={styles.card}
    >
      <Text accessibilityRole="header" style={styles.label}>
        {t('ADVERTISEMENT')}
      </Text>
      <View style={styles.bannerWell}>
        <BannerAd
          key={`${placementID}-${reloadToken}`}
          unitId={settings.bannerAdUnitID}
          size={BannerAdSize.LARGE_ANCHORED_ADAPTIVE_BANNER}
          requestOptions={{
            requestNonPersonalizedAdsOnly: true,
            networkExtras: { npa: '1' },
          }}
          onAdFailedToLoad={() => setFailed(true)}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    width: '100%',
    padding: AppTheme.paddingMedium,
    backgroundColor: AppTheme.adBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    borderWidth: 1,
    borderColor: AppTheme.separator,
    gap: 8,
    overflow: 'hidden',
  },
  label: {
    ...Typography.smallCaption,
    fontFamily: FontFamily.bold,
    color: AppTheme.tertiaryText,
    letterSpacing: 0.6,
  },
  bannerWell: {
    height: BANNER_WELL_HEIGHT,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
});
