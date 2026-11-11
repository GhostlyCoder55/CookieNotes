import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Image, type ImageSource } from 'expo-image';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { FOOD_PNG_ASSETS, FOOD_SVG_ASSETS } from '../../assets/foodIconRegistry';
import { AppTheme } from '../../constants/theme';

export interface FoodIconViewProps {
  iconID?: string;
  iconIDs?: string[];
  size?: number;
}

const SINGLE_ALIASES: Record<string, string> = {
  tomato: 'tomatoes_vine',
  carrot: 'carrots_radish',
  berries: 'berry_bowl',
  banana: 'bananas_oranges',
  fish: 'salmon_steak',
  salmon: 'salmon_steak',
  chicken: 'roast_chicken',
  eggs: 'eggs_bowl',
  egg: 'eggs_bowl',
  cheese: 'cheese_wedge',
  rice: 'rice_bowl',
  bread: 'bread_loaf',
  pasta: 'spaghetti_bowl',
  spaghetti: 'spaghetti_bowl',
  salad: 'salad_bowl',
  soup: 'soup_bowl',
  pizza: 'pepperoni_pizza',
  chocolate: 'chocolate_bar',
  honey: 'honey_jar',
  coffee: 'coffee_cup',
};

function SingleFoodIcon({ iconID, size }: { iconID: string; size: number }) {
  const trimmed = iconID.trim();
  if (!trimmed) {
    return (
      <View style={[styles.centerBox, { width: size, height: size }]}>
        <MaterialCommunityIcons
          name="leaf"
          size={Math.max(16, Math.round(size * 0.62))}
          color={AppTheme.leafGreen}
        />
      </View>
    );
  }

  const normalized = SINGLE_ALIASES[trimmed] ?? trimmed;
  const pngSource = FOOD_PNG_ASSETS[normalized];
  if (pngSource) {
    return (
      <Image
        source={pngSource as number | ImageSource}
        style={{ width: size, height: size }}
        contentFit="contain"
        cachePolicy="memory-disk"
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      />
    );
  }

  const SvgComponent = FOOD_SVG_ASSETS[normalized];
  if (SvgComponent) {
    return (
      <View
        style={[styles.centerBox, { width: size, height: size }]}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      >
        <SvgComponent width={size} height={size} />
      </View>
    );
  }

  return (
    <View
      style={[
        styles.centerBox,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: 'rgba(251, 227, 98, 0.25)',
        },
      ]}
    >
      <MaterialCommunityIcons
        name="silverware-fork-knife"
        size={Math.max(18, Math.round(size * 0.55))}
        color={AppTheme.burntOrange}
      />
    </View>
  );
}

const X_OFFSETS = [-0.22, 0.02, 0.24];
const Y_OFFSETS = [-0.14, 0.02, 0.12];
const ROTATIONS = ['-14deg', '4deg', '12deg'];

export function DishCoverView({
  iconIDs,
  size = 96,
}: {
  iconIDs: string[];
  size?: number;
}) {
  const pieces = iconIDs.filter((id) => id.trim().length > 0).slice(0, 3);
  if (pieces.length <= 1) {
    return <SingleFoodIcon iconID={pieces[0] ?? ''} size={size} />;
  }

  const count = pieces.length;

  return (
    <View style={[styles.dishContainer, { width: size, height: size }]}>
      {pieces.map((id, index) => {
        const progress = count > 1 ? index / (count - 1) : 1;
        const pieceSize = size * (0.52 + progress * 0.16);
        const offsetX = size * (X_OFFSETS[index] ?? 0);
        const offsetY = size * (Y_OFFSETS[index] ?? 0);
        const rotate = ROTATIONS[index] ?? '0deg';

        return (
          <View
            key={`${index}-${id}`}
            style={[
              styles.dishPiece,
              {
                zIndex: index + 1,
                transform: [
                  { translateX: offsetX },
                  { translateY: offsetY },
                  { rotate },
                ],
              },
            ]}
          >
            <SingleFoodIcon iconID={id} size={pieceSize} />
          </View>
        );
      })}
    </View>
  );
}

export function FoodIconView({ iconID = '', iconIDs, size = 48 }: FoodIconViewProps) {
  if (iconIDs && iconIDs.filter((id) => id.trim().length > 0).length > 1) {
    return <DishCoverView iconIDs={iconIDs} size={size} />;
  }
  const resolvedSingle =
    iconIDs?.find((id) => id.trim().length > 0) ?? iconID;
  return <SingleFoodIcon iconID={resolvedSingle} size={size} />;
}

const styles = StyleSheet.create({
  centerBox: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  dishContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
  },
  dishPiece: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
