// Sana — SanaWidgetBundle.swift
// Add this file to the Widget Extension target only.
// @main widget bundle — registers SanaWidget, SanaLiveActivity, FastingLiveActivity.
import WidgetKit
import SwiftUI

@main
struct SanaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SanaWidget()
        SanaLiveActivity()
        FastingLiveActivity()
    }
}
