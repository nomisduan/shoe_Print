# HealthKit + ML Integration Architecture

## 🎯 Integration Overview

Seamless integration between HealthKit data streams and on-device machine learning models to enable intelligent, automated shoe attribution while maintaining strict privacy and performance standards.

## 🏗️ Architecture Diagram

```
HealthKit Data Sources
         ↓
┌─────────────────────────────────────┐
│        Data Collection Layer        │
├─────────────────────────────────────┤
│  • Step Count & Walking Distance    │
│  • Walking Speed & Pace            │
│  • Walking Double Support %        │
│  • Walking Asymmetry %             │
│  • Walking Step Length             │
│  • Heart Rate (optional)           │
│  • Location & Elevation           │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│      Data Processing Pipeline       │
├─────────────────────────────────────┤
│  • Real-time Stream Processing     │
│  • Feature Extraction             │
│  • Data Normalization             │
│  • Temporal Windowing             │
│  • Quality Validation             │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│        ML Inference Engine         │
├─────────────────────────────────────┤
│  • Pattern Recognition            │
│  • Contextual Analysis            │
│  • Confidence Scoring             │
│  • Real-time Classification       │
│  • Batch Processing               │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│      Attribution Service           │
├─────────────────────────────────────┤
│  • Automatic Attribution          │
│  • Manual Review Queue            │
│  • Feedback Integration           │
│  • Continuous Learning            │
└─────────────────────────────────────┘
```

## 📊 HealthKit Data Integration

### Advanced Data Collection
```swift
class AdvancedHealthKitCollector: ObservableObject {
    
    private let healthStore = HKHealthStore()
    private let workoutManager = WorkoutDataManager()
    
    // Define all required data types
    private let requiredDataTypes: Set<HKSampleType> = [
        HKSampleType.quantityType(forIdentifier: .stepCount)!,
        HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKSampleType.quantityType(forIdentifier: .walkingSpeed)!,
        HKSampleType.quantityType(forIdentifier: .walkingDoubleSupport)!,
        HKSampleType.quantityType(forIdentifier: .walkingAsymmetry)!,
        HKSampleType.quantityType(forIdentifier: .walkingStepLength)!,
        HKSampleType.quantityType(forIdentifier: .heartRate)!,
        HKSampleType.workoutType()
    ]
    
    func startAdvancedDataCollection() async throws {
        // Request comprehensive permissions
        try await requestAdvancedPermissions()
        
        // Start real-time monitoring
        await startRealTimeMonitoring()
        
        // Start background data collection
        await startBackgroundCollection()
        
        // Initialize workout detection
        await startWorkoutDetection()
    }
    
    private func requestAdvancedPermissions() async throws {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: requiredDataTypes) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? HealthKitError.permissionDenied)
                }
            }
        }
    }
    
    private func startRealTimeMonitoring() async {
        // Monitor step count in real-time
        await monitorStepCount()
        
        // Monitor walking metrics
        await monitorWalkingMetrics()
        
        // Monitor heart rate during activity
        await monitorHeartRate()
    }
    
    private func monitorWalkingMetrics() async {
        let walkingMetrics = [
            HKQuantityTypeIdentifier.walkingSpeed,
            .walkingDoubleSupport,
            .walkingAsymmetry,
            .walkingStepLength
        ]
        
        for metricIdentifier in walkingMetrics {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: metricIdentifier) else {
                continue
            }
            
            let query = HKAnchoredObjectQuery(
                type: quantityType,
                predicate: nil,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { [weak self] query, samples, deletedObjects, anchor, error in
                
                if let samples = samples as? [HKQuantitySample] {
                    Task {
                        await self?.processWalkingMetrics(samples, type: metricIdentifier)
                    }
                }
            }
            
            query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
                if let samples = samples as? [HKQuantitySample] {
                    Task {
                        await self?.processWalkingMetrics(samples, type: metricIdentifier)
                    }
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func processWalkingMetrics(_ samples: [HKQuantitySample], type: HKQuantityTypeIdentifier) async {
        let processedData = WalkingMetricProcessor.process(samples, type: type)
        
        // Send to ML pipeline
        await MLDataPipeline.shared.ingestWalkingMetrics(processedData)
        
        // Trigger real-time analysis if enough data
        if await MLDataPipeline.shared.hasEnoughDataForAnalysis() {
            await triggerRealTimeAnalysis()
        }
    }
}
```

