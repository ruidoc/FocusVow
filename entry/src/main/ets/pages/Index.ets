import { common } from '@kit.AbilityKit';
import {
  FocusRunStatus,
  FocusSession,
  createFocusSession,
  formatRemainingSeconds,
  getRemainingSeconds,
  isFocusSessionFinished
} from '../common/FocusSession';
import {
  applyAppRestriction,
  pickRestrictedApps,
  releaseAppRestriction,
  requestGuardAuthorization
} from '../common/FocusGuardService';

@Entry
@Component
struct Index {
  @State durationMinutes: number = 25;
  @State selectedTokens: string[] = [];
  @State hasAuthorized: boolean = false;
  @State focusStatus: FocusRunStatus = FocusRunStatus.Idle;
  @State statusMessage: string = '先申请系统授权，再选择需要锁定的应用';
  @State remainingLabel: string = '25:00';
  @State sessionStartAt: number = 0;
  @State sessionEndAt: number = 0;

  private timerId: number = -1;
  private isStopping: boolean = false;
  private readonly durationOptions: number[] = [10, 25, 45, 60];

  aboutToAppear(): void {
    this.remainingLabel = formatRemainingSeconds(this.durationMinutes * 60);
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private isRunning(): boolean {
    return this.focusStatus === FocusRunStatus.Running;
  }

  private buildSessionSnapshot(): FocusSession {
    return {
      selectedTokens: [...this.selectedTokens],
      selectedCount: this.selectedTokens.length,
      durationMinutes: this.durationMinutes,
      startAt: this.sessionStartAt,
      endAt: this.sessionEndAt,
      status: this.focusStatus
    };
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.syncRemainingLabel();
    }, 1000);
  }

  private syncRemainingLabel(): void {
    if (!this.isRunning()) {
      this.remainingLabel = formatRemainingSeconds(this.durationMinutes * 60);
      return;
    }

    const session = this.buildSessionSnapshot();
    const nowAt = Date.now();
    const remainSeconds = getRemainingSeconds(session, nowAt);
    this.remainingLabel = formatRemainingSeconds(remainSeconds);

    if (isFocusSessionFinished(session, nowAt)) {
      this.finishFocus(true);
    }
  }

  private updateDuration(minutes: number): void {
    if (this.isRunning()) {
      return;
    }
    this.durationMinutes = minutes;
    this.remainingLabel = formatRemainingSeconds(minutes * 60);
  }

  private async authorizeGuard(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestGuardAuthorization(hostContext);
    this.hasAuthorized = result.ok;
    this.statusMessage = result.message;
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await pickRestrictedApps(hostContext, this.selectedTokens);
    if (result.ok && result.data) {
      this.selectedTokens = [...result.data];
    }
    this.statusMessage = result.message;
  }

  private async startFocus(): Promise<void> {
    if (this.isRunning()) {
      return;
    }

    if (this.selectedTokens.length === 0) {
      this.statusMessage = '请先选择至少 1 个应用';
      return;
    }

    if (!this.hasAuthorized) {
      await this.authorizeGuard();
      if (!this.hasAuthorized) {
        return;
      }
    }

    const result = await applyAppRestriction(this.selectedTokens);
    this.statusMessage = result.message;
    if (!result.ok) {
      return;
    }

    const session = createFocusSession(this.selectedTokens, this.durationMinutes, Date.now());
    this.focusStatus = session.status;
    this.sessionStartAt = session.startAt;
    this.sessionEndAt = session.endAt;
    this.remainingLabel = formatRemainingSeconds(getRemainingSeconds(session, session.startAt));
    this.startTimer();
  }

  private async finishFocus(isAutoFinished: boolean): Promise<void> {
    if (!this.isRunning() || this.isStopping) {
      return;
    }

    this.isStopping = true;
    this.clearTimer();

    const result = await releaseAppRestriction(this.selectedTokens);
    this.focusStatus = FocusRunStatus.Finished;
    this.sessionStartAt = 0;
    this.sessionEndAt = 0;
    this.remainingLabel = '00:00';
    this.statusMessage = isAutoFinished
      ? (result.ok ? '专注完成，限制已自动解除' : `专注完成，但解除限制失败：${result.message}`)
      : (result.ok ? '你已手动结束专注' : `结束专注失败：${result.message}`);

    this.isStopping = false;
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Text('FocusVow')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')

          Text('首版 MVP：先跑通授权、选 App、开始专注、结束专注')
            .fontSize(14)
            .fontColor('#6B7280')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 12 }) {
          Text(this.remainingLabel)
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')

          Text(this.isRunning() ? '专注进行中' : '准备开始')
            .fontSize(14)
            .fontColor(this.isRunning() ? '#2563EB' : '#6B7280')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#F3F7FF')
        .borderRadius(24)

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
                .fontSize(14)
                .enabled(!this.isRunning())
                .backgroundColor(this.durationMinutes === item ? '#111827' : '#FFFFFF')
                .fontColor(this.durationMinutes === item ? '#FFFFFF' : '#111827')
                .borderRadius(20)
                .border({
                  width: 1,
                  color: this.durationMinutes === item ? '#111827' : '#D1D5DB'
                })
                .onClick(() => {
                  this.updateDuration(item);
                })
            }, (item: number) => item.toString())
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)

        Column({ space: 10 }) {
          Row() {
            Text('已选择应用')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
            Blank()
            Text(`${this.selectedTokens.length} 个`)
              .fontSize(16)
              .fontColor('#2563EB')
          }
          .width('100%')

          Text(this.statusMessage)
            .fontSize(14)
            .fontColor('#6B7280')
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)

        Column({ space: 12 }) {
          Button(this.hasAuthorized ? '重新授权' : '申请系统授权')
            .width('100%')
            .height(48)
            .type(ButtonType.Capsule)
            .backgroundColor('#E5E7EB')
            .fontColor('#111827')
            .onClick(() => {
              this.authorizeGuard();
            })

          Button('选择需要锁定的应用')
            .width('100%')
            .height(48)
            .type(ButtonType.Capsule)
            .backgroundColor('#FFFFFF')
            .fontColor('#111827')
            .border({ width: 1, color: '#D1D5DB' })
            .onClick(() => {
              this.chooseApps();
            })

          if (!this.isRunning()) {
            Button('开始专注')
              .width('100%')
              .height(52)
              .type(ButtonType.Capsule)
              .backgroundColor('#111827')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.startFocus();
              })
          } else {
            Button('结束专注')
              .width('100%')
              .height(52)
              .type(ButtonType.Capsule)
              .backgroundColor('#EF4444')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.finishFocus(false);
              })
          }
        }
        .width('100%')

        Text('提示：这一版使用即时限制 + 本地倒计时，先验证真机授权和锁定链路。')
          .fontSize(12)
          .fontColor('#9CA3AF')
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 32, bottom: 32 })
      .backgroundColor('#F7F8FA')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}