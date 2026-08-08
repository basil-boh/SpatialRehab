import RealityKit
import SwiftUI

struct HummingbirdVolumeView: View {
    var body: some View {
        Model3D(named: "hummingbird_anim") { model in
            model
                .resizable()
                .aspectRatio(contentMode: .fit)
                .manipulable()
        } placeholder: {
            ProgressView()
        }
        .padding(40)
    }
}

#Preview(windowStyle: .volumetric) {
    HummingbirdVolumeView()
}
