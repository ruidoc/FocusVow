import { PlanCollectionPage } from '../../components/plans/PlanCollectionPage';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct PlanListPage {
  build() {
    Stack() {
      PlanCollectionPage({
        title: '契约列表',
        showBack: true
      })
    }
    .width('100%')
    .height('100%')
  }
}
