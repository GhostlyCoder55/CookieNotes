import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import {
  type AppLanguage,
  DEFAULT_LANGUAGE,
  getActiveLanguage,
  setActiveLanguage,
  subscribeLanguage,
  tFor,
} from './i18n';

interface LanguageContextValue {
  language: AppLanguage;
  setLanguage: (lang: AppLanguage) => void;
  t: (key: string, ...args: Array<string | number>) => string;
}

const LanguageContext = createContext<LanguageContextValue>({
  language: DEFAULT_LANGUAGE,
  setLanguage: () => {},
  t: (key, ...args) => tFor(DEFAULT_LANGUAGE, key, ...args),
});

interface LanguageProviderProps {
  initialLanguage?: AppLanguage;
  onLanguagePersist?: (lang: AppLanguage) => void;
  children: React.ReactNode;
}

export function LanguageProvider({
  initialLanguage,
  onLanguagePersist,
  children,
}: LanguageProviderProps) {
  const [language, setLanguageState] = useState<AppLanguage>(() => {
    if (initialLanguage) {
      setActiveLanguage(initialLanguage);
      return initialLanguage;
    }
    return getActiveLanguage();
  });

  useEffect(() => {
    if (initialLanguage) {
      setActiveLanguage(initialLanguage);
      setLanguageState(initialLanguage);
    }
  }, [initialLanguage]);

  useEffect(() => {
    return subscribeLanguage((next) => {
      setLanguageState(next);
    });
  }, []);

  const changeLanguage = useCallback(
    (next: AppLanguage) => {
      setActiveLanguage(next);
      setLanguageState(next);
      onLanguagePersist?.(next);
    },
    [onLanguagePersist]
  );

  const translate = useCallback(
    (key: string, ...args: Array<string | number>) => tFor(language, key, ...args),
    [language]
  );

  const value = useMemo<LanguageContextValue>(
    () => ({
      language,
      setLanguage: changeLanguage,
      t: translate,
    }),
    [language, changeLanguage, translate]
  );

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage(): LanguageContextValue {
  return useContext(LanguageContext);
}
