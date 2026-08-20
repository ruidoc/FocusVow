import { common } from '@kit.AbilityKit';
import { CustomContentDialog } from '@kit.ArkUI';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { UsersIcon } from '../../components/common/UsersIcon';
import { AppTheme } from '../../constants/Theme';
import { isOrgClassroomJoinable, ORG_DEFAULT_INTRO, ORG_DEFAULT_THEME, OrgListItem } from '../../models/OrgModel';
import { PageRoutes, backRoute, pushOrgClassroomCreate, pushRoute } from '../../router/PageRoutes';
import { OrgStore } from '../../stores/OrgStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const THEME_PRESETS: string[] = [
  '#3D6B8C',
  '#2F6F5E',
  '#6B4F8C',
  '#8B5A3C',
  '#3B6B6B',
  '#5C4A8A',
  '#7A4E5C',
  '#2E5A7A',
  '#4A6B3D',
  '#8C5E3A'
];

@Entry
@Component
struct OrgManagePage {
  @State loading: boolean = true;
  @State saving: boolean = false;
  @State org: OrgListItem | null = null;
  @State nameDraft: string = '';
  @State introDraft: string = '';
  @State classroomActive: boolean = false;

  private nameDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: '组织名称',
      contentBuilder: (): void => {
        this.buildNameInput();
      },
      buttons: [
        {
          value: '取消',
          action: (): void => {
            this.nameDialogController.close();
          }
        },
        {
          value: '保存',
          action: (): void => {
            void this.confirmName();
          }
        }
      ]
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  private introDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: '组织介绍',
      contentBuilder: (): void => {
        this.buildIntroInput();
      },
      buttons: [
        {
          value: '取消',
          action: (): void => {
            this.introDialogController.close();
          }
        },
        {
          value: '保存',
          action: (): void => {
            void this.confirmIntro();
          }
        }
      ]
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false
  });

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    void this.loadOwnedOrg();
  }

  aboutToDisappear(): void {
    this.nameDialogController.close();
    this.introDialogController.close();
  }

  private async loadOwnedOrg(): Promise<void> {
    this.loading = true;
    await OrgStore.listMine();
    const owned = OrgStore.findOwnedOrg();
    this.org = owned;
    this.loading = false;
    if (!owned) {
      showToast('仅组织创建者可管理', this.getUIContext());
      backRoute();
      return;
    }
    const active = await OrgStore.getActiveClassroom(owned.id);
    this.classroomActive = isOrgClassroomJoinable(active);
  }

  private getThemeColor(): string {
    if (this.org && this.org.theme_color.length > 0) {
      return this.org.theme_color;
    }
    return ORG_DEFAULT_THEME;
  }

  private getIntroText(): string {
    if (this.org && this.org.intro.trim().length > 0) {
      return this.org.intro.trim();
    }
    return ORG_DEFAULT_INTRO;
  }

  private async patchOrg(body: Record<string, Object>): Promise<boolean> {
    if (!this.org) {
      return false;
    }
    this.saving = true;
    const response = await OrgStore.patchOrg(this.org.id, body);
    this.saving = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '保存失败', this.getUIContext());
      return false;
    }
    const owned = OrgStore.findOwnedOrg();
    if (owned) {
      this.org = owned;
    }
    return true;
  }

  private openNameDialog(): void {
    if (!this.org || this.saving) {
      return;
    }
    this.nameDraft = this.org.name;
    this.nameDialogController.open();
  }

  private openIntroDialog(): void {
    if (!this.org || this.saving) {
      return;
    }
    this.introDraft = this.org.intro;
    this.introDialogController.open();
  }

  private async confirmName(): Promise<void> {
    const name = this.nameDraft.trim();
    if (name.length === 0) {
      showToast('请输入组织名称', this.getUIContext());
      return;
    }
    this.nameDialogController.close();
    const ok = await this.patchOrg({ 'name': name });
    if (ok) {
      showToast('名称已更新', this.getUIContext());
    }
  }

  private async confirmIntro(): Promise<void> {
    this.introDialogController.close();
    const ok = await this.patchOrg({ 'intro': this.introDraft.trim() });
    if (ok) {
      showToast('介绍已更新', this.getUIContext());
    }
  }

  private async onPickTheme(color: string): Promise<void> {
    if (!this.org || this.saving) {
      return;
    }
    if (color.toUpperCase() === this.getThemeColor().toUpperCase()) {
      return;
    }
    const ok = await this.patchOrg({ 'theme_color': color });
    if (ok) {
      showToast('主题色已更新', this.getUIContext());
    }
  }

  @Builder
  private buildNameInput(): void {
    TextInput({ text: this.nameDraft, placeholder: '输入组织名称' })
      .width('100%')
      .fontSize(16)
      .fontColor(AppTheme.colors.textPrimary)
      .placeholderColor(AppTheme.colors.textMuted)
      .onChange((value: string) => {
        this.nameDraft = value;
      })
  }

  @Builder
  private buildIntroInput(): void {
    TextArea({ text: this.introDraft, placeholder: '介绍一下你们的组织' })
      .width('100%')
      .height(100)
      .fontSize(16)
      .fontColor(AppTheme.colors.textPrimary)
      .placeholderColor(AppTheme.colors.textMuted)
      .onChange((value: string) => {
        this.introDraft = value;
      })
  }

  @Builder
  private buildFieldRow(title: string, value: string, onPress: () => void, showDivider: boolean): void {
    Column({ space: 0 }) {
      Button() {
        Row() {
          Text(title)
            .fontSize(15)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)
          Text(value)
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '55%' })
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([AppTheme.colors.textMuted])
            .margin({ left: 6 })
        }
        .width('100%')
        .height(52)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        onPress();
      })

      if (showDivider) {
        Divider()
          .color('#EEF1F6')
          .strokeWidth(1)
          .margin({ left: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  private buildManageContent(): void {
    if (this.loading || !this.org) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .padding({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else {
      Column({ space: 16 }) {
        Column() {
          Row({ space: 12 }) {
            if (this.org.avatar.length > 0) {
              Image(this.org.avatar)
                .width(44)
                .height(44)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
            } else {
              Row() {
                UsersIcon({ iconSize: 22, color: '#FFFFFF' })
              }
              .width(44)
              .height(44)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('rgba(255,255,255,0.18)')
              .borderRadius(12)
            }

            Column({ space: 4 }) {
              Text(this.org.name)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text(this.getIntroText())
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.78)')
                .maxLines(2)
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.getThemeColor())
        .borderRadius(16)

        Column({ space: 0 }) {
          this.buildFieldRow('组织名称', this.org.name, (): void => {
            this.openNameDialog();
          }, true)
          this.buildFieldRow(
            '组织介绍',
            this.org.intro.length > 0 ? this.org.intro : '未设置',
            (): void => {
              this.openIntroDialog();
            },
            true
          )
          this.buildFieldRow(
            '组织课堂',
            this.classroomActive ? '进行中' : '发起',
            (): void => {
              pushOrgClassroomCreate();
            },
            false
          )
        }
        .width('100%')
        .backgroundColor(AppTheme.colors.surface)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(12)
        .clip(true)

        Column({ space: 12 }) {
          Text('主题色')
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
            .margin({ left: 4 })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(THEME_PRESETS, (color: string) => {
              Button({ type: ButtonType.Normal }) {
                if (this.getThemeColor().toUpperCase() === color.toUpperCase()) {
                  SymbolGlyph($r('sys.symbol.checkmark'))
                    .fontSize(16)
                    .fontColor([Color.White])
                }
              }
              .width(36)
              .height(36)
              .margin({ right: 12, bottom: 12 })
              .backgroundColor(color)
              .borderRadius(18)
              .border({
                width: this.getThemeColor().toUpperCase() === color.toUpperCase() ? 2 : 0,
                color: AppTheme.colors.textPrimary
              })
              .enabled(!this.saving)
              .onClick(() => {
                void this.onPickTheme(color);
              })
            }, (color: string) => color)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.colors.surface)
          .borderRadius(12)
        }
        .width('100%')

        if (this.saving) {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(AppTheme.colors.primary)
            .margin({ top: 8 })
        }
      }
      .width('100%')
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '组织管理',
        showBack: true,
        onBack: (): void => {
          backRoute();
        },
        content: (): void => {
          this.buildManageContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
