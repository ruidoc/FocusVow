import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { getNode, hvigor } from '@ohos/hvigor';

function applySigningConfigByBuildMode(): void {
  hvigor.nodesEvaluated(() => {
    const node = getNode(__filename);
    const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
    const buildMode = appContext.getBuildMode();
    const signingConfig = buildMode === 'release' ? 'release' : 'debug';
    const profileOpt = appContext.getBuildProfileOpt();
    const products = profileOpt?.app?.products;
    if (!Array.isArray(products)) {
      return;
    }
    products.forEach((product: { signingConfig?: string }) => {
      product.signingConfig = signingConfig;
    });
    appContext.setBuildProfileOpt(profileOpt);
    console.log(`[FocusVow] buildMode=${buildMode}, signingConfig=${signingConfig}`);
  });
}

applySigningConfigByBuildMode();

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}