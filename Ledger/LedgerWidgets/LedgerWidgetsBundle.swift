import WidgetKit
import SwiftUI

@main
struct LedgerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SafeToSpendWidget()
        BucketsWidget()
        SavingsGoalWidget()
    }
}
