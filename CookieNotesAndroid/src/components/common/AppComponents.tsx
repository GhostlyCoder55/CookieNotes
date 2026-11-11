import React, { useRef, type ComponentRef } from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { RecipeInputLimits } from '../../constants/limits';
import { AppTheme, CardElevation, FontFamily, Typography } from '../../constants/theme';
import { useLanguage } from '../../localization/LanguageContext';
import type { EditableLine } from '../../types/models';
import { hapticSelection } from '../../utils/haptics';
import { formatDurationShort } from '../../utils/recipeTimeEstimator';
import { FoodIconView } from './FoodIconView';

export function TitleSubtitleBlock({
  title,
  subtitle = '',
  styleVariant = 'page',
  alignment = 'center',
}: {
  title: string;
  subtitle?: string;
  styleVariant?: 'hero' | 'page' | 'compact';
  alignment?: 'center' | 'leading';
}) {
  const titleTypo =
    styleVariant === 'hero' ? Typography.largeTitle : Typography.title;
  const subtitleTypo =
    styleVariant === 'compact' ? Typography.caption : Typography.body;
  const textAlign = alignment === 'leading' ? 'left' : 'center';
  const trimmedSub = subtitle.trim();

  return (
    <View
      style={[
        styles.titleBlock,
        alignment === 'leading' ? styles.alignStart : styles.alignCenter,
      ]}
    >
      <Text
        accessibilityRole="header"
        style={[
          titleTypo,
          { color: AppTheme.primaryText, textAlign },
        ]}
      >
        {title}
      </Text>
      {trimmedSub.length > 0 && (
        <Text
          style={[
            subtitleTypo,
            styles.subtitleText,
            {
              color: AppTheme.secondaryText,
              textAlign,
              marginTop: styleVariant === 'compact' ? 4 : 8,
            },
          ]}
        >
          {trimmedSub}
        </Text>
      )}
    </View>
  );
}

export function PrimaryButton({
  title,
  onPress,
  disabled = false,
  iconName,
  style,
  testID,
}: {
  title: string;
  onPress: () => void;
  disabled?: boolean;
  iconName?: keyof typeof Ionicons.glyphMap;
  style?: StyleProp<ViewStyle>;
  testID?: string;
}) {
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={title}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.primaryBtn,
        pressed && !disabled && styles.primaryBtnPressed,
        disabled && styles.primaryBtnDisabled,
        style,
      ]}
    >
      <View style={styles.btnInnerRow}>
        {iconName && (
          <Ionicons
            name={iconName}
            size={18}
            color={AppTheme.white}
            style={styles.btnIcon}
          />
        )}
        <Text style={styles.primaryBtnText} numberOfLines={1}>
          {title}
        </Text>
      </View>
    </Pressable>
  );
}

export function SecondaryButton({
  title,
  onPress,
  disabled = false,
  style,
}: {
  title: string;
  onPress: () => void;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={title}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.secondaryBtn,
        pressed && !disabled && styles.secondaryBtnPressed,
        disabled && styles.secondaryBtnDisabled,
        style,
      ]}
    >
      <Text
        style={[
          styles.secondaryBtnText,
          disabled && { color: AppTheme.tertiaryText },
        ]}
        numberOfLines={1}
      >
        {title}
      </Text>
    </Pressable>
  );
}

export function ColorChip({
  title,
  selected,
  onPress,
  testID,
}: {
  title: string;
  selected: boolean;
  onPress: () => void;
  testID?: string;
}) {
  return (
    <Pressable
      testID={testID}
      accessibilityRole="tab"
      accessibilityState={{ selected }}
      accessibilityLabel={title}
      onPress={() => {
        if (!selected) void hapticSelection();
        onPress();
      }}
      style={({ pressed }) => [
        styles.chipOuter,
        { opacity: pressed ? 0.88 : 1 },
      ]}
    >
      <View
        style={[
          styles.chipPill,
          selected ? styles.chipPillSelected : styles.chipPillDefault,
        ]}
      >
        <Text
          style={[
            styles.chipText,
            { color: selected ? AppTheme.white : AppTheme.primaryText },
          ]}
          numberOfLines={1}
        >
          {title}
        </Text>
      </View>
    </Pressable>
  );
}

