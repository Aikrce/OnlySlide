//
//  OnlySlideApp.swift
//  OnlySlide
//
//  Created by Ni Qian on 2025/4/13.
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
