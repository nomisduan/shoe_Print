# iOS Widget Integration

## 🎯 Feature Overview

Modern iOS widgets that provide at-a-glance shoe information and quick selection capabilities directly from the home screen and lock screen, showcasing advanced WidgetKit development expertise.

## 💡 Value Proposition

### User Benefits
- **Quick Access**: Instant shoe selection without opening the app
- **Glanceable Information**: Current shoe status and daily stats at a glance
- **Smart Suggestions**: Context-aware shoe recommendations
- **Seamless Integration**: Native iOS widget experience

### Portfolio Benefits
- **WidgetKit Mastery**: Modern iOS widget development skills
- **Timeline Management**: Dynamic content updates and scheduling
- **Design Excellence**: Beautiful, functional widget interfaces
- **Deep Linking**: Seamless app integration and navigation

## 🏗️ Widget Architecture

### Widget Extension Structure
```swift
ShoePrintWidgets/
├── Widgets/
│   ├── QuickSelectionWidget.swift
│   ├── DailyStatsWidget.swift
│   ├── ShoeStatusWidget.swift
│   └── SmartSuggestionsWidget.swift
├── Views/
│   ├── ShoeWidgetView.swift
│   ├── StatsWidgetView.swift
│   └── SelectionWidgetView.swift
├── Providers/
│   ├── ShoeTimelineProvider.swift
│   ├── StatsTimelineProvider.swift
│   └── SuggestionsTimelineProvider.swift
├── Models/
│   ├── WidgetShoe.swift
│   ├── WidgetStats.swift
│   └── WidgetEntry.swift
└── Intents/
    ├── ShoeSelectionIntent.swift
    └── ConfigurationIntent.swift
```

## 📱 Widget Types & Sizes

### 1. Quick Selection Widget (Small)
```swift
struct QuickSelectionWidget: Widget {
    let kind: String = "QuickSelection"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickSelectionProvider()) { entry in
            QuickSelectionView(entry: entry)
        }
        .configurationDisplayName("Quick Shoe Selection")
        .description("Quickly select and switch between your shoes")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickSelectionView: View {
    var entry: QuickSelectionEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Current shoe display
            if let currentShoe = entry.currentShoe {
                VStack(spacing: 4) {
                    Text(currentShoe.icon)
                        .font(.system(size: 32))
                    Text(currentShoe.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "shoe.2")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("Select Shoes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick stats
            if let stats = entry.todayStats {
                HStack(spacing: 12) {
                    StatItem(value: "\(stats.steps)", label: "steps")
                    StatItem(value: stats.distanceFormatted, label: "km")
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
            }
        }
        .padding(12)
        .widgetURL(URL(string: "shoeprint://quickSelect"))
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}
```

### 2. Daily Stats Widget (Medium)
```swift
struct DailyStatsWidget: Widget {
    let kind: String = "DailyStats"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyStatsProvider()) { entry in
            DailyStatsView(entry: entry)
        }
        .configurationDisplayName("Daily Activity Stats")
        .description("View your daily walking statistics and shoe usage")
        .supportedFamilies([.systemMedium])
    }
}

struct DailyStatsView: View {
    var entry: DailyStatsEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Current shoe section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current Shoe")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                if let shoe = entry.currentShoe {
                    HStack(spacing: 8) {
                        Text(shoe.icon)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shoe.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Active for \(shoe.sessionDuration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No active shoe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Stats section
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Activity")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 6) {
                    StatRow(
                        icon: "figure.walk",
                        value: "\(entry.stats.steps)",
                        label: "Steps"
                    )
                    
                    StatRow(
                        icon: "location",
                        value: entry.stats.distanceFormatted,
                        label: "Distance"
                    )
                    
                    StatRow(
                        icon: "clock",
                        value: entry.stats.activeTimeFormatted,
                        label: "Active Time"
                    )
                }
            }
        }
        .padding(16)
        .widgetURL(URL(string: "shoeprint://dashboard"))
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}
```

