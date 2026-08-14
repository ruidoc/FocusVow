export interface InboxItem {
  id: string;
  title: string;
  subtitle: string;
  body: string;
  link: string;
  kind: string;
  created_at: string;
  read: boolean;
}

function asString(value: Object | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  return String(value);
}

function asBool(value: Object | undefined): boolean {
  return value === true || value === 'true' || value === 1 || value === '1';
}

export function createEmptyInboxItem(): InboxItem {
  return {
    id: '',
    title: '',
    subtitle: '',
    body: '',
    link: '',
    kind: 'normal',
    created_at: '',
    read: true
  };
}

export function parseInboxItem(raw: Record<string, Object>): InboxItem {
  const kind = asString(raw['kind']);
  return {
    id: asString(raw['id']),
    title: asString(raw['title']),
    subtitle: asString(raw['subtitle']),
    body: asString(raw['body']),
    link: asString(raw['link']),
    kind: kind === 'important' ? 'important' : 'normal',
    created_at: asString(raw['created_at']),
    read: asBool(raw['read'])
  };
}

export function parseInboxItems(raw: Object | undefined): InboxItem[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const list = raw as Object[];
  const items: InboxItem[] = [];
  for (let i = 0; i < list.length; i++) {
    const row = list[i];
    if (row && typeof row === 'object') {
      items.push(parseInboxItem(row as Record<string, Object>));
    }
  }
  return items;
}

export function formatInboxTime(raw: string): string {
  if (raw.length === 0) {
    return '';
  }
  return raw.replace('T', ' ').slice(0, 16);
}

export function isImportantInbox(item: InboxItem): boolean {
  return item.kind === 'important';
}

export function inboxBadgeLabel(count: number): string {
  if (count > 99) {
    return '99';
  }
  return `${count}`;
}
