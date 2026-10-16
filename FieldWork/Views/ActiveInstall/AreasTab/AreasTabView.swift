import SwiftUI
import SwiftData

struct AreasTabView: View {
    var viewModel: ActiveInstallViewModel
    var onCameraForSurface: ((UUID) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.booking.surfaces.sorted(by: { $0.displayOrder < $1.displayOrder }), id: \.surfaceId) { surface in
                    InstallSurfaceCard(
                        surface: surface,
                        surfaceStatus: viewModel.status(for: surface.surfaceId),
                        viewModel: viewModel,
                        onCamera: {
                            onCameraForSurface?(surface.surfaceId)
                        }
                    )
                }
            }
            .padding()
        }
    }
}