export function NoticeBanner({
  message,
  iconName = 'information-circle-outline',
  onDismiss,
  testID = 'notice-banner',
}: {
  message: string;
  iconName?: keyof typeof Ionicons.glyphMap;
  onDismiss?: () => void;
  testID?: string;
}) {
  const { t } = useLanguage();
  return (
    <View testID={testID} style={styles.noticeBanner}>
      <Ionicons
        name={iconName}
        size={20}
        color={AppTheme.burntOrange}
        style={styles.noticeIcon}
      />
      <Text style={styles.noticeText}>{message}</Text>
      {onDismiss && (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('Dismiss')}
          onPress={onDismiss}
          style={styles.noticeDismiss}
        >
          <Text style={styles.noticeDismissText}>{t('Dismiss')}</Text>
        </Pressable>
      )}
    </View>
  );
}

export function RecipeThumbnail({
  uri,
  iconID = '',
  iconIDs = [],
  size = 80,
}: {
  uri?: string | null;
  iconID?: string;
  iconIDs?: string[];
  size?: number;
}) {
  const cleanIDs = iconIDs.filter((id) => id.trim().length > 0);
  return (
    <View style={styles.thumbFill}>
      {uri ? (
        <Image
          source={{ uri }}
          style={StyleSheet.absoluteFill}
          contentFit="cover"
          transition={150}
          cachePolicy="memory-disk"
        />
      ) : cleanIDs.length > 0 || iconID.trim().length > 0 ? (
        <FoodIconView iconID={iconID} iconIDs={cleanIDs} size={size} />
      ) : (
        <Ionicons
          name="restaurant-outline"
          size={40}
          color={AppTheme.burntOrange}
        />
      )}
    </View>
  );
}

export function EmptyState({
  iconName = 'book-outline',
  title,
  message = '',
  illustration,
  actionTitle,
  onAction,
}: {
  iconName?: keyof typeof Ionicons.glyphMap;
  title: string;
  message?: string;
  illustration?: string;
  actionTitle?: string;
  onAction?: () => void;
}) {
  return (
    <View style={styles.emptyState}>
      {illustration ? (
        <FoodIconView iconID={illustration} size={112} />
      ) : (
        <Ionicons
          name={iconName}
          size={48}
          color={AppTheme.burntOrange}
        />
      )}

      <View style={styles.emptyTextWrap}>
        <TitleSubtitleBlock title={title} subtitle={message} styleVariant="page" />
      </View>

      {actionTitle && onAction && (
        <PrimaryButton title={actionTitle} onPress={onAction} />
      )}
    </View>
  );
}

