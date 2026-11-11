module.exports = {
  preset: 'jest-expo',
  testMatch: ['**/__tests__/**/*.test.ts', '**/__tests__/**/*.test.tsx'],
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?)|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@sentry/react-native|native-base|react-native-svg)',
  ],
  moduleNameMapper: {
    '\\.svg$': '<rootDir>/src/__tests__/mocks/svgMock.ts',
    '\\.(png|jpg|jpeg|gif|webp)$': '<rootDir>/src/__tests__/mocks/imageMock.ts',
  },
};
