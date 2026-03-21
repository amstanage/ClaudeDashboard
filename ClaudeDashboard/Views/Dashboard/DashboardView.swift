import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                UsageHeatmapView(data: viewModel.heatmapData, maxTokens: viewModel.maxDailyTokens)
                HStack(spacing: 16) {
                    WeeklyChartView(data: viewModel.weeklyData)
                    MonthlyTrendView(data: viewModel.monthlyData)
                }
                ModelUsageView(data: viewModel.modelBreakdown, period: Binding(
                    get: { viewModel.modelPeriod },
                    set: { newValue in viewModel.modelPeriod = newValue; Task { await viewModel.loadModelBreakdown() } }
                ))
            }
            .padding(16)
        }
        .task {
            if let db = appViewModel.database { viewModel.configure(database: db) }
            await viewModel.loadAll()
        }
    }
}
