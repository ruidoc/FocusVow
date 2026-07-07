import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { UIContext } from '@kit.ArkUI';
import { DuoSessionView } from '../models/DuoModel';
import { PageRoutes, pushRoute } from '../router/PageRoutes';
import { DuoApiService } from './DuoApiService';
import { UserStore } from '../stores/UserStore';

const DUO_JOIN_TOKEN_KEY: string = 'duo.join.token';
let dismissedToken: string = '';
let suppressedToken: string = '';

export function extractDuoInviteToken(raw: string): string {
  const match = /\$([^$]+)\$/.exec(raw);
  return match ? match[1].trim() : raw.trim();
}

export function isFocusInviteClipboardText(raw: string): boolean {
  const text = raw.trim();
  if (text.length === 0) {
    return false;
  }
  if (text.includes('【专注契约】')) {
    return true;
  }
  return text.includes('重载口令') && /\$[^$]+\$/.test(text) ||
    text.includes('复制口令') && /\$[^$]+\$/.test(text);
}

function buildInviteDialogMessage(session: DuoSessionView): string {
  const initiatorName = session.initiator?.nickname ?? '好友';
  const durationLabel = session.type === 'scheduled'
    ? '定时契约 · 到点一起履约'
    : `时长 ${session.duration_min} 分钟 · 白名单模式`;
  return `「${session.title}」\n${durationLabel}\n发起人：${initiatorName}\n\n确认后将选择要限制的应用并加入契约。`;
}

export class DuoInviteClipboardService {
  static stashJoinToken(token: string): void {
    AppStorage.setOrCreate(DUO_JOIN_TOKEN_KEY, token);
  }

  static consumeJoinToken(): string {
    const token = String(AppStorage.get<string>(DUO_JOIN_TOKEN_KEY) ?? '');
    if (token.length > 0) {
      AppStorage.setOrCreate(DUO_JOIN_TOKEN_KEY, '');
    }
    return token;
  }

  static clearJoinFlow(): void {
    AppStorage.setOrCreate(DUO_JOIN_TOKEN_KEY, '');
  }

  static dismissToken(token: string): void {
    if (token.length === 0) {
      return;
    }
    dismissedToken = token;
    suppressedToken = token;
  }

  static async clearInviteClipboard(): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const data = await systemPasteboard.getData();
      const text = data.getPrimaryText() ?? '';
      if (!isFocusInviteClipboardText(text)) {
        return;
      }
      const emptyData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, '');
      await systemPasteboard.setData(emptyData);
    } catch (error) {
      console.warn(`clear invite clipboard failed: ${String(error)}`);
    }
  }

  private static isOwnInvite(session: DuoSessionView, myUserId: string): boolean {
    if (myUserId.length === 0) {
      return false;
    }
    if (session.viewer_role === 'initiator') {
      return true;
    }
    return session.initiator?.id === myUserId;
  }

  static async probeClipboard(
    context: common.UIAbilityContext,
    uiContext: UIContext
  ): Promise<void> {
    UserStore.hydrate(context);
    if (!UserStore.isLoggedIn()) {
      return;
    }

    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const data = await systemPasteboard.getData();
      const text = data.getPrimaryText() ?? '';
      if (!isFocusInviteClipboardText(text)) {
        return;
      }

      const token = extractDuoInviteToken(text);
      if (token.length === 0 || token === dismissedToken || token === suppressedToken) {
        return;
      }

      const response = await DuoApiService.getByToken(token);
      const session = DuoApiService.parseSession(response);
      if (!session) {
        const message = response.message ?? '';
        if (
          message.includes('自己发起') ||
          message.includes('不能加入') ||
          message.includes('已有其他搭子') ||
          message.includes('邀请已过期') ||
          message.includes('邀请已取消') ||
          message.includes('不可加入') ||
          message.includes('无法加入')
        ) {
          DuoInviteClipboardService.dismissToken(token);
          await DuoInviteClipboardService.clearInviteClipboard();
        }
        return;
      }

      const myUserId = UserStore.getUserInfo().id;
      if (DuoInviteClipboardService.isOwnInvite(session, myUserId)) {
        DuoInviteClipboardService.dismissToken(token);
        await DuoInviteClipboardService.clearInviteClipboard();
        return;
      }

      if (
        session.viewer_role === 'partner' ||
        session.status === 'active'
      ) {
        DuoInviteClipboardService.dismissToken(token);
        await DuoInviteClipboardService.clearInviteClipboard();
        return;
      }

      if (session.status === 'expired' || session.status === 'cancelled') {
        DuoInviteClipboardService.dismissToken(token);
        return;
      }

      suppressedToken = token;
      uiContext.showAlertDialog({
        title: '发现搭子契约邀请',
        message: buildInviteDialogMessage(session),
        autoCancel: true,
        primaryButton: {
          value: '加入契约',
          action: () => {
            DuoInviteClipboardService.stashJoinToken(token);
            DuoInviteClipboardService.dismissToken(token);
            pushRoute(PageRoutes.DuoJoin);
          }
        },
        secondaryButton: {
          value: '暂不',
          action: () => {
            DuoInviteClipboardService.dismissToken(token);
          }
        }
      });
    } catch (error) {
      console.warn(`clipboard invite probe failed: ${String(error)}`);
    }
  }
}
