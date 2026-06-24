import { getAppVersion } from '../../common/AppInfo';
import { showErrorToast, showToast } from '../../common/Toast';
import { AppActionButton } from '../../components/common/AppActionButton';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';
import { FeedbackApiService } from '../../services/FeedbackApiService';

interface FeedbackOption {
  label: string;
  value: string;
}

function createFeedbackOptions(): FeedbackOption[] {
  const accountRights: FeedbackOption = { label: '账号权益问题', value: 'account_rights' };
  const bug: FeedbackOption = { label: 'Bug 反馈', value: 'bug' };
  const featureSuggestion: FeedbackOption = { label: '功能建议', value: 'feature_suggestion' };
  const other: FeedbackOption = { label: '其他问题', value: 'other' };
  return [accountRights, bug, featureSuggestion, other];
}

const FEEDBACK_OPTIONS: FeedbackOption[] = createFeedbackOptions();

@Entry
@Component
struct FeedbackPage {
  @State feedbackType: string = '';
  @State content: string = '';
  @State contact: string = '';
  @State loading: boolean = false;

  private isFormValid(): boolean {
    return this.feedbackType.length > 0 && this.content.trim().length > 0;
  }

  private async submitFeedback(): Promise<void> {
    if (!this.isFormValid() || this.loading) {
      return;
    }

    this.loading = true;
    const appVersion = await getAppVersion();
    const response = await FeedbackApiService.submitFeedback(
      this.feedbackType,
      this.content.trim(),
      this.contact.trim(),
      appVersion
    );
    this.loading = false;

    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '提交失败', this.getUIContext());
      return;
    }

    showToast('反馈成功', this.getUIContext());
    backRoute();
  }

  @Builder
  private buildTypeRadioItem(option: FeedbackOption): void {
    Row({ space: 8 }) {
      Radio({ value: option.value, group: 'feedbackType' })
        .width(20)
        .height(20)
        .checked(this.feedbackType === option.value)
        .radioStyle({
          checkedBackgroundColor: AppTheme.colors.primary,
          uncheckedBorderColor: AppTheme.colors.textMuted
        })
        .onChange((isChecked: boolean) => {
          if (isChecked) {
            this.feedbackType = option.value;
          }
        })

      Text(option.label)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .opacity(0.8)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.feedbackType = option.value;
    })
  }

  @Builder
  private buildTypeSection(): void {
    Column({ space: 8 }) {
      Text('反馈类型')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Column({ space: 12 }) {
        Row({ space: 12 }) {
          this.buildTypeRadioItem(FEEDBACK_OPTIONS[0])
          this.buildTypeRadioItem(FEEDBACK_OPTIONS[1])
        }
        .width('100%')

        Row({ space: 12 }) {
          this.buildTypeRadioItem(FEEDBACK_OPTIONS[2])
          this.buildTypeRadioItem(FEEDBACK_OPTIONS[3])
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 15, bottom: 15 })
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.md)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 40, bottom: 30 })
  }

  @Builder
  private buildContentSection(): void {
    Column({ space: 8 }) {
      Text('反馈内容')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Column() {
        TextArea({
          placeholder: '请输入您的意见和反馈，我们会尽快处理并改进',
          text: this.content
        })
          .width('100%')
          .height(168)
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
          .placeholderColor(AppTheme.colors.textMuted)
          .backgroundColor(Color.Transparent)
          .padding({ left: 4, right: 4, top: 8, bottom: 8 })
          .onChange((value: string) => {
            this.content = value;
          })
      }
      .width('100%')
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.md)
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 30 })
  }

  @Builder
  private buildContactSection(): void {
    Column({ space: 8 }) {
      Row({ space: 4 }) {
        Text('联系方式')
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)

        Text('（选填）')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')

      Column() {
        TextInput({
          placeholder: '微信号或邮箱，方便我们联系你',
          text: this.contact
        })
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
          .placeholderColor(AppTheme.colors.textMuted)
          .backgroundColor(Color.Transparent)
          .padding({ left: 4, right: 4 })
          .onChange((value: string) => {
            this.contact = value;
          })
      }
      .width('100%')
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.md)
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 30 })
  }

  @Builder
  private buildFeedbackContent(): void {
    Column({ space: 0 }) {
      this.buildTypeSection()
      this.buildContentSection()
      this.buildContactSection()

      AppActionButton({
        label: this.loading ? '提交中...' : '提交反馈',
        isEnabled: this.isFormValid() && !this.loading,
        onPress: () => {
          void this.submitFeedback();
        }
      })
        .margin({ top: 14 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '意见反馈',
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 20,
        topSpacerHeight: 20,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildFeedbackContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
