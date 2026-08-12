import { common } from '@kit.AbilityKit';
import { CustomContentDialog } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { createEmptyUserInfo, UserInfo } from '../../models/UserModel';
import { PageRoutes, backRoute, pushRoute, pushAvatarCrop } from '../../router/PageRoutes';
import { UserStore } from '../../stores/UserStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

/** 展示用：sex 0/1/2 → 未知/男/女 */
const SEX_LABELS: string[] = ['未知', '男', '女'];
/** 选择器用：男 / 女 / 未知，对应 sex 1 / 2 / 0 */
const SEX_PICKER_OPTIONS: string[] = ['男', '女', '未知'];
const SEX_PICKER_VALUES: number[] = [1, 2, 0];

@Entry
@Component
struct ProfileEditPage {
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @State usernameDraft: string = '';
  /** 仅保存资料时的 loading，不与头像文案共用 */
  @State isSaving: boolean = false;
  @State isBindingWechat: boolean = false;

  private usernameDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: '修改用户名',
      contentBuilder: (): void => {
        this.buildUsernameInput();
      },
      buttons: [
        {
          value: '取消',
          action: (): void => {
            this.usernameDialogController.close();
          }
        },
        {
          value: '保存',
          action: (): void => {
            void this.confirmUsernameDialog();
          }
        }
      ]
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    void UserStore.refreshUserInfo(hostContext);
  }

  onPageShow(): void {
    // 从裁剪页返回时刷新头像等字段
    if (!UserStore.isLoggedIn()) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void UserStore.refreshUserInfo(hostContext);
  }

  aboutToDisappear(): void {
    this.usernameDialogController.close();
  }

  private getSexLabel(): string {
    const sex = this.userInfo.sex;
    if (sex >= 0 && sex < SEX_LABELS.length) {
      return SEX_LABELS[sex];
    }
    return '未知';
  }

  private openUsernameDialog(): void {
    if (this.isSaving) {
      return;
    }
    this.usernameDraft = this.userInfo.username;
    this.usernameDialogController.open();
  }

  private async confirmUsernameDialog(): Promise<void> {
    const name = this.usernameDraft.trim();
    if (name.length === 0) {
      showToast('请输入用户名', this.getUIContext());
      return;
    }
    this.usernameDialogController.close();
    this.isSaving = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const error = await UserStore.updateUser(hostContext, { 'username': name } as Record<string, Object>);
    this.isSaving = false;
    if (error) {
      showErrorToast(error, this.getUIContext());
      return;
    }
    showToast('用户名已更新', this.getUIContext());
  }

  @Builder
  private buildUsernameInput(): void {
    TextInput({ placeholder: '请输入用户名', text: this.usernameDraft })
      .width('100%')
      .onChange((value: string) => {
        this.usernameDraft = value;
      })
  }

  private async pickAndUploadAvatar(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      options.isEditSupported = false;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      if (!result.photoUris || result.photoUris.length === 0) {
        return;
      }
      // 选图后进入 oh-crop 正方形裁剪页，完成后再压缩上传
      pushAvatarCrop(result.photoUris[0]);
    } catch (_e) {
      showErrorToast('选择图片失败', this.getUIContext());
    }
  }

  private getSexPickerSelectedIndex(): number {
    const sex = this.userInfo.sex;
    if (sex === 1) {
      return 0;
    }
    if (sex === 2) {
      return 1;
    }
    return 2;
  }

  private resolvePickerIndex(raw: number | number[]): number {
    if (raw instanceof Array) {
      if (raw.length > 0) {
        return raw[0];
      }
      return -1;
    }
    return raw;
  }

  private openSexPicker(): void {
    if (this.isSaving) {
      return;
    }
    this.getUIContext().showTextPickerDialog({
      range: SEX_PICKER_OPTIONS,
      selected: this.getSexPickerSelectedIndex(),
      canLoop: false,
      onAccept: (value: TextPickerResult) => {
        const index = this.resolvePickerIndex(value.index);
        void this.applySexSelection(index);
      }
    });
  }

  private async applySexSelection(index: number): Promise<void> {
    if (index < 0 || index >= SEX_PICKER_VALUES.length) {
      return;
    }
    const sex = SEX_PICKER_VALUES[index];
    this.isSaving = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const error = await UserStore.updateUser(hostContext, { 'sex': sex } as Record<string, Object>);
    this.isSaving = false;
    if (error) {
      showErrorToast(error, this.getUIContext());
      return;
    }
    showToast('性别已更新', this.getUIContext());
  }

  @Builder
  private buildAvatarBlock(): void {
    Column({ space: 8 }) {
      if (this.userInfo.avatar.length > 0) {
        Image(this.userInfo.avatar)
          .width(96)
          .height(96)
          .borderRadius(48)
          .objectFit(ImageFit.Cover)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            void this.pickAndUploadAvatar();
          })
      } else {
        Image($r('app.media.startIcon'))
          .width(96)
          .height(96)
          .borderRadius(48)
          .objectFit(ImageFit.Cover)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            void this.pickAndUploadAvatar();
          })
      }

      Text('点击更换头像')
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .width('100%')
    .padding({ top: 24, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildUsernameRow(): void {
    Column({ space: 0 }) {
      Row() {
        Text('用户名')
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)

        Blank()

        Text(this.userInfo.username.length > 0 ? this.userInfo.username : '未设置')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ right: 6 })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
      .height(52)
      .alignItems(VerticalAlign.Center)
      .opacity(this.isSaving ? 0.6 : 1)
      .onClick(() => {
        this.openUsernameDialog();
      })

      Divider()
        .color('#EEF1F6')
        .strokeWidth(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private buildWechatRow(): void {
    Column({ space: 0 }) {
      Row() {
        Text('微信')
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)

        Blank()

        Text(this.userInfo.openid.length > 0 ? '已绑定' : '未绑定')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ right: 6 })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
      .height(52)
      .alignItems(VerticalAlign.Center)
      .opacity(this.isBindingWechat ? 0.6 : 1)
      .onClick(() => {
        void this.onWechatRowPress();
      })

      Divider()
        .color('#EEF1F6')
        .strokeWidth(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  private async onWechatRowPress(): Promise<void> {
    if (this.userInfo.openid.length > 0) {
      showToast('微信已绑定', this.getUIContext());
      return;
    }
    if (this.isBindingWechat || this.isSaving) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.isBindingWechat = true;
    const errorMessage = await UserStore.bindWechat(hostContext);
    this.isBindingWechat = false;
    if (errorMessage) {
      showErrorToast(errorMessage, this.getUIContext());
      return;
    }
    if (UserStore.getUserInfo().openid.length > 0) {
      showToast('微信绑定成功', this.getUIContext());
    }
  }

  @Builder
  private buildEmailRow(): void {
    Column({ space: 0 }) {
      Row() {
        Text('邮箱')
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)

        Blank()

        Text(this.userInfo.email.length > 0 ? this.userInfo.email : '未设置')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ right: 6 })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
      .height(52)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (this.userInfo.email.length > 0) {
          showToast('邮箱不可修改', this.getUIContext());
        }
      })

      Divider()
        .color('#EEF1F6')
        .strokeWidth(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private buildSexRow(): void {
    Column({ space: 0 }) {
      Row() {
        Text('性别')
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)

        Blank()

        Text(this.getSexLabel())
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ right: 6 })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
      .height(52)
      .alignItems(VerticalAlign.Center)
      .opacity(this.isSaving ? 0.6 : 1)
      .onClick(() => {
        this.openSexPicker();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 14 }) {
      this.buildAvatarBlock()

      Column({ space: 0 }) {
        this.buildUsernameRow()
        this.buildEmailRow()
        this.buildWechatRow()
        this.buildSexRow()
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(14)
      .clip(true)
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 4, bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '编辑资料',
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 20,
        onBack: () => {
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
