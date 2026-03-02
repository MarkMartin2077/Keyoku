import SwiftUI

@MainActor
protocol StatsRouter: GlobalRouter { }

extension CoreRouter: StatsRouter { }
