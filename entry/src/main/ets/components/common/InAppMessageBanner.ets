import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
import { InAppMessageView } from '../../models/InAppMessageModel';
import { InAppMessageService } from '../../services/InAppMessageService';
import { StoreKeys } from '../../stores/StoreKeys';

@Component
export struct InAppMessageBanner {
  @StorageLink(StoreKeys.InAppMessage) message: InAppMessageView = {
    id: '',
    title: '',
    message: '',
    type: '',
    visible: false
  };
  @State private topSafeInsetVp: number = 0;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    const hostContext = ctx as common.UIAbilityContext;
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
    });
  }

  build() {
    Column() {
      if (this.message.visible) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(this.message.title)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.message.message)
              .fontSize(13)
              .fontColor(AppTheme.colors.textSecondary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('关闭')
            .fontSize(12)
            .fontColor(AppTheme.colors.primary)
            .onClick(() => {
              InAppMessageService.dismiss();
            })
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 12,
          bottom: 12
        })
        .backgroundColor(AppTheme.colors.backgroundSoft)
        .borderRadius(AppTheme.radius.md)
        .shadow({
          radius: 18,
          color: '#1A111827',
          offsetX: 0,
          offsetY: 8
        })
        .onClick(() => {
          InAppMessageService.dismiss();
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8 + this.topSafeInsetVp })
    .visibility(this.message.visible ? Visibility.Visible : Visibility.None)
    .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut }))
  }
}
