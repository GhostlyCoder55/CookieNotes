import React from 'react';
import {
  Linking,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Image } from 'expo-image';
import { useIsFocused } from '@react-navigation/native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppTheme, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { useLanguage } from '../../localization/LanguageContext';
import { SUPPORTED_LANGUAGES } from '../../localization/i18n';
import { getCurrentAdSettings } from '../../services/adConfiguration';
import { hapticSelection } from '../../utils/haptics';
import {
  NoticeBanner,
  PrimaryButton,
  SecondaryButton,
  SectionSurface,
  TitleSubtitleBlock,
} from '../../components/common/AppComponents';
import { AdvertisementSlot } from '../../components/common/AdvertisementSlot';
import { HexagonFlagBadge } from '../../components/common/HexagonFlagBadge';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const APP_LOGO = require('../../../assets/branding/AppLogo.png');

export function AboutScreen() {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const isFocused = useIsFocused();
  const {
    setAppLanguage,
    adState,
    adsAreUnobstructed,
    openPrivacySheet,
    presentPlatformPrivacyOptions,
  } = useAppState();

  const adSettings = getCurrentAdSettings();

  const openPrivacyPolicy = () => {
    if (adSettings.privacyPolicyURL) {
      void Linking.openURL(adSettings.privacyPolicyURL);
    }
  };

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.headerRow}>
        <Text accessibilityRole="header" style={styles.headerTitle}>
          {t('About')}
        </Text>
      </View>

      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Brand Block */}
        <View style={styles.brandRow}>
          <Image
            source={APP_LOGO}
            style={styles.logo}
            contentFit="contain"
            accessibilityElementsHidden
          />
          <View style={styles.brandTextWrap}>
            <TitleSubtitleBlock
              title="CookieNotes"
              subtitle={t('Your personal cooking library')}
              styleVariant="compact"
              alignment="leading"
            />
          </View>
        </View>

        {/* Language Section */}
        <SectionSurface>
          <Text accessibilityRole="header" style={styles.sectionTitle}>
            {t('Language')}
          </Text>
          <View style={styles.langList}>
            {SUPPORTED_LANGUAGES.map((option, idx) => {
              const isSelected = language === option.code;
              return (
                <React.Fragment key={option.code}>
                  <Pressable
                    accessibilityRole="radio"
                    accessibilityLabel={option.displayName}
                    accessibilityState={{ checked: isSelected }}
                    onPress={() => {
                      void hapticSelection();
                      void setAppLanguage(option.code);
                    }}
                    style={styles.langRow}
                  >
                    <View
                      style={[
                        styles.radioOuter,
                        {
                          borderColor: isSelected
                            ? AppTheme.burntOrange
                            : AppTheme.separator,
                        },
                      ]}
                    >
                      {isSelected && <View style={styles.radioInner} />}
                    </View>
                    <HexagonFlagBadge
                      language={option.code}
                      width={24}
                      height={27}
                    />
                    <Text style={styles.langLabel}>{option.displayName}</Text>
                  </Pressable>
                  {idx < SUPPORTED_LANGUAGES.length - 1 && (
                    <View style={styles.divider} />
                  )}
                </React.Fragment>
              );
            })}
          </View>
        </SectionSurface>

        {/* About Blocks */}
        <SectionSurface style={styles.aboutSection}>
          <AboutBlock
            title={t('Library')}
            body={t(
              'Keep personal recipes with photos, illustrated ingredients, favorites, and cook mode.'
            )}
          />
          <AboutBlock
            title={t('Discover')}
            body={t(
              'Explore recipes from the database, preview the details, and save your favorites directly to your journal.'
            )}
          />
          <AboutBlock
            title={t('List')}
            body={t(
              'Keep a grocery checklist, check items off as you shop, sort, and clear completed items anytime.'
            )}
          />
          <AboutBlock
            title={t('Privacy and ads')}
            body={t(
              'Recipes stay on this device. Ads help keep CookieNotes free.'
            )}
          />

          {adState.availabilityMessage && (
            <NoticeBanner message={adState.availabilityMessage} />
          )}

          <PrimaryButton
            title={t('Ads')}
            onPress={() => openPrivacySheet('settings')}
            style={styles.fullBtn}
          />

          {adState.privacyOptionsRequired && (
            <SecondaryButton
              title={t('Manage privacy options')}
              onPress={() => void presentPlatformPrivacyOptions()}
              style={styles.fullBtn}
            />
          )}

          {adSettings.privacyPolicyURL && (
            <SecondaryButton
              title={t('Privacy Policy')}
              onPress={openPrivacyPolicy}
              style={styles.fullBtn}
            />
          )}
        </SectionSurface>

        {adsAreUnobstructed && isFocused && adState.canPresentAds && (
          <AdvertisementSlot
            placementID="about"
            canPresentAds={adState.canPresentAds}
            reloadToken={adState.reloadToken}
          />
        )}
      </ScrollView>
    </View>
  );
}

function AboutBlock({ title, body }: { title: string; body: string }) {
  return (
    <View style={styles.aboutBlock} accessible>
      <Text accessibilityRole="header" style={styles.sectionTitle}>
        {title}
      </Text>
      <Text style={styles.aboutBody}>{body}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  headerRow: {
    paddingHorizontal: AppTheme.paddingMedium,
    paddingTop: 12,
    paddingBottom: 6,
  },
  headerTitle: {
    ...Typography.largeTitle,
    color: AppTheme.primaryText,
  },
  scrollContent: {
    padding: AppTheme.paddingMedium,
    gap: AppTheme.paddingLarge,
    paddingBottom: 28,
  },
  brandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  logo: {
    width: 64,
    height: 64,
    borderRadius: 16,
  },
  brandTextWrap: {
    flex: 1,
  },
  sectionTitle: {
    ...Typography.sectionLabel,
    color: AppTheme.accent,
  },
  langList: {
    marginTop: 8,
  },
  langRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    minHeight: 46,
    paddingVertical: 6,
  },
  radioOuter: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: AppTheme.burntOrange,
  },
  langLabel: {
    ...Typography.headline,
    color: AppTheme.primaryText,
    flex: 1,
  },
  divider: {
    height: 1,
    backgroundColor: AppTheme.separator,
  },
  aboutSection: {
    gap: AppTheme.paddingMedium,
  },
  aboutBlock: {
    gap: 6,
  },
  aboutBody: {
    ...Typography.body,
    color: AppTheme.primaryText,
  },
  fullBtn: {
    width: '100%',
  },
});
