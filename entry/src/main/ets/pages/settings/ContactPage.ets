import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { showErrorToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';
import { WeComCustomerService } from '../../services/WeComCustomerService';

const WECHAT_ACCENT: string = '#07C160';

function readEntrySource(): string {
  try {
    const params = router.getParams() as Record<string, Object> | undefined;
    const raw = params?.['entrySource'];
    if (typeof raw === 'string' && raw.trim().length > 0) {
      return raw.trim();
    }
  } catch (_e) {
  }
  return 'contact_page';
}

@Entry
@Component
struct ContactPage {
  @State entrySource: string = 'contact_page';

  aboutToAppear(): void {
    this.entrySource = readEntrySource();
  }

  private async openWecom(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const errorMessage = await WeComCustomerService.open(hostContext, this.entrySource);
    if (errorMessage !== null) {
      showErrorToast(errorMessage, this.getUIContext());
    }
  }

  @Builder
  private buildWecomCard(): void {
    Column({ space: 12 }) {
      Text('在线客服')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
      Text('工作日优先回复；账号、会员、屏时权限等问题可直接说明。')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
      Button('打开微信客服')
        .width('100%')
        .height(48)
        .type(ButtonType.Normal)
        .borderRadius(AppTheme.radius.button)
        .backgroundColor(WECHAT_ACCENT)
        .fontColor('#FFFFFF')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .onClick(() => {
          void this.openWecom();
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
  }

  @Builder
  private buildAdminHint(): void {
    Column({ space: 8 }) {
      Text('其他联系方式')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
      Text('可在「意见反馈」提交问题，或通过微信客服索取管理员微信二维码。')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
  }

  @Builder
  private buildContent(): void {
    Column({ space: 16 }) {
      this.buildWecomCard()
      this.buildAdminHint()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '联系客服',
        showBack: true,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContent();
        },
      })
    }
    .width('100%')
    .height('100%')
  }
}