### Workout Context Detection
```swift
class WorkoutContextDetector {
    
    private let healthStore = HKHealthStore()
    
    func startWorkoutDetection() {
        let workoutQuery = HKAnchoredObjectQuery(
            type: HKWorkoutType.workoutType(),
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            
            if let workouts = samples as? [HKWorkout] {
                Task {
                    await self?.processWorkoutContext(workouts)
                }
            }
        }
        
        workoutQuery.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            if let workouts = samples as? [HKWorkout] {
                Task {
                    await self?.processWorkoutContext(workouts)
                }
            }
        }
        
        healthStore.execute(workoutQuery)
    }
    
    private func processWorkoutContext(_ workouts: [HKWorkout]) async {
        for workout in workouts {
            let context = extractWorkoutContext(workout)
            await MLContextAnalyzer.shared.updateWorkoutContext(context)
            
            // Special handling for walking/running workouts
            if workout.workoutActivityType == .walking || workout.workoutActivityType == .running {
                await handleWalkingWorkout(workout)
            }
        }
    }
    
    private func extractWorkoutContext(_ workout: HKWorkout) -> WorkoutContext {
        return WorkoutContext(
            activityType: workout.workoutActivityType,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            totalDistance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            totalSteps: extractStepCount(from: workout),
            averageHeartRate: extractAverageHeartRate(from: workout),
            locations: extractLocationData(from: workout),
            weather: await WeatherService.shared.getWeather(for: workout.startDate)
        )
    }
    
    private func handleWalkingWorkout(_ workout: HKWorkout) async {
        // Extract detailed walking metrics during workout
        let walkingData = await extractDetailedWalkingData(workout)
        
        // Create high-confidence training example
        let trainingExample = WorkoutTrainingExample(
            workout: workout,
            walkingData: walkingData,
            confidence: 0.95, // High confidence for explicit workout data
            labels: await inferShoeLabels(workout)
        )
        
        // Add to training dataset
        await MLTrainingManager.shared.addTrainingExample(trainingExample)
    }
}
```

## 🔄 Real-time Data Pipeline

