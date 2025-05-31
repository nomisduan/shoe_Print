# shoePrint - Technical Documentation

## Architecture Overview

shoePrint employs a sophisticated session-based architecture designed around temporal tracking precision. The application transcends simple active/inactive shoe states by implementing comprehensive session management with automatic lifecycle control and retroactive attribution capabilities.

### Core Architecture Principles

1. **Session-First Design**: All tracking activities are built around temporal sessions with precise start/end dates
2. **Auto-Management**: Intelligent session lifecycle management with configurable inactivity timeouts
3. **Retroactive Attribution**: Manual assignment capabilities for historical data through a posteriori operations
4. **Data Integrity**: Conflict resolution and session overlap handling for accurate historical records
5. **Privacy-Centric**: All health data processing occurs on-device with granular permission control

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        shoePrint                            │
│                     iOS Application                         │
├─────────────────────────────────────────────────────────────┤
│                     Presentation Layer                      │
│  ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐  │
│  │   ShoeGridView  │ │HealthDashboard  │ │ ShoeDetailView│  │
│  │   (Collection)  │ │   (Journal)     │ │  (Analytics)  │  │
│  └─────────────────┘ └─────────────────┘ └───────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     Business Logic Layer                    │
│  ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐  │
│  │ShoeSessionService│ │HealthKitViewModel│ │HealthKitManager│  │
│  │ (Session Mgmt)  │ │ (Data Processing)│ │(Authorization)│  │
│  └─────────────────┘ └─────────────────┘ └───────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     Data Persistence Layer                  │
│  ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐  │
│  │     SwiftData   │ │     HealthKit   │ │  UserDefaults │  │
│  │   (App Data)    │ │  (Health Data)  │ │  (Preferences)│  │
│  └─────────────────┘ └─────────────────┘ └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Data Models

### Shoe Entity
```swift
@Model
final class Shoe {
    // Core Properties
    var id: UUID = UUID()
    var emoji: String = "👟"
    var brand: String = ""
    var model: String = ""
    var colorHex: String = ""
    var purchaseDate: Date?
    var purchasePrice: Double?
    var isDefault: Bool = false
    var archived: Bool = false
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ShoeSession.shoe)
    var sessions: [ShoeSession] = []
    
    @Relationship(deleteRule: .cascade, inverse: \StepEntry.shoe)
    var entries: [StepEntry] = []
    
    // Computed Properties (Legacy Compatibility)
    var isActive: Bool { activeSession != nil }
    var activeSession: ShoeSession? { /* Returns current active session */ }
    var totalDistance: Measurement<UnitLength> { /* Aggregated from sessions */ }
    var totalSteps: Int { /* Computed from HealthKit data through sessions */ }
}
```

### ShoeSession Entity
```swift
@Model
final class ShoeSession {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date?
    var autoStarted: Bool = false
    var autoClosed: Bool = false
    
    // Relationships
    var shoe: Shoe?
    
    // Computed Properties
    var isActive: Bool { endDate == nil }
    var duration: TimeInterval { /* Calculated duration */ }
    var durationFormatted: String { /* Human-readable format */ }
    
    // Temporal Logic
    func coversHour(_ date: Date) -> Bool {
        // Returns true if this session covers the given hour
    }
    
    func closeSession(autoClosed: Bool = false) {
        // Closes the session with proper timestamp
    }
}
```

## Service Architecture

### ShoeSessionService

The `ShoeSessionService` is the core business logic component responsible for session lifecycle management and data attribution.

#### Key Responsibilities
- **Session Management**: Creating, starting, stopping, and auto-closing sessions
- **Auto-Management**: Default shoe activation and inactivity monitoring
- **Attribution Logic**: Real-time and retroactive data attribution to sessions
- **Conflict Resolution**: Handling overlapping sessions and data conflicts
- **Query Optimization**: Efficient session retrieval with SwiftData limitations

#### Critical Methods

```swift
// Session Lifecycle
func startSession(for shoe: Shoe, autoStarted: Bool = false) async -> ShoeSession
func stopSession(for shoe: Shoe, autoClosed: Bool = false) async
func toggleSession(for shoe: Shoe) async

// Auto-Management
func checkAndAutoCloseInactiveSessions() async
func checkAndAutoStartDefaultShoe() async

// A Posteriori Attribution
func createHourSession(for shoe: Shoe, hourDate: Date) async -> ShoeSession
func createHourSessions(for shoe: Shoe, hourDates: [Date]) async
func removeHourAttribution(for hourDate: Date) async

// Data Queries
func getSessionsForDate(_ date: Date) async -> [ShoeSession]
func getHourlyStepDataForDate(_ date: Date, healthKitData: [HourlyStepData]) async -> [HourlyStepData]
```

#### SwiftData Predicate Limitations

Due to SwiftData's limitations with complex predicates involving optional force unwrapping, the service implements in-memory filtering:

```swift
// Instead of complex predicates:
session.startDate < endOfDay && (session.endDate == nil || session.endDate! > startOfDay)

// We use memory filtering:
let allSessions = try modelContext.fetch(FetchDescriptor<ShoeSession>())
let filteredSessions = allSessions.filter { session in
    let startsBeforeDayEnds = session.startDate < endOfDay
    let endsAfterDayStarts = session.endDate == nil || session.endDate! > startOfDay
    return startsBeforeDayEnds && endsAfterDayStarts
}
```

### HealthKitViewModel

Coordinates HealthKit data processing with session-based attribution logic.

#### Key Features
- **Hourly Data Processing**: Fetches HealthKit data in hourly segments
- **Session Integration**: Combines HealthKit data with session attribution
- **Permission Management**: Handles iOS authorization bugs with workarounds
- **Error Handling**: Graceful degradation when HealthKit is unavailable

