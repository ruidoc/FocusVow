import { PlanCollectionPage } from '../../components/plans/PlanCollectionPage';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Component
export struct ContractTabPage {
  @Prop isPageActive: boolean = true;

  build() {
    PlanCollectionPage({
      title: '定时契约',
      showBack: false,
      isPageActive: this.isPageActive
    })
  }
}