### Stream Processing Architecture
```swift
class HealthKitDataStream: ObservableObject {
    
    @Published var isStreamingActive = false
    @Published var dataQuality: DataQuality = .unknown
    
    private let streamProcessor = StreamProcessor()
    private let qualityMonitor = DataQualityMonitor()
    private let bufferManager = DataBufferManager()
    
    func startDataStreaming() async {
        isStreamingActive = true
        
        // Initialize streaming components
        await streamProcessor.initialize()
        await qualityMonitor.start()
        await bufferManager.start()
        
        // Start multiple concurrent streams
        async let stepStream = startStepCountStream()
        async let walkingStream = startWalkingMetricsStream()
        async let contextStream = startContextualDataStream()
        
        // Wait for all streams to initialize
        _ = await (stepStream, walkingStream, contextStream)
    }
    
    private func startStepCountStream() async {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let query = HKAnchoredObjectQuery(
            type: stepType,
            predicate: HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-300), // Last 5 minutes
                end: nil,
                options: .strictEndDate
            ),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            Task {
                await self?.processStepSamples(samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            Task {
                await self?.processStepSamples(samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processStepSamples(_ samples: [HKQuantitySample]) async {
        // Quality check
        let qualityScore = await qualityMonitor.assessQuality(samples)
        await updateDataQuality(qualityScore)
        
        if qualityScore >= 0.7 { // Only process high-quality data
            // Buffer management
            await bufferManager.addSamples(samples)
            
            // Real-time processing
            let processedData = await streamProcessor.processStepData(samples)
            
            // Send to ML pipeline
            await MLDataPipeline.shared.ingestStepData(processedData)
        }
    }
    
    @MainActor
    private func updateDataQuality(_ score: Double) {
        dataQuality = DataQuality(score: score)
    }
}

class DataQualityMonitor {
    
    func assessQuality(_ samples: [HKQuantitySample]) async -> Double {
        var qualityFactors: [Double] = []
        
        // Temporal consistency
        qualityFactors.append(assessTemporalConsistency(samples))
        
        // Data completeness
        qualityFactors.append(assessDataCompleteness(samples))
        
        // Value reasonableness
        qualityFactors.append(assessValueReasonableness(samples))
        
        // Sample frequency
        qualityFactors.append(assessSampleFrequency(samples))
        
        // Calculate weighted average
        return qualityFactors.reduce(0, +) / Double(qualityFactors.count)
    }
    
    private func assessTemporalConsistency(_ samples: [HKQuantitySample]) -> Double {
        guard samples.count > 1 else { return 1.0 }
        
        let intervals = zip(samples.dropFirst(), samples).map { next, current in
            next.startDate.timeIntervalSince(current.endDate)
        }
        
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let intervalVariance = intervals.map { pow($0 - averageInterval, 2) }.reduce(0, +) / Double(intervals.count)
        
        // Lower variance = higher quality
        return max(0, 1.0 - (intervalVariance / 3600.0)) // Normalize by 1 hour
    }
    
    private func assessDataCompleteness(_ samples: [HKQuantitySample]) -> Double {
        guard let first = samples.first, let last = samples.last else { return 0.0 }
        
        let totalTimeSpan = last.endDate.timeIntervalSince(first.startDate)
        let expectedSamples = max(1, Int(totalTimeSpan / 60.0)) // Expect ~1 sample per minute
        
        return min(1.0, Double(samples.count) / Double(expectedSamples))
    }
    
    private func assessValueReasonableness(_ samples: [HKQuantitySample]) -> Double {
        let stepCounts = samples.map { $0.quantity.doubleValue(for: .count()) }
        
        // Check for unreasonable values
        let unreasonableCount = stepCounts.filter { $0 > 10000 || $0 < 0 }.count
        return max(0, 1.0 - (Double(unreasonableCount) / Double(stepCounts.count)))
    }
    
    private func assessSampleFrequency(_ samples: [HKQuantitySample]) -> Double {
        guard samples.count > 1 else { return 0.5 }
        
        let timeSpan = samples.last!.endDate.timeIntervalSince(samples.first!.startDate)
        let frequency = Double(samples.count) / timeSpan * 60.0 // Samples per minute
        
        // Optimal frequency is around 1 sample per minute
        return max(0, 1.0 - abs(frequency - 1.0))
    }
}
```

## 🧠 ML Data Pipeline Integration

