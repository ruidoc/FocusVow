import { AppTheme, isDarkThemeMode } from '../../constants/Theme';

const DISMISS_PREFIX: string = 'feature_intro_dismissed:';

export function isFeatureIntroDismissed(id: string): boolean {
  return AppStorage.get<boolean>(`${DISMISS_PREFIX}${id}`) ?? false;
}

function dismissFeatureIntro(id: string): void {
  AppStorage.setOrCreate(`${DISMISS_PREFIX}${id}`, true);
}

@Component
export struct FeatureIntroCard {
  @Prop introId: string = '';
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop confirmTitle: string = '确定了解了？';
  @Prop confirmMessage: string = '关闭后不再显示此介绍';
  @State private visible: boolean = true;

  aboutToAppear(): void {
    this.visible = !isFeatureIntroDismissed(this.introId);
  }

  private confirmDismiss(): void {
    dismissFeatureIntro(this.introId);
    this.visible = false;
  }

  private showDismissConfirmDialog(): void {
    this.getUIContext().showAlertDialog({
      title: this.confirmTitle,
      message: this.confirmMessage,
      autoCancel: true,
      primaryButton: {
        value: '确认',
        fontColor: AppTheme.colors.primary,
        action: () => {
          this.confirmDismiss();
        },
      },
      secondaryButton: {
        value: '取消',
        action: () => {},
      },
    });
  }

  build() {
    if (!this.visible) {
      Column()
    } else {
      Column({ space: 0 }) {
        Row({ space: 8 }) {
          Column({ space: 4 }) {
            if (this.title.length > 0) {
              Text(this.title)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(isDarkThemeMode() ? '#7CD4FD' : '#1570EF')
                .width('100%')
            }
            if (this.description.length > 0) {
              Text(this.description)
                .fontSize(13)
                .lineHeight(20)
                .fontColor(AppTheme.colors.textSecondary)
                .width('100%')
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(16)
            .fontColor([isDarkThemeMode() ? '#7CD4FD' : '#1570EF'])
            .onClick(() => {
              this.showDismissConfirmDialog();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .margin({ bottom: 16 })
      .borderRadius(12)
      .backgroundColor(isDarkThemeMode() ? 'rgba(46, 144, 250, 0.12)' : '#EFF8FF')
      .border({
        width: 1,
        color: isDarkThemeMode() ? 'rgba(46, 144, 250, 0.28)' : '#B2DDFF',
      })
    }
  }
}
