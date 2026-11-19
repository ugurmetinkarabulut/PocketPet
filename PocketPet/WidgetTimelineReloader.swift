import WidgetKit

protocol WidgetTimelineReloading {
    func reloadPocketPetWidget()
}

struct WidgetCenterTimelineReloader: WidgetTimelineReloading {
    func reloadPocketPetWidget() {
        WidgetCenter.shared.reloadTimelines(
            ofKind: PocketPetWidgetConfiguration.kind
        )
    }
}
