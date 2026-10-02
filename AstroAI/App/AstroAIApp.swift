//
//  AstroAIApp.swift
//  AstroAI
//
//  Created by Arsenkin Bogdan on 02.10.2026..
//

import SwiftUI

@main
struct AstroAIApp: App {
    @State private var coordinator = AppCoordinator(dependencies: AppDependencies())

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator)
        }
    }
}
