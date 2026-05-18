import SwiftUI

struct DocumentWarningView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.yellow)
            
            Text("Sensitive Content")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("You are about to enter the document folder which contains sensitive photos of rashes. Please ensure you are in a private space.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                NavigationLink(destination: PhotosPageView()) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
        .navigationBarBackButtonHidden(true)
    }
}
