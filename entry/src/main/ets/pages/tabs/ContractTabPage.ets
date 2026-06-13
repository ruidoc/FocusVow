import { PlanCollectionPage } from '../../components/plans/PlanCollectionPage';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Component
export struct ContractTabPage {
  build() {
    PlanCollectionPage({
      title: '契约',
      showBack: false
    })
  }
}
