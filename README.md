# ShoePrint 

> A sustainable footwear tracking app that helps you make conscious consumption choices by monitoring the real usage and lifespan of your shoes.

ShoePrint encourages mindful consumption by providing detailed insights into your footwear usage patterns, helping you maximize the lifespan of each pair and make informed purchasing decisions.

## Philosophy: Sustainable Footwear Management

Rather than promoting endless consumption, ShoePrint focuses on:
- **Maximizing shoe lifespan** through proper usage tracking
- **Informed purchasing decisions** based on real usage data
- **Conscious consumption** by understanding actual vs. perceived needs
- **Repair-first mentality** with integrated maintenance tracking
- **Quality over quantity** philosophy in footwear choices

## Key Features

### Real-time Activity Tracking
- **HealthKit Integration**: Leverages real step count and walking distance data
- **Automatic Attribution**: Smart session management assigns activity to specific shoes
- **Hourly Precision**: Detailed journal view with hourly step and distance breakdowns
- **True Data**: No estimations - uses actual HealthKit measurements

### Smart Shoe Management
- **Visual Collection**: Grid-based shoe library with custom colors and emojis
- **Active Session Tracking**: Real-time monitoring of which shoes you're wearing
- **Usage Analytics**: Distance, steps, wear time, and repair history per pair
- **Lifespan Progress**: Track how much life is left in each pair

### Maintenance & Sustainability
- **Repair Tracking**: Log maintenance and repairs to extend shoe lifespan
- **Default Shoe System**: Auto-start tracking with your primary pair
- **Archive System**: Keep historical data while organizing your collection
- **Durability Insights**: Make data-driven decisions about shoe quality

### Historical Journal
- **Daily Activity View**: Horizontal scrolling timeline of hourly activity
- **Retrospective Attribution**: Assign past activities to specific shoes
- **Batch Operations**: Efficiently manage multiple hours of activity
- **Visual Feedback**: Clear attribution with shoe emojis and colors

## Technical Architecture

### Data Layer
- **SwiftData**: Modern Core Data replacement for local persistence
- **HealthKit Integration**: Real-time access to step and distance data
- **Session-Based Tracking**: Precise start/end times for each wearing session

### Real Data Sources
- **Steps**: Direct from HealthKit step count samples
- **Distance**: Actual walking/running distance from HealthKit
- **Duration**: Real session start/end times
- **No Estimations**: Eliminated all calculated approximations

### Modern iOS Implementation
- **SwiftUI**: Native iOS interface with smooth animations
- **Async/Await**: Modern concurrency for HealthKit operations
- **@Observable**: Latest data binding for responsive UI updates
- **iOS 18.1+**: Takes advantage of newest platform features

## User Interface

### Collection View
- **Grid Layout**: Two-column shoe collection with visual cards
- **Real-time Stats**: Live distance and usage statistics
- **Quick Actions**: Long-press to start/stop wearing sessions
- **Status Indicators**: Clear visual feedback for active shoes

### Journal Interface
- **Horizontal Scrolling**: Intuitive timeline navigation
- **Hourly Columns**: Visual bars showing activity intensity
- **Smart Attribution**: Tap to assign activities to shoes
- **Daily Statistics**: Distance and step summaries

### Shoe Details
- **Comprehensive Stats**: Distance, steps, wear time, repairs
- **Lifespan Tracking**: Progress indicators for shoe longevity
- **Purchase History**: Track investment and value per wear
- **Action Center**: Start sessions, set defaults, log repairs

## Recent Technical Improvements

### HealthKit Data Integration (Latest Update)
- **Real Distance Data**: Direct integration with HealthKit distance measurements
- **True Step Counts**: Actual step data from device sensors
- **Session Enhancement**: Store real HealthKit data in ShoeSession objects

### Architecture Enhancements
- **ShoeSessionService**: Centralized session management with HealthKit integration
- **Data Consistency**: Unified calculation methods across all views
- **Performance Optimization**: Efficient data fetching and caching
- **Debug Improvements**: Enhanced logging for troubleshooting

### UI/UX Polish
- **Journal Redesign**: Horizontal layout with optimized bar visualization
- **Responsive Design**: Adaptive layouts for different screen sizes
- **Visual Consistency**: Unified color schemes and typography
- **Animation Improvements**: Smooth transitions and feedback

## Next Steps & Roadmap

### UI/UX Improvements
- [ ] **HealthKit Request Enhancement**: Improve permission flow in Journal
- [ ] **Date Navigation**: Add horizontal swipe gestures in Journal for day switching
- [ ] **Empty States**: Design collection empty state similar to archives view
- [ ] **Number Formatting**: Standardize decimal places across all statistics
- [ ] **Visual Polish**: Enhance iconography and spacing consistency

### Apple Watch Companion
- [ ] **Watch App Development**: Standalone watch application
- [ ] **ShoeCardView Integration**: Reuse existing card components for shoe selection
- [ ] **Quick Selection**: Rapid shoe switching directly from wrist
- [ ] **Session Control**: Start/stop wearing sessions from watch
- [ ] **Activity Sync**: Real-time synchronization with iPhone app

### Advanced Features
- [ ] **Machine Learning**: Intelligent shoe recommendations based on activity patterns
- [ ] **Social Features**: Share sustainability achievements with friends
- [ ] **Carbon Footprint**: Calculate environmental impact of shoe choices
- [ ] **Shopping Assistant**: Integration with sustainable footwear retailers
- [ ] **Repair Network**: Connect with local shoe repair services

### Data & Analytics
- [ ] **Export Functionality**: Export usage data for external analysis
- [ ] **Advanced Reporting**: Monthly and yearly sustainability reports
- [ ] **Prediction Models**: Forecast shoe lifespan based on usage patterns
- [ ] **Cost Analysis**: Track cost-per-wear and investment efficiency

## Sustainability Impact

ShoePrint aims to reduce footwear waste by:
- **Extending Product Life**: Encouraging maximum use of each pair
- **Informed Decisions**: Data-driven purchasing based on actual needs
- **Repair Culture**: Promoting maintenance over replacement
- **Quality Awareness**: Highlighting differences in shoe durability
- **Conscious Consumption**: Mindful approach to footwear acquisition


## Privacy & Data

- **Local Storage**: All data stored locally on device
- **HealthKit Privacy**: Only reads step and distance data
- **No Tracking**: No analytics or user behavior tracking
- **User Control**: Complete control over data attribution and deletion