### Feature Engineering Pipeline
```swift
class MLFeatureEngineeringPipeline {
    
    private let featureCache = NSCache<NSString, FeatureVector>()
    private let processingQueue = DispatchQueue(label: "feature.engineering", qos: .utility)
    
    func processHealthKitData(_ healthData: HealthKitDataBatch) async -> MLFeatureVector {
        return await withTaskGroup(of: FeatureGroup.self) { group in
            // Parallel feature extraction
            group.addTask {
                await self.extractBasicMetrics(healthData.stepSamples, healthData.distanceSamples)
            }
            
            group.addTask {
                await self.extractGaitFeatures(healthData.walkingMetrics)
            }
            
            group.addTask {
                await self.extractTemporalFeatures(healthData.timeWindow)
            }
            
            group.addTask {
                await self.extractContextualFeatures(healthData.context)
            }
            
            group.addTask {
                await self.extractHeartRateFeatures(healthData.heartRateSamples)
            }
            
            // Combine all feature groups
            var featureGroups: [FeatureGroup] = []
            for await featureGroup in group {
                featureGroups.append(featureGroup)
            }
            
            return combineFeatureGroups(featureGroups)
        }
    }
    
    private func extractGaitFeatures(_ walkingMetrics: [WalkingMetricSample]) async -> FeatureGroup {
        guard !walkingMetrics.isEmpty else {
            return FeatureGroup.empty(type: .gait)
        }
        
        var features: [String: Double] = [:]
        
        // Extract cadence features
        let cadenceValues = walkingMetrics.compactMap(\.cadence)
        if !cadenceValues.isEmpty {
            features["cadence_mean"] = cadenceValues.average()
            features["cadence_std"] = cadenceValues.standardDeviation()
            features["cadence_min"] = cadenceValues.min() ?? 0
            features["cadence_max"] = cadenceValues.max() ?? 0
        }
        
        // Extract step regularity features
        let regularityValues = walkingMetrics.compactMap(\.stepRegularity)
        if !regularityValues.isEmpty {
            features["step_regularity_mean"] = regularityValues.average()
            features["step_regularity_std"] = regularityValues.standardDeviation()
        }
        
        // Extract walking asymmetry features
        let asymmetryValues = walkingMetrics.compactMap(\.walkingAsymmetry)
        if !asymmetryValues.isEmpty {
            features["walking_asymmetry_mean"] = asymmetryValues.average()
            features["walking_asymmetry_std"] = asymmetryValues.standardDeviation()
        }
        
        // Extract double support features
        let doubleSupportValues = walkingMetrics.compactMap(\.doubleSupport)
        if !doubleSupportValues.isEmpty {
            features["double_support_mean"] = doubleSupportValues.average()
            features["double_support_std"] = doubleSupportValues.standardDeviation()
        }
        
        // Extract step length features
        let stepLengthValues = walkingMetrics.compactMap(\.stepLength)
        if !stepLengthValues.isEmpty {
            features["step_length_mean"] = stepLengthValues.average()
            features["step_length_std"] = stepLengthValues.standardDeviation()
        }
        
        return FeatureGroup(type: .gait, features: features)
    }
    
    private func extractTemporalFeatures(_ timeWindow: TimeWindow) async -> FeatureGroup {
        let calendar = Calendar.current
        let startDate = timeWindow.startTime
        
        var features: [String: Double] = [:]
        
        // Time of day features
        features["hour_of_day"] = Double(calendar.component(.hour, from: startDate))
        features["minute_of_hour"] = Double(calendar.component(.minute, from: startDate))
        
        // Day of week features
        features["day_of_week"] = Double(calendar.component(.weekday, from: startDate))
        features["is_weekend"] = calendar.isDateInWeekend(startDate) ? 1.0 : 0.0
        
        // Seasonal features
        features["month_of_year"] = Double(calendar.component(.month, from: startDate))
        features["day_of_year"] = Double(calendar.ordinality(of: .day, in: .year, for: startDate) ?? 0)
        
        // Time window features
        features["window_duration"] = timeWindow.duration
        features["window_start_timestamp"] = startDate.timeIntervalSince1970
        
        return FeatureGroup(type: .temporal, features: features)
    }
    
    private func extractContextualFeatures(_ context: HealthKitContext) async -> FeatureGroup {
        var features: [String: Double] = [:]
        
        // Location features
        if let location = context.location {
            features["latitude"] = location.coordinate.latitude
            features["longitude"] = location.coordinate.longitude
            features["altitude"] = location.altitude
            features["horizontal_accuracy"] = location.horizontalAccuracy
            features["speed"] = max(0, location.speed)
        }
        
        // Weather features
        if let weather = context.weather {
            features["temperature"] = weather.temperature
            features["humidity"] = weather.humidity
            features["wind_speed"] = weather.windSpeed
            features["precipitation"] = weather.precipitationProbability
            features["uv_index"] = weather.uvIndex
        }
        
        // Activity context features
        features["is_workout"] = context.isWorkout ? 1.0 : 0.0
        features["activity_type"] = Double(context.activityType.rawValue)
        
        return FeatureGroup(type: .contextual, features: features)
    }
    
    private func combineFeatureGroups(_ groups: [FeatureGroup]) -> MLFeatureVector {
        var allFeatures: [String: Double] = [:]
        
        for group in groups {
            for (key, value) in group.features {
                allFeatures["\(group.type.rawValue)_\(key)"] = value
            }
        }
        
        return MLFeatureVector(
            features: allFeatures,
            timestamp: Date(),
            dataQuality: calculateOverallQuality(groups)
        )
    }
}
```