### 3. Smart Suggestions Widget (Large)
```swift
struct SmartSuggestionsWidget: Widget {
    let kind: String = "SmartSuggestions"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SmartSuggestionsProvider()) { entry in
            SmartSuggestionsView(entry: entry)
        }
        .configurationDisplayName("Smart Shoe Suggestions")
        .description("AI-powered shoe recommendations based on your activity patterns")
        .supportedFamilies([.systemLarge])
    }
}

struct SmartSuggestionsView: View {
    var entry: SmartSuggestionsEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Suggestions")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Based on your activity patterns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Suggestions grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(entry.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
            
            // Weekly insights
            if let insight = entry.weeklyInsight {
                WeeklyInsightCard(insight: insight)
            }
        }
        .padding(16)
        .widgetURL(URL(string: "shoeprint://suggestions"))
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

struct SuggestionCard: View {
    let suggestion: ShoeSuggestion
    
    var body: some View {
        VStack(spacing: 8) {
            Text(suggestion.shoe.icon)
                .font(.title)
            
            Text(suggestion.shoe.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(suggestion.reason)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text("\(Int(suggestion.confidence * 100))% match")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .widgetURL(URL(string: "shoeprint://selectShoe/\(suggestion.shoe.id)"))
    }
}
```

## ⏰ Timeline Management

### Dynamic Content Updates
```swift
struct ShoeTimelineProvider: TimelineProvider {
    typealias Entry = ShoeWidgetEntry
    
    func placeholder(in context: Context) -> ShoeWidgetEntry {
        ShoeWidgetEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ShoeWidgetEntry) -> ()) {
        let entry = createCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoeWidgetEntry>) -> ()) {
        let currentDate = Date()
        var entries: [ShoeWidgetEntry] = []
        
        // Current entry
        entries.append(createCurrentEntry())
        
        // Schedule updates based on context
        let updateSchedule = determineUpdateSchedule()
        
        for (index, updateTime) in updateSchedule.enumerated() {
            let entry = createEntryForTime(updateTime)
            entries.append(entry)
        }
        
        let nextUpdate = calculateNextUpdate()
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func determineUpdateSchedule() -> [Date] {
        var schedule: [Date] = []
        let now = Date()
        
        // Morning suggestions (7 AM)
        if let morningTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: now) {
            if morningTime > now {
                schedule.append(morningTime)
            }
        }
        
        // Lunch time update (12 PM)
        if let lunchTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) {
            if lunchTime > now {
                schedule.append(lunchTime)
            }
        }
        
        // Evening update (6 PM)
        if let eveningTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: now) {
            if eveningTime > now {
                schedule.append(eveningTime)
            }
        }
        
        return schedule
    }
}
```

### Intelligent Update Strategy
```swift
class WidgetUpdateManager {
    
    func scheduleIntelligentUpdates() {
        // Update immediately on significant events
        scheduleImmediateUpdates()
        
        // Schedule periodic updates based on user patterns
        schedulePeriodicUpdates()
        
        // Schedule context-aware updates
        scheduleContextualUpdates()
    }
    
    private func scheduleImmediateUpdates() {
        // Update when shoe selection changes
        NotificationCenter.default.addObserver(forName: .shoeSelectionChanged, object: nil, queue: .main) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        // Update when session starts/ends
        NotificationCenter.default.addObserver(forName: .sessionStateChanged, object: nil, queue: .main) { _ in
            WidgetCenter.shared.reloadTimelines(ofKind: "QuickSelection")
        }
    }
    
    private func schedulePeriodicUpdates() {
        // Morning refresh for new day
        let morningRefresh = BGAppRefreshTaskRequest(identifier: "com.shoeprint.morning-widget-refresh")
        morningRefresh.earliestBeginDate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 6, minute: 0),
            matchingPolicy: .nextTime
        )
        
        try? BGTaskScheduler.shared.submit(morningRefresh)
    }
    
    private func scheduleContextualUpdates() {
        // Update based on location changes (home, work, gym)
        LocationManager.shared.onSignificantLocationChange { location in
            if let context = LocationContextAnalyzer.analyzeLocation(location) {
                self.updateWidgetsForContext(context)
            }
        }
        
        // Update based on calendar events
        CalendarEventMonitor.shared.onUpcomingEvent { event in
            if let shoeRecommendation = self.getShoeRecommendation(for: event) {
                self.updateSuggestionWidgets(with: shoeRecommendation)
            }
        }
    }
}
```

