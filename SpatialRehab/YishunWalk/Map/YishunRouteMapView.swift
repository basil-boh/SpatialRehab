import MapKit
import SwiftUI

struct YishunRouteMapView: View {
    @Bindable var session: WalkSessionModel
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        Map(position: $cameraPosition) {
            Marker(YishunRoute.sourceTitle, coordinate: session.sourceCoordinate)
                .tint(.blue)

            Marker(YishunRoute.destinationTitle, coordinate: session.destinationCoordinate)
                .tint(.purple)

            if let route = session.route {
                MapPolyline(route.polyline)
                    .stroke(.teal, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }

            Annotation("You", coordinate: session.walkerCoordinate, anchor: .bottom) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .blue)
                    .shadow(radius: 2)
                    .accessibilityLabel("Current position on the walk")
            }

            ForEach(session.trafficLights) { light in
                Annotation(light.name, coordinate: light.coordinate, anchor: .bottom) {
                    Button {
                        session.selectTrafficLight(light.id)
                    } label: {
                        Image(systemName: "light.beacon.max.fill")
                            .font(.title2)
                            .foregroundStyle(.white, light.state.tint)
                            .shadow(radius: 2)
                    }
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("\(light.name), \(light.state.accessibilityLabel)")
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
    }
}
