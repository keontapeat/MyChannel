// ⚡ PERFORMANCE: Extracted from SettingsView.swift to its own compilation unit.
// Separate file = independent incremental compilation.
import SwiftUI

// MARK: - Terms View
struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("MyChannel Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: January 1, 2025")
                    .foregroundColor(.secondary)
                
                Group {
                    TermsSection(title: "1. Acceptance of Terms", content: """
                    By accessing or using MyChannel ("Service"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Service.
                    """)
                    
                    TermsSection(title: "2. Description of Service", content: """
                    MyChannel is a video sharing platform that allows users to upload, share, and view video content. The Service includes all features, applications, and content provided by MyChannel.
                    """)
                    
                    TermsSection(title: "3. User Accounts", content: """
                    • You must be at least 13 years old to use this Service
                    • You are responsible for maintaining the security of your account
                    • You must provide accurate and complete information
                    • One person may not maintain more than one account
                    • You are responsible for all activity under your account
                    """)
                    
                    TermsSection(title: "4. User Content", content: """
                    • You retain ownership of content you upload
                    • You grant MyChannel a license to display and distribute your content
                    • You are responsible for ensuring you have rights to upload content
                    • Content must comply with our Community Guidelines
                    • We may remove content that violates these terms
                    """)
                    
                    TermsSection(title: "5. Prohibited Conduct & Zero-Tolerance Content Policy", content: """
                    MyChannel has a ZERO-TOLERANCE policy for objectionable content and abusive behavior. You agree not to:
                    • Upload illegal, harmful, threatening, defamatory, obscene, or otherwise objectionable content
                    • Post content depicting nudity, sexual acts, or exploitation of minors
                    • Harass, bully, abuse, stalk, or threaten other users
                    • Upload hate speech, content promoting violence, terrorism, or self-harm
                    • Spam or engage in deceptive practices
                    • Attempt to circumvent security measures
                    • Use the Service for unauthorized commercial purposes
                    • Violate any applicable laws or regulations
                    
                    Violations will result in immediate content removal and account suspension or permanent ban. MyChannel reviews all reports within 24 hours.
                    """)
                    
                    TermsSection(title: "6. Monetization", content: """
                    • Eligible creators may participate in our Partner Program
                    • Revenue sharing is subject to separate Partner terms
                    • We reserve the right to modify monetization features
                    • Tax obligations are the responsibility of creators
                    """)
                    
                    TermsSection(title: "7. Intellectual Property", content: """
                    • MyChannel and its features are protected by copyright and trademark
                    • You may not copy, modify, or distribute our proprietary content
                    • Report copyright violations through our DMCA process
                    """)
                    
                    TermsSection(title: "8. Termination", content: """
                    • We may suspend or terminate accounts for violations
                    • You may delete your account at any time
                    • Upon termination, your content may be removed
                    """)
                    
                    TermsSection(title: "9. Disclaimers", content: """
                    THE SERVICE IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT GUARANTEE UNINTERRUPTED ACCESS OR ERROR-FREE OPERATION.
                    """)
                    
                    TermsSection(title: "10. Contact", content: """
                    For questions about these Terms, contact us at:
                    legal@mychannel.live
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms Section
struct TermsSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: January 1, 2025")
                    .foregroundColor(.secondary)
                
                Group {
                    TermsSection(title: "1. Information We Collect", content: """
                    We collect information you provide directly:
                    • Account information (name, email, username)
                    • Profile information (photo, bio)
                    • Content you upload (videos, comments)
                    • Communications with us
                    
                    We automatically collect:
                    • Device information
                    • Usage data and analytics
                    • Log data
                    """)
                    
                    TermsSection(title: "2. How We Use Information", content: """
                    We use your information to:
                    • Provide and improve the Service
                    • Personalize your experience
                    • Communicate with you
                    • Ensure safety and security
                    • Comply with legal obligations
                    """)
                    
                    TermsSection(title: "3. Information Sharing", content: """
                    We do not sell your personal information. We may share information with:
                    • Service providers who assist our operations
                    • Law enforcement when required by law
                    • Other users (only content you choose to share publicly)
                    """)
                    
                    TermsSection(title: "4. Data Security", content: """
                    We implement industry-standard security measures:
                    • Encryption of data in transit and at rest
                    • Regular security audits
                    • Access controls and authentication
                    • Secure data centers
                    """)
                    
                    TermsSection(title: "5. Your Rights", content: """
                    You have the right to:
                    • Access your personal data
                    • Correct inaccurate data
                    • Delete your account and data
                    • Export your data
                    • Opt out of marketing communications
                    """)
                    
                    TermsSection(title: "6. Children's Privacy", content: """
                    Our Service is not intended for children under 13. We do not knowingly collect information from children under 13. If you believe we have collected such information, please contact us.
                    """)
                    
                    TermsSection(title: "7. Cookies & Tracking", content: """
                    We use cookies and similar technologies for:
                    • Authentication and security
                    • Preferences and settings
                    • Analytics and performance
                    
                    You can control cookies through your browser settings.
                    """)
                    
                    TermsSection(title: "8. Contact Us", content: """
                    For privacy questions or requests:
                    privacy@mychannel.live
                    
                    MyChannel, Inc.
                    Atlanta, GA, USA
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