## 🔗 Deep Linking Integration

### URL Scheme Handling
```swift
class WidgetDeepLinkHandler {
    
    enum WidgetAction {
        case quickSelect
        case selectShoe(String)
        case openDashboard
        case openSuggestions
        case startSession
        case endSession
    }
    
    func handleWidgetURL(_ url: URL) -> WidgetAction? {
        guard url.scheme == "shoeprint" else { return nil }
        
        switch url.host {
        case "quickSelect":
            return .quickSelect
        case "selectShoe":
            if let shoeId = url.pathComponents.last {
                return .selectShoe(shoeId)
            }
        case "dashboard":
            return .openDashboard
        case "suggestions":
            return .openSuggestions
        case "startSession":
            return .startSession
        case "endSession":
            return .endSession
        default:
            return nil
        }
        
        return nil
    }
    
    func executeAction(_ action: WidgetAction) {
        switch action {
        case .quickSelect:
            presentQuickSelection()
        case .selectShoe(let shoeId):
            selectShoe(withId: shoeId)
        case .openDashboard:
            navigateToDashboard()
        case .openSuggestions:
            presentSuggestions()
        case .startSession:
            startCurrentSession()
        case .endSession:
            endCurrentSession()
        }
    }
}
```

### Intent-based Configuration
```swift
import Intents

class ShoeSelectionIntentHandler: NSObject, ShoeSelectionIntentHandling {
    
    func provideShoeOptionsCollection(for intent: ShoeSelectionIntent, with completion: @escaping (INObjectCollection<ShoeOption>?, Error?) -> Void) {
        
        let shoeService = DIContainer.shared.resolve(ShoeService.self)
        
        Task {
            do {
                let shoes = try await shoeService.getActiveShoes()
                let shoeOptions = shoes.map { shoe in
                    ShoeOption(
                        identifier: shoe.id.uuidString,
                        display: "\(shoe.icon) \(shoe.brand) \(shoe.model)"
                    )
                }
                
                let collection = INObjectCollection(items: shoeOptions)
                completion(collection, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func handle(intent: ShoeSelectionIntent, completion: @escaping (ShoeSelectionIntentResponse) -> Void) {
        guard let shoeOption = intent.shoe,
              let shoeId = shoeOption.identifier else {
            completion(ShoeSelectionIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        let response = ShoeSelectionIntentResponse(code: .success, userActivity: nil)
        response.selectedShoe = shoeOption
        completion(response)
        
        // Trigger shoe selection in main app
        NotificationCenter.default.post(
            name: .widgetShoeSelectionRequested,
            object: shoeId
        )
    }
}
```

## 🎨 Advanced Widget Features

### Interactive Widget Elements (iOS 17+)
```swift
struct InteractiveSelectionWidget: View {
    var entry: SelectionWidgetEntry
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Select")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(entry.topShoes.prefix(4)) { shoe in
                    Button(intent: SelectShoeIntent(shoeId: shoe.id.uuidString)) {
                        VStack(spacing: 4) {
                            Text(shoe.icon)
                                .font(.title2)
                            Text(shoe.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(shoe.isActive ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(shoe.isActive ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

@available(iOS 17.0, *)
struct SelectShoeIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Shoe"
    static var description = IntentDescription("Quickly select a shoe from the widget")
    
    @Parameter(title: "Shoe ID")
    var shoeId: String
    
    init() {}
    
    init(shoeId: String) {
        self.shoeId = shoeId
    }
    
    func perform() async throws -> some IntentResult {
        // Handle shoe selection
        await ShoeSelectionManager.shared.selectShoe(withId: shoeId)
        
        // Update widgets
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}
```