### Batch Processing System
```swift
class HealthKitBatchProcessor {
    
    private let batchSize = 1000
    private let processingInterval: TimeInterval = 3600 // 1 hour
    
    func startBatchProcessing() {
        Timer.scheduledTimer(withTimeInterval: processingInterval, repeats: true) { _ in
            Task {
                await self.processPendingBatches()
            }
        }
    }
    
    private func processPendingBatches() async {
        // Get unprocessed data from the last interval
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-processingInterval)
        
        do {
            let batchData = try await fetchHealthKitData(from: startTime, to: endTime)
            
            // Process in chunks
            let chunks = batchData.chunked(into: batchSize)
            
            for chunk in chunks {
                await processBatch(chunk)
            }
            
            // Trigger model updates if enough new data
            let totalProcessed = chunks.reduce(0) { $0 + $1.count }
            if totalProcessed >= 100 {
                await triggerModelUpdate()
            }
            
        } catch {
            print("Batch processing error: \(error)")
        }
    }
    
    private func processBatch(_ batch: [HealthKitDataPoint]) async {
        // Feature extraction
        let features = await MLFeatureEngineeringPipeline.shared.processDataPoints(batch)
        
        // Quality filtering
        let highQualityFeatures = features.filter { $0.dataQuality >= 0.7 }
        
        // Store for training
        await MLTrainingDataStore.shared.addFeatures(highQualityFeatures)
        
        // Real-time inference if applicable
        if shouldRunInference(highQualityFeatures) {
            await runBatchInference(highQualityFeatures)
        }
    }
    
    private func runBatchInference(_ features: [MLFeatureVector]) async {
        for featureVector in features {
            do {
                let prediction = try await MLInferenceEngine.shared.predict(featureVector)
                
                if prediction.confidence >= 0.8 {
                    await createAutomaticAttribution(featureVector, prediction)
                }
                
            } catch {
                print("Inference error: \(error)")
            }
        }
    }
}
```

## 🔧 Implementation Phases

### Phase 1: Enhanced HealthKit Integration (2-3 weeks)
- [ ] Advanced data collection setup
- [ ] Real-time stream processing
- [ ] Data quality monitoring
- [ ] Workout context detection

### Phase 2: ML Data Pipeline (3-4 weeks)
- [ ] Feature engineering pipeline
- [ ] Batch processing system
- [ ] Data preprocessing and normalization
- [ ] Quality assurance framework

### Phase 3: Real-time Analysis (2-3 weeks)
- [ ] Streaming inference engine
- [ ] Buffer management system
- [ ] Performance optimization
- [ ] Memory management

### Phase 4: Integration Testing (1-2 weeks)
- [ ] End-to-end testing
- [ ] Performance validation
- [ ] Privacy compliance verification
- [ ] Error handling improvement

## 🎯 Success Metrics

### Technical Performance
- **Data Quality**: >90% high-quality samples
- **Processing Latency**: <2 seconds for real-time inference
- **Memory Usage**: <50MB peak during processing
- **Battery Impact**: <5% additional drain

### ML Performance
- **Attribution Accuracy**: >85% correct predictions
- **False Positive Rate**: <10%
- **Model Update Frequency**: Daily with sufficient data
- **Personalization Improvement**: 10% accuracy gain after 2 weeks

This HealthKit + ML integration creates a sophisticated, privacy-preserving system that demonstrates advanced technical skills in data processing, machine learning, and real-time systems while delivering intelligent automation to users.