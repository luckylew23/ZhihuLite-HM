import { DetailActionBar } from '../components/detail/DetailActionBar';

@Entry
@Component
struct TestActionBarPage {
  @State upCount: number = 12;
  @State ccCount: number = 3;
  @State collected: boolean = false;

  build() {
    Column() {
      Scroll() {
        Column() {
          Text('test')
        }
      }
      .layoutWeight(1)

      DetailActionBar({
        upvoteCount: this.upCount,
        commentCount: this.ccCount,
        collected: this.collected,
        onComment: () => this.onComment(),
        onSave: () => this.saveContent(),
      })
    }
    .width('100%')
    .height('100%')
  }

  private onComment(): void {}
  private saveContent(): void {}
}
