import { common } from '@kit.AbilityKit';
import { PageHeader } from '../../components/common/PageHeader';
import { PlanDraft } from '../../models/PlanModel';
import { PageRoutes, backRoute, replaceRoute } from '../../router/PageRoutes';
import { chooseRestrictedApps } from '../../services/ScreenTimeService';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct PlanAddPage {
  @State planName: string = '';
  @State startTime: string = '09:00';
  @State endTime: string = '18:00';
  @State repeatDays: number[] = [1, 2, 3, 4, 5];
  @State selectedTokens: string[] = [];
  @State mode: 'shield' | 'allow' = 'shield';
  @State statusMessage: string = '建议先选择和快速专注一致的一组应用，再保存为契约模板';

  private readonly dayOptions: number[] = [1, 2, 3, 4, 5, 6, 0];

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    const settingsState = SettingsStore.getState();
    this.selectedTokens = [...settingsState.selectedTokens];
    this.statusMessage = settingsState.statusMessage;
  }

  private getWeekdayLabel(day: number): string {
    switch (day) {
      case 1:
        return '一';
      case 2:
        return '二';
      case 3:
        return '三';
      case 4:
        return '四';
      case 5:
        return '五';
      case 6:
        return '六';
      default:
        return '日';
    }
  }

  private toggleRepeatDay(day: number): void {
    if (this.repeatDays.includes(day)) {
      this.repeatDays = this.repeatDays.filter((item: number) => item !== day);
      return;
    }

    this.repeatDays = [...this.repeatDays, day].sort((left, right) => left - right);
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      this.selectedTokens = [...result.data];
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
      this.statusMessage = result.message;
      return;
    }

    this.statusMessage = result.message;
  }

  private savePlan(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.selectedTokens.length === 0) {
      this.statusMessage = '请先至少选择 1 个应用，再保存契约';
      return;
    }

    const draft: PlanDraft = {
      name: this.planName,
      startTime: this.startTime,
      endTime: this.endTime,
      repeatDays: this.repeatDays,
      selectedTokens: this.selectedTokens,
      mode: this.mode
    };

    PlanStore.savePlan(hostContext, draft);
    replaceRoute(PageRoutes.PlanList);
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({
          title: '新增计划',
          subtitle: '先做本地基础字段，后面再继续贴近 iOS 的完整表单',
          showBack: true,
          onBack: () => backRoute()
        })

        Column({ space: 12 }) {
          Text('计划名称')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
          TextInput({ text: this.planName, placeholder: '例如：工作日上午专注' })
            .height(48)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.planName = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Text('时间区间')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')

          Row({ space: 12 }) {
            TextInput({ text: this.startTime, placeholder: '09:00' })
              .width('48%')
              .height(48)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.startTime = value;
              })
            TextInput({ text: this.endTime, placeholder: '18:00' })
              .width('48%')
              .height(48)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.endTime = value;
              })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Text('重复日期')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
          Row({ space: 8 }) {
            ForEach(this.dayOptions, (item: number) => {
              Button(this.getWeekdayLabel(item))
                .width(40)
                .height(40)
                .type(ButtonType.Capsule)
                .backgroundColor(this.repeatDays.includes(item) ? '#111827' : '#FFFFFF')
                .fontColor(this.repeatDays.includes(item) ? '#FFFFFF' : '#111827')
                .border({ width: 1, color: '#D1D5DB' })
                .onClick(() => {
                  this.toggleRepeatDay(item);
                })
            }, (item: number) => item.toString())
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          Text('限制模式')
            .fontSize(15)
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
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Text(`当前已选应用：${this.selectedTokens.length} 个`)
            .fontSize(14)
            .fontColor('#111827')
          Text(this.statusMessage)
            .fontSize(12)
            .fontColor('#6B7280')
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)
        .alignItems(HorizontalAlign.Start)

        Button('选择计划应用')
          .width('100%')
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor('#FFFFFF')
          .fontColor('#111827')
          .border({ width: 1, color: '#D1D5DB' })
          .onClick(() => {
            this.chooseApps();
          })

        Button('保存计划')
          .width('100%')
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor('#111827')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.savePlan();
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
