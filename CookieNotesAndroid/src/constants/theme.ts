export const AppTheme = {
  // Official CookieNotes palette
  burntOrange: '#C65D24',
  brightOrange: '#F08A43',
  goldenYellow: '#FBE362',
  warmBrown: '#6B5221',
  nearBlack: '#12100F',

  // Illustration helpers
  leafGreen: '#6BAD52',
  tomatoRed: '#DB4738',
  berryBlue: '#598CE0',

  // Dark charcoal journal surfaces (matches iOS preferredColorScheme(.dark))
  cream: '#171412',
  parchment: '#29231F',
  background: '#171412',
  cardBackground: '#332B24',
  surfaceBackground: '#29231F',
  elevatedHighlight: '#29231F',
  primaryText: '#F7F0E0',
  secondaryText: '#C7A87A',
  tertiaryText: 'rgba(199, 168, 122, 0.65)',
  separator: 'rgba(199, 168, 122, 0.22)',
  accent: '#C65D24',
  accentAction: '#F08A43',
  adBackground: '#29231F',
  error: '#C7382E',
  success: '#6BAD52',
  bannerFill: 'rgba(198, 93, 36, 0.28)',
  coral: '#F08A43',
  blush: '#29231F',
  cardShadow: 'rgba(0, 0, 0, 0.45)',
  tabBarBackground: '#171412',
  white: '#FFFFFF',

  // Spacing / radii (dp)
  paddingSmall: 8,
  paddingMedium: 16,
  paddingLarge: 24,
  paddingXLarge: 32,
  cornerRadiusSmall: 12,
  cornerRadiusMedium: 18,
  cornerRadiusLarge: 24,
} as const;

export const FontFamily = {
  regular: 'Nunito_400Regular',
  semiBold: 'Nunito_600SemiBold',
  bold: 'Nunito_700Bold',
  extraBold: 'Nunito_800ExtraBold',
} as const;

export const Typography = {
  largeTitle: {
    fontFamily: FontFamily.extraBold,
    fontSize: 30,
    lineHeight: 36,
  },
  title: {
    fontFamily: FontFamily.bold,
    fontSize: 22,
    lineHeight: 28,
  },
  headline: {
    fontFamily: FontFamily.semiBold,
    fontSize: 17,
    lineHeight: 23,
  },
  body: {
    fontFamily: FontFamily.regular,
    fontSize: 16,
    lineHeight: 22,
  },
  caption: {
    fontFamily: FontFamily.regular,
    fontSize: 15,
    lineHeight: 20,
  },
  footnote: {
    fontFamily: FontFamily.regular,
    fontSize: 13,
    lineHeight: 18,
  },
  smallCaption: {
    fontFamily: FontFamily.regular,
    fontSize: 12,
    lineHeight: 16,
  },
  sectionLabel: {
    fontFamily: FontFamily.bold,
    fontSize: 15,
    lineHeight: 20,
  },
} as const;

export const CardElevation = {
  shadowColor: '#000000',
  shadowOffset: { width: 0, height: 4 },
  shadowOpacity: 0.45,
  shadowRadius: 10,
  elevation: 4,
} as const;
