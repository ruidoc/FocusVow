import { TasksCollectionPage } from '../../components/plans/TasksCollectionPage';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct PlanListPage {
  build() {
    Stack() {
      TasksCollectionPage({
        showBack: true,
        isPageActive: true
      })
    }
    .width('100%')
    .height('100%')
  }
}
