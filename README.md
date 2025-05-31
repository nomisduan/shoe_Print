# shoePrint

**shoePrint** is a comprehensive iOS application built with SwiftUI and SwiftData that enables users to track and manage their shoe usage through seamless HealthKit integration. The app provides detailed analytics, wear patterns, and maintenance tracking for athletic footwear using an intelligent session-based architecture.

## Overview

shoePrint addresses the common challenge faced by runners and fitness enthusiasts: tracking shoe mileage and determining optimal replacement timing. By integrating with Apple HealthKit, the application automatically attributes step count and distance data to specific shoes through temporal sessions, providing valuable insights into wear patterns and helping users maximize their footwear investment.

## Key Features

### Core Functionality
- **Shoe Management**: Add, edit, and organize multiple pairs of shoes with detailed specifications
- **Session-Based Tracking**: Intelligent temporal tracking with automatic session management
- **Smart Defaults**: Set default shoes that auto-activate when no other shoe is active
- **Usage Analytics**: Real-time statistics including total distance, step count, usage time, and repair history

### Advanced Features
- **Auto-Management**: Sessions automatically close after 6 hours of inactivity
- **Batch Attribution**: Select multiple hours and assign to shoes at once
- **Repair Tracking**: Log repairs and maintenance activities with date stamps
- **Visual Dashboard**: Intuitive card-based interface with color-coded organization
- **Archive System**: Keep your collection organized by archiving old shoes

### HealthKit Integration
- **Hourly Data Processing**: Granular step and distance tracking with hourly breakdowns
- **Session Attribution**: Smart attribution logic assigns data to active sessions
- **iOS Bug Workarounds**: Robust permission handling with persistent storage
- **Privacy-First**: All health data remains on-device with user-controlled permissions

## Technical Architecture

### Technology Stack
- **Framework**: SwiftUI (iOS 18.1+)
- **Data Persistence**: SwiftData with migration support
- **Health Integration**: HealthKit framework
- **Architecture Pattern**: MVVM with session-based data management
- **Async Processing**: Swift Concurrency (async/await)

### Core Components

#### Data Models
- **Shoe**: Core entity with session relationships and computed properties for compatibility
- **ShoeSession**: Temporal records with start/end dates for precise tracking
- **StepEntry**: Activity records for repairs and manual entries
- **HealthKitManager**: Unified HealthKit permissions and data access with iOS bug workarounds

#### Service Layer
- **ShoeSessionService**: Comprehensive session management including auto-logic and data attribution
- **HealthKitViewModel**: Coordinates HealthKit data with session-based attribution

#### Business Logic
- **Session Management**: Automatic start/stop with intelligent lifecycle management
- **Data Attribution**: HealthKit data attributed through sessions for historical accuracy
- **Auto-Management**: Default shoe auto-activation and inactive session cleanup
- **Temporal Accuracy**: Complete timeline of shoe usage with precise start/end times

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
3. Set a shoe as "default" for automatic activation

### Daily Usage
1. Long-press a shoe card to start/stop wearing sessions
2. Data automatically attributes to active sessions
3. Review daily/hourly breakdowns in Journal view
4. Manual attribution available for historical data

### Maintenance Tracking
1. Log repairs and maintenance activities
2. Monitor wear progression with session-based analytics
3. Archive retired shoes while preserving historical data

## Project Structure

```
shoePrint/
├── Models/
│   ├── Shoe.swift                    # Core shoe entity with session relationships
│   ├── ShoeSession.swift             # Session tracking model
│   ├── StepEntry.swift               # Activity records for repairs
│   ├── HealthKitManager.swift        # Unified HealthKit integration
│   └── ShoeMigrationPlan.swift       # SwiftData schema migration
├── Services/
│   └── Data/
│       └── ShoeSessionService.swift  # Session management and auto-logic
├── ViewModels/
│   └── HealthKitViewModel.swift      # HealthKit data coordination
├── Views/
│   ├── Dashboard/
│   │   └── HealthDashboardView.swift # Hourly step attribution journal
│   ├── HealthKit/
│   │   └── HealthKitSetupView.swift  # Permission management
│   ├── ShoeCardView.swift            # Primary shoe display component
│   ├── ShoeDetailView.swift          # Detailed shoe information
│   ├── ShoeGridView.swift            # Main shoe collection view
│   ├── ShoeListView.swift            # Archive view
│   ├── AddAPairView.swift            # Add new shoes
│   ├── EditPairView.swift            # Edit existing shoes
│   └── MainView.swift                # Tab-based navigation
└── Extensions/
    ├── Color+Extensions.swift        # Custom color definitions
    ├── Date+Extensions.swift         # Date formatting utilities
    ├── Measurement+Extensions.swift  # Unit conversion helpers
    └── PreviewContainer.swift        # SwiftUI preview data
```

## Technical Highlights

### Session-Based Architecture
- **Temporal Tracking**: Precise start/end times instead of simple active/inactive states
- **Auto-Management**: Intelligent session lifecycle with 6-hour inactivity timeout
- **Data Attribution**: HealthKit data attributed through sessions for historical accuracy
- **Conflict Resolution**: Smart handling of overlapping sessions and data gaps

### SwiftData Implementation
- **Modern Persistence**: Declarative data modeling with relationship management
- **Migration Support**: Seamless schema updates as the app evolves
- **Optimized Queries**: Efficient data fetching with `@Query` property wrapper
- **Session Relationships**: Proper modeling of shoe-session-entry relationships

### HealthKit Integration Challenges
- **iOS Permission Bugs**: Implemented persistent storage workarounds for unreliable authorization
- **Data Attribution Logic**: Session-based attribution replacing direct assignment
- **Privacy Compliance**: Granular permission management with user control
- **Performance Optimization**: Efficient hourly data processing with batch operations

### Architecture Decisions
- **Session-First Design**: All tracking built around temporal sessions
- **Service Layer**: Modular design with clear separation of concerns
- **Async/Await**: Modern concurrency patterns for smooth user experience
- **Error Handling**: Comprehensive error management with graceful degradation

## Future Enhancements

### Planned Features
- **Machine Learning**: Enhanced attribution using Core ML activity recognition
- **Advanced Analytics**: Trend analysis and predictive maintenance recommendations
- **Apple Watch Support**: Quick session control from your wrist
- **Export Capabilities**: Share data with other fitness apps

### Technical Improvements
- **Widget Extensions**: Home screen widgets for quick stats
- **Shortcuts Integration**: Siri shortcuts for common actions
- **Social Features**: Share achievements with running communities
- **Wear Pattern Analysis**: Visual insights into usage patterns

## Contributing

This is a portfolio project demonstrating iOS development expertise. The codebase showcases:
- Modern SwiftUI development patterns
- Sophisticated session-based architecture
- Complex HealthKit integration with iOS bug workarounds
- Professional code organization and documentation

## License

This project is developed for portfolio demonstration purposes. All rights reserved.

## Contact

**Simon Naud**  
iOS Developer  
[Portfolio] | [LinkedIn] | [GitHub]

---

*shoePrint represents a comprehensive solution for athletic footwear tracking, demonstrating advanced iOS development skills including session-based architecture, HealthKit integration, SwiftData persistence, and sophisticated business logic implementation.* 