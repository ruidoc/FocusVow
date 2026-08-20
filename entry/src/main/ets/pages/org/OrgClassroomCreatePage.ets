import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  formatOrgClassroomElapsed,
  isOrgClassroomJoinable,
  OrgClassroomActive,
  OrgClassroomExitRequest,
  parseOrgClassroomActive,
} from '../../models/OrgModel';
import { OrgListItem } from '../../models/OrgModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { OrgStore } from '../../stores/OrgStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { handleOrgClassroomEndedLocally } from '../../services/OrgClassroomService';

bootstrapStores();

@Entry
@Component
struct OrgClassroomCreatePage {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State org: OrgListItem | null = null;
  @State activeClassroom: OrgClassroomActive | null = null;
  @State classroomTitle: string = '';
  @State classroomMaxApps: string = '2';
  @State classroomAllowExit: boolean = false;
  @State nowMs: number = Date.now();
  private timerId: number = -1;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    void this.refresh(true);
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

  private async refresh(initial: boolean): Promise<void> {
    if (initial) {
      this.loading = true;
      await OrgStore.listDiscover();
    }
    const owned = OrgStore.findOwnedOrg();
    this.org = owned;
    if (!owned) {
      this.activeClassroom = null;
      this.loading = false;
      if (initial) {
        showToast('仅组织创建者可管理课堂', this.getUIContext());
        backRoute();
      }
      return;
    }
    const active = await OrgStore.getActiveClassroom(owned.id);
    this.activeClassroom = isOrgClassroomJoinable(active) ? active : null;
    this.loading = false;
    this.startTimer();
  }

  private async onCreateClassroom(): Promise<void> {
    if (!this.org || this.submitting) {
      return;
    }
    const title = this.classroomTitle.trim();
    const maxApps = Number(this.classroomMaxApps);
    if (title.length === 0) {
      showToast('请填写课堂标题', this.getUIContext());
      return;
    }
    if (!maxApps || maxApps < 1) {
      showToast('请填写可用应用数量', this.getUIContext());
      return;
    }
    this.submitting = true;
    const res = await OrgStore.createClassroom(
      this.org.id,
      title,
      Math.max(1, Math.min(20, Math.floor(maxApps))),
      this.classroomAllowExit
    );
    this.submitting = false;
    if (res.statusCode === 200) {
      const parsed = parseOrgClassroomActive(res.data);
      if (parsed) {
        this.activeClassroom = parsed;
        this.startTimer();
      }
      showToast('课堂已发起', this.getUIContext());
      return;
    }
    showErrorToast(res.message && res.message.length > 0 ? res.message : '发起失败', this.getUIContext());
  }

  private confirmEndClassroom(): void {
    this.getUIContext().showAlertDialog({
      title: '结束课堂？',
      message: '结束后所有成员将解除专注，且无法继续加入。',
      primaryButton: {
        value: '确认结束',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.onEndClassroom();
        }
      },
      secondaryButton: {
        value: '再等等',
        action: () => {}
      }
    });
  }

  private async onEndClassroom(): Promise<void> {
    if (!this.org || !this.activeClassroom || this.submitting) {
      return;
    }
    this.submitting = true;
    const res = await OrgStore.endClassroom(this.org.id, this.activeClassroom.classroom.id);
    this.submitting = false;
    if (res.statusCode === 200) {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await handleOrgClassroomEndedLocally(hostContext);
      this.activeClassroom = null;
      this.clearTimer();
      showToast('课堂已结束', this.getUIContext());
      return;
    }
    showErrorToast(res.message && res.message.length > 0 ? res.message : '结束失败', this.getUIContext());
  }

  private async onApprove(requestId: string): Promise<void> {
    if (!this.org || !this.activeClassroom || this.submitting) {
      return;
    }
    this.submitting = true;
    const res = await OrgStore.approveExitRequest(
      this.org.id,
      this.activeClassroom.classroom.id,
      requestId
    );
    this.submitting = false;
    if (res.statusCode === 200) {
      showToast('已同意退出', this.getUIContext());
      await this.refresh(false);
      return;
    }
    showErrorToast(res.message && res.message.length > 0 ? res.message : '操作失败', this.getUIContext());
  }

  private async onReject(requestId: string): Promise<void> {
    if (!this.org || !this.activeClassroom || this.submitting) {
      return;
    }
    this.submitting = true;
    const res = await OrgStore.rejectExitRequest(
      this.org.id,
      this.activeClassroom.classroom.id,
      requestId
    );
    this.submitting = false;
    if (res.statusCode === 200) {
      showToast('已拒绝退出', this.getUIContext());
      await this.refresh(false);
      return;
    }
    showErrorToast(res.message && res.message.length > 0 ? res.message : '操作失败', this.getUIContext());
  }

  @Builder
  private buildActiveView(): void {
    Column({ space: 12 }) {
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
        Text(formatOrgClassroomElapsed(
          this.activeClassroom ? this.activeClassroom.classroom.active_at : '',
          this.nowMs
        ))
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

      this.buildInfoRow(
        '可用应用数量',
        `${this.activeClassroom ? this.activeClassroom.classroom.max_apps : 0} 个`
      )
      this.buildInfoRow(
        '退出需要审批',
        this.activeClassroom && this.activeClassroom.classroom.allow_exit ? '已开启' : '未开启'
      )

      Row() {
        this.buildStatCell('已加入', this.activeClassroom ? this.activeClassroom.stats.joined : 0)
        this.buildStatCell('专注中', this.activeClassroom ? this.activeClassroom.stats.focusing : 0)
        this.buildStatCell('已完成', this.activeClassroom ? this.activeClassroom.stats.completed : 0)
        this.buildStatCell('已退出', this.activeClassroom ? this.activeClassroom.stats.left : 0)
      }
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(16)

      if (this.activeClassroom && this.activeClassroom.exit_requests.length > 0) {
        Column({ space: 12 }) {
          Text('待审批退出')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')
          ForEach(this.activeClassroom ? this.activeClassroom.exit_requests : [], (item: OrgClassroomExitRequest) => {
            Row() {
              Text(item.username)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor(AppTheme.colors.textPrimary)
              Button('拒绝')
                .fontSize(13)
                .fontColor(AppTheme.colors.textSecondary)
                .backgroundColor(AppTheme.colors.surfaceRaised)
                .height(32)
                .enabled(!this.submitting)
                .onClick(() => {
                  void this.onReject(item.id);
                })
              Button('同意')
                .fontSize(13)
                .fontColor(Color.White)
                .backgroundColor(AppTheme.colors.primary)
                .height(32)
                .margin({ left: 8 })
                .enabled(!this.submitting)
                .onClick(() => {
                  void this.onApprove(item.id);
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (item: OrgClassroomExitRequest) => item.id)
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(AppTheme.colors.surface)
        .borderRadius(16)
      }

      Text('结束课堂')
        .fontSize(15)
        .fontColor(AppTheme.colors.danger)
        .margin({ top: 16 })
        .onClick(() => {
          if (!this.submitting) {
            this.confirmEndClassroom();
          }
        })
    }
    .width('100%')
  }

  @Builder
  private buildInfoRow(title: string, value: string): void {
    Row() {
      Text(title)
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
      Text(value)
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(16)
  }

  @Builder
  private buildStatCell(label: string, value: number): void {
    Column({ space: 4 }) {
      Text(`${value}`)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
      Text(label)
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildCreateForm(): void {
    Column({ space: 12 }) {
      Text('成员可在组织详情加入本次课堂。')
        .fontSize(14)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')

      Row() {
        Text('课堂标题')
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
        TextInput({ text: this.classroomTitle, placeholder: '例如：晚自习' })
          .layoutWeight(1)
          .textAlign(TextAlign.End)
          .backgroundColor(Color.Transparent)
          .maxLength(100)
          .onChange((value: string) => {
            this.classroomTitle = value;
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(16)

      Row() {
        Text('可用应用数量')
          .layoutWeight(1)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
        TextInput({ text: this.classroomMaxApps, placeholder: '2' })
          .width(56)
          .type(InputType.Number)
          .textAlign(TextAlign.End)
          .backgroundColor(Color.Transparent)
          .maxLength(2)
          .onChange((value: string) => {
            this.classroomMaxApps = value;
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(16)

      Row() {
        Column({ space: 4 }) {
          Text('退出需要审批')
            .fontSize(15)
            .fontColor(AppTheme.colors.textPrimary)
          Text('开启后成员需向你申请，同意后才能退出')
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.classroomAllowExit })
          .onChange((isOn: boolean) => {
            this.classroomAllowExit = isOn;
          })
      }
      .width('100%')
      .padding(16)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(16)

      Button(this.submitting ? '发起中' : '发起课堂')
        .width('100%')
        .height(48)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.primary)
        .enabled(!this.submitting)
        .onClick(() => {
          void this.onCreateClassroom();
        })
    }
    .width('100%')
  }

  @Builder
  private buildContent(): void {
    if (this.loading || !this.org) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .padding({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else if (this.activeClassroom) {
      this.buildActiveView()
    } else {
      this.buildCreateForm()
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.activeClassroom ? this.activeClassroom.classroom.title : '发起课堂',
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