### Lock Screen Widgets (iOS 16+)
```swift
struct LockScreenShoeWidget: Widget {
    let kind: String = "LockScreenShoe"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenShoeView(entry: entry)
        }
        .configurationDisplayName("Current Shoe")
        .description("Shows your currently selected shoe on the lock screen")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenShoeView: View {
    var entry: LockScreenEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        default:
            EmptyView()
        }
    }
}

struct CircularLockScreenView: View {
    let entry: LockScreenEntry
    
    var body: some View {
        ZStack {
            if let shoe = entry.currentShoe {
                Text(shoe.icon)
                    .font(.title2)
                    .widgetAccentable()
            } else {
                Image(systemName: "shoe.2")
                    .font(.title3)
                    .widgetAccentable()
            }
        }
        .widgetURL(URL(string: "shoeprint://quickSelect"))
    }
}
```

## 📊 Performance Optimization

### Efficient Data Loading
```swift
class WidgetDataManager {
    private let cache = NSCache<NSString, WidgetData>()
    private let userDefaults = UserDefaults(suiteName: "group.com.shoeprint.widgets")
    
    func loadWidgetData() async -> WidgetData {
        // Try cache first
        if let cachedData = cache.object(forKey: "currentData") {
            if cachedData.isValid {
                return cachedData
            }
        }
        
        // Try shared user defaults
        if let sharedData = loadSharedData() {
            cache.setObject(sharedData, forKey: "currentData")
            return sharedData
        }
        
        // Fallback to placeholder data
        return WidgetData.placeholder
    }
    
    private func loadSharedData() -> WidgetData? {
        guard let data = userDefaults?.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        
        return widgetData
    }
    
    func updateSharedData(_ data: WidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        userDefaults?.set(encoded, forKey: "widgetData")
        cache.setObject(data, forKey: "currentData")
    }
}
```

### Memory Management
```swift
class WidgetMemoryManager {
    
    static func optimizeForWidget() {
        // Limit image sizes for widgets
        ImageCache.shared.maxCacheSize = 5 * 1024 * 1024 // 5MB
        
        // Reduce data retention
        DataCache.shared.maxAge = 3600 // 1 hour
        
        // Optimize view hierarchy
        reduceViewComplexity()
    }
    
    private static func reduceViewComplexity() {
        // Use simplified views for widgets
        // Avoid complex animations
        // Minimize view nesting
    }
}
```

## 🔧 Implementation Timeline

### Phase 1: Basic Widgets (1-2 weeks)
- [ ] Quick selection widget (small)
- [ ] Daily stats widget (medium)
- [ ] Timeline providers
- [ ] Basic deep linking

### Phase 2: Advanced Features (2-3 weeks)
- [ ] Smart suggestions widget (large)
- [ ] Lock screen widgets
- [ ] Interactive elements (iOS 17+)
- [ ] Intent-based configuration

### Phase 3: Optimization & Polish (1 week)
- [ ] Performance optimization
- [ ] Memory management
- [ ] Widget preview improvements
- [ ] Comprehensive testing

## 🎯 Portfolio Impact

### Technical Skills Demonstrated
- **WidgetKit Mastery**: Modern iOS widget development
- **Timeline Management**: Dynamic content scheduling
- **App Extensions**: Widget extension architecture
- **Deep Linking**: Seamless app integration
- **Intent Framework**: Siri shortcuts and configuration

### Advanced Concepts Showcased
- Interactive widgets (iOS 17+)
- Lock screen widgets (iOS 16+)
- App group data sharing
- Background task scheduling
- Memory and performance optimization

These iOS widgets showcase cutting-edge widget development skills and demonstrate the ability to create beautiful, functional home screen experiences that enhance user productivity and engagement.