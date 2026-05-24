// NourishAI — NourishWidgetBundle.swift
// Add this file to the Widget Extension target only.
// This replaces the @main on NourishWidget.
import WidgetKit
import SwiftUI

@main
struct NourishWidgetBundle: WidgetBundle {
    var body: some Widget {
        NourishWidget()
        NourishLiveActivity()
        FastingLiveActivity()
    }
}