export function SectionSurface({
  children,
  style,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return <View style={[styles.sectionSurface, style]}>{children}</View>;
}

export function RecipeFormSection({
  title,
  actionTitle,
  onAction,
  children,
}: {
  title: string;
  actionTitle?: string;
  onAction?: () => void;
  children: React.ReactNode;
}) {
  return (
    <SectionSurface>
      <View style={styles.formSectionHeader}>
        <Text accessibilityRole="header" style={styles.formSectionTitle}>
          {title}
        </Text>
        {actionTitle && onAction && (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={actionTitle}
            onPress={onAction}
            style={styles.formActionBtn}
          >
            <Text style={styles.formActionText}>{actionTitle}</Text>
          </Pressable>
        )}
      </View>
      <View style={styles.formSectionBody}>{children}</View>
    </SectionSurface>
  );
}

export function TimeInfoView({ title, time }: { title: string; time: number }) {
  const { t, language } = useLanguage();
  const formatted = time === 0 ? t('None') : formatDurationShort(time, language);
  return (
    <View style={styles.timeInfoCard} accessible accessibilityLabel={`${title}: ${formatted}`}>
      <Text style={styles.timeInfoLabel}>{title}</Text>
      <Text style={styles.timeInfoValue} numberOfLines={1}>
        {formatted}
      </Text>
    </View>
  );
}

export function TimeStepperRow({
  prepTime,
  cookTime,
  servings,
  onChangePrep,
  onChangeCook,
  onChangeServings,
}: {
  prepTime: number;
  cookTime: number;
  servings: number;
  onChangePrep: (v: number) => void;
  onChangeCook: (v: number) => void;
  onChangeServings: (v: number) => void;
}) {
  const { t } = useLanguage();
  return (
    <View style={styles.timeStepperRow}>
      <TimeStepperItem
        title={t('Prep')}
        value={prepTime}
        unit={t('min')}
        max={RecipeInputLimits.maxMinutes}
        onChange={onChangePrep}
      />
      <TimeStepperItem
        title={t('Cook')}
        value={cookTime}
        unit={t('min')}
        max={RecipeInputLimits.maxMinutes}
        onChange={onChangeCook}
      />
      <TimeStepperItem
        title={t('Serves')}
        value={servings}
        unit=""
        max={RecipeInputLimits.maxServings}
        onChange={onChangeServings}
      />
    </View>
  );
}

function TimeStepperItem({
  title,
  value,
  unit,
  max,
  onChange,
}: {
  title: string;
  value: number;
  unit: string;
  max: number;
  onChange: (next: number) => void;
}) {
  const { t } = useLanguage();
  const canDec = value > 0;
  const canInc = value < max;
  return (
    <View style={styles.stepperCol}>
      <Text style={styles.stepperTitle}>{title}</Text>
      <View style={styles.stepperBox}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('Decrease %@', title.toLowerCase())}
          disabled={!canDec}
          onPress={() => {
            void hapticSelection();
            onChange(Math.max(0, value - 1));
          }}
          style={styles.stepperHit}
        >
          <Ionicons
            name="remove-circle"
            size={22}
            color={canDec ? AppTheme.burntOrange : AppTheme.tertiaryText}
          />
        </Pressable>

        <View style={styles.stepperValueBox}>
          <Text style={styles.stepperValue} numberOfLines={1}>
            {value}
          </Text>
          {unit.length > 0 && (
            <Text style={styles.stepperUnit} numberOfLines={1}>
              {unit}
            </Text>
          )}
        </View>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel={t('Increase %@', title.toLowerCase())}
          disabled={!canInc}
          onPress={() => {
            void hapticSelection();
            onChange(Math.min(max, value + 1));
          }}
          style={styles.stepperHit}
        >
          <Ionicons
            name="add-circle"
            size={22}
            color={canInc ? AppTheme.burntOrange : AppTheme.tertiaryText}
          />
        </Pressable>
      </View>
    </View>
  );
}

