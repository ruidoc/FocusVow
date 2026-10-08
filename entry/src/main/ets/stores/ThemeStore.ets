import { common, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppContextHolder } from '../common/AppContextHolder';
import { ThemeMode } from '../constants/Theme';
import { readStoredString, writeStoredString } from '../services/PreferencesService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

/** 与 RN `app_theme` 一致：有值表示用户手动选过主题，冷启动不再跟系统 */
const THEME_PREF_KEY: string = 'app_theme';

function normalizeThemeMode(raw: string): ThemeMode {
  return raw === 'dark' ? 'dark' : 'light';
}

function colorModeToTheme(colorMode: ConfigurationConstant.ColorMode | undefined): ThemeMode {
  return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? 'dark' : 'light';
}

export class ThemeStore {
  private static initialized: boolean = false;
  /** 手动 setColorMode 会触发 configuration 回调，需跳过避免递归/闪退 */
  private static suppressConfigSync: boolean = false;

  private static readPersistedMode(context: common.Context): ThemeMode | null {
    const raw = readStoredString(context, THEME_PREF_KEY, '');
    if (raw === 'dark' || raw === 'light') {
      return raw;
    }
    return null;
  }

  static hydrate(context: common.UIAbilityContext): void {
    bootstrapStores();
    if (!ThemeStore.initialized) {
      const persisted = ThemeStore.readPersistedMode(context);
      let mode: ThemeMode;
      if (persisted !== null) {
        mode = persisted;
        ThemeStore.applyNativeColorMode(context, mode);
      } else {
        ThemeStore.ensureFollowSystemColorMode(context);
        mode = ThemeStore.resolveSystemThemeMode(context);
      }
      AppStorage.setOrCreate(StoreKeys.ThemeMode, mode);
      ThemeStore.initialized = true;
    }
    void ThemeStore.applySystemBarStyle(context, ThemeStore.getMode());
  }

  static resolveSystemThemeMode(context: common.UIAbilityContext): ThemeMode {
    return colorModeToTheme(context.config.colorMode);
  }

  /** AbilityStage / EntryAbility 系统配置变化入口 */
  static onSystemConfiguration(config: Configuration): void {
    if (ThemeStore.suppressConfigSync) {
      return;
    }
    const abilityContext = AppContextHolder.getAbility();
    if (abilityContext) {
      ThemeStore.syncWithSystem(abilityContext, config);
      return;
    }
    bootstrapStores();
    const mode = colorModeToTheme(config.colorMode);
    if (ThemeStore.getMode() === mode) {
      return;
    }
    AppStorage.setOrCreate(StoreKeys.ThemeMode, mode);
  }

  /** 系统亮暗色变化：恢复跟随系统并更新 store（覆盖此前手动切换） */
  static syncWithSystem(context: common.UIAbilityContext, config?: Configuration): void {
    if (ThemeStore.suppressConfigSync) {
      return;
    }
    if (ThemeStore.readPersistedMode(context) !== null) {
      return;
    }
    bootstrapStores();
    const mode = colorModeToTheme(config?.colorMode ?? context.config.colorMode);
    if (ThemeStore.getMode() === mode) {
      return;
    }
    ThemeStore.suppressConfigSync = true;
    try {
      ThemeStore.ensureFollowSystemColorMode(context);
      AppStorage.setOrCreate(StoreKeys.ThemeMode, mode);
      void ThemeStore.applySystemBarStyle(context, mode);
    } finally {
      ThemeStore.suppressConfigSync = false;
    }
  }

  static getMode(): ThemeMode {
    return normalizeThemeMode(AppStorage.get<string>(StoreKeys.ThemeMode) ?? 'light');
  }

  /** 设置页手动切换：锁定应用 colorMode，并同步 AppStorage */
  static setMode(context: common.UIAbilityContext, mode: ThemeMode): void {
    bootstrapStores();
    if (ThemeStore.getMode() === mode) {
      return;
    }
    ThemeStore.suppressConfigSync = true;
    try {
      ThemeStore.applyNativeColorMode(context, mode);
      writeStoredString(context, THEME_PREF_KEY, mode);
      AppStorage.setOrCreate(StoreKeys.ThemeMode, mode);
      void ThemeStore.applySystemBarStyle(context, mode);
    } finally {
      ThemeStore.suppressConfigSync = false;
    }
  }

  private static ensureFollowSystemColorMode(context: common.UIAbilityContext): void {
    try {
      context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
      console.error(`ThemeStore.ensureFollowSystemColorMode failed: ${String(error)}`);
    }
  }

  private static applyNativeColorMode(context: common.UIAbilityContext, mode: ThemeMode): void {
    try {
      const colorMode = mode === 'dark'
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      console.error(`ThemeStore.applyNativeColorMode failed: ${String(error)}`);
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
