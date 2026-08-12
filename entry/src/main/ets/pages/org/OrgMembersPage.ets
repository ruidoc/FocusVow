import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { formatOrgShortMins, OrgMember } from '../../models/OrgModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { OrgStore } from '../../stores/OrgStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct OrgMembersPage {
  @State orgId: string = '';
  @State members: OrgMember[] = [];
  @State query: string = '';
  @State loading: boolean = true;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    this.orgId = String(AppStorage.get<string>(StoreKeys.OrgDetailId) ?? '');
    void this.loadMembers();
  }

  private sortMembers(list: OrgMember[]): OrgMember[] {
    const sorted = [...list];
    sorted.sort((a: OrgMember, b: OrgMember) => {
      if (a.role === 'owner' && b.role !== 'owner') {
        return -1;
      }
      if (a.role !== 'owner' && b.role === 'owner') {
        return 1;
      }
      return 0;
    });
    return sorted;
  }

  private getFilteredMembers(): OrgMember[] {
    const sorted = this.sortMembers(this.members);
    const q = this.query.trim().toLowerCase();
    if (q.length === 0) {
      return sorted;
    }
    const filtered: OrgMember[] = [];
    for (let i = 0; i < sorted.length; i++) {
      if (sorted[i].username.toLowerCase().indexOf(q) >= 0) {
        filtered.push(sorted[i]);
      }
    }
    return filtered;
  }

  private async loadMembers(): Promise<void> {
    if (this.orgId.length === 0) {
      this.loading = false;
      return;
    }
    const cached = OrgStore.getDetail();
    if (cached && cached.id === this.orgId && cached.members.length > 0) {
      this.members = cached.members;
      this.loading = false;
      return;
    }
    this.loading = true;
    const response = await OrgStore.fetchDetail(this.orgId);
    const detail = OrgStore.getDetail();
    if (response.statusCode === 200 && detail) {
      this.members = detail.members;
    } else if (detail && detail.id === this.orgId) {
      this.members = detail.members;
    } else {
      this.members = [];
    }
    this.loading = false;
  }

  @Builder
  private buildMemberRow(member: OrgMember): void {
    Row({ space: 12 }) {
      Image(member.avatar.length > 0 ? member.avatar : $r('app.media.startIcon'))
        .width(40)
        .height(40)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(member.username)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (member.role === 'owner') {
            Text('创建者')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#D97706')
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .backgroundColor('rgba(217,119,6,0.12)')
              .borderRadius(4)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(`今日 ${formatOrgShortMins(member.today_mins)} · 本周 ${formatOrgShortMins(member.week_mins)}`)
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(AppTheme.colors.surface)
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
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List() {
        ForEach(this.getFilteredMembers(), (member: OrgMember) => {
          ListItem() {
            this.buildMemberRow(member)
          }
        }, (member: OrgMember) => member.user_id)
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 1, color: '#0F000000' })
      .edgeEffect(EdgeEffect.None)
    }
  }

  @Builder
  private buildPageBody(): void {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
          .fontColor([AppTheme.colors.textMuted])
        TextInput({ text: this.query, placeholder: '搜索成员' })
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
          .placeholderColor(AppTheme.colors.textMuted)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.query = value;
          })
      }
      .width('100%')
      .height(42)
      .padding({ left: 12, right: 12 })
      .margin({ left: 16, right: 16, bottom: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(12)

      if (!this.loading && this.getFilteredMembers().length === 0) {
        Text(this.query.trim().length > 0 ? '没有匹配的成员' : '暂无成员')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 64 })
      }

      this.buildContent()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '所有成员',
        showBack: true,
        usePageScroll: false,
        onBack: (): void => {
          backRoute();
        },
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
