import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import {
  parseReferralProgress,
  ReferralInvitee,
  ReferralProgress,
  ReferralApiService
} from '../../services/ReferralApiService';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

interface SummaryCard {
  label: string;
  value: string;
  color: string;
}

@Entry
@Component
struct InviteRecordPage {
  @State loading: boolean = true;
  @State progress: ReferralProgress | null = null;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    const response = await ReferralApiService.progress();
    this.loading = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '加载失败', this.getUIContext());
      return;
    }
    this.progress = parseReferralProgress(response.data);
  }

  private formatDate(raw: string): string {
    if (raw.length === 0) {
      return '—';
    }
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) {
      return '—';
    }
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${m}-${day}`;
  }

  private getSummaryCards(): SummaryCard[] {
    const data = this.progress;
    const rows = data ? data.invitees : [];
    return [
      {
        label: '邀请人数',
        value: String(data ? data.invited_count : rows.length),
        color: AppTheme.colors.accentBlue
      },
      {
        label: '已成功',
        value: String(data ? data.successful_count : 0),
        color: AppTheme.colors.accentBlue
      },
      {
        label: '已得会员(天)',
        value: `${data ? data.total_days_earned : 0}`,
        color: AppTheme.colors.textPrimary
      }
    ];
  }

  @Builder
  private buildSummary(): void {
    Row({ space: 8 }) {
      ForEach(this.getSummaryCards(), (item: SummaryCard) => {
        Column({ space: 6 }) {
          Text(item.label)
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
          Text(item.value)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(item.color)
        }
        .layoutWeight(1)
        .padding({ top: 14, bottom: 14 })
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppTheme.colors.surface)
        .borderRadius(16)
      }, (item: SummaryCard) => item.label)
    }
    .width('100%')
  }

  @Builder
  private buildInviteeRow(item: ReferralInvitee, isLast: boolean): void {
    Row() {
      Text(item.username.length > 0 ? item.username : '用户')
        .layoutWeight(1.4)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Column() {
        Text(item.status === 'granted' ? '已发放' : '待专注')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.status === 'granted' ? AppTheme.colors.accentBlue : AppTheme.colors.textSecondary)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(item.status === 'granted' ? '#E8F1FE' : '#F1F5F9')
          .borderRadius(999)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      Text(item.status === 'granted' ? `+${item.inviter_days > 0 ? item.inviter_days : 15}` : '—')
        .layoutWeight(0.9)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.status === 'granted' ? AppTheme.colors.accentBlue : AppTheme.colors.textMuted)
        .textAlign(TextAlign.Center)
      Text(this.formatDate(item.granted_at.length > 0 ? item.granted_at : item.created_at))
        .layoutWeight(0.9)
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .border(isLast ? { width: 0 } : { width: { bottom: 1 }, color: AppTheme.colors.border })
  }

  @Builder
  private buildTable(): void {
    Column() {
      Row() {
        Text('用户')
          .layoutWeight(1.4)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)
        Text('状态')
          .layoutWeight(1)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
        Text('奖励')
          .layoutWeight(0.9)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
        Text('日期')
          .layoutWeight(0.9)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#F8FAFC')
      .border({ width: { bottom: 1 }, color: AppTheme.colors.border })

      if (!this.progress || this.progress.invitees.length === 0) {
        Column() {
          Text('暂无邀请记录')
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
            .lineHeight(20)
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
        .alignItems(HorizontalAlign.Center)
      } else {
        ForEach(this.progress.invitees, (item: ReferralInvitee, index: number) => {
          this.buildInviteeRow(item, index === this.progress!.invitees.length - 1)
        }, (item: ReferralInvitee) => item.user_id)
      }
    }
    .width('100%')
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(16)
    .clip(true)
  }

  @Builder
  private buildPageBody(): void {
    if (this.loading && !this.progress) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.accentBlue)
      }
      .width('100%')
      .padding({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else {
      Column({ space: 14 }) {
        this.buildSummary()
        this.buildTable()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '邀请记录',
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 20,
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
