import { AppTheme } from '../../constants/Theme';

class MdBlock {
  kind: string = 'p';
  text: string = '';
}

class MdInline {
  type: string = 'text';
  text: string = '';
  href: string = '';
}

function parseMdBlocks(raw: string): MdBlock[] {
  const lines = raw.replace(/\r\n/g, '\n').split('\n');
  const blocks: MdBlock[] = [];
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed.length === 0) {
      continue;
    }
    const block = new MdBlock();
    if (trimmed.startsWith('### ')) {
      block.kind = 'h3';
      block.text = trimmed.slice(4);
    } else if (trimmed.startsWith('## ')) {
      block.kind = 'h2';
      block.text = trimmed.slice(3);
    } else if (trimmed.startsWith('# ')) {
      block.kind = 'h1';
      block.text = trimmed.slice(2);
    } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('+ ')) {
      block.kind = 'li';
      block.text = trimmed.slice(2);
    } else {
      block.kind = 'p';
      block.text = trimmed;
    }
    blocks.push(block);
  }
  return blocks;
}

function parseMdInline(text: string): MdInline[] {
  const parts: MdInline[] = [];
  const pattern = /\*\*([^*]+)\*\*|\*([^*]+)\*|\[([^\]]+)\]\(([^)]+)\)/g;
  let last = 0;
  let match = pattern.exec(text);
  while (match) {
    if (match.index > last) {
      const plain = new MdInline();
      plain.type = 'text';
      plain.text = text.slice(last, match.index);
      parts.push(plain);
    }
    const part = new MdInline();
    if (match[1] && match[1].length > 0) {
      part.type = 'bold';
      part.text = match[1];
    } else if (match[2] && match[2].length > 0) {
      part.type = 'italic';
      part.text = match[2];
    } else {
      part.type = 'link';
      part.text = match[3] ?? '';
      part.href = match[4] ?? '';
    }
    parts.push(part);
    last = match.index + match[0].length;
    match = pattern.exec(text);
  }
  if (last < text.length) {
    const plain = new MdInline();
    plain.type = 'text';
    plain.text = text.slice(last);
    parts.push(plain);
  }
  if (parts.length === 0) {
    const plain = new MdInline();
    plain.type = 'text';
    plain.text = text;
    parts.push(plain);
  }
  return parts;
}

@Component
export struct MarkdownBody {
  @Prop @Watch('onContentChange') content: string = '';
  onLink: (url: string) => void = (_url: string) => {};
  @State private blocks: MdBlock[] = [];

  aboutToAppear(): void {
    this.blocks = parseMdBlocks(this.content);
  }

  onContentChange(): void {
    this.blocks = parseMdBlocks(this.content);
  }

  private fontSizeOf(kind: string): number {
    if (kind === 'h1') {
      return 20;
    }
    if (kind === 'h2') {
      return 18;
    }
    if (kind === 'h3') {
      return 16;
    }
    return 15;
  }

  @Builder
  private buildBlock(block: MdBlock): void {
    Text() {
      ForEach(parseMdInline(block.text), (part: MdInline, index: number) => {
        Span((block.kind === 'li' && index === 0 ? '• ' : '') + part.text)
          .fontWeight(part.type === 'bold' ? FontWeight.Bold : FontWeight.Regular)
          .fontStyle(part.type === 'italic' ? FontStyle.Italic : FontStyle.Normal)
          .fontColor(part.type === 'link' ? AppTheme.colors.primary : AppTheme.colors.textPrimary)
          .onClick(() => {
            if (part.type === 'link' && part.href.length > 0) {
              this.onLink(part.href);
            }
          })
      }, (part: MdInline, index: number) => `${index}-${part.type}-${part.text}`)
    }
    .fontSize(this.fontSizeOf(block.kind))
    .fontWeight((block.kind === 'h1' || block.kind === 'h2' || block.kind === 'h3') ? FontWeight.Medium : FontWeight.Regular)
    .fontColor(AppTheme.colors.textPrimary)
    .lineHeight(this.fontSizeOf(block.kind) + 8)
    .width('100%')
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.blocks, (block: MdBlock, index: number) => {
        this.buildBlock(block)
      }, (block: MdBlock, index: number) => `${index}-${block.kind}-${block.text}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
