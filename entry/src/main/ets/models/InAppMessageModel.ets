export interface InAppMessageView {
  id: string;
  title: string;
  message: string;
  type: string;
  visible: boolean;
}

export function createHiddenInAppMessage(): InAppMessageView {
  return {
    id: '',
    title: '',
    message: '',
    type: '',
    visible: false
  };
}
