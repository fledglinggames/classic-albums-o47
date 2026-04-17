import SwiftUI

struct PermissionNoteView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 20) {
                Text("Note about Photo permissions")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)

                (
                    Text("Hi there! I (the developer) am someone who is a little cautious about giving Full Access permissions to photos. That's part of why I made this app for myself. Since the purpose of the app is to navigate and edit your photos and albums, it ")
                    + Text("does need you to choose \"Allow Full Access\" on the next screen").bold()
                    + Text(" to work.")
                )
                .font(.body)

                NoteAboutMakingOwnApp()
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct NoteAboutMakingOwnApp: View {
    var body: some View {
        Text("Note that if you really don't want to do this, one thing you can do is make your own app with AI (you'll need an Apple computer). If you're curious, I posted the prompts that I gave Claude and the source code for this app at https://www.fledglinggames.com/other-projects/classic-albums-spec")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
