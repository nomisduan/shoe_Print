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
    var distance: Double
    var repair: Bool
    
    init(startDate: Date , endDate: Date, steps: Int, distance: Double, repair: Bool) {
        self.startDate = startDate
        self.endDate = endDate
        self.steps = steps
        self.distance = distance
        self.repair = repair
    }
}

