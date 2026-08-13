import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { sanitizeOrgInviteCode } from '../../models/OrgModel';
import { PageRoutes, backRoute, pushRoute, replaceRoute } from '../../router/PageRoutes';
import { OrgStore } from '../../stores/OrgStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const CODE_LENGTH: number = 8;

@Entry
@Component
struct OrgJoinPage {
  @State code: string = '';
  @State isSubmitting: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
    }
  }

  private onCodeChange(value: string): void {
    this.code = sanitizeOrgInviteCode(value);
  }

  private getCodeBorderColor(): string {
    if (this.code.length === CODE_LENGTH) {
      return `${AppTheme.colors.primary}55`;
    }
    return AppTheme.colors.border;
  }

  private async onJoin(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    const trimmed = sanitizeOrgInviteCode(this.code);
    if (trimmed.length === 0) {
      showToast('请输入邀请码', this.getUIContext());
      return;
    }
    if (trimmed.length !== CODE_LENGTH) {
      showToast('邀请码为 8 位英文字母或数字', this.getUIContext());
      return;
    }
    this.isSubmitting = true;
    const response = await OrgStore.join(trimmed);
    this.isSubmitting = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '加入失败，请检查邀请码', this.getUIContext());
      return;
    }
    showToast('加入成功', this.getUIContext());
    const data = response.data;
    const orgId = data ? String(data['id'] ?? '') : '';
    if (orgId.length > 0) {
      AppStorage.setOrCreate(StoreKeys.OrgDetailId, orgId);
      replaceRoute(PageRoutes.OrgDetail);
      return;
    }
    backRoute();
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 20 }) {
      Column({ space: 20 }) {
        Text('输入组织邀请码（8 位）')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
          .width('100%')

        TextInput({ text: this.code, placeholder: '邀请码' })
          .width(280)
          .height(52)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(4)
          .textAlign(TextAlign.Center)
          .fontColor(AppTheme.colors.textPrimary)
          .placeholderColor(AppTheme.colors.textMuted)
          .backgroundColor(AppTheme.colors.surface)
          .border({ width: 1, color: this.getCodeBorderColor() })
          .borderRadius(16)
          .onChange((value: string) => {
            this.onCodeChange(value);
          })

        Button(this.isSubmitting ? '加入中' : '加入组织')
          .width(280)
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.colors.primary)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .enabled(!this.isSubmitting && this.code.length === CODE_LENGTH)
          .opacity(!this.isSubmitting && this.code.length === CODE_LENGTH ? 1 : 0.5)
          .onClick(() => {
            void this.onJoin();
          })
      }
      .width('100%')
      .padding({ top: 24 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '加入组织',
        showBack: true,
        onBack: (): void => {
          backRoute();
        },
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
