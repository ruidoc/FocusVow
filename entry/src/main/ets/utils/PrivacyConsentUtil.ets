/**
 * 登录/注册主按钮未勾选协议时的二次确认（对齐 RN confirmPrivacyAgreementForAuth）。
 * 同意后由调用方勾选并继续。
 */
export function confirmPrivacyAgreementForAuth(uiContext: UIContext): Promise<boolean> {
  return new Promise<boolean>((resolve: (accepted: boolean) => void) => {
    uiContext.showAlertDialog({
      title: '阅读隐私政策',
      message: '请阅读并同意《隐私政策》后继续（可点页面下方链接查看）',
      autoCancel: false,
      primaryButton: {
        value: '取消',
        action: () => {
          resolve(false);
        }
      },
      secondaryButton: {
        value: '同意并继续',
        action: () => {
          resolve(true);
        }
      }
    });
  });
}

/** Paywall 未勾选《付费服务协议》时的二次确认（对齐 RN Alert） */
export function confirmPaidServiceAgreement(uiContext: UIContext): Promise<boolean> {
  return new Promise<boolean>((resolve: (accepted: boolean) => void) => {
    uiContext.showAlertDialog({
      title: '会员付费服务协议',
      message: '已阅读并同意会员付费服务协议',
      autoCancel: false,
      primaryButton: {
        value: '取消',
        action: () => {
          resolve(false);
        }
      },
      secondaryButton: {
        value: '同意',
        action: () => {
          resolve(true);
        }
      }
    });
  });
}
