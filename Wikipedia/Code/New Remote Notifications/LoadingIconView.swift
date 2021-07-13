import SwiftUI

@available(iOS 13.0, *)
struct LoadingIconView: View {
    var body: some View {
        if #available(iOS 14.0, *) {
            ProgressView()
        } else {
            Image(systemName: "clock.arrow.2.circlepath")
        }
    }
}

@available(iOS 13.0, *)
struct LoadingIconView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingIconView()
    }
}
