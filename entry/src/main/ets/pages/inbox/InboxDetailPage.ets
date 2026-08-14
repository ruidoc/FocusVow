import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppActionButton } from '../../components/common/AppActionButton';
import { MarkdownBody } from '../../components/inbox/MarkdownBody';
import { AppTheme } from '../../constants/Theme';
import { InboxItem, createEmptyInboxItem } from '../../models/InboxModel';
import { backToHome, pushLogin, pushWebView } from '../../router/PageRoutes';
import { InboxStore } from '../../stores/InboxStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct InboxDetailPage {
  @StorageLink(StoreKeys.InboxDetailId) detailId: string = '';
  @State item: InboxItem = createEmptyInboxItem();
  @State loading: boolean = true;
  @State missing: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushLogin();
      return;
    }
    void this.loadDetail();
  }

  private async loadDetail(): Promise<void> {
    const id = this.detailId;
    if (id.length === 0) {
      this.loading = false;
      this.missing = true;
      return;
    }
    this.loading = true;
    const next = await InboxStore.fetchOne(id);
    this.loading = false;
    if (!next) {
      this.missing = true;
      return;
    }
    this.item = next;
    this.missing = false;
    if (!next.read) {
      void InboxStore.markRead(next.id);
    }
  }

  private openLink(url: string): void {
    if (url.length === 0) {
      return;
    }
    pushWebView(url, '详情');
  }

  @Builder
  private buildContent(): void {
    if (this.loading) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .padding({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else if (this.missing) {
      Text('消息不存在')
        .fontSize(15)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 80 })
    } else {
      Column({ space: 16 }) {
        Text(this.item.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
        MarkdownBody({
          content: this.item.body,
          onLink: (url: string) => {
            this.openLink(url);
          }
        })
        if (this.item.link.length > 0) {
          AppActionButton({
            label: '查看详情',
            onPress: () => {
              this.openLink(this.item.link);
            }
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.item.title.length > 0 ? this.item.title : '消息详情',
        showBack: true,
        onBack: (): void => {
          backToHome();
        },
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
