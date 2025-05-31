//
//  StepEntry.swift
//  shoePrint
//
//  Created by Simon Naud on 11/04/2025.
//

import Foundation
import SwiftData

@Model
final class StepEntry {
    var startDate: Date
    var endDate: Date
    var steps: Int
    var distance: Double // in kilometers
    var repair: Bool
    var shoe: Shoe?
    var source: String // "manual" or "healthkit" or "hourly"
    
    init(startDate: Date, endDate: Date, steps: Int, distance: Double, repair: Bool = false, shoe: Shoe? = nil, source: String = "manual") {
        self.startDate = startDate
        self.endDate = endDate
        self.steps = steps
        self.distance = distance
        self.repair = repair
        self.shoe = shoe
        self.source = source
    }
    
    // MARK: - Computed Properties
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var durationHours: Double {
        duration / 3600
    }
    
    var averageSpeed: Double {
        guard durationHours > 0 else { return 0 }
        return distance / durationHours
    }
}

