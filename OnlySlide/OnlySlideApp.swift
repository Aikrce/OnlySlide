//
//  OnlySlideApp.swift
//  OnlySlide
//
//  Created by Ni Qian on 2025/3/20.
//

import SwiftUI

@main
struct OnlySlideApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
