import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  formatOrgClassroomElapsed,
  isOrgClassroomFocusing,
  isOrgClassroomJoinable,
  OrgClassroomActive,
} from '../../models/OrgModel';
import { PageRoutes, backRoute, pushRoute, returnToMainTab } from '../../router/PageRoutes';
import { OrgStore } from '../../stores/OrgStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import {
  currentUserId,
  joinAndStartOrgClassroom,
} from '../../services/OrgClassroomService';
import {
  chooseRestrictedApps,
  ensureScreenTimeAuthorization,
} from '../../services/ScreenTimeService';

bootstrapStores();

@Entry
@Component
struct OrgClassroomJoinPage {
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @State loading: boolean = true;
  @State joining: boolean = false;
  @State orgId: string = '';
  @State activeClassroom: OrgClassroomActive | null = null;
  @State nowMs: number = Date.now();
  private timerId: number = -1;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    SettingsStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    this.orgId = String(AppStorage.get<string>(StoreKeys.OrgDetailId) ?? '');
    void this.load();
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTimer(): void {
    this.clearTimer();
    if (!this.activeClassroom) {
      return;
    }
    this.timerId = setInterval(() => {
      this.nowMs = Date.now();
    }, 1000);
  }

  private async load(): Promise<void> {
    if (this.orgId.length === 0) {
      backRoute();
      return;
    }
    this.loading = true;
    const active = await OrgStore.getActiveClassroom(this.orgId);
    if (!isOrgClassroomJoinable(active)) {
      this.activeClassroom = null;
      this.loading = false;
      showToast('当前没有可加入的课堂', this.getUIContext());
      backRoute();
      return;
    }
    this.activeClassroom = active;
    this.loading = false;
    this.startTimer();
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const auth = await ensureScreenTimeAuthorization(hostContext);
    if (!auth.ok) {
      showErrorToast(auth.message, this.getUIContext());
      return;
    }
    SettingsStore.updateAuthorization(hostContext, true, auth.message);
    const result = await chooseRestrictedApps(hostContext, SettingsStore.getState().selectedTokens);
    if (result.data) {
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
    }
  }

  private async onJoin(): Promise<void> {
    if (!this.activeClassroom || this.joining) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const auth = await ensureScreenTimeAuthorization(hostContext);
    if (!auth.ok) {
      showErrorToast(auth.message, this.getUIContext());
      return;
    }
    this.joining = true;
    const error = await joinAndStartOrgClassroom(
      hostContext,
      this.orgId,
      this.activeClassroom,
      SettingsStore.getState().selectedTokens
    );
    this.joining = false;
    if (error.length > 0) {
      showErrorToast(error, this.getUIContext());
      return;
    }
    showToast('已加入组织课堂', this.getUIContext());
    returnToMainTab('focus');
  }

  @Builder
  private buildContent(): void {
    if (this.loading || !this.activeClassroom) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .padding({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Circle()
              .width(8)
              .height(8)
              .fill(AppTheme.colors.success)
            Text('正在上课中')
              .fontSize(13)
              .fontColor(AppTheme.colors.textSecondary)
          }
          Text(formatOrgClassroomElapsed(this.activeClassroom.classroom.active_at, this.nowMs))
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
          Text('已上课，请尽快加入课堂')
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppTheme.colors.surface)
        .borderRadius(16)

        Column({ space: 14 }) {
          Row() {
            Text('要放行的应用')
              .layoutWeight(1)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            Text('+ 选择')
              .fontSize(14)
              .fontColor(AppTheme.colors.primary)
              .onClick(() => {
                void this.chooseApps();
              })
          }
          .width('100%')
          Text(this.selectedAppCount === 0
            ? '未选择应用'
            : `已选 ${this.selectedAppCount} 个，最多 ${this.activeClassroom.classroom.max_apps} 个`)
            .fontSize(15)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(AppTheme.colors.surface)
        .borderRadius(16)

        Button(this.joining
          ? '加入中'
          : (isOrgClassroomFocusing(this.activeClassroom, currentUserId()) ? '继续专注' : '加入'))
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor(AppTheme.colors.primary)
          .enabled(!this.joining)
          .onClick(() => {
            void this.onJoin();
          })
      }
      .width('100%')
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.activeClassroom ? this.activeClassroom.classroom.title : '加入课堂',
        showBack: true,
        onBack: (): void => {
          backRoute();
        },
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
