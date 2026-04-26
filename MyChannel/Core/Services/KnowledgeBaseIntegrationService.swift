//
//  KnowledgeBaseIntegrationService.swift
//  MyChannel
//
//  Knowledge Base Integration - Connect to docs, SOPs, runbooks
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class KnowledgeBaseIntegrationService: ObservableObject {
    static let shared = KnowledgeBaseIntegrationService()
    
    @Published private(set) var articles: [KnowledgeArticle] = []
    @Published private(set) var categories: [KnowledgeCategory] = []
    @Published private(set) var searchResults: [KnowledgeArticle] = []
    
    struct KnowledgeArticle: Identifiable, Codable {
        let id: String
        let title: String
        let content: String
        let category: String
        let tags: [String]
        let author: String
        let lastUpdated: Date
        let relatedIncidents: [String]
    }
    
    struct KnowledgeCategory: Identifiable, Codable {
        let id: String
        let name: String
        let articleCount: Int
        let icon: String
    }
    
    private init() {
        Task { await loadArticles() }
        Task { await loadCategories() }
    }
    
    func loadArticles() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("knowledgeBase")
            .order(by: "lastUpdated", descending: true)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        articles = snapshot?.documents.compactMap { doc -> KnowledgeArticle? in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let content = data["content"] as? String,
                  let category = data["category"] as? String,
                  let tags = data["tags"] as? [String],
                  let author = data["author"] as? String,
                  let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() else { return nil }
            
            return KnowledgeArticle(
                id: doc.documentID,
                title: title,
                content: content,
                category: category,
                tags: tags,
                author: author,
                lastUpdated: lastUpdated,
                relatedIncidents: data["relatedIncidents"] as? [String] ?? []
            )
        } ?? []
        #endif
    }
    
    func loadCategories() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("knowledgeCategories").getDocuments()
        
        categories = snapshot?.documents.compactMap { doc -> KnowledgeCategory? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let articleCount = data["articleCount"] as? Int,
                  let icon = data["icon"] as? String else { return nil }
            
            return KnowledgeCategory(
                id: doc.documentID,
                name: name,
                articleCount: articleCount,
                icon: icon
            )
        } ?? []
        #endif
    }
    
    func searchArticles(query: String) async {
        let lowerQuery = query.lowercased()
        searchResults = articles.filter { article in
            article.title.lowercased().contains(lowerQuery) ||
            article.content.lowercased().contains(lowerQuery) ||
            article.tags.contains { $0.lowercased().contains(lowerQuery) }
        }
    }
    
    func createArticle(title: String, content: String, category: String, tags: [String], author: String) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("knowledgeBase").document()
        
        try await docRef.setData([
            "title": title,
            "content": content,
            "category": category,
            "tags": tags,
            "author": author,
            "lastUpdated": FieldValue.serverTimestamp(),
            "relatedIncidents": []
        ])
        await loadArticles()
        return docRef.documentID
        #else
        throw NSError(domain: "KnowledgeBase", code: -1, userInfo: nil)
        #endif
    }
}
