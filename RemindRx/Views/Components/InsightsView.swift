import SwiftUI
import Charts // If using iOS 16+

struct InsightsView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedTab = 0
    @State private var refreshTrigger = UUID() // To force refresh when needed
    
    private let tabTitles = ["Overview", "Expiration", "Shopping List"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab selector
            HStack(spacing: 0) {
                ForEach(0..<tabTitles.count, id: \.self) { index in
                    Button(action: {
                        withAnimation {
                            selectedTab = index
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(tabTitles[index])
                                .font(.headline)
                                .fontWeight(selectedTab == index ? .bold : .regular)
                                .foregroundColor(selectedTab == index ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == index ? AppColors.primaryFallback() : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Overview Tab - Charts and Safety
                OverviewTabView()
                    .tag(0)
                
                // Expiration Tab - Calendar view
                ExpirationCalendarView()
                    .tag(1)
                
                // Shopping List Tab
                ShoppingListView()
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Insights")
        .onAppear {
            medicineStore.loadMedicines()
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MedicineDataChanged"))) { _ in
            refreshTrigger = UUID()
        }
    }
}

// Placeholder views that we'll implement one by one
struct OverviewTabView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Safety rating card
                SafetyRatingCard()
                
                // Medicine category breakdown
                MedicineCategoryChart()
                
                // Manufacturer distribution
                ManufacturerDistributionChart()
            }
            .padding()
        }
    }
}
