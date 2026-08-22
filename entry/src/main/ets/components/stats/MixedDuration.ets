import { DurationLabelPart } from '../../services/StatsRecordUtil';

/**
 * 数字大、单位小：如 "2 小时 30 分" / "20 分钟" / "1 h 30 m"
 * 用 Span 混排，保证数字与单位底部基线对齐。
 */
@Component
export struct MixedDuration {
  @Prop text: string = '';
  @Prop parts: DurationLabelPart[] = [];
  @Prop color: string = '#111827';
  @Prop numberSize: number = 20;
  @Prop unitSize: number = 11;
  @Prop numberWeight: FontWeight = FontWeight.Bold;

  private getTextParts(): string[] {
    const parts: string[] = [];
    let buffer = '';
    let lastIsDigit = false;
    for (let i = 0; i < this.text.length; i++) {
      const ch = this.text.charAt(i);
      const isDigit = ch >= '0' && ch <= '9';
      if (i === 0) {
        buffer = ch;
        lastIsDigit = isDigit;
        continue;
      }
      if (isDigit === lastIsDigit) {
        buffer += ch;
      } else {
        if (buffer.length > 0) {
          parts.push(buffer);
        }
        buffer = ch;
        lastIsDigit = isDigit;
      }
    }
    if (buffer.length > 0) {
      parts.push(buffer);
    }
    return parts;
  }

  private isNumberPart(part: string): boolean {
    if (part.length === 0) {
      return false;
    }
    for (let i = 0; i < part.length; i++) {
      const ch = part.charAt(i);
      if (ch < '0' || ch > '9') {
        return false;
      }
    }
    return true;
  }

  private getResolvedParts(): DurationLabelPart[] {
    if (this.parts.length > 0) {
      return this.parts;
    }
    const textParts = this.getTextParts();
    const resolved: DurationLabelPart[] = [];
    for (let i = 0; i < textParts.length; i++) {
      const part = textParts[i];
      resolved.push({
        kind: this.isNumberPart(part) ? 'number' : 'unit',
        value: part
      });
    }
    return resolved;
  }

  build() {
    Text() {
      ForEach(this.getResolvedParts(), (part: DurationLabelPart, idx: number) => {
        Span(part.value)
          .fontSize(part.kind === 'number' ? this.numberSize : this.unitSize)
          .fontWeight(part.kind === 'number' ? this.numberWeight : FontWeight.Regular)
          .fontColor(this.color)
      }, (part: DurationLabelPart, idx: number) => `${idx}-${part.kind}-${part.value}`)
    }
  }
}