## A Posteriori Attribution System

### Overview
The attribution system allows users to retroactively assign HealthKit data to specific shoes through the journal interface. This addresses scenarios where users forget to activate sessions or need to correct historical attributions.

### Architecture Components

#### 1. HealthDashboardView (Journal Interface)
- **Hourly Visualization**: Displays HealthKit data in hourly segments with color-coded attributions
- **Selection Mode**: Multi-selection interface for batch operations
- **Attribution Controls**: Single-tap and batch attribution workflows
- **Real-time Updates**: Live synchronization with session changes

#### 2. Attribution Workflow
```
User Action → ShoeSessionService → Session Creation → Database Update → UI Refresh
```

#### 3. Conflict Resolution
When creating new attributions, the system:
1. Identifies existing sessions that overlap with the target time range
2. Removes conflicting sessions to prevent data duplication
3. Creates new session(s) for the specified time period
4. Updates the UI to reflect the new attribution

### Implementation Details

#### Hour-Specific Session Creation
```swift
func createHourSession(for shoe: Shoe, hourDate: Date) async -> ShoeSession {
    let calendar = Calendar.current
    let hourStart = calendar.date(bySettingHour: calendar.component(.hour, from: hourDate), 
                                 minute: 0, second: 0, of: hourDate) ?? hourDate
    let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
    
    // Remove conflicting sessions
    await removeConflictingSessions(for: hourStart, to: hourEnd)
    
    // Create precise hour session
    let session = ShoeSession(startDate: hourStart, endDate: hourEnd, autoStarted: false, shoe: shoe)
    modelContext.insert(session)
    try modelContext.save()
    
    return session
}
```

#### Batch Operations
```swift
func createHourSessions(for shoe: Shoe, hourDates: [Date]) async {
    // Process multiple hours efficiently
    for hourDate in hourDates {
        await createHourSession(for: shoe, hourDate: hourDate)
    }
}
```

## HealthKit Integration

### Permission Management
The app implements sophisticated HealthKit permission handling with iOS bug workarounds:

#### Authorization Override System
```swift
// Persistent storage for authorization status
private let authOverrideKey = "HealthKitAuthorizationOverride"

func overrideAuthorizationStatus() {
    isPermissionGranted = true
    UserDefaults.standard.set(true, forKey: authOverrideKey)
}

func loadPersistedAuthorizationStatus() {
    if UserDefaults.standard.bool(forKey: authOverrideKey) {
        isPermissionGranted = true
    }
}
```

### Data Processing Pipeline

#### 1. Data Fetching
- **HKSampleQuery**: Retrieves step count and distance data
- **Hourly Aggregation**: Groups data into hour-specific segments
- **Date Range Processing**: Efficient querying for specific time periods

#### 2. Attribution Logic
- **Session Mapping**: Maps HealthKit data to active sessions
- **Temporal Matching**: Matches data timestamps with session time ranges
- **Color Coding**: Assigns shoe colors to attributed hours for visualization

#### 3. Real-time Updates
- **Reactive Programming**: Uses Combine for real-time data flow
- **Background Processing**: Async operations for smooth UI performance
- **Error Handling**: Graceful degradation when HealthKit is unavailable

## Performance Optimizations

### SwiftData Optimizations
- **Relationship Loading**: Efficient eager/lazy loading strategies
- **Query Batching**: Minimizing database round trips
- **Memory Management**: Proper model context lifecycle management

### HealthKit Optimizations
- **Query Caching**: Intelligent caching of frequently accessed data
- **Batch Processing**: Efficient bulk data operations
- **Background Threading**: Non-blocking UI operations

### UI Performance
- **Lazy Loading**: Efficient view rendering for large datasets
- **State Management**: Minimizing unnecessary view updates
- **Memory Footprint**: Optimized data structures for mobile constraints

## Error Handling & Edge Cases

### Session Management
- **Overlapping Sessions**: Automatic conflict resolution
- **Orphaned Sessions**: Cleanup of incomplete sessions
- **Data Consistency**: Ensuring temporal data integrity

### HealthKit Edge Cases
- **Permission Revocation**: Graceful handling of permission changes
- **Data Unavailability**: Fallback mechanisms when HealthKit is restricted
- **iOS Bugs**: Workarounds for known iOS authorization issues

### User Experience
- **Offline Operation**: Full functionality without network connectivity
- **Data Migration**: Seamless schema updates across app versions
- **Recovery Mechanisms**: Data repair tools for edge cases

## Testing Strategy

### Unit Testing
- **Session Logic**: Comprehensive testing of session management
- **Attribution Logic**: Validation of temporal attribution algorithms
- **Data Integrity**: Ensuring consistency across operations

### Integration Testing
- **HealthKit Integration**: Mocked HealthKit testing
- **SwiftData Operations**: Database operation validation
- **UI Workflows**: End-to-end user workflow testing

### Performance Testing
- **Large Datasets**: Testing with extensive session histories
- **Memory Usage**: Profiling for memory leaks and optimization
- **Battery Impact**: Monitoring background processing efficiency

## Security & Privacy

### Data Protection
- **Local Storage**: All data remains on-device
- **HealthKit Privacy**: Granular permission management
- **User Control**: Complete user control over data access

### Compliance
- **iOS Privacy Guidelines**: Full compliance with Apple's privacy standards
- **HealthKit Requirements**: Proper HealthKit implementation patterns
- **Data Minimization**: Only necessary permissions requested

---

This technical documentation provides a comprehensive overview of shoePrint's sophisticated architecture, demonstrating advanced iOS development patterns and robust engineering solutions for complex temporal data management. 