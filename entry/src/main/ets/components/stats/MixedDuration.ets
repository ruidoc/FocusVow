/**
 * 数字大、单位小：如 "2 小时 30 分" / "20 分钟" / "3 天"
 * 用 Span 混排，保证数字与单位底部基线对齐。
 */
@Component
export struct MixedDuration {
  @Prop text: string = '';
  @Prop color: string = '#111827';
  @Prop numberSize: number = 20;
  @Prop unitSize: number = 11;
  @Prop numberWeight: FontWeight = FontWeight.Bold;

  private getParts(): string[] {
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

  build() {
    Text() {
      ForEach(this.getParts(), (part: string, idx: number) => {
        Span(part)
          .fontSize(this.isNumberPart(part) ? this.numberSize : this.unitSize)
          .fontWeight(this.isNumberPart(part) ? this.numberWeight : FontWeight.Regular)
          .fontColor(this.color)
      }, (part: string, idx: number) => `${idx}-${part}`)
    }
  }
}
