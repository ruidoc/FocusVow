import { common } from '@kit.AbilityKit';
import { PageHeader } from '../../components/common/PageHeader';
import { FocusSource } from '../../models/FocusSession';
import { backRoute, replaceRoute, PageRoutes } from '../../router/PageRoutes';
import {
  applyScreenRestriction,
  chooseRestrictedApps,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { FocusStore } from '../../stores/FocusStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct QuickStartPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.SettingsStatusMessage) statusMessage: string = '先申请系统授权，再选择需要限制的应用';
  @State durationMinutes: number = FocusStore.getDurationMinutes();
  @State mode: 'shield' | 'allow' = 'shield';

  private readonly durationOptions: number[] = [10, 25, 45, 60];

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    FocusStore.hydrate(hostContext);
    this.durationMinutes = FocusStore.getDurationMinutes();
  }

  private async authorize(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
    } else {
      SettingsStore.updateStatusMessage(hostContext, result.message);
    }
  }

  private async startFocus(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (FocusStore.isRunning()) {
      SettingsStore.updateStatusMessage(hostContext, '当前已有进行中的专注，请先回首页结束后再开始新的专注');
      return;
    }

    if (this.selectedTokens.length === 0) {
      SettingsStore.updateStatusMessage(hostContext, '请先选择至少 1 个应用');
      return;
    }

    if (!this.hasAuthorized) {
      await this.authorize();
      if (!SettingsStore.getState().hasAuthorized) {
        return;
      }
    }

    const result = await applyScreenRestriction(this.selectedTokens, this.mode);
    SettingsStore.updateStatusMessage(hostContext, result.message);
    if (!result.ok) {
      return;
    }

    FocusStore.startSession(
      hostContext,
      this.selectedTokens,
      this.durationMinutes,
      FocusSource.QuickStart,
      '',
      '快速专注',
      this.mode
    );
    replaceRoute(PageRoutes.FocusHome);
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({
          title: '快速专注',
          subtitle: '把即时专注从首页拆出来，后续再继续贴近 iOS 页面结构',
          showBack: true,
          onBack: () => backRoute()
        })

        Column({ space: 12 }) {
          Text('专注时长')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')

          Row({ space: 10 }) {
            ForEach(this.durationOptions, (item: number) => {
              Button(`${item} 分钟`)
                .type(ButtonType.Capsule)
                .height(40)
                .backgroundColor(this.durationMinutes === item ? '#111827' : '#FFFFFF')
                .fontColor(this.durationMinutes === item ? '#FFFFFF' : '#111827')
                .border({ width: 1, color: this.durationMinutes === item ? '#111827' : '#D1D5DB' })
                .onClick(() => {
                  this.durationMinutes = item;
                  const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
                  FocusStore.setDurationMinutes(hostContext, item);
                })
            }, (item: number) => item.toString())
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Text('限制模式')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')

          Row({ space: 10 }) {
            Button('锁定黑名单')
              .type(ButtonType.Capsule)
              .backgroundColor(this.mode === 'shield' ? '#111827' : '#FFFFFF')
              .fontColor(this.mode === 'shield' ? '#FFFFFF' : '#111827')
              .border({ width: 1, color: '#D1D5DB' })
              .onClick(() => {
                this.mode = 'shield';
              })
            Button('仅放行白名单')
              .type(ButtonType.Capsule)
              .backgroundColor(this.mode === 'allow' ? '#111827' : '#FFFFFF')
              .fontColor(this.mode === 'allow' ? '#FFFFFF' : '#111827')
              .border({ width: 1, color: '#D1D5DB' })
              .onClick(() => {
                this.mode = 'allow';
              })
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 10 }) {
          Text(`已选择应用：${this.selectedAppCount} 个`)
            .fontSize(15)
            .fontColor('#111827')
          Text(this.statusMessage)
            .fontSize(13)
            .fontColor('#6B7280')
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)
        .alignItems(HorizontalAlign.Start)

        Button(this.hasAuthorized ? '重新申请系统授权' : '申请系统授权')
          .width('100%')
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor('#E5E7EB')
          .fontColor('#111827')
          .onClick(() => {
            this.authorize();
          })

        Button('选择需要限制的应用')
          .width('100%')
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor('#FFFFFF')
          .fontColor('#111827')
          .border({ width: 1, color: '#D1D5DB' })
          .onClick(() => {
            this.chooseApps();
          })

        Button('开始这次专注')
          .width('100%')
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor('#111827')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.startFocus();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 28 })
      .backgroundColor('#F7F8FA')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}
