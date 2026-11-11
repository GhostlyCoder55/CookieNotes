import React, { useMemo, useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { RecipeInputLimits } from '../../constants/limits';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { useLanguage } from '../../localization/LanguageContext';
import type { EditableLine, PendingPhoto, RecipeCategory } from '../../types/models';
import {
  RECIPE_CATEGORIES,
  getCategoryCoverElements,
  getCategoryIconName,
  getCategoryTitle,
} from '../../utils/recipeCategory';
import {
  deletePhotoFiles,
  processAndSavePhotoFromUri,
} from '../../utils/photoProcessing';
import { cleanRecipeDraft } from '../../utils/recipeSanitizer';
import { generateUUID } from '../../utils/uuid';
import {
  ColorChip,
  EditableLinesSection,
  RecipeFormSection,
  SectionSurface,
  ThemedTextInput,
  TimeStepperRow,
} from '../../components/common/AppComponents';
import { FoodIconView } from '../../components/common/FoodIconView';
import { IngredientPickerModal } from './IngredientPickerModal';
import { PhotoViewerModal } from './PhotoViewerModal';

interface Props {
  visible: boolean;
  onClose: () => void;
}

export function AddRecipeScreen({ visible, onClose }: Props) {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const { saveNewRecipe } = useAppState();

  const [name, setName] = useState('');
  const [ingredients, setIngredients] = useState<EditableLine[]>([
    { id: generateUUID(), text: '', iconID: '' },
  ]);
  const [instructions, setInstructions] = useState<EditableLine[]>([
    { id: generateUUID(), text: '', iconID: '' },
  ]);
  const [notes, setNotes] = useState('');
  const [source, setSource] = useState('');
  const [prepTime, setPrepTime] = useState(0);
  const [cookTime, setCookTime] = useState(0);
  const [servings, setServings] = useState(1);
  const [category, setCategory] = useState<RecipeCategory>('uncategorized');
  const [coverIconID, setCoverIconID] = useState('veggie_plate');
  const [usesCategoryCover, setUsesCategoryCover] = useState(false);
  const [photos, setPhotos] = useState<PendingPhoto[]>([]);
  const [isSaving, setIsSaving] = useState(false);

  const [showingIngredientPicker, setShowingIngredientPicker] = useState(false);
  const [illustrationTargetID, setIllustrationTargetID] = useState<string | null>(
    null
  );
  const [viewerVisible, setViewerVisible] = useState(false);
  const [viewerIndex, setViewerIndex] = useState(0);

  const canSave = name.trim().length > 0 && !isSaving;

  const resetForm = () => {
    setName('');
    setIngredients([{ id: generateUUID(), text: '', iconID: '' }]);
    setInstructions([{ id: generateUUID(), text: '', iconID: '' }]);
    setNotes('');
    setSource('');
    setPrepTime(0);
    setCookTime(0);
    setServings(1);
    setCategory('uncategorized');
    setCoverIconID('veggie_plate');
    setUsesCategoryCover(false);
    setPhotos([]);
    setIsSaving(false);
  };

  const handleCancel = () => {
    for (const p of photos) {
      deletePhotoFiles(p);
    }
    resetForm();
    onClose();
  };

  const coverPreviewElements = useMemo(() => {
    if (
      (category === 'dinner' || category === 'dessert') &&
      (coverIconID === getCategoryIconName(category) ||
        coverIconID === 'veggie_plate')
    ) {
      return getCategoryCoverElements(category);
    }
    return [coverIconID];
  }, [category, coverIconID]);

  const handlePickPhoto = async () => {
    if (photos.length >= RecipeInputLimits.photoCount) return;
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        quality: 0.9,
      });
      if (result.canceled || !result.assets?.[0]?.uri) return;
      const stored = await processAndSavePhotoFromUri(result.assets[0].uri);
      if (!stored) {
        Alert.alert(
          t("Couldn't save"),
          t("That photo couldn't be read. Try a different one.")
        );
        return;
      }
      setPhotos((prev) => [
        ...prev,
        {
          id: generateUUID(),
          imageUri: stored.imageUri,
          thumbnailUri: stored.thumbnailUri,
        },
      ]);
    } catch {
      Alert.alert(
        t("Couldn't save"),
        t("That photo couldn't be read. Try a different one.")
      );
    }
  };

  const removePhoto = (photo: PendingPhoto) => {
    deletePhotoFiles(photo);
    setPhotos((prev) => prev.filter((p) => p.id !== photo.id));
  };

  const handleSave = async () => {
    if (!canSave) return;
    setIsSaving(true);
    try {
      const draft = cleanRecipeDraft({
        name,
        ingredients: ingredients.map((i) => i.text),
        instructions: instructions.map((i) => i.text),
        notes,
        source,
      });
      if (!draft.name) return;

      await saveNewRecipe({
        draft,
        ingredientLines: ingredients,
        prepTime,
        cookTime,
        servings,
        category,
        coverIconID,
        usesCategoryCover,
        photos,
      });
      resetForm();
      onClose();
    } catch {
      setIsSaving(false);
      Alert.alert(
        t("Couldn't save"),
        t("The recipe couldn't be saved. Try again.")
      );
    }
  };

  const coverImageUri = photos[0]?.thumbnailUri ?? null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      onRequestClose={handleCancel}
      statusBarTranslucent
    >
      <View
        style={[
          styles.screen,
          { paddingTop: insets.top, paddingBottom: insets.bottom },
        ]}
      >
        {/* Top Bar */}
        <View style={styles.topBar}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={t('Cancel')}
            onPress={handleCancel}
            style={styles.barActionBtn}
          >
            <Text style={styles.cancelText}>{t('Cancel')}</Text>
          </Pressable>

          <Text accessibilityRole="header" style={styles.topTitle}>
            {t('New Recipe')}
          </Text>

          <Pressable
            accessibilityRole="button"
            accessibilityLabel={t('Save')}
            accessibilityState={{ disabled: !canSave }}
            disabled={!canSave}
            onPress={() => void handleSave()}
            style={styles.barActionBtn}
          >
            <Text
              style={[
                styles.saveText,
                !canSave && { color: AppTheme.tertiaryText },
              ]}
            >
              {t('Save')}
            </Text>
          </Pressable>
        </View>

        <KeyboardAvoidingView
          style={styles.flex}
          behavior={Platform.OS === 'android' ? undefined : 'padding'}
        >
          <ScrollView
            contentContainerStyle={styles.scrollContent}
            keyboardShouldPersistTaps="handled"
            showsVerticalScrollIndicator={false}
          >
            {/* Cover Preview */}
            <SectionSurface>
              <View style={styles.coverRow}>
                <View style={styles.coverThumb}>
                  {coverImageUri ? (
                    <Image
                      source={{ uri: coverImageUri }}
                      style={StyleSheet.absoluteFill}
                      contentFit="cover"
                    />
                  ) : (
                    <FoodIconView iconIDs={coverPreviewElements} size={86} />
                  )}
                </View>
                <View style={styles.coverMeta}>
                  <Text style={styles.coverTitle}>
                    {coverImageUri ? t('Cover photo') : t('Cover illustration')}
                  </Text>
                  <Text style={styles.coverSub}>
                    {coverImageUri
                      ? t(
                          'Your first photo is the cover. Remove all photos to use an illustration instead.'
                        )
                      : t(
                          'Shown when you haven’t added photos. Pick a category vibe below.'
                        )}
                  </Text>
                </View>
              </View>
            </SectionSurface>

            {/* Recipe Name */}
            <RecipeFormSection title={t('Recipe Name')}>
              <ThemedTextInput
                value={name}
                onChangeText={setName}
                placeholder={t('Weeknight chili, banana bread…')}
                autoCapitalize="words"
              />
            </RecipeFormSection>

            {/* Category */}
            <RecipeFormSection title={t('Category')}>
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={styles.chipsRow}
              >
                {RECIPE_CATEGORIES.map((item) => (
                  <ColorChip
                    key={item}
                    title={getCategoryTitle(item, language)}
                    selected={category === item}
                    onPress={() => {
                      setCategory(item);
                      setCoverIconID(getCategoryIconName(item));
                      setUsesCategoryCover(true);
                    }}
                  />
                ))}
              </ScrollView>
            </RecipeFormSection>

            {/* Times & Servings */}
            <TimeStepperRow
              prepTime={prepTime}
              cookTime={cookTime}
              servings={servings}
              onChangePrep={setPrepTime}
              onChangeCook={setCookTime}
              onChangeServings={setServings}
            />

            {/* Ingredients */}
            <EditableLinesSection
              title={t('Ingredients')}
              addTitle={t('Add')}
              placeholder={t('Ingredient')}
              lines={ingredients}
              onChangeLines={setIngredients}
              illustrated
              onPickIllustration={(lineID) => {
                setIllustrationTargetID(lineID);
                setShowingIngredientPicker(true);
              }}
            />

            {/* Instructions */}
            <EditableLinesSection
              title={t('Instructions')}
              addTitle={t('Add Step')}
              placeholder={t('Write the step…')}
              lines={instructions}
              onChangeLines={setInstructions}
              numbered
            />

            {/* Notes */}
            <RecipeFormSection title={t('Notes')}>
              <ThemedTextInput
                value={notes}
                onChangeText={setNotes}
                placeholder={t('A tip, a memory, or a swap')}
                multiline
              />
            </RecipeFormSection>

            {/* Source */}
            <RecipeFormSection title={t('Source')}>
              <ThemedTextInput
                value={source}
                onChangeText={setSource}
                placeholder={t('Optional link or where it came from')}
                autoCapitalize="none"
                autoCorrect={false}
              />
            </RecipeFormSection>

            {/* Photos */}
            <RecipeFormSection title={t('Photos')}>
              <View style={styles.photoHeader}>
                <Text style={styles.photoCountText}>
                  {t('%lld of %lld', photos.length, RecipeInputLimits.photoCount)}
                </Text>
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={t('Add Photo')}
                  disabled={photos.length >= RecipeInputLimits.photoCount}
                  onPress={() => void handlePickPhoto()}
                  style={styles.addPhotoBtn}
                >
                  <Ionicons
                    name="add-circle"
                    size={20}
                    color={
                      photos.length >= RecipeInputLimits.photoCount
                        ? AppTheme.tertiaryText
                        : AppTheme.burntOrange
                    }
                  />
                  <Text
                    style={[
                      styles.addPhotoText,
                      photos.length >= RecipeInputLimits.photoCount && {
                        color: AppTheme.tertiaryText,
                      },
                    ]}
                  >
                    {t('Add Photo')}
                  </Text>
                </Pressable>
              </View>

              {photos.length === 0 ? (
                <Text style={styles.photoEmptyHint}>
                  {t('Optional dish photos')}
                </Text>
              ) : (
                <View style={styles.photoGrid}>
                  {photos.map((photo, index) => (
                    <View key={photo.id} style={styles.photoCell}>
                      <Pressable
                        accessibilityRole="button"
                        accessibilityLabel={t('View photo %lld', index + 1)}
                        onPress={() => {
                          setViewerIndex(index);
                          setViewerVisible(true);
                        }}
                        style={styles.photoThumbBtn}
                      >
                        <Image
                          source={{ uri: photo.thumbnailUri }}
                          style={StyleSheet.absoluteFill}
                          contentFit="cover"
                        />
                      </Pressable>
                      <Pressable
                        accessibilityRole="button"
                        accessibilityLabel={t('Remove photo')}
                        onPress={() => removePhoto(photo)}
                        style={styles.removePhotoBtn}
                      >
                        <Ionicons
                          name="close-circle"
                          size={22}
                          color={AppTheme.error}
                        />
                      </Pressable>
                    </View>
                  ))}
                </View>
              )}
            </RecipeFormSection>
          </ScrollView>
        </KeyboardAvoidingView>

        <IngredientPickerModal
          visible={showingIngredientPicker}
          onClose={() => setShowingIngredientPicker(false)}
          onPick={(displayName, iconID) => {
            if (
              illustrationTargetID &&
              ingredients.some((l) => l.id === illustrationTargetID)
            ) {
              setIngredients((prev) =>
                prev.map((l) =>
                  l.id === illustrationTargetID
                    ? { ...l, text: displayName, iconID }
                    : l
                )
              );
            } else {
              setIngredients((prev) => [
                ...prev,
                { id: generateUUID(), text: displayName, iconID },
              ]);
            }
            setIllustrationTargetID(null);
            if (!coverIconID || coverIconID === 'veggie_plate') {
              setCoverIconID(iconID);
            }
          }}
        />

        <PhotoViewerModal
          visible={viewerVisible}
          photoUris={photos.map((p) => p.imageUri)}
          initialIndex={viewerIndex}
          onClose={() => setViewerVisible(false)}
        />
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: AppTheme.paddingMedium,
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: AppTheme.separator,
  },
  barActionBtn: {
    minWidth: 64,
    minHeight: 44,
    justifyContent: 'center',
  },
  cancelText: {
    ...Typography.body,
    color: AppTheme.secondaryText,
  },
  topTitle: {
    ...Typography.headline,
    color: AppTheme.primaryText,
  },
  saveText: {
    ...Typography.headline,
    color: AppTheme.burntOrange,
    textAlign: 'right',
  },
  scrollContent: {
    padding: AppTheme.paddingMedium,
    gap: AppTheme.paddingLarge,
    paddingBottom: 40,
  },
  coverRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  coverThumb: {
    width: 100,
    height: 100,
    borderRadius: 20,
    backgroundColor: AppTheme.parchment,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  coverMeta: {
    flex: 1,
    gap: 6,
  },
  coverTitle: {
    ...Typography.headline,
    color: AppTheme.primaryText,
  },
  coverSub: {
    ...Typography.caption,
    color: AppTheme.secondaryText,
  },
  chipsRow: {
    gap: 8,
  },
  photoHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  photoCountText: {
    ...Typography.smallCaption,
    color: AppTheme.tertiaryText,
  },
  addPhotoBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    minHeight: 44,
  },
  addPhotoText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.burntOrange,
  },
  photoEmptyHint: {
    ...Typography.body,
    color: AppTheme.tertiaryText,
  },
  photoGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  photoCell: {
    width: 100,
    height: 100,
    position: 'relative',
  },
  photoThumbBtn: {
    width: 100,
    height: 100,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: AppTheme.parchment,
  },
  removePhotoBtn: {
    position: 'absolute',
    top: -6,
    right: -6,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: AppTheme.elevatedHighlight,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
