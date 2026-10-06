import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  HonorCertificateData,
  ShameCertificateData,
  createEmptyHonorCertificateData,
  createEmptyShameCertificateData,
} from '../../models/CertificateModel';
import { backRoute } from '../../router/PageRoutes';
import { HttpService } from '../../services/HttpService';
import { refreshStats } from '../../stores/StatsStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct CertificateAdjustPage {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  @StorageLink(StoreKeys.CertificateKind) kind: string = 'honor';
  @StorageLink(StoreKeys.CertificateHonor) honorData: HonorCertificateData = createEmptyHonorCertificateData();
  @StorageLink(StoreKeys.CertificateShame) shameData: ShameCertificateData = createEmptyShameCertificateData();
  @State minutes: number = 1;
  @State title: string = '';
  @State saving: boolean = false;
  private initialTitle: string = '';
  private maxMinutes: number = 1;
  private recordId: string = '';

  aboutToAppear(): void {
    if (this.kind === 'shame') {
      this.maxMinutes = Math.max(1, this.shameData.actualMinutes);
      this.recordId = this.shameData.recordId;
      this.title = this.shameData.contractTitle;
    } else {
      this.maxMinutes = Math.max(1, this.honorData.durationMinutes);
      this.recordId = this.honorData.recordId;
      this.title = this.honorData.contractTitle;
    }
    this.minutes = this.maxMinutes;
    this.initialTitle = this.title;
  }

  private step(): number {
    return this.maxMinutes > 60 ? 5 : 1;
  }

  private minimum(): number {
    return this.step() === 5 ? 5 : 1;
  }

  private canEditDuration(): boolean {
    return this.maxMinutes > 1;
  }

  private async save(): Promise<void> {
    if (this.saving || this.recordId.length === 0) {
      return;
    }
    const nextTitle = this.title.trim();
    if (nextTitle.length === 0) {
      showToast('请填写任务名称', this.getUIContext());
      return;
    }
    const durationChanged = this.canEditDuration() && this.minutes < this.maxMinutes && this.minutes >= this.minimum();
    const titleChanged = nextTitle !== this.initialTitle;
    if (!durationChanged && !titleChanged) {
      backRoute();
      return;
    }
    const body: Record<string, Object> = {};
    if (durationChanged) {
      body['actual_min'] = this.minutes;
    }
    if (titleChanged) {
      body['title'] = nextTitle;
    }
    this.saving = true;
    const response = await HttpService.post(`/record/reduce/${this.recordId}`, body, true);
    this.saving = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '保存失败', this.getUIContext());
      return;
    }
    if (this.kind === 'shame') {
      const next: ShameCertificateData = {
        userName: this.shameData.userName,
        counterpartName: this.shameData.counterpartName,
        cardTitle: this.shameData.cardTitle,
        roleLabel: this.shameData.roleLabel,
        modeLabel: this.shameData.modeLabel,
        contractTitle: nextTitle,
        totalMinutes: this.shameData.totalMinutes,
        actualMinutes: durationChanged ? this.minutes : this.shameData.actualMinutes,
        recordId: this.shameData.recordId,
        resultNarrative: this.shameData.resultNarrative,
        footerBrand: this.shameData.footerBrand,
        footerDatetime: this.shameData.footerDatetime,
        adSlogan: this.shameData.adSlogan,
        shameVariant: this.shameData.shameVariant,
      };
      AppStorage.setOrCreate(StoreKeys.CertificateShame, next);
    } else {
      const next: HonorCertificateData = {
        userName: this.honorData.userName,
        partnerName: this.honorData.partnerName,
        cardTitle: this.honorData.cardTitle,
        modeLabel: this.honorData.modeLabel,
        contractTitle: nextTitle,
        durationMinutes: durationChanged ? this.minutes : this.honorData.durationMinutes,
        recordId: this.honorData.recordId,
        resultNarrative: this.honorData.resultNarrative,
        footerBrand: this.honorData.footerBrand,
        footerDatetime: this.honorData.footerDatetime,
        adSlogan: this.honorData.adSlogan,
      };
      AppStorage.setOrCreate(StoreKeys.CertificateHonor, next);
    }
    refreshStats();
    showToast('已更新', this.getUIContext());
    backRoute();
  }

  build() {
    Stack() {
    SystemNavPage({
      title: '编辑记录',
      showBack: true,
      onBack: () => {
        backRoute();
      },
      content: (): void => {
        this.buildForm();
      }
    })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildForm(): void {
    Column({ space: 16 }) {
      Text('只能把时长改短，改完统计和证书一起更新')
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Text('任务名称')
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
      TextInput({ text: this.title, placeholder: '这次在做什么' })
        .width('100%')
        .height(48)
        .onChange((value: string) => {
          this.title = value;
        })

      if (this.canEditDuration()) {
        Text(`时长 ${this.minutes} 分钟（最多 ${this.maxMinutes}）`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
        Slider({
          value: this.minutes,
          min: this.minimum(),
          max: this.maxMinutes,
          step: this.step(),
        })
          .width('100%')
          .onChange((value: number) => {
            this.minutes = Math.round(value);
          })
      }

      Button(this.saving ? '保存中...' : '确认')
        .width('100%')
        .height(48)
        .enabled(!this.saving)
        .onClick(() => {
          void this.save();
        })
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
