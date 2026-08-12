/**
 * 登录/注册主按钮未勾选协议时的二次确认（对齐 RN confirmPrivacyAgreementForAuth）。
 * 同意后由调用方勾选并继续。
 */
export function confirmPrivacyAgreementForAuth(uiContext: UIContext): Promise<boolean> {
  return new Promise<boolean>((resolve: (accepted: boolean) => void) => {
    uiContext.showAlertDialog({
      title: '阅读隐私政策',
      message: '请阅读并同意《隐私政策》后继续',
      autoCancel: false,
      primaryButton: {
        value: '同意并继续',
        action: () => {
          resolve(true);
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
          resolve(false);
        }
      }
    });
  });
}
