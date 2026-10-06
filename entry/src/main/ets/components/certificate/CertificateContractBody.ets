import {
  CONTRACT_FONT,
  certificateHidesTitle,
  ContractPalette,
  getContractDocket,
  getContractPalette,
} from '../../utils/CertificateTemplate';
import { StoreKeys } from '../../stores/StoreKeys';

@Component
export struct CertificateContractBody {
  /** honor | duo | shame | traitor | victim */
  @Prop kind: string = 'honor';
  @Prop templateStyle: string = 'classic';
  @Prop title: string = '';
  @Prop datetime: string = '';
  @Prop userName: string = '';
  @Prop partnerName: string = '';
  @Prop contractTitle: string = '';
  @Prop minutes: number = 0;
  @Prop totalMinutes: number = 0;
  @Prop actualMinutes: number = 0;
  @StorageLink(StoreKeys.CertificateScale) certScale: number = 1;

  private fs(value: number): number {
    const scale = this.certScale > 0 ? this.certScale : 1;
    return Math.round(value * scale * 10) / 10;
  }

  private palette(): ContractPalette {
    const shame = this.kind === 'shame' || this.kind === 'traitor' || this.kind === 'victim';
    return getContractPalette(shame ? 'shame' : 'honor', this.templateStyle);
  }

  private docketPrefix(): string {
    if (this.kind === 'duo') {
      return '盟';
    }
    if (this.kind === 'shame') {
      return '违';
    }
    if (this.kind === 'traitor') {
      return '惩';
    }
    if (this.kind === 'victim') {
      return '冤';
    }
    return '契';
  }

  private fallbackTitle(): string {
    if (this.kind === 'duo') {
      return '同舟履约公证书';
    }
    if (this.kind === 'shame') {
      return '单人违约裁决书';
    }
    if (this.kind === 'traitor') {
      return '连坐毁约惩戒书';
    }
    if (this.kind === 'victim') {
      return '连坐受难昭雪书';
    }
    return '专注履约公证书';
  }

  @Builder
  private spanLabel(text: string): void {
    Span(text)
      .fontSize(this.fs(15))
      .fontColor(this.palette().clauseLabel)
      .fontFamily(CONTRACT_FONT)
  }

  @Builder
  private spanBody(text: string): void {
    Span(text)
      .fontSize(this.fs(15))
      .fontColor(this.palette().clauseBody)
      .fontFamily(CONTRACT_FONT)
  }

  @Builder
  private spanHi(text: string): void {
    Span(text)
      .fontSize(this.fs(15))
      .fontColor(this.palette().highlight)
      .fontFamily(CONTRACT_FONT)
  }

  @Builder
  private buildClauses(): void {
    if (this.kind === 'duo') {
      Column({ space: 11 }) {
      Text() {
        this.spanLabel('【立约主体】')
        this.spanBody('  ')
        this.spanHi(this.userName)
        this.spanBody('、')
        this.spanHi(this.partnerName)
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【任务名称】')
        this.spanBody('  《')
        this.spanHi(this.contractTitle)
        this.spanBody('》 ')
        this.spanHi(`${this.minutes}`)
        this.spanBody('分钟 · 双人连坐')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【履行查验】')
        this.spanBody('  并肩完成 ')
        this.spanHi(`${this.minutes}`)
        this.spanBody('分钟。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【公证裁定】')
        this.spanBody('  同舟履约，特此赐证。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      }
    } else if (this.kind === 'shame') {
      Column({ space: 11 }) {
      Text() {
        this.spanLabel('【违约主体】')
        this.spanBody('  ')
        this.spanHi(this.userName)
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【任务名称】')
        this.spanBody('  《')
        this.spanHi(this.contractTitle)
        this.spanBody('》 ')
        this.spanHi(`${this.totalMinutes}`)
        this.spanBody('分钟')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【违约核验】')
        this.spanBody('  第 ')
        this.spanHi(`${this.actualMinutes}`)
        this.spanBody('分钟违约退出。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【裁决惩戒】')
        this.spanBody('  契约作废，立此存诫。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      }
    } else if (this.kind === 'traitor') {
      Column({ space: 11 }) {
      Text() {
        this.spanLabel('【裁定主体】')
        this.spanBody('  ')
        this.spanHi(this.userName)
        this.spanBody('（连坐 ')
        this.spanHi(this.partnerName)
        this.spanBody('）')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【任务名称】')
        this.spanBody('  《')
        this.spanHi(this.contractTitle)
        this.spanBody('》 ')
        this.spanHi(`${this.totalMinutes}`)
        this.spanBody('分钟 · 连坐')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【背信核实】')
        this.spanBody('  第 ')
        this.spanHi(`${this.actualMinutes}`)
        this.spanBody('分钟退出，触发连坐。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【公证惩戒】')
        this.spanBody('  毁约确凿，公开处刑。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      }
    } else if (this.kind === 'victim') {
      Column({ space: 11 }) {
      Text() {
        this.spanLabel('【受难主体】')
        this.spanBody('  ')
        this.spanHi(this.userName)
        this.spanBody('（搭子 ')
        this.spanHi(this.partnerName)
        this.spanBody(' 弃约）')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【任务名称】')
        this.spanBody('  《')
        this.spanHi(this.contractTitle)
        this.spanBody('》 ')
        this.spanHi(`${this.totalMinutes}`)
        this.spanBody('分钟 · 连坐')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【受害查实】')
        this.spanBody('  已守 ')
        this.spanHi(`${this.actualMinutes}/${this.totalMinutes}`)
        this.spanBody('分钟，因搭子退出终止。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【昭雪裁定】')
        this.spanBody('  败非君过，特此昭雪。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      }
    } else {
      Column({ space: 11 }) {
      Text() {
        this.spanLabel('【立约主体】')
        this.spanBody('  ')
        this.spanHi(this.userName)
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【任务名称】')
        this.spanBody('  《')
        this.spanHi(this.contractTitle)
        this.spanBody('》 ')
        this.spanHi(`${this.minutes}`)
        this.spanBody('分钟')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【履行查验】')
        this.spanBody('  足额坚守 ')
        this.spanHi(`${this.minutes}`)
        this.spanBody('分钟。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      Text() {
        this.spanLabel('【公证裁定】')
        this.spanBody('  履约完毕，特此存证。')
      }.fontSize(this.fs(15)).lineHeight(this.fs(24)).width('100%')
      }
    }
  }

  build() {
    Column() {
      Text(this.title.length > 0 ? this.title : this.fallbackTitle())
        .fontSize(this.fs(21))
        .fontFamily(CONTRACT_FONT)
        .fontColor(certificateHidesTitle(this.templateStyle) ? Color.Transparent : this.palette().title)
        .letterSpacing(5)
        .textAlign(TextAlign.Center)
        .width('100%')
      Text(getContractDocket(this.datetime, this.docketPrefix()))
        .fontSize(this.fs(10.5))
        .fontFamily(CONTRACT_FONT)
        .fontColor(certificateHidesTitle(this.templateStyle) ? Color.Transparent : this.palette().docket)
        .letterSpacing(0.8)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4 })
      Row() {
        Column()
          .layoutWeight(1)
          .height(1)
          .backgroundColor(this.palette().divider)
          .opacity(0.7)
        Text('❖')
          .fontSize(this.fs(8))
          .fontColor(this.palette().divider)
          .margin({ left: 8, right: 8 })
        Column()
          .layoutWeight(1)
          .height(1)
          .backgroundColor(this.palette().divider)
          .opacity(0.7)
      }
      .width('92%')
      .margin({ top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)
      Column() {
        this.buildClauses()
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
      .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
