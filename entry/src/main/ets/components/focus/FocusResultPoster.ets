import { PosterCoverSplit } from '../../models/ShareConfigModel';
import { checkinPosterHeight } from '../../utils/CertificateTemplate';
import { limitPosterTagsLine, splitCertificatePosterCover } from '../../utils/ShareConfigUtil';

function posterTemplateBackground(id: string): string {
  if (id === 'white') {
    return '#ffffff';
  }
  if (id === 'warm') {
    return '#f4efe6';
  }
  if (id === 'blush') {
    return '#f6e8e4';
  }
  if (id === 'mist') {
    return '#d7e6f5';
  }
  if (id === 'lemon') {
    return '#f3e36b';
  }
  if (id === 'gold') {
    return '#f0c45a';
  }
  if (id === 'mint') {
    return '#a8e0c0';
  }
  if (id === 'lime') {
    return '#c6e86a';
  }
  if (id === 'emerald') {
    return '#1dcc74';
  }
  return '#f4efe6';
}

@Component
export struct FocusResultPoster {
  @Prop imageUrl: string = '';
  @Prop backgroundId: string = 'warm';
  @Prop colorMode: 'light' | 'dark' = 'light';
  @Prop username: string = '';
  @Prop avatar: string = '';
  @Prop endedAt: number = 0;
  @Prop minutes: number = 0;
  @Prop coverLine: string = '';
  @Prop tags: string = '';
  @Prop posterWidth: number = 320;
  @Prop layoutScreenWidthVp: number = 390;
  @Prop snapshotId: string = 'focusResultPoster';

  private posterHeight(): number {
    return checkinPosterHeight(this.layoutScreenWidthVp);
  }

  private formatEndedAt(): string {
    if (this.endedAt <= 0) {
      return '';
    }
    const date = new Date(this.endedAt);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hour = date.getHours();
    const minute = date.getMinutes();
    const pad = (value: number): string => (value < 10 ? `0${value}` : `${value}`);
    return `${month}月${day}日 ${pad(hour)}:${pad(minute)}`;
  }

  private durationLabel(): string {
    if (this.minutes <= 0) {
      return '';
    }
    const h = Math.floor(this.minutes / 60);
    const m = this.minutes % 60;
    if (h > 0 && m > 0) {
      return `${h} 小时 ${m} 分钟`;
    }
    if (h > 0) {
      return `${h} 小时`;
    }
    return `${m} 分钟`;
  }

  private posterCover(): PosterCoverSplit {
    return splitCertificatePosterCover(this.coverLine);
  }

  private posterTagLine(): string {
    return limitPosterTagsLine(this.tags, 2);
  }

  private isDarkMode(): boolean {
    return this.colorMode === 'dark';
  }

  private inkColor(): string {
    return this.isDarkMode() ? '#fafafa' : '#1c1917';
  }

  private mutedColor(): string {
    return this.isDarkMode() ? 'rgba(250,250,250,0.72)' : 'rgba(28,25,23,0.55)';
  }

  private posterBgColor(): string {
    return posterTemplateBackground(this.backgroundId);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.imageUrl.trim().length > 0) {
        Image(this.imageUrl)
          .width(this.posterWidth)
          .height(this.posterHeight())
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width(this.posterWidth)
          .height(this.posterHeight())
          .backgroundColor(this.posterBgColor())
      }

      Column({ space: 12 }) {
        if (this.posterCover().primary.length > 0) {
          Text(this.posterCover().primary)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.inkColor())
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.posterCover().secondary.length > 0) {
          Text(this.posterCover().secondary)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.mutedColor())
            .maxLines(2)
        }
        if (this.durationLabel().length > 0) {
          Text(this.durationLabel())
            .fontSize(13)
            .fontColor(this.mutedColor())
        }
        Blank().layoutWeight(1)
        Row() {
          if (this.avatar.trim().length > 0) {
            Image(this.avatar)
              .width(22)
              .height(22)
              .borderRadius(11)
              .margin({ right: 6 })
          }
          Text(`@${this.username.length > 0 ? this.username : '用户'}`)
            .fontSize(12)
            .fontColor(this.mutedColor())
            .maxLines(1)
            .layoutWeight(1)
          Text(this.formatEndedAt())
            .fontSize(11)
            .fontColor(this.mutedColor())
        }
        .width('100%')
        if (this.posterTagLine().length > 0) {
          Text(this.posterTagLine())
            .fontSize(11)
            .fontColor(this.mutedColor())
            .maxLines(2)
        }
      }
      .width(this.posterWidth)
      .height(this.posterHeight())
      .padding(20)
    }
    .id(this.snapshotId)
    .width(this.posterWidth)
    .height(this.posterHeight())
    .borderRadius(16)
    .clip(true)
  }
}
