import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { showErrorToast, showToast } from '../common/Toast';
import { DuoInviteClipboardService, extractDuoInviteToken } from './DuoInviteClipboardService';

export async function copyDuoInviteText(
  uiContext: UIContext,
  text: string
): Promise<void> {
  if (text.length === 0) {
    return;
  }
  const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
  const systemPasteboard = pasteboard.getSystemPasteboard();
  await systemPasteboard.setData(pasteData);
  DuoInviteClipboardService.dismissToken(extractDuoInviteToken(text));
  showToast('口令已复制', uiContext);
}

export async function shareDuoInviteText(
  context: common.UIAbilityContext,
  uiContext: UIContext,
  text: string
): Promise<void> {
  if (text.length === 0) {
    return;
  }
  DuoInviteClipboardService.dismissToken(extractDuoInviteToken(text));
  try {
    const preview = text.length > 120 ? `${text.substring(0, 120)}...` : text;
    const shareData = new systemShare.SharedData({
      utd: utd.UniformDataType.PLAIN_TEXT,
      content: text,
      title: '搭子互督邀请',
      description: preview
    });
    const controller = new systemShare.ShareController(shareData);
    await controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DETAIL
    });
  } catch (error) {
    showErrorToast(formatDuoInviteShareError(error as BusinessError), uiContext);
  }
}

export function formatDuoInviteShareError(error: BusinessError): string {
  if (error.message && error.message.length > 0) {
    return `分享失败：${error.message}`;
  }
  return `分享失败（${error.code}）`;
}
