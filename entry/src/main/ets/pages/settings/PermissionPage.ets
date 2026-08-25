import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { backRoute } from '../../router/PageRoutes';
import {
  NotificationPermissionService,
  NotifyStatus
} from '../../services/NotificationPermissionService';
import {
  checkScreenTimeAuthorized,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

/**
 * 通知开关交互：
 * 1. 点击 → 开关保持关
 * 2. 弹出系统授权框
 * 3. 用户操作并关闭弹框后，再读系统权限
 * 4. 只有系统已开启，才把开关拨开
 */
@Entry
@Component
struct PermissionPage {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.AppIsForeground) @Watch('onForegroundChanged') isForeground: boolean = false;
  @State notifyEnabled: boolean = false;
  @State bannerEnabled: boolean = false;
  private busy: boolean = false;
  private statusSeq: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    void this.syncFromSystem();
  }

  onPageShow(): void {
    void this.syncFromSystem();
  }

  private onForegroundChanged(): void {
    if (this.isForeground) {
      void this.syncFromSystem();
    }
  }

  /** Toggle 无 $$ 时，值没变不会重绘；开关拨一下再拨回，强制对齐系统状态 */
  private applyNotifyEnabled(enabled: boolean): void {
    if (this.notifyEnabled === enabled) {
      this.notifyEnabled = !enabled;
    }
    this.notifyEnabled = enabled;
  }

  private applyStatus(status: NotifyStatus): void {
    this.applyNotifyEnabled(status.enabled);
    this.bannerEnabled = status.bannerEnabled;
  }

  private async syncFromSystem(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const authorized = await checkScreenTimeAuthorized();
      if (authorized !== this.hasAuthorized) {
        SettingsStore.updateAuthorization(
          hostContext,
          authorized,
          authorized ? '系统授权已开启' : '请先完成系统授权'
        );
      }
    } catch (_error) {
      // ignore
    }
    this.applyStatus(await NotificationPermissionService.readStatus());
    this.busy = false;
  }

  private async onToggleScreenTime(next: boolean): Promise<void> {
    if (this.busy) {
      return;
    }
    if (!next) {
      this.hasAuthorized = await checkScreenTimeAuthorized();
      if (this.hasAuthorized) {
        showToast('请在系统设置中关闭屏时授权', this.getUIContext());
      }
      return;
    }
    this.hasAuthorized = false;
    this.busy = true;
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await requestScreenTimeAuthorization(hostContext);
      SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
      this.hasAuthorized = result.ok || (await checkScreenTimeAuthorized());
      if (!this.hasAuthorized) {
        showToast(result.message, this.getUIContext());
      }
    } finally {
      this.busy = false;
    }
  }

  private async onToggleNotify(next: boolean): Promise<void> {
    if (this.busy) {
      return;
    }
    if (!next) {
      const enabled = await NotificationPermissionService.isNotifyEnabled();
      this.applyNotifyEnabled(enabled);
      if (enabled) {
        showToast('请在系统设置中关闭通知权限', this.getUIContext());
      }
      return;
    }

    this.applyNotifyEnabled(false);
    this.busy = true;
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const granted = await NotificationPermissionService.requestNotify(hostContext);
      this.applyStatus(await NotificationPermissionService.readStatus());
      if (this.notifyEnabled || granted) {
        return;
      }
      showToast('请在系统设置中开启通知权限', this.getUIContext());
      this.applyStatus(await NotificationPermissionService.openSettingsAndRead(hostContext));
    } finally {
      this.busy = false;
      this.applyStatus(await NotificationPermissionService.readStatus());
    }
  }

  private async onOpenBannerSettings(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const seq = ++this.statusSeq;
    const previous = await NotificationPermissionService.readStatus();
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      // 半模态 Promise 可能卡住；最多等一会就放行，避免横幅入口点了没反应
      await Promise.race([
        NotificationPermissionService.openSettings(hostContext),
        new Promise<void>((resolve) => {
          setTimeout(resolve, 800);
        })
      ]);
    } finally {
      this.busy = false;
    }
    const status = await NotificationPermissionService.pollUntilStatusChanged(previous);
    if (seq !== this.statusSeq) {
      return;
    }
    this.applyStatus(status);
  }

  @Builder
  private buildPermissionContent(): void {
    Column({ space: 12 }) {
      Column({ space: 0 }) {
        Row({ space: 14 }) {
          Text('屏时授权')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.hasAuthorized })
            .selectedColor(AppTheme.colors.primary)
            .enabled(!this.hasAuthorized && !this.busy)
            .opacity(this.hasAuthorized ? 0.4 : 1)
            .onChange((next: boolean) => {
              void this.onToggleScreenTime(next);
            })
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 18, right: 18 })

        Divider()
          .color(AppTheme.colors.divider)
          .strokeWidth(1)
          .margin({ left: 18, right: 18 })

        Row({ space: 14 }) {
          Text('通知权限')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.notifyEnabled })
            .selectedColor(AppTheme.colors.primary)
            .enabled(!this.notifyEnabled && !this.busy)
            .opacity(this.notifyEnabled ? 0.4 : 1)
            .onChange((next: boolean) => {
              void this.onToggleNotify(next);
            })
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 18, right: 18 })

        if (this.notifyEnabled) {
          Divider()
            .color(AppTheme.colors.divider)
            .strokeWidth(1)
            .margin({ left: 18, right: 18 })

          Row({ space: 14 }) {
            Text('横幅通知')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
              .layoutWeight(1)
            Row({ space: 4 }) {
              Text(this.bannerEnabled ? '打开' : '关闭')
                .fontSize(14)
                .fontColor(AppTheme.colors.textMuted)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([AppTheme.colors.textMuted])
            }
          }
          .width('100%')
          .height(56)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 18, right: 18 })
          .onClick(() => {
            void this.onOpenBannerSettings();
          })
        }
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(24)
      .clip(true)

      Text('屏时授权用于限制分心应用；通知用于搭子邀请、撕毁提醒和专注进度。横幅等提醒方式请在系统通知管理中设置。开启后需在系统设置中关闭。')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '权限管理',
        showBack: true,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPermissionContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
