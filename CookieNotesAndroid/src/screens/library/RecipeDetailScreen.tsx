import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  BackHandler,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import {
  useNavigation,
  useRoute,
  type RouteProp,
} from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { RecipeInputLimits } from '../../constants/limits';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { useLanguage } from '../../localization/LanguageContext';
import { showsContentBanner } from '../../services/adPlacement';
import type {
  EditableLine,
  LibraryStackParamList,
  PendingPhoto,
  Recipe,
  RecipeCategory,
} from '../../types/models';
import { findMatchingIconID } from '../../utils/ingredientCatalog';
import { hapticSelection } from '../../utils/haptics';
import {
  deletePhotoFiles,
  processAndSavePhotoFromUri,
} from '../../utils/photoProcessing';
import {
  RECIPE_CATEGORIES,
  getCategoryColor,
  getCategoryCoverElements,
  getCategoryIconName,
  getCategoryTitle,
  parseRecipeCategory,
  resolveRecipeCoverElements,
} from '../../utils/recipeCategory';
import {
  buildRecipeShareText,
  formatRecipeServings,
  formatRecipeTotalTime,
  getRecipeTotalTime,
  getSortedPhotos,
  resolveDisplayIngredientsForDetail,
  resolveDisplayInstructionsForDetail,
  resolveLocalizedIngredients,
  resolveLocalizedInstructions,
  resolveLocalizedRecipeName,
} from '../../utils/recipeLibrary';
import {
  cleanRecipeDraft,
  sanitizeMinutes,
  sanitizeServings,
} from '../../utils/recipeSanitizer';
import { generateUUID } from '../../utils/uuid';
import { AdvertisementSlot } from '../../components/common/AdvertisementSlot';
import {
  ColorChip,
  EditableLinesSection,
  EmptyState,
  PrimaryButton,
  RecipeFormSection,
  SecondaryButton,
  SectionSurface,
  ThemedTextInput,
  TimeInfoView,
  TimeStepperRow,
} from '../../components/common/AppComponents';
import { FoodIconView } from '../../components/common/FoodIconView';
import { IngredientPickerModal } from './IngredientPickerModal';
import { PhotoViewerModal } from './PhotoViewerModal';

type DetailRoute = RouteProp<LibraryStackParamList, 'RecipeDetail'>;
type NavProp = NativeStackNavigationProp<LibraryStackParamList, 'RecipeDetail'>;

function buildIngredientLines(
  recipe: Recipe,
  lang: 'en' | 'fr' | 'es'
): EditableLine[] {
  const localized = resolveLocalizedIngredients(recipe, lang);
  return localized.map((text, index) => ({
    id: generateUUID(),
    text,
    iconID: recipe.ingredientIconIDs[index] ?? '',
  }));
}

