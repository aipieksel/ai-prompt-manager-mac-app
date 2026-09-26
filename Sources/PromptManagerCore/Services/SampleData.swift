import Foundation

public enum SampleData {
    public static func demoLibrary() -> PromptLibrary {
        let marketing = Folder(name: "Marketing", sortOrder: 0)
        let ecommerceFolder = Folder(name: "E-commerce", parentFolderID: marketing.id, sortOrder: 1)
        let seo = Folder(name: "SEO", parentFolderID: marketing.id, sortOrder: 2)
        let email = Folder(name: "Email", parentFolderID: marketing.id, sortOrder: 3)
        let social = Folder(name: "Social Media", parentFolderID: marketing.id, sortOrder: 4)
        let ads = Folder(name: "Ads", parentFolderID: marketing.id, sortOrder: 5)
        let development = Folder(name: "Development", sortOrder: 5)
        let client = Folder(name: "Client Work", sortOrder: 6)
        let research = Folder(name: "Research", sortOrder: 7)
        let personal = Folder(name: "Personal", sortOrder: 8)
        let prompts = [
            Prompt(title: "Homepage SEO Prompt", content: "Create an SEO-optimized homepage outline with metadata, H1/H2 recommendations, and internal-link suggestions.", folderID: seo.id, updatedAt: .now.addingTimeInterval(-7_200)),
            Prompt(title: "Product Description Generator", content: productDescriptionContent, folderID: ecommerceFolder.id, isFavorite: true, updatedAt: .now.addingTimeInterval(-10_800), lastOpenedAt: .now.addingTimeInterval(-300), copyCount: 27, notes: "Use for new product launches and category pages. Works best when features and target audience are clearly defined."),
            Prompt(title: "React Component Refactor", content: "Refactor the following React component for readability, state isolation, accessibility, and testability.", folderID: development.id, updatedAt: .now.addingTimeInterval(-18_000)),
            Prompt(title: "Client Email Rewrite", content: "Rewrite this email to be more professional, concise, and action-oriented while preserving the original request.", folderID: email.id, isFavorite: true, updatedAt: .now.addingTimeInterval(-86_400)),
            Prompt(title: "AI Workflow Summary", content: "Summarize this workflow and suggest improvements with clear next steps, risks, and owners.", folderID: research.id, updatedAt: .now.addingTimeInterval(-90_000)),
            Prompt(title: "Blog Post Outline", content: "Create a detailed outline for a blog post about sustainable growth, including target keywords and section goals.", folderID: social.id, updatedAt: .now.addingTimeInterval(-172_800)),
            Prompt(title: "Ad Copy Variations", content: "Write 5 variations of ad copy for this product targeting different buyer motivations and objections.", folderID: ads.id, isFavorite: true, updatedAt: .now.addingTimeInterval(-180_000)),
            Prompt(title: "Competitor Analysis Prompt", content: "Analyze the following competitor and provide a SWOT analysis, positioning notes, and content gaps.", folderID: client.id, updatedAt: .now.addingTimeInterval(-259_200))
        ]
        return PromptLibrary(prompts: prompts, folders: [marketing, ecommerceFolder, seo, email, social, ads, development, client, research, personal])
    }

    private static let productDescriptionContent = """
    You are a world-class e-commerce copywriter. Your task is to write a compelling, benefit-driven product description that converts browsers into buyers.

    Input you will receive:
    • Product name
    • Key features
    • Specifications (if any)
    • Target audience
    • Brand voice / tone
    • Any unique selling points

    Instructions:
    • Write 2–3 short paragraphs that highlight the value and benefits of the product.
    • Use persuasive, clear, and engaging language.
    • Focus on how the product solves a problem or improves the customer’s life.
    • Include sensory details and specific benefits where relevant.
    • End with a subtle call-to-action (no hard sell).
    """
}
