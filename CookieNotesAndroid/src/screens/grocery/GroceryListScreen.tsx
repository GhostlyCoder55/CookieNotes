import React, { useMemo, useState } from 'react';
import {
  Alert,
  FlatList,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppTheme, FontFamily, Typography } from '../../constants/theme';
import { useAppState } from '../../context/AppStateContext';
import { useLanguage } from '../../localization/LanguageContext';
import type { GroceryItem, GrocerySort } from '../../types/models';
import {
  GROCERY_SORTS,
  getGrocerySortTitle,
  sortGroceryItems,
} from '../../utils/groceryListLogic';
import { hapticSelection } from '../../utils/haptics';
import { EmptyState } from '../../components/common/AppComponents';
import { AddGroceryModal } from './AddGroceryModal';

export function GroceryListScreen() {
  const { t, language } = useLanguage();
  const insets = useSafeAreaInsets();
  const {
    groceryItems,
    grocerySort,
    setGrocerySort,
    addGrocery,
    toggleGrocery,
    editGrocery,
    removeGrocery,
    clearCheckedGrocery,
    clearAllGrocery,
  } = useAppState();

  const [showAddModal, setShowAddModal] = useState(false);
  const [showSortMenu, setShowSortMenu] = useState(false);
  const [editingItem, setEditingItem] = useState<GroceryItem | null>(null);
  const [editedName, setEditedName] = useState('');

  const displayedItems = useMemo(
    () => sortGroceryItems(groceryItems, grocerySort),
    [groceryItems, grocerySort]
  );

  const hasCheckedItems = useMemo(
    () => groceryItems.some((item) => item.isChecked),
    [groceryItems]
  );

  const handleSelectSort = (option: GrocerySort) => {
    void hapticSelection();
    void setGrocerySort(option);
    setShowSortMenu(false);
  };

  const handleClearPress = () => {
    if (groceryItems.length === 0) return;

    if (hasCheckedItems) {
      Alert.alert(
        t('Clear list?'),
        t('Choose an option to clear your grocery list.'),
        [
          { text: t('Cancel'), style: 'cancel' },
          {
            text: t('Clear checked'),
            onPress: () => void clearCheckedGrocery(),
          },
          {
            text: t('Delete all'),
            style: 'destructive',
            onPress: () => void clearAllGrocery(),
          },
        ]
      );
      return;
    }

    Alert.alert(
      t('Clear list?'),
      t('All items on your grocery list will be deleted.'),
      [
        { text: t('Cancel'), style: 'cancel' },
        {
          text: t('Delete all'),
          style: 'destructive',
          onPress: () => void clearAllGrocery(),
        },
      ]
    );
  };

  const beginEditing = (item: GroceryItem) => {
    setEditingItem(item);
    setEditedName(item.name);
  };

  const commitEdit = async () => {
    if (!editingItem) return;
    const target = editingItem;
    const nextName = editedName;
    setEditingItem(null);
    setEditedName('');
    await editGrocery(target.itemID, nextName);
  };

  const renderControlsBar = () => (
    <View style={styles.controlsBar}>
      <Pressable
        testID="grocery-sort-button"
        accessibilityRole="button"
        accessibilityLabel={t('Sort list')}
        onPress={() => setShowSortMenu(true)}
        style={styles.controlPill}
      >
        <Ionicons name="swap-vertical" size={16} color={AppTheme.primaryText} />
        <Text style={styles.controlText}>{t('Sort')}</Text>
      </Pressable>

      <Pressable
        testID="grocery-clear-button"
        accessibilityRole="button"
        accessibilityLabel={t('Clear list')}
        accessibilityState={{ disabled: groceryItems.length === 0 }}
        disabled={groceryItems.length === 0}
        onPress={handleClearPress}
        style={[
          styles.controlPill,
          groceryItems.length === 0 ? styles.clearPillDisabled : styles.clearPillActive,
        ]}
      >
        <Ionicons
          name="trash-outline"
          size={16}
          color={
            groceryItems.length === 0
              ? AppTheme.tertiaryText
              : AppTheme.tomatoRed
          }
        />
        <Text
          style={[
            styles.controlText,
            {
              color:
                groceryItems.length === 0
                  ? AppTheme.tertiaryText
                  : AppTheme.tomatoRed,
            },
          ]}
        >
          {t('Clear')}
        </Text>
      </Pressable>
    </View>
  );

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.headerRow}>
        <Text accessibilityRole="header" style={styles.headerTitle}>
          {t('List')}
        </Text>
      </View>

      {displayedItems.length === 0 ? (
        <View style={styles.emptyWrap}>
          {renderControlsBar()}
          <View style={styles.emptyCenter}>
            <EmptyState
              iconName="checkbox-outline"
              title={t('Your list is empty')}
              message={t('Tap + below to add groceries to your list.')}
            />
          </View>
        </View>
      ) : (
        <FlatList
          data={displayedItems}
          keyExtractor={(item) => item.itemID}
          ListHeaderComponent={renderControlsBar}
          contentContainerStyle={styles.listContent}
          keyboardShouldPersistTaps="handled"
          renderItem={({ item }) => (
            <View style={styles.rowContainer}>
              <Pressable
                testID="grocery-item-row"
                accessibilityRole="checkbox"
                accessibilityLabel={item.name}
                accessibilityState={{ checked: item.isChecked }}
                accessibilityHint={
                  item.isChecked
                    ? t('Double tap to uncheck')
                    : t('Double tap to check off')
                }
                onPress={() => {
                  void hapticSelection();
                  void toggleGrocery(item.itemID);
                }}
                onLongPress={() => beginEditing(item)}
                style={styles.rowTapArea}
              >
                <View
                  style={[
                    styles.checkbox,
                    item.isChecked
                      ? styles.checkboxChecked
                      : styles.checkboxUnchecked,
                  ]}
                >
                  {item.isChecked && (
                    <Ionicons
                      name="checkmark"
                      size={14}
                      color={AppTheme.white}
                    />
                  )}
                </View>

                <Text
                  style={[
                    styles.itemName,
                    item.isChecked && styles.itemNameChecked,
                  ]}
                >
                  {item.name}
                </Text>
              </Pressable>

              <View style={styles.rowActions}>
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={t('Edit')}
                  onPress={() => beginEditing(item)}
                  style={styles.rowActionBtn}
                >
                  <Ionicons
                    name="pencil-outline"
                    size={18}
                    color={AppTheme.secondaryText}
                  />
                </Pressable>

                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={t('Delete')}
                  onPress={() => void removeGrocery(item.itemID)}
                  style={styles.rowActionBtn}
                >
                  <Ionicons
                    name="trash-outline"
                    size={18}
                    color={AppTheme.tomatoRed}
                  />
                </Pressable>
              </View>
            </View>
          )}
        />
      )}

      {/* Floating bottom center + button matching iOS */}
      <View pointerEvents="box-none" style={styles.fabContainer}>
        <Pressable
          testID="add-grocery-button"
          accessibilityRole="button"
          accessibilityLabel={t('Add grocery')}
          onPress={() => setShowAddModal(true)}
          style={({ pressed }) => [
            styles.fab,
            pressed && { transform: [{ scale: 0.94 }], opacity: 0.9 },
          ]}
        >
          <Ionicons name="add" size={28} color={AppTheme.white} />
        </Pressable>
      </View>

      <AddGroceryModal
        visible={showAddModal}
        onAdd={addGrocery}
        onClose={() => setShowAddModal(false)}
      />

      {/* Sort option dialog */}
      <Modal
        visible={showSortMenu}
        transparent
        animationType="fade"
        onRequestClose={() => setShowSortMenu(false)}
        statusBarTranslucent
      >
        <Pressable
          style={styles.dialogBackdrop}
          onPress={() => setShowSortMenu(false)}
        >
          <Pressable style={styles.dialogCard} onPress={() => {}}>
            <Text style={styles.dialogTitle}>{t('Sort list')}</Text>
            {GROCERY_SORTS.map((option) => {
              const selected = grocerySort === option;
              return (
                <Pressable
                  key={option}
                  accessibilityRole="radio"
                  accessibilityState={{ checked: selected }}
                  onPress={() => handleSelectSort(option)}
                  style={styles.sortOptionRow}
                >
                  <Text
                    style={[
                      styles.sortOptionText,
                      selected && { color: AppTheme.burntOrange },
                    ]}
                  >
                    {getGrocerySortTitle(option, language)}
                  </Text>
                  {selected && (
                    <Ionicons
                      name="checkmark"
                      size={20}
                      color={AppTheme.burntOrange}
                    />
                  )}
                </Pressable>
              );
            })}
          </Pressable>
        </Pressable>
      </Modal>

      {/* Edit item modal */}
      <Modal
        visible={editingItem !== null}
        transparent
        animationType="fade"
        onRequestClose={() => setEditingItem(null)}
        statusBarTranslucent
      >
        <View style={styles.dialogBackdrop}>
          <View style={styles.dialogCard}>
            <Text style={styles.dialogTitle}>{t('Edit item')}</Text>
            <TextInput
              value={editedName}
              onChangeText={setEditedName}
              placeholder={t('Grocery item')}
              placeholderTextColor={AppTheme.tertiaryText}
              autoFocus
              style={styles.editInput}
              returnKeyType="done"
              onSubmitEditing={() => void commitEdit()}
            />
            <View style={styles.editActions}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Cancel')}
                onPress={() => {
                  setEditingItem(null);
                  setEditedName('');
                }}
                style={styles.editBtn}
              >
                <Text style={styles.editCancelText}>{t('Cancel')}</Text>
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={t('Save')}
                onPress={() => void commitEdit()}
                style={styles.editBtn}
              >
                <Text style={styles.editSaveText}>{t('Save')}</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
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
  emptyWrap: {
    flex: 1,
    paddingHorizontal: AppTheme.paddingMedium,
  },
  emptyCenter: {
    flex: 1,
    paddingBottom: 88,
  },
  controlsBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingTop: 4,
    paddingBottom: 12,
  },
  controlPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    minHeight: 38,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 999,
    backgroundColor: AppTheme.cardBackground,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.25)',
  },
  clearPillActive: {
    backgroundColor: 'rgba(219, 71, 56, 0.12)',
    borderColor: 'rgba(219, 71, 56, 0.4)',
  },
  clearPillDisabled: {
    backgroundColor: 'rgba(51, 43, 36, 0.45)',
    borderColor: AppTheme.separator,
  },
  controlText: {
    ...Typography.caption,
    fontFamily: FontFamily.semiBold,
    color: AppTheme.primaryText,
  },
  listContent: {
    paddingHorizontal: AppTheme.paddingMedium,
    paddingBottom: 96,
  },
  rowContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    minHeight: 50,
    paddingVertical: 4,
  },
  rowTapArea: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    minHeight: 44,
    paddingVertical: 6,
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: AppTheme.burntOrange,
    borderWidth: 1.75,
    borderColor: AppTheme.burntOrange,
  },
  checkboxUnchecked: {
    backgroundColor: 'transparent',
    borderWidth: 1.75,
    borderColor: 'rgba(199, 168, 122, 0.75)',
  },
  itemName: {
    ...Typography.body,
    color: AppTheme.primaryText,
    flex: 1,
  },
  itemNameChecked: {
    color: AppTheme.tertiaryText,
    textDecorationLine: 'line-through',
  },
  rowActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  rowActionBtn: {
    width: 38,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fabContainer: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 20,
    alignItems: 'center',
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: AppTheme.burntOrange,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 8,
    elevation: 6,
  },
  dialogBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  dialogCard: {
    width: '100%',
    maxWidth: 340,
    backgroundColor: AppTheme.cardBackground,
    borderRadius: AppTheme.cornerRadiusMedium,
    padding: AppTheme.paddingMedium,
    gap: 8,
  },
  dialogTitle: {
    ...Typography.headline,
    color: AppTheme.primaryText,
    marginBottom: 4,
  },
  sortOptionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    minHeight: 44,
    paddingVertical: 6,
  },
  sortOptionText: {
    ...Typography.body,
    color: AppTheme.primaryText,
  },
  editInput: {
    ...Typography.body,
    color: AppTheme.primaryText,
    backgroundColor: AppTheme.parchment,
    borderRadius: AppTheme.cornerRadiusSmall,
    borderWidth: 1,
    borderColor: 'rgba(198, 93, 36, 0.25)',
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  editActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 12,
    marginTop: 4,
  },
  editBtn: {
    minHeight: 44,
    paddingHorizontal: 12,
    justifyContent: 'center',
  },
  editCancelText: {
    ...Typography.headline,
    color: AppTheme.secondaryText,
  },
  editSaveText: {
    ...Typography.headline,
    color: AppTheme.burntOrange,
  },
});
