import { AppTheme } from '../../constants/Theme';

@Component
export struct DuoFocusHeader {
  @Prop selfName: string = '我';
  @Prop partnerName: string = '搭子';

  build() {
    Row({ space: 8 }) {
      Row({ space: 6 }) {
        Text(this.selfName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('×')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textMuted)

        Text(this.partnerName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Text('共同专注中')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.success)
        .backgroundColor(AppTheme.colors.successSoft)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(AppTheme.radius.pill)
    }
    .alignItems(VerticalAlign.Center)
  }
}
