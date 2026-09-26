import SwiftUI

enum ProTipKind { case sidebar, details }

struct ProTipCardView: View {
    let kind: ProTipKind
    @State private var showingTip = false

    var body: some View {
        VStack(alignment: .leading, spacing: kind == .sidebar ? 10 : 8) {
            Label(kind == .sidebar ? "Prompt smarter" : "Pro tip", systemImage: kind == .sidebar ? "wand.and.stars" : "lightbulb")
                .font(DT.FontToken.bodySmallStrong).foregroundStyle(kind == .details ? DT.ColorToken.accentBlue : DT.ColorToken.textPrimary)
            Text(kind == .sidebar ? "Organize, reuse, and improve your prompts so you can ship better work, faster." : "Use variables like {{product_name}} or {{brand_tone}} to reuse this prompt with different inputs.")
                .font(kind == .sidebar ? DT.FontToken.bodySmall : DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .lineSpacing(kind == .sidebar ? 3 : 2)
            if kind == .sidebar {
                Button("Learn more →") { showingTip = true }
                    .buttonStyle(.plain)
                    .font(DT.FontToken.bodySmallStrong)
                    .foregroundStyle(DT.ColorToken.accentBlue)
            }
        }
        .padding(kind == .sidebar ? 16 : 16)
        .frame(maxWidth: .infinity, minHeight: kind == .sidebar ? 150 : nil, alignment: .leading)
        .background(kind == .sidebar ? DT.ColorToken.accentBlueSoft : DT.ColorToken.accentBlueSoft, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.proTipBorder))
        .alert(kind == .sidebar ? "Prompt smarter" : "Pro tip", isPresented: $showingTip) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(kind == .sidebar ? "Use folders, favorites, and saved prompt templates to keep reusable work easy to find." : "Variables make a prompt reusable across products, clients, and campaigns.")
        }
    }
}
