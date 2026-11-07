/**
 * 排行榜前三名奖牌，与 RN components/icons/MedalIcon 同源 SVG。
 */
@Component
export struct RankMedalIcon {
  @Prop place: number = 1;
  @Prop iconSize: number = 24;

  private medalResource(): Resource {
    if (this.place === 1) {
      return $r('app.media.gold_medal');
    }
    if (this.place === 2) {
      return $r('app.media.silver_medal');
    }
    return $r('app.media.bronze_medal');
  }

  build() {
    Image(this.medalResource())
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
  }
}
