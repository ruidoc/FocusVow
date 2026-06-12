import { common } from '@kit.AbilityKit';

/**
 * 主进程在 EntryAbility 启动时缓存 ApplicationContext。
 * 扩展进程无法共享此引用，须在扩展内自行 getApplicationContext()。
 */
export class AppContextHolder {
  private static appContext: common.Context | null = null;

  static bind(context: common.Context): void {
    AppContextHolder.appContext = context.getApplicationContext();
  }

  static get(): common.Context | null {
    return AppContextHolder.appContext;
  }
}
