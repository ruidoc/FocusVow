import { AppTheme } from '../../constants/Theme';
import { SCHEDULED_SCENE_PRESETS, ScheduledScenePreset } from '../../models/ScheduledScenePreset';

@Component
export struct ScheduledSceneCards {
  @Prop showHeading: boolean = true;
  onSelect?: (preset: ScheduledScenePreset) => void;

  @Builder
  private buildSceneCard(preset: ScheduledScenePreset): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(preset.background)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.45)')

      Column() {
        Row() {
          Blank()
          Row() {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(16)
              .fontColor([AppTheme.colors.textPrimary])
          }
          .width(20)
          .height(20)
          .justifyContent(FlexAlign.Center)
          .borderRadius(11)
          .backgroundColor(AppTheme.colors.surface)
        }
        .width('100%')

        Blank()

        Text(preset.name)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .width('100%')
          .margin({ bottom: 4 })

        Text(preset.description)
          .fontSize(11)
          .lineHeight(16)
          .fontColor('rgba(255, 255, 255, 0.85)')
          .maxLines(2)
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .borderRadius(12)
    .clip(true)
    .onClick(() => {
      this.onSelect?.(preset);
    })
  }

  build() {
    Column({ space: 10 }) {
      if (this.showHeading) {
        Text('添加常见任务场景')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
          .margin({ left: 4 })
      }

      Row({ space: 10 }) {
        ForEach(SCHEDULED_SCENE_PRESETS, (preset: ScheduledScenePreset) => {
          this.buildSceneCard(preset)
        }, (preset: ScheduledScenePreset) => preset.id)
      }
      .width('100%')
    }
    .width('100%')
  }
}
