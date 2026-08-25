import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { readStoredString, writeStoredString } from '../services/PreferencesService';
import { ThemeMode } from '../constants/Theme';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

const THEME_PREF_KEY: string = 'mythem';

function normalizeThemeMode(raw: string): ThemeMode {
  return raw === 'dark' ? 'dark' : 'light';
}

export class ThemeStore {
  static hydrate(context: common.UIAbilityContext): void {
    bootstrapStores();
    const raw = readStoredString(context, THEME_PREF_KEY, 'light');
    const mode = normalizeThemeMode(raw);
    AppStorage.setOrCreate(StoreKeys.ThemeMode, mode);
    ThemeStore.applyNativeColorMode(context, mode);
    void ThemeStore.applySystemBarStyle(context, mode);
  }

  static getMode(): ThemeMode {
    return normalizeThemeMode(AppStorage.get<string>(StoreKeys.ThemeMode) ?? 'light');
  }

  static setMode(context: common.UIAbilityContext, mode: ThemeMode): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.ThemeMode, mode);
    writeStoredString(context, THEME_PREF_KEY, mode);
    ThemeStore.applyNativeColorMode(context, mode);
    void ThemeStore.applySystemBarStyle(context, mode);
  }

  static applyNativeColorMode(context: common.UIAbilityContext, mode: ThemeMode): void {
    try {
      const colorMode = mode === 'dark'
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      console.error(`ThemeStore.setColorMode failed: ${String(error)}`);
    }
  }

  static async applySystemBarStyle(context: common.Context, mode: ThemeMode): Promise<void> {
    try {
      const win = await window.getLastWindow(context);
      const barProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: mode === 'dark' ? '#FFFFFFFF' : '#FF0F172A',
        navigationBarContentColor: mode === 'dark' ? '#FFFFFFFF' : '#FF0F172A',
      };
      win.setWindowSystemBarProperties(barProps);
    } catch (error) {
      console.error(`ThemeStore.applySystemBarStyle failed: ${String(error)}`);
    }
  }
}