export function EditableLinesSection({
  title,
  addTitle,
  placeholder,
  lines,
  onChangeLines,
  numbered = false,
  illustrated = false,
  onPickIllustration,
}: {
  title: string;
  addTitle: string;
  placeholder: string;
  lines: EditableLine[];
  onChangeLines: (next: EditableLine[]) => void;
  numbered?: boolean;
  illustrated?: boolean;
  onPickIllustration?: (lineID: string) => void;
}) {
  const { t } = useLanguage();
  const inputRefs = useRef<Record<string, ComponentRef<typeof TextInput> | null>>({});

  const addLine = () => {
    const newId = `line_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    const updated = [...lines, { id: newId, text: '', iconID: '' }];
    onChangeLines(updated);
    setTimeout(() => {
      inputRefs.current[newId]?.focus();
    }, 80);
  };

  const removeLine = (id: string) => {
    if (lines.length <= 1) return;
    onChangeLines(lines.filter((l) => l.id !== id));
  };

  const updateLineText = (id: string, text: string) => {
    onChangeLines(lines.map((l) => (l.id === id ? { ...l, text } : l)));
  };

  return (
    <RecipeFormSection title={title} actionTitle={addTitle} onAction={addLine}>
      {lines.length === 0 ? (
        <Text style={styles.emptyHint}>
          {t('Tap %@ to start writing.', addTitle)}
        </Text>
      ) : (
        lines.map((line, index) => (
          <View key={line.id} style={styles.editableRow}>
            {illustrated && (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Choose ingredient')}
                onPress={() => onPickIllustration?.(line.id)}
                style={styles.illustrationPickBtn}
              >
                {line.iconID ? (
                  <FoodIconView iconID={line.iconID} size={34} />
                ) : (
                  <Ionicons name="add" size={20} color={AppTheme.burntOrange} />
                )}
              </Pressable>
            )}

            {numbered && (
              <Text style={styles.stepNumberLabel}>{index + 1}.</Text>
            )}

            <TextInput
              ref={(el) => {
                inputRefs.current[line.id] = el;
              }}
              value={line.text}
              onChangeText={(txt) => updateLineText(line.id, txt)}
              placeholder={placeholder}
              placeholderTextColor={AppTheme.tertiaryText}
              multiline={numbered}
              style={[
                styles.textInputBase,
                styles.flexInput,
                numbered && { minHeight: 52, textAlignVertical: 'top' },
              ]}
              autoCapitalize={numbered ? 'sentences' : 'words'}
              returnKeyType="next"
              maxLength={
                numbered
                  ? RecipeInputLimits.instruction
                  : RecipeInputLimits.ingredient
              }
            />

            {lines.length > 1 && (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Remove %@', placeholder.toLowerCase())}
                onPress={() => removeLine(line.id)}
                style={styles.removeLineBtn}
              >
                <Ionicons
                  name="remove-circle"
                  size={22}
                  color={AppTheme.error}
                />
              </Pressable>
            )}
          </View>
        ))
      )}
    </RecipeFormSection>
  );
}

export function ThemedTextInput({
  value,
  onChangeText,
  placeholder,
  multiline = false,
  autoCapitalize = 'sentences',
  autoCorrect = true,
  style,
  testID,
}: {
  value: string;
  onChangeText: (text: string) => void;
  placeholder: string;
  multiline?: boolean;
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters';
  autoCorrect?: boolean;
  style?: StyleProp<TextStyle>;
  testID?: string;
}) {
  return (
    <TextInput
      testID={testID}
      value={value}
      onChangeText={onChangeText}
      placeholder={placeholder}
      placeholderTextColor={AppTheme.tertiaryText}
      multiline={multiline}
      autoCapitalize={autoCapitalize}
      autoCorrect={autoCorrect}
      style={[
        styles.textInputBase,
        multiline && styles.multilineInput,
        style,
      ]}
    />
  );
}

const styles = StyleSheet.create({
  titleBlock: {
    width: '100%',
  },
  alignCenter: {
    alignItems: 'center',
  },
  alignStart: {
    alignItems: 'flex-start',
  },
  subtitleText: {
    maxWidth: 360,
  },
  primaryBtn: {
    minHeight: 48,
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 12,
    borderRadius: AppTheme.cornerRadiusMedium,
    backgroundColor: AppTheme.burntOrange,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primaryBtnPressed: {
    backgroundColor: AppTheme.brightOrange,
    transform: [{ scale: 0.98 }],
  },
  primaryBtnDisabled: {
    opacity: 0.48,
  },
  primaryBtnText: {
    ...Typography.headline,
    color: AppTheme.white,
  },
  btnInnerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  btnIcon: {
    marginRight: 8,
  },
  secondaryBtn: {
    minHeight: 48,
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 12,
    borderRadius: AppTheme.cornerRadiusMedium,
    backgroundColor: AppTheme.parchment,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.32)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryBtnPressed: {
    backgroundColor: 'rgba(251, 227, 98, 0.18)',
    transform: [{ scale: 0.98 }],
  },
  secondaryBtnDisabled: {
    opacity: 0.5,
  },
  secondaryBtnText: {
    ...Typography.headline,
    color: AppTheme.burntOrange,
  },
  chipOuter: {
    minHeight: 44,
    justifyContent: 'center',
  },
  chipPill: {
    minHeight: 38,
    paddingHorizontal: 14,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  chipPillSelected: {
    backgroundColor: AppTheme.burntOrange,
    borderColor: AppTheme.burntOrange,
  },
  chipPillDefault: {
    backgroundColor: AppTheme.cardBackground,
    borderColor: 'rgba(198, 93, 36, 0.25)',
  },
  chipText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
  },
  noticeBanner: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: AppTheme.bannerFill,
    borderRadius: AppTheme.cornerRadiusMedium,
    padding: AppTheme.paddingMedium,
    gap: 10,
  },
  noticeIcon: {
    marginTop: 1,
  },
  noticeText: {
    ...Typography.caption,
    color: AppTheme.primaryText,
    flex: 1,
  },
  noticeDismiss: {
    minHeight: 44,
    justifyContent: 'center',
    paddingLeft: 8,
  },
  noticeDismissText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.burntOrange,
  },
  thumbFill: {
    flex: 1,
    width: '100%',
    height: '100%',
    backgroundColor: AppTheme.parchment,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: AppTheme.paddingLarge,
    paddingVertical: AppTheme.paddingXLarge,
    gap: AppTheme.paddingLarge,
  },
  emptyTextWrap: {
    width: '100%',
    alignItems: 'center',
  },
  sectionSurface: {
    width: '100%',
    padding: AppTheme.paddingMedium,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    ...CardElevation,
  },
  formSectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  formSectionTitle: {
    ...Typography.sectionLabel,
    color: AppTheme.burntOrange,
  },
  formActionBtn: {
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  formActionText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.burntOrange,
  },
  formSectionBody: {
    gap: 10,
  },
  timeInfoCard: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    paddingHorizontal: 6,
    backgroundColor: AppTheme.surfaceBackground,
    borderRadius: 12,
    gap: 4,
  },
  timeInfoLabel: {
    ...Typography.smallCaption,
    color: AppTheme.tertiaryText,
  },
  timeInfoValue: {
    ...Typography.headline,
    color: AppTheme.primaryText,
  },
  timeStepperRow: {
    flexDirection: 'row',
    gap: 8,
  },
  stepperCol: {
    flex: 1,
    gap: 6,
  },
  stepperTitle: {
    ...Typography.sectionLabel,
    color: AppTheme.secondaryText,
  },
  stepperBox: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: AppTheme.surfaceBackground,
    borderRadius: AppTheme.cornerRadiusSmall,
    paddingVertical: 4,
  },
  stepperHit: {
    width: 36,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepperValueBox: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepperValue: {
    ...Typography.caption,
    fontFamily: FontFamily.bold,
    color: AppTheme.primaryText,
  },
  stepperUnit: {
    ...Typography.smallCaption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.secondaryText,
  },
  editableRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  illustrationPickBtn: {
    width: 46,
    height: 46,
    borderRadius: 10,
    backgroundColor: AppTheme.parchment,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.22)',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 2,
  },
  stepNumberLabel: {
    ...Typography.body,
    fontFamily: FontFamily.bold,
    color: AppTheme.burntOrange,
    width: 26,
    marginTop: 13,
  },
  removeLineBtn: {
    width: 40,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyHint: {
    ...Typography.caption,
    color: AppTheme.tertiaryText,
  },
  textInputBase: {
    ...Typography.body,
    color: AppTheme.primaryText,
    backgroundColor: AppTheme.parchment,
    borderRadius: AppTheme.cornerRadiusSmall,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.22)',
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 12,
  },
  flexInput: {
    flex: 1,
  },
  multilineInput: {
    minHeight: 120,
    textAlignVertical: 'top',
  },
});
