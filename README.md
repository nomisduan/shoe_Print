# shoePrint

**shoePrint** is a comprehensive iOS application built with SwiftUI and SwiftData that enables users to track and manage their shoe usage through seamless HealthKit integration. The app provides detailed analytics, wear patterns, and maintenance tracking for athletic footwear.

## Overview

shoePrint addresses the common challenge faced by runners and fitness enthusiasts: tracking shoe mileage and determining optimal replacement timing. By integrating with Apple HealthKit, the application automatically attributes step count and distance data to specific shoes, providing valuable insights into wear patterns and helping users maximize their footwear investment.

## Key Features

### Core Functionality
- **Shoe Management**: Add, edit, and organize multiple pairs of shoes with detailed specifications
- **Automatic Data Attribution**: Intelligent HealthKit integration automatically assigns walking/running data to active shoes
- **Manual Data Entry**: Comprehensive manual entry system for repairs, maintenance, and custom activities
- **Usage Analytics**: Real-time statistics including total distance, step count, usage days, and repair history

### Advanced Features
- **Lifespan Tracking**: Intelligent estimation of shoe lifespan based on type (running shoes: 800km, hiking boots: 1200km, etc.)
- **Active Shoe Management**: Mark shoes as currently worn for automatic data attribution
- **Repair Tracking**: Log repairs and maintenance activities with date stamps
- **Visual Dashboard**: Intuitive card-based interface with color-coded organization

### HealthKit Integration
- **Hourly Data Processing**: Granular step and distance tracking with hourly breakdowns
- **Automatic Attribution**: Smart attribution logic assigns data to active shoes when unambiguous
- **Manual Override**: Complete control over data attribution with batch processing capabilities
- **Privacy-First**: All health data remains on-device with user-controlled permissions

## Technical Architecture

### Technology Stack
- **Framework**: SwiftUI (iOS 18.1+)
- **Data Persistence**: SwiftData with CloudKit sync
- **Health Integration**: HealthKit framework
- **Architecture Pattern**: MVVM with ObservableObject view models
- **Async Processing**: Swift Concurrency (async/await)

### Core Components

#### Data Models
- **Shoe**: Core entity with properties for brand, model, color, purchase information, and lifecycle tracking
- **StepEntry**: Activity records linking time periods, step counts, and distances to specific shoes
- **HealthKit Integration**: Real-time data fetching with automatic attribution logic

#### Service Layer
- **HealthKitManager**: Handles permissions, data queries, and iOS-specific HealthKit workarounds
- **DataAttributionService**: Manages automatic and manual attribution of walking sessions to shoes
- **HourlyAttributionService**: Processes granular hourly data with intelligent auto-attribution

#### Business Logic
- **Automatic Attribution**: Single active shoe triggers automatic data assignment
- **Conflict Resolution**: Manual attribution required when multiple shoes are active
- **Data Validation**: Prevents duplicate entries and maintains data integrity
- **Lifecycle Management**: Tracks shoe progression from purchase to retirement

## Installation & Setup

### Prerequisites
- iOS 18.1 or later
- Xcode 16.0 or later
- Active Apple Developer account (for HealthKit entitlements)

### Configuration
1. Clone the repository
2. Open `shoePrint.xcodeproj` in Xcode
3. Configure HealthKit entitlements in project capabilities
4. Build and run on device (HealthKit requires physical device)

### HealthKit Permissions
The app requests the following HealthKit permissions:
- Step Count (read access)
- Walking + Running Distance (read access)

All health data processing occurs on-device and is never transmitted externally.

## Usage Workflow

### Initial Setup
1. Launch application and grant HealthKit permissions
2. Add your first pair of shoes with relevant details
3. Mark shoes as "active" when wearing them

### Daily Usage
1. Wear tracked shoes during activities
2. Data automatically attributes to active shoes
3. Review daily/hourly breakdowns in Journal view
4. Manual attribution available for complex scenarios

### Maintenance Tracking
1. Log repairs and maintenance activities
2. Monitor wear progression against estimated lifespan
3. Receive insights on replacement timing
4. Archive retired shoes while preserving historical data

## Project Structure

```
shoePrint/
├── Models/
│   ├── Shoe.swift                    # Core shoe entity
│   ├── StepEntry.swift              # Activity records
│   └── HealthKit/
│       ├── HealthKitManager.swift    # Core HealthKit integration
│       └── HealthKitDataModels.swift # Data transfer objects
├── Services/
│   ├── Data/
│   │   ├── DataAttributionService.swift    # Session attribution logic
│   │   └── HourlyAttributionService.swift  # Hourly data processing
│   └── HealthKit/
│       └── HealthKitDataService.swift      # Data fetching service
├── ViewModels/
│   └── HealthKitViewModel.swift     # Main view model
├── Views/
│   ├── Dashboard/
│   │   └── HealthDashboardView.swift      # Hourly data visualization
│   ├── HealthKit/
│   │   ├── AttributionView.swift          # Manual attribution interface
│   │   └── HealthKitSetupView.swift       # Permission management
│   ├── ShoeCardView.swift           # Primary shoe display component
│   ├── ShoeDetailView.swift         # Detailed shoe information
│   └── ShoeGridView.swift           # Main shoe collection view
└── Extensions/
    ├── Color+Extensions.swift       # Custom color definitions
    ├── Date+Extensions.swift        # Date formatting utilities
    └── Measurement+Extensions.swift # Unit conversion helpers
```

## Technical Highlights

### SwiftData Implementation
- Modern declarative data persistence with automatic CloudKit sync
- Optimized queries with `@Query` property wrapper
- Relationship management between shoes and step entries
- Migration handling for schema updates

### HealthKit Integration Challenges
- **iOS Permission Bugs**: Implemented workarounds for unreliable authorization status reporting
- **Data Attribution Logic**: Sophisticated algorithms for automatic activity assignment
- **Privacy Compliance**: Granular permission management with user control
- **Performance Optimization**: Efficient batch processing of large datasets

### Architecture Decisions
- **MVVM Pattern**: Clear separation of concerns with reactive UI updates
- **Service Layer**: Modular design enabling independent testing and maintenance
- **Async/Await**: Modern concurrency patterns for smooth user experience
- **Error Handling**: Comprehensive error management with graceful degradation

## Future Enhancements

### Planned Features
- **Machine Learning**: Enhanced attribution using Core ML activity recognition
- **Social Features**: Share achievements and milestones with running communities
- **Advanced Analytics**: Trend analysis and predictive maintenance recommendations
- **Wear Pattern Analysis**: Visual heat maps of activity distribution

### Technical Improvements
- **Widget Extensions**: Home screen widgets for quick stats
- **Shortcuts Integration**: Siri shortcuts for common actions
- **Apple Watch Companion**: Dedicated watchOS app for real-time tracking
- **Export Capabilities**: Data export in standard formats

## Contributing

This is a portfolio project demonstrating iOS development expertise. The codebase showcases:
- Modern SwiftUI development patterns
- Complex HealthKit integration
- Sophisticated data attribution algorithms
- Professional code organization and documentation

## License

This project is developed for portfolio demonstration purposes. All rights reserved.

## Contact

**Simon Naud**  
iOS Developer  
[Portfolio] | [LinkedIn] | [GitHub]

---

*shoePrint represents a comprehensive solution for athletic footwear tracking, demonstrating advanced iOS development skills including HealthKit integration, SwiftData persistence, and sophisticated business logic implementation.* 