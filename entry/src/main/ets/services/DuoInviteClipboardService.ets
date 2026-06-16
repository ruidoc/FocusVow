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
  return text.includes('重载口令') && /\$[^$]+\$/.test(text);
}

function buildInviteDialogMessage(session: DuoSessionView): string {
  const initiatorName = session.initiator?.nickname ?? '好友';
  return `「${session.title}」\n时长 ${session.duration_min} 分钟 · 白名单模式\n发起人：${initiatorName}\n\n确认后将选择要限制的应用并加入契约。`;
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
    suppressedToken = '';
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
      if (!session || session.status === 'expired' || session.status === 'cancelled') {
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
            pushRoute(PageRoutes.DuoJoin);
          }
        },
        secondaryButton: {
          value: '暂不',
          action: () => {
            dismissedToken = token;
            suppressedToken = '';
          }
        }
      });
    } catch (error) {
      console.warn(`clipboard invite probe failed: ${String(error)}`);
    }
  }
}