export function RecipeDetailScreen() {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<NavProp>();
  const route = useRoute<DetailRoute>();
  const {
    recipes,
    adState,
    adsAreUnobstructed,
    toggleFavorite,
    updateRecipe,
    deleteRecipe,
  } = useAppState();

  const recipe = useMemo(
    () => recipes.find((r) => r.recipeID === route.params.recipeID) ?? null,
    [recipes, route.params.recipeID]
  );

  const [isEditing, setIsEditing] = useState(false);
  const [cookMode, setCookMode] = useState(false);
  const [cookStep, setCookStep] = useState(0);
  const [moreMenuVisible, setMoreMenuVisible] = useState(false);
  const [viewerUris, setViewerUris] = useState<string[] | null>(null);
  const [viewerIndex, setViewerIndex] = useState(0);
  const [showingIngredientPicker, setShowingIngredientPicker] = useState(false);
  const [illustrationTargetID, setIllustrationTargetID] = useState<string | null>(
    null
  );

  // Editor state
  const [name, setName] = useState('');
  const [ingredients, setIngredients] = useState<EditableLine[]>([]);
  const [instructions, setInstructions] = useState<EditableLine[]>([]);
  const [notes, setNotes] = useState('');
  const [source, setSource] = useState('');
  const [prepTime, setPrepTime] = useState(0);
  const [cookTime, setCookTime] = useState(0);
  const [servings, setServings] = useState(0);
  const [category, setCategory] = useState<RecipeCategory>('uncategorized');
  const [coverIconID, setCoverIconID] = useState('');
  const [usesCategoryCover, setUsesCategoryCover] = useState(false);
  const [removedPhotoIDs, setRemovedPhotoIDs] = useState<Set<string>>(
    () => new Set()
  );
  const [pendingPhotos, setPendingPhotos] = useState<PendingPhoto[]>([]);
  const [isSaving, setIsSaving] = useState(false);

  const sortedPhotos = useMemo(
    () => (recipe ? getSortedPhotos(recipe) : []),
    [recipe]
  );

  const visibleExistingPhotos = useMemo(
    () => sortedPhotos.filter((p) => !removedPhotoIDs.has(p.photoID)),
    [sortedPhotos, removedPhotoIDs]
  );

  const photoCount = visibleExistingPhotos.length + pendingPhotos.length;

  const beginEditing = useCallback(() => {
    if (!recipe) return;
    setName(resolveLocalizedRecipeName(recipe, language));
    setIngredients(buildIngredientLines(recipe, language));
    const steps = resolveLocalizedInstructions(recipe, language);
    setInstructions(
      steps.length > 0
        ? steps.map((s) => ({ id: generateUUID(), text: s, iconID: '' }))
        : [{ id: generateUUID(), text: '', iconID: '' }]
    );
    setNotes(recipe.notes);
    setSource(recipe.source);
    setPrepTime(recipe.prepTime);
    setCookTime(recipe.cookTime);
    setServings(recipe.servings);
    setCategory(parseRecipeCategory(recipe.categoryRaw));
    setCoverIconID(recipe.coverIconID);
    setUsesCategoryCover(recipe.usesCategoryCover);
    setRemovedPhotoIDs(new Set());
    setPendingPhotos([]);
    setIsEditing(true);
  }, [recipe, language]);

  const cancelEditing = useCallback(() => {
    for (const p of pendingPhotos) {
      deletePhotoFiles(p);
    }
    setRemovedPhotoIDs(new Set());
    setPendingPhotos([]);
    setIsEditing(false);
  }, [pendingPhotos]);

  const sanitizedDraft = useMemo(
    () =>
      cleanRecipeDraft({
        name,
        ingredients: ingredients.map((i) => i.text),
        instructions: instructions.map((i) => i.text),
        notes,
        source,
      }),
    [name, ingredients, instructions, notes, source]
  );

  const hasChanges = useMemo(() => {
    if (!recipe) return false;
    const baseName = resolveLocalizedRecipeName(recipe, language);
    const baseIng = resolveLocalizedIngredients(recipe, language);
    const baseInst = resolveLocalizedInstructions(recipe, language);
    const nonEmptyLines = ingredients.filter(
      (l) => l.text.replace(/[\r\n]+/g, ' ').trim().length > 0
    );
    const currentIcons = nonEmptyLines
      .slice(0, sanitizedDraft.ingredients.length)
      .map((l) => l.iconID);
    const baseIcons = baseIng.map((_, idx) => recipe.ingredientIconIDs[idx] ?? '');

    return (
      sanitizedDraft.name !== baseName ||
      JSON.stringify(sanitizedDraft.ingredients) !== JSON.stringify(baseIng) ||
      JSON.stringify(sanitizedDraft.instructions) !== JSON.stringify(baseInst) ||
      sanitizedDraft.notes !== recipe.notes ||
      sanitizedDraft.source !== recipe.source ||
      sanitizeMinutes(prepTime) !== recipe.prepTime ||
      sanitizeMinutes(cookTime) !== recipe.cookTime ||
      sanitizeServings(servings) !== recipe.servings ||
      category !== parseRecipeCategory(recipe.categoryRaw) ||
      coverIconID !== recipe.coverIconID ||
      usesCategoryCover !== recipe.usesCategoryCover ||
      JSON.stringify(currentIcons) !== JSON.stringify(baseIcons) ||
      removedPhotoIDs.size > 0 ||
      pendingPhotos.length > 0
    );
  }, [
    recipe,
    language,
    sanitizedDraft,
    ingredients,
    prepTime,
    cookTime,
    servings,
    category,
    coverIconID,
    usesCategoryCover,
    removedPhotoIDs,
    pendingPhotos,
  ]);

  // Android hardware back handler
  useEffect(() => {
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      if (cookMode) {
        setCookMode(false);
        return true;
      }
      if (isEditing) {
        if (hasChanges) {
          Alert.alert(
            t('Discard changes?'),
            t('Your unsaved edits will be lost.'),
            [
              { text: t('Keep editing'), style: 'cancel' },
              {
                text: t('Discard'),
                style: 'destructive',
                onPress: cancelEditing,
              },
            ]
          );
        } else {
          cancelEditing();
        }
        return true;
      }
      return false;
    });
    return () => sub.remove();
  }, [cookMode, isEditing, hasChanges, cancelEditing, t]);

  if (!recipe) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top }]}>
        <View style={styles.topHeader}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={t('Library')}
            onPress={() => navigation.goBack()}
            style={styles.backBtn}
          >
            <Ionicons name="chevron-back" size={24} color={AppTheme.burntOrange} />
          </Pressable>
        </View>
        <EmptyState
          illustration="soup_bowl"
          title={t('Recipe unavailable')}
          message={t('This recipe is no longer in your library.')}
        />
      </View>
    );
  }

  const displayTitle = resolveLocalizedRecipeName(recipe, language);
  const displayIngredients = resolveDisplayIngredientsForDetail(recipe, language);
  const displayInstructions = resolveDisplayInstructionsForDetail(recipe, language);
  const recipeCat = parseRecipeCategory(recipe.categoryRaw);
  const coverElements = resolveRecipeCoverElements(recipe);

  const editCoverElements = (() => {
    if (
      (category === 'dinner' || category === 'dessert') &&
      (coverIconID === getCategoryIconName(category) || !coverIconID)
    ) {
      return getCategoryCoverElements(category);
    }
    if (!coverIconID) return getCategoryCoverElements(category);
    return [coverIconID];
  })();

  const handleShare = async () => {
    try {
      await Share.share({
        title: displayTitle,
        message: buildRecipeShareText(recipe, language),
      });
    } catch {
      // Ignore user cancellation
    }
  };

  const confirmDelete = () => {
    setMoreMenuVisible(false);
    Alert.alert(
      t('Delete Recipe'),
      t("Delete %@? This can't be undone.", displayTitle),
      [
        { text: t('Cancel'), style: 'cancel' },
        {
          text: t('Delete'),
          style: 'destructive',
          onPress: () => {
            void deleteRecipe(recipe.recipeID).then(() => {
              navigation.goBack();
            });
          },
        },
      ]
    );
  };

  const handlePickPhoto = async () => {
    if (photoCount >= RecipeInputLimits.photoCount) return;
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
      setPendingPhotos((prev) => [
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

  const saveChanges = async () => {
    if (!sanitizedDraft.name || isSaving) return;
    setIsSaving(true);
    try {
      await updateRecipe({
        original: recipe,
        draft: sanitizedDraft,
        ingredientLines: ingredients,
        prepTime,
        cookTime,
        servings,
        category,
        coverIconID,
        usesCategoryCover,
        removedPhotoIDs,
        pendingPhotos,
      });
      setRemovedPhotoIDs(new Set());
      setPendingPhotos([]);
      setIsEditing(false);
    } catch {
      Alert.alert(
        t("Couldn't save"),
        t("The recipe couldn't be saved. Try again.")
      );
    } finally {
      setIsSaving(false);
    }
  };

  const galleryUris = [
    ...visibleExistingPhotos.map((p) => p.imageUri),
    ...pendingPhotos.map((p) => p.imageUri),
  ];

  // COOK MODE SCREEN
  if (cookMode) {
    const stepTotal = Math.max(displayInstructions.length, 1);
    const hasStep = cookStep < displayInstructions.length;
    const isLast = cookStep >= displayInstructions.length - 1;
    const progressPct = Math.min(100, ((cookStep + 1) / stepTotal) * 100);

    return (
      <View
        style={[
          styles.screen,
          { paddingTop: insets.top, paddingBottom: Math.max(insets.bottom, 16) },
        ]}
      >
        <View style={styles.topHeader}>
          <View style={styles.headerSpacer} />
          <Text style={styles.topTitle}>{t('Cook Mode')}</Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={t('Done')}
            onPress={() => setCookMode(false)}
            style={styles.headerTextBtn}
          >
            <Text style={styles.burntTextBtn}>{t('Done')}</Text>
          </Pressable>
        </View>

        <View style={styles.progressTrack}>
          <View style={[styles.progressFill, { width: `${progressPct}%` }]} />
        </View>

        <View style={styles.cookCenter}>
          {hasStep ? (
            <>
              <FoodIconView iconIDs={coverElements} size={100} />
              <Text style={styles.cookStepLabel}>
                {t(
                  'Step %lld of %lld',
                  cookStep + 1,
                  displayInstructions.length
                )}
              </Text>
              <ScrollView
                style={styles.cookStepScroll}
                contentContainerStyle={styles.cookStepScrollInner}
              >
                <Text style={styles.cookStepText}>
                  {displayInstructions[cookStep]}
                </Text>
              </ScrollView>
            </>
          ) : (
            <>
              <Text accessibilityRole="header" style={styles.doneTitle}>
                {t('You’re done!')}
              </Text>
              <FoodIconView iconID="cupcake" size={120} />
            </>
          )}
        </View>

        <View style={styles.cookFooter}>
          <SecondaryButton
            title={t('Previous')}
            disabled={cookStep === 0}
            onPress={() => {
              void hapticSelection();
              setCookStep((s) => Math.max(0, s - 1));
            }}
            style={styles.cookNavBtn}
          />
          <PrimaryButton
            title={isLast ? t('Finish') : t('Next')}
            onPress={() => {
              void hapticSelection();
              if (isLast) {
                setCookMode(false);
              } else {
                setCookStep((s) => s + 1);
              }
            }}
            style={styles.cookNavBtn}
          />
        </View>
      </View>
    );
  }

  const servingsText = formatRecipeServings(recipe.servings, language);

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      {/* Top Toolbar */}
      <View style={styles.topHeader}>
        {isEditing ? (
          <>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Cancel')}
              onPress={cancelEditing}
              style={styles.headerTextBtn}
            >
              <Text style={styles.secondaryTextBtn}>{t('Cancel')}</Text>
            </Pressable>
            <Text accessibilityRole="header" style={styles.topTitle}>
              {t('Edit Recipe')}
            </Text>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Save')}
              disabled={!hasChanges || !sanitizedDraft.name || isSaving}
              onPress={() => void saveChanges()}
              style={styles.headerTextBtn}
            >
              <Text
                style={[
                  styles.burntTextBtn,
                  (!hasChanges || !sanitizedDraft.name || isSaving) && {
                    color: AppTheme.tertiaryText,
                  },
                ]}
              >
                {t('Save')}
              </Text>
            </Pressable>
          </>
        ) : (
          <>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('Library')}
              onPress={() => navigation.goBack()}
              style={styles.backBtn}
            >
              <Ionicons
                name="chevron-back"
                size={26}
                color={AppTheme.burntOrange}
              />
            </Pressable>
            <View style={styles.readerToolbarRight}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={
                  recipe.isFavorite
                    ? t('Remove favorite')
                    : t('Add favorite')
                }
                onPress={() => void toggleFavorite(recipe.recipeID)}
                style={styles.iconBtn}
              >
                <Ionicons
                  name={recipe.isFavorite ? 'heart' : 'heart-outline'}
                  size={22}
                  color={AppTheme.burntOrange}
                />
              </Pressable>

              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Share recipe')}
                onPress={() => void handleShare()}
                style={styles.iconBtn}
              >
                <Ionicons
                  name="share-outline"
                  size={22}
                  color={AppTheme.burntOrange}
                />
              </Pressable>

              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Edit')}
                onPress={beginEditing}
                style={styles.headerTextBtn}
              >
                <Text style={styles.burntTextBtn}>{t('Edit')}</Text>
              </Pressable>

              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('More options')}
                onPress={() => setMoreMenuVisible(true)}
                style={styles.iconBtn}
              >
                <Ionicons
                  name="ellipsis-horizontal-circle"
                  size={22}
                  color={AppTheme.burntOrange}
                />
              </Pressable>
            </View>
          </>
        )}
      </View>

      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'android' ? undefined : 'padding'}
      >
        <ScrollView
          contentContainerStyle={[
            styles.scrollContent,
            { paddingBottom: Math.max(insets.bottom, 24) },
          ]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {isEditing ? (
            <>
              <RecipeFormSection title={t('Recipe Name')}>
                <ThemedTextInput
                  value={name}
                  onChangeText={setName}
                  placeholder={t('Recipe name')}
                  autoCapitalize="words"
                />
              </RecipeFormSection>

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

              <SectionSurface>
                <View style={styles.editCoverRow}>
                  <View style={styles.editCoverThumb}>
                    {visibleExistingPhotos[0]?.thumbnailUri ||
                    pendingPhotos[0]?.thumbnailUri ? (
                      <Image
                        source={{
                          uri:
                            visibleExistingPhotos[0]?.thumbnailUri ??
                            pendingPhotos[0]?.thumbnailUri,
                        }}
                        style={StyleSheet.absoluteFill}
                        contentFit="cover"
                      />
                    ) : (
                      <FoodIconView iconIDs={editCoverElements} size={72} />
                    )}
                  </View>
                  <View style={styles.editCoverText}>
                    <Text style={styles.coverTitle}>
                      {visibleExistingPhotos.length + pendingPhotos.length > 0
                        ? t('Cover photo')
                        : t('Cover illustration')}
                    </Text>
                    <Text style={styles.coverSub}>
                      {visibleExistingPhotos.length + pendingPhotos.length > 0
                        ? t(
                            'Your first photo is the cover. Remove all photos to use an illustration instead.'
                          )
                        : t(
                            'Shown when this recipe has no photos. Pick a category to choose the illustration.'
                          )}
                    </Text>
                  </View>
                </View>
              </SectionSurface>

              <TimeStepperRow
                prepTime={prepTime}
                cookTime={cookTime}
                servings={servings}
                onChangePrep={setPrepTime}
                onChangeCook={setCookTime}
                onChangeServings={setServings}
              />

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

              <EditableLinesSection
                title={t('Instructions')}
                addTitle={t('Add Step')}
                placeholder={t('Write the step…')}
                lines={instructions}
                onChangeLines={setInstructions}
                numbered
              />

              <RecipeFormSection title={t('Notes')}>
                <ThemedTextInput
                  value={notes}
                  onChangeText={setNotes}
                  placeholder={t('A tip or a memory')}
                  multiline
                />
              </RecipeFormSection>

              <RecipeFormSection title={t('Source')}>
                <ThemedTextInput
                  value={source}
                  onChangeText={setSource}
                  placeholder={t('Optional link or where it came from')}
                  autoCapitalize="none"
                  autoCorrect={false}
                />
              </RecipeFormSection>

              <RecipeFormSection title={t('Photos')}>
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={t('Add Photo')}
                  disabled={photoCount >= RecipeInputLimits.photoCount}
                  onPress={() => void handlePickPhoto()}
                  style={styles.addPhotoBtn}
                >
                  <Ionicons
                    name="add-circle"
                    size={20}
                    color={
                      photoCount >= RecipeInputLimits.photoCount
                        ? AppTheme.tertiaryText
                        : AppTheme.burntOrange
                    }
                  />
                  <Text
                    style={[
                      styles.addPhotoText,
                      photoCount >= RecipeInputLimits.photoCount && {
                        color: AppTheme.tertiaryText,
                      },
                    ]}
                  >
                    {t('Add Photo')}
                  </Text>
                </Pressable>

                {photoCount === 0 ? (
                  <Text style={styles.emptyHint}>{t('No photos yet')}</Text>
                ) : (
                  <View style={styles.photoGrid}>
                    {visibleExistingPhotos.map((photo, index) => (
                      <View key={photo.photoID} style={styles.photoCell}>
                        <Pressable
                          accessibilityRole="button"
                          accessibilityLabel={t('View photo %lld', index + 1)}
                          onPress={() => {
                            setViewerIndex(index);
                            setViewerUris(galleryUris);
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
                          onPress={() =>
                            setRemovedPhotoIDs((prev) => {
                              const next = new Set(prev);
                              next.add(photo.photoID);
                              return next;
                            })
                          }
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

                    {pendingPhotos.map((photo, pIdx) => {
                      const idx = visibleExistingPhotos.length + pIdx;
                      return (
                        <View key={photo.id} style={styles.photoCell}>
                          <Pressable
                            accessibilityRole="button"
                            accessibilityLabel={t('View photo %lld', idx + 1)}
                            onPress={() => {
                              setViewerIndex(idx);
                              setViewerUris(galleryUris);
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
                            onPress={() => {
                              deletePhotoFiles(photo);
                              setPendingPhotos((prev) =>
                                prev.filter((p) => p.id !== photo.id)
                              );
                            }}
                            style={styles.removePhotoBtn}
                          >
                            <Ionicons
                              name="close-circle"
                              size={22}
                              color={AppTheme.error}
                            />
                          </Pressable>
                        </View>
                      );
                    })}
                  </View>
                )}
              </RecipeFormSection>
            </>
          ) : (
            <>
              {/* Hero Photo or Category Illustration */}
              {visibleExistingPhotos[0]?.imageUri ? (
                <Pressable
                  onPress={() => {
                    setViewerIndex(0);
                    setViewerUris(galleryUris);
                  }}
                  style={styles.heroPhotoWrap}
                >
                  <Image
                    source={{ uri: visibleExistingPhotos[0].imageUri }}
                    style={StyleSheet.absoluteFill}
                    contentFit="cover"
                  />
                </Pressable>
              ) : (
                <View
                  style={[
                    styles.heroIllustrationWrap,
                    { backgroundColor: `${getCategoryColor(recipeCat)}33` },
                  ]}
                >
                  <FoodIconView iconIDs={coverElements} size={136} />
                </View>
              )}

              {/* Title + Metadata */}
              <View style={styles.titleBlock}>
                <Text accessibilityRole="header" style={styles.recipeTitle}>
                  {displayTitle}
                </Text>
                <View style={styles.metaPills}>
                  <View style={styles.metaItem}>
                    <Ionicons
                      name="time-outline"
                      size={15}
                      color={AppTheme.secondaryText}
                    />
                    <Text style={styles.metaText}>
                      {formatRecipeTotalTime(recipe, language)}
                    </Text>
                  </View>
                  {servingsText && (
                    <View style={styles.metaItem}>
                      <Ionicons
                        name="people-outline"
                        size={15}
                        color={AppTheme.secondaryText}
                      />
                      <Text style={styles.metaText}>{servingsText}</Text>
                    </View>
                  )}
                  <View
                    style={[
                      styles.catBadge,
                      { backgroundColor: `${getCategoryColor(recipeCat)}33` },
                    ]}
                  >
                    <Text style={styles.catBadgeText}>
                      {getCategoryTitle(recipeCat, language)}
                    </Text>
                  </View>
                </View>
              </View>

              {/* Time Cards */}
              <View style={styles.timeRow}>
                <TimeInfoView title={t('Prep')} time={recipe.prepTime} />
                <TimeInfoView title={t('Cook')} time={recipe.cookTime} />
                <TimeInfoView
                  title={t('Total')}
                  time={getRecipeTotalTime(recipe)}
                />
              </View>

              {/* Ingredients */}
              <SectionSurface style={styles.readSection}>
                <Text accessibilityRole="header" style={styles.sectionHeader}>
                  {t('Ingredients')}
                </Text>
                {displayIngredients.map((text, idx) => {
                  const stored = recipe.ingredientIconIDs[idx] ?? '';
                  const iconID =
                    stored || findMatchingIconID(text, language) || '';
                  return (
                    <View key={`ing-${idx}-${text}`} style={styles.ingRow}>
                      <FoodIconView iconID={iconID} size={38} />
                      <Text style={styles.ingText}>{text}</Text>
                    </View>
                  );
                })}
              </SectionSurface>

              {/* Instructions */}
              <SectionSurface style={styles.readSection}>
                <Text accessibilityRole="header" style={styles.sectionHeader}>
                  {t('Instructions')}
                </Text>
                {displayInstructions.map((step, idx) => (
                  <View key={`step-${idx}`} style={styles.stepRow} accessible>
                    <View style={styles.stepCircle}>
                      <Text style={styles.stepCircleText}>{idx + 1}</Text>
                    </View>
                    <Text style={styles.stepText}>{step}</Text>
                  </View>
                ))}
              </SectionSurface>

              {recipe.notes.trim().length > 0 && (
                <SectionSurface style={styles.readSection}>
                  <Text accessibilityRole="header" style={styles.sectionHeader}>
                    {t('Notes')}
                  </Text>
                  <Text style={styles.bodyText}>{recipe.notes}</Text>
                </SectionSurface>
              )}

              {recipe.source.trim().length > 0 && (
                <SectionSurface style={styles.readSection}>
                  <Text accessibilityRole="header" style={styles.sectionHeader}>
                    {t('Source')}
                  </Text>
                  <Text style={styles.sourceText}>{recipe.source}</Text>
                </SectionSurface>
              )}

              {visibleExistingPhotos.length > 0 && (
                <RecipeFormSection title={t('Photos')}>
                  <View style={styles.photoGrid}>
                    {visibleExistingPhotos.map((photo, idx) => (
                      <Pressable
                        key={photo.photoID}
                        accessibilityRole="button"
                        accessibilityLabel={t('View photo %lld', idx + 1)}
                        onPress={() => {
                          setViewerIndex(idx);
                          setViewerUris(galleryUris);
                        }}
                        style={styles.photoThumbBtn}
                      >
                        <Image
                          source={{ uri: photo.thumbnailUri }}
                          style={StyleSheet.absoluteFill}
                          contentFit="cover"
                        />
                      </Pressable>
                    ))}
                  </View>
                </RecipeFormSection>
              )}

              <PrimaryButton
                title={t('Start cooking')}
                onPress={() => {
                  setCookStep(0);
                  setCookMode(true);
                }}
              />

              {showsContentBanner(adState.canPresentAds, true) &&
                adsAreUnobstructed && (
                  <AdvertisementSlot
                    placementID={`detail-${recipe.recipeID}`}
                    canPresentAds={adState.canPresentAds}
                    reloadToken={adState.reloadToken}
                  />
                )}
            </>
          )}
        </ScrollView>
      </KeyboardAvoidingView>

      {/* Overflow Menu Modal */}
      <Modal
        visible={moreMenuVisible}
        transparent
        animationType="fade"
        onRequestClose={() => setMoreMenuVisible(false)}
        statusBarTranslucent
      >
        <Pressable
          style={styles.menuBackdrop}
          onPress={() => setMoreMenuVisible(false)}
        >
          <View style={styles.menuCard}>
            <Pressable
              accessibilityRole="button"
              onPress={() => {
                setMoreMenuVisible(false);
                setCookStep(0);
                setCookMode(true);
              }}
              style={styles.menuRow}
            >
              <Ionicons
                name="restaurant-outline"
                size={20}
                color={AppTheme.primaryText}
              />
              <Text style={styles.menuRowText}>{t('Cook Mode')}</Text>
            </Pressable>

            <View style={styles.menuDivider} />

            <Pressable
              accessibilityRole="button"
              onPress={confirmDelete}
              style={styles.menuRow}
            >
              <Ionicons
                name="trash-outline"
                size={20}
                color={AppTheme.tomatoRed}
              />
              <Text style={[styles.menuRowText, { color: AppTheme.tomatoRed }]}>
                {t('Delete')}
              </Text>
            </Pressable>
          </View>
        </Pressable>
      </Modal>

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
        }}
      />

      <PhotoViewerModal
        visible={viewerUris !== null}
        photoUris={viewerUris ?? []}
        initialIndex={viewerIndex}
        onClose={() => setViewerUris(null)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: {
    flex: 1,
    backgroundColor: AppTheme.background,
  },
  topHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 10,
    minHeight: 50,
    borderBottomWidth: 1,
    borderBottomColor: AppTheme.separator,
  },
  backBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  readerToolbarRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  iconBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTextBtn: {
    minHeight: 44,
    paddingHorizontal: 10,
    justifyContent: 'center',
  },
  headerSpacer: {
    minWidth: 64,
  },
  topTitle: {
    ...Typography.headline,
    color: AppTheme.primaryText,
  },
  burntTextBtn: {
    ...Typography.headline,
    color: AppTheme.burntOrange,
  },
  secondaryTextBtn: {
    ...Typography.body,
    color: AppTheme.secondaryText,
  },
  scrollContent: {
    padding: AppTheme.paddingMedium,
    gap: AppTheme.paddingLarge,
  },
  heroPhotoWrap: {
    width: '100%',
    height: 240,
    borderRadius: AppTheme.cornerRadiusLarge,
    overflow: 'hidden',
    backgroundColor: AppTheme.parchment,
  },
  heroIllustrationWrap: {
    width: '100%',
    height: 220,
    borderRadius: AppTheme.cornerRadiusLarge,
    alignItems: 'center',
    justifyContent: 'center',
  },
  titleBlock: {
    gap: 8,
  },
  recipeTitle: {
    ...Typography.largeTitle,
    color: AppTheme.primaryText,
  },
  metaPills: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: 10,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  metaText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.secondaryText,
  },
  catBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 999,
  },
  catBadgeText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.secondaryText,
  },
  timeRow: {
    flexDirection: 'row',
    gap: 8,
  },
  readSection: {
    gap: 12,
  },
  sectionHeader: {
    ...Typography.sectionLabel,
    color: AppTheme.accent,
  },
  ingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  ingText: {
    ...Typography.body,
    color: AppTheme.primaryText,
    flex: 1,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
  },
  stepCircle: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: AppTheme.burntOrange,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 1,
  },
  stepCircleText: {
    ...Typography.smallCaption,
    fontFamily: FontFamily.bold,
    color: AppTheme.white,
  },
  stepText: {
    ...Typography.body,
    color: AppTheme.primaryText,
    flex: 1,
  },
  bodyText: {
    ...Typography.body,
    color: AppTheme.primaryText,
  },
  sourceText: {
    ...Typography.body,
    color: AppTheme.secondaryText,
  },
  chipsRow: {
    gap: 8,
  },
  editCoverRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  editCoverThumb: {
    width: 88,
    height: 88,
    borderRadius: 18,
    backgroundColor: AppTheme.parchment,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  editCoverText: {
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
  emptyHint: {
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
  progressTrack: {
    height: 4,
    backgroundColor: AppTheme.parchment,
    marginHorizontal: AppTheme.paddingMedium,
    marginTop: 12,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: AppTheme.burntOrange,
  },
  cookCenter: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: AppTheme.paddingLarge,
    gap: 20,
  },
  cookStepLabel: {
    ...Typography.caption,
    fontFamily: FontFamily.bold,
    color: AppTheme.accentAction,
  },
  cookStepScroll: {
    maxHeight: 260,
    width: '100%',
  },
  cookStepScrollInner: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  cookStepText: {
    ...Typography.title,
    color: AppTheme.primaryText,
    textAlign: 'center',
  },
  doneTitle: {
    ...Typography.largeTitle,
    color: AppTheme.primaryText,
    textAlign: 'center',
  },
  cookFooter: {
    flexDirection: 'row',
    gap: 16,
    paddingHorizontal: AppTheme.paddingLarge,
    paddingBottom: AppTheme.paddingMedium,
  },
  cookNavBtn: {
    flex: 1,
  },
  menuBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.45)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  menuCard: {
    width: '100%',
    maxWidth: 300,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    paddingVertical: 6,
  },
  menuRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 18,
    minHeight: 50,
  },
  menuRowText: {
    ...Typography.body,
    color: AppTheme.primaryText,
  },
  menuDivider: {
    height: 1,
    backgroundColor: AppTheme.separator,
  },
});
