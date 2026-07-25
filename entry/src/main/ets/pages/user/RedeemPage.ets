import { common } from '@kit.AbilityKit';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { ApiEnvelope, createEmptyUserInfo, UserInfo } from '../../models/UserModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { formatSaveError } from '../../services/CertificateImageService';
import { HttpService } from '../../services/HttpService';
import { BenefitStore } from '../../stores/BenefitStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct RedeemPage {
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @StorageLink(StoreKeys.BenefitMembershipStatus) membershipStatus: string = 'none';
  @StorageLink(StoreKeys.BenefitCommunityQrUrl) communityQrUrl: string = '';
  @StorageLink(StoreKeys.BenefitCommunityHint) communityHint: string = '';
  @State codeInput: string = '';
  @State isSubmitting: boolean = false;
  @State isSavingQr: boolean = false;
  @State redeemedCode: string = '';

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    BenefitStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    void this.refreshStatus();
  }

  private async refreshStatus(): Promise<void> {
    await BenefitStore.refresh();
    const statusRes: ApiEnvelope = await HttpService.get('/redeem/status');
    if (statusRes.statusCode === 200 && statusRes.data) {
      const redemption = statusRes.data['redemption'] as Record<string, Object> | undefined;
      if (redemption) {
        this.redeemedCode = String(redemption['code'] ?? '');
      }
      const qr = String(statusRes.data['community_qr_url'] ?? '');
      if (qr.length > 0) {
        this.communityQrUrl = qr;
      }
      const hint = String(statusRes.data['community_hint'] ?? '');
      if (hint.length > 0) {
        this.communityHint = hint;
      }
    }
  }

  private async onRedeem(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    const code = this.codeInput.trim();
    if (code.length === 0) {
      showToast('请输入兑换码', this.getUIContext());
      return;
    }
    this.isSubmitting = true;
    const response = await HttpService.post('/redeem', { 'code': code } as Record<string, Object>);
    this.isSubmitting = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '兑换失败', this.getUIContext());
      return;
    }
    await BenefitStore.refresh();
    const status = String(response.data?.['membership_status'] ?? 'pending');
    const redemption = response.data?.['redemption'] as Record<string, Object> | undefined;
    if (redemption) {
      this.redeemedCode = String(redemption['code'] ?? code);
    }
    const qr = String(response.data?.['community_qr_url'] ?? '');
    if (qr.length > 0) {
      this.communityQrUrl = qr;
    }
    this.codeInput = '';
    showToast(
      status === 'active' ? '兑换成功，会员已激活' : '兑换成功，待激活',
      this.getUIContext()
    );
  }

  private onCopyUid(): void {
    const uid = this.userInfo.id;
    if (uid.length === 0) {
      showToast('暂无 UID', this.getUIContext());
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, uid);
      pasteboard.getSystemPasteboard().setData(data);
      showToast('UID 已复制', this.getUIContext());
    } catch (_e) {
      showErrorToast('复制失败', this.getUIContext());
    }
  }

  private async onSaveQr(): Promise<void> {
    if (this.communityQrUrl.length === 0) {
      showToast('二维码暂未配置', this.getUIContext());
      return;
    }
    if (this.isSavingQr) {
      return;
    }
    this.isSavingQr = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const req = http.createHttp();
    try {
      const res = await req.request(this.communityQrUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 15000
      });
      const buffer = res.result as ArrayBuffer;
      if (!buffer || buffer.byteLength === 0) {
        showErrorToast('下载二维码失败', this.getUIContext());
        return;
      }
      const helper = photoAccessHelper.getPhotoAccessHelper(hostContext);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png');
      const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      try {
        await fileIo.write(file.fd, buffer);
      } finally {
        await fileIo.close(file.fd);
      }
      showToast('二维码已保存到相册', this.getUIContext());
    } catch (error) {
      const message = formatSaveError(error as BusinessError);
      showErrorToast(message, this.getUIContext());
    } finally {
      req.destroy();
      this.isSavingQr = false;
    }
  }

  @Builder
  private buildSaveQrButton(): void {
    if (this.isSavingQr) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.arrow_down'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor([AppTheme.colors.primary])

        Text('保存中...')
          .fontSize(15)
          .fontColor(AppTheme.colors.primary)
      }
      .width('100%')
      .height(50)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.colors.primarySoft)
      .opacity(0.7)
      .borderRadius(AppTheme.radius.pill)
    } else {
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        text: SaveDescription.SAVE_TO_GALLERY,
        buttonType: ButtonType.Capsule
      })
        .width('100%')
        .height(50)
        .fontSize(15)
        .fontColor(AppTheme.colors.primary)
        .iconColor(AppTheme.colors.primary)
        .iconSize(18)
        .textIconSpace(8)
        .layoutDirection(SecurityComponentLayoutDirection.HORIZONTAL)
        .backgroundColor(AppTheme.colors.primarySoft)
        .onClick(async (_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            await this.onSaveQr();
          } else {
            showErrorToast('未获得相册保存授权', this.getUIContext());
          }
        })
    }
  }

  @Builder
  private buildPendingCard(): void {
    Column({ space: 12 }) {
      Text('已兑换 · 待激活')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#D4A44A')
        .width('100%')

      if (this.redeemedCode.length > 0) {
        Text(`兑换码 ${this.redeemedCode}`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }

      Text(this.communityHint.length > 0
        ? this.communityHint
        : '扫码加入用户群后，@管理员并发送你的 UID，即可完成会员激活')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      if (this.communityQrUrl.length > 0) {
        Image(this.communityQrUrl)
          .width(200)
          .height(200)
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignSelf(ItemAlign.Center)
      }

      if (this.userInfo.id.length > 0) {
        Text(`你的 UID：${this.userInfo.id}`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      this.buildSaveQrButton()

      Button('复制 UID')
        .width('100%')
        .height(48)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#461702')
        .backgroundColor('#D4A44A')
        .borderRadius(24)
        .onClick(() => {
          this.onCopyUid();
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFBF0')
    .border({ width: 1, color: 'rgba(212,164,74,0.35)' })
    .borderRadius(20)
  }

  @Builder
  private buildActiveCard(): void {
    Column({ space: 10 }) {
      Text('会员已激活')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#D4A44A')
        .width('100%')

      Text('搭子互督时长已不限额度。可在个人中心查看会员信息。')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFBF0')
    .border({ width: 1, color: 'rgba(212,164,74,0.35)' })
    .borderRadius(20)
  }

  @Builder
  private buildRedeemForm(): void {
    Column({ space: 14 }) {
      Text('输入兑换码')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text('兑换会员后可解锁每日无限搭子互督。兑换成功后需加群完成激活。')
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      TextInput({ placeholder: '请输入兑换码', text: this.codeInput })
        .height(48)
        .width('100%')
        .type(InputType.Normal)
        .onChange((value: string) => {
          this.codeInput = value;
        })

      Button(this.isSubmitting ? '兑换中…' : '立即兑换')
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(AppTheme.colors.primary)
        .borderRadius(24)
        .enabled(!this.isSubmitting)
        .opacity(this.isSubmitting ? 0.55 : 1)
        .onClick(() => {
          void this.onRedeem();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 18 }) {
      if (this.membershipStatus === 'active') {
        this.buildActiveCard()
      } else if (this.membershipStatus === 'pending') {
        this.buildPendingCard()
      } else {
        this.buildRedeemForm()
      }
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '兑换会员',
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
