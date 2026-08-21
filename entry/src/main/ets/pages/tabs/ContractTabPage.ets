import { TasksCollectionPage } from '../../components/plans/TasksCollectionPage';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Component
export struct ContractTabPage {
  @Prop isPageActive: boolean = true;

  build() {
    TasksCollectionPage({
      showBack: false,
      isPageActive: this.isPageActive
    })
  }
}
