//
//  TeamCollaborationService.swift
//  MyChannel
//
//  Team Collaboration - Comments, @mentions, task assignments within CC
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class TeamCollaborationService: ObservableObject {
    static let shared = TeamCollaborationService()
    
    @Published private(set) var comments: [CollaborationComment] = []
    @Published private(set) var tasks: [CollaborationTask] = []
    @Published private(set) var mentions: [Mention] = []
    
    struct CollaborationComment: Identifiable, Codable {
        let id: String
        let resourceId: String
        let resourceType: String
        let authorId: String
        let authorName: String
        let content: String
        let mentionedUsers: [String]
        let createdAt: Date
        let resolved: Bool
    }
    
    struct CollaborationTask: Identifiable, Codable {
        let id: String
        let title: String
        let description: String
        let assignedTo: String
        let assignedToName: String
        let assignedBy: String
        let priority: String
        let status: String
        let dueDate: Date?
        let relatedResource: String?
        let createdAt: Date
    }
    
    struct Mention: Identifiable, Codable {
        let id: String
        let mentionedUserId: String
        let mentionedUserName: String
        let mentionedBy: String
        let commentId: String
        let read: Bool
        let mentionedAt: Date
    }
    
    private init() {
        Task { await loadComments() }
        Task { await loadTasks() }
        Task { await loadMentions() }
    }
    
    func loadComments() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("collaborationComments")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        comments = snapshot?.documents.compactMap { doc -> CollaborationComment? in
            let data = doc.data()
            guard let resourceId = data["resourceId"] as? String,
                  let resourceType = data["resourceType"] as? String,
                  let authorId = data["authorId"] as? String,
                  let authorName = data["authorName"] as? String,
                  let content = data["content"] as? String,
                  let mentionedUsers = data["mentionedUsers"] as? [String],
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return CollaborationComment(
                id: doc.documentID,
                resourceId: resourceId,
                resourceType: resourceType,
                authorId: authorId,
                authorName: authorName,
                content: content,
                mentionedUsers: mentionedUsers,
                createdAt: createdAt,
                resolved: data["resolved"] as? Bool ?? false
            )
        } ?? []
        #endif
    }
    
    func loadTasks() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("collaborationTasks")
            .whereField("status", isNotEqualTo: "completed")
            .order(by: "priority", descending: true)
            .order(by: "dueDate", descending: false)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        tasks = snapshot?.documents.compactMap { doc -> CollaborationTask? in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let description = data["description"] as? String,
                  let assignedTo = data["assignedTo"] as? String,
                  let assignedToName = data["assignedToName"] as? String,
                  let assignedBy = data["assignedBy"] as? String,
                  let priority = data["priority"] as? String,
                  let status = data["status"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return CollaborationTask(
                id: doc.documentID,
                title: title,
                description: description,
                assignedTo: assignedTo,
                assignedToName: assignedToName,
                assignedBy: assignedBy,
                priority: priority,
                status: status,
                dueDate: (data["dueDate"] as? Timestamp)?.dateValue(),
                relatedResource: data["relatedResource"] as? String,
                createdAt: createdAt
            )
        } ?? []
        #endif
    }
    
    func loadMentions() async {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        let db = Firestore.firestore()
        
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let snapshot = try? await db.collection("mentions")
            .whereField("mentionedUserId", isEqualTo: currentUser.uid)
            .whereField("read", isEqualTo: false)
            .order(by: "mentionedAt", descending: true)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        mentions = snapshot?.documents.compactMap { doc -> Mention? in
            let data = doc.data()
            guard let mentionedUserId = data["mentionedUserId"] as? String,
                  let mentionedUserName = data["mentionedUserName"] as? String,
                  let mentionedBy = data["mentionedBy"] as? String,
                  let commentId = data["commentId"] as? String,
                  let mentionedAt = (data["mentionedAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return Mention(
                id: doc.documentID,
                mentionedUserId: mentionedUserId,
                mentionedUserName: mentionedUserName,
                mentionedBy: mentionedBy,
                commentId: commentId,
                read: data["read"] as? Bool ?? false,
                mentionedAt: mentionedAt
            )
        } ?? []
        #endif
    }
    
    func addComment(resourceId: String, resourceType: String, authorId: String, authorName: String, content: String, mentionedUsers: [String]) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("collaborationComments").document()
        
        try await docRef.setData([
            "resourceId": resourceId,
            "resourceType": resourceType,
            "authorId": authorId,
            "authorName": authorName,
            "content": content,
            "mentionedUsers": mentionedUsers,
            "createdAt": FieldValue.serverTimestamp(),
            "resolved": false
        ])
        
        // Create mentions
        for userId in mentionedUsers {
            try await db.collection("mentions").addDocument(data: [
                "mentionedUserId": userId,
                "mentionedUserName": "",
                "mentionedBy": authorName,
                "commentId": docRef.documentID,
                "read": false,
                "mentionedAt": FieldValue.serverTimestamp()
            ])
        }
        
        await loadComments()
        await loadMentions()
        return docRef.documentID
        #else
        throw NSError(domain: "TeamCollaboration", code: -1, userInfo: nil)
        #endif
    }
    
    func createTask(title: String, description: String, assignedTo: String, assignedToName: String, assignedBy: String, priority: String, dueDate: Date?, relatedResource: String?) async throws -> String {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("collaborationTasks").document()
        
        var data: [String: Any] = [
            "title": title,
            "description": description,
            "assignedTo": assignedTo,
            "assignedToName": assignedToName,
            "assignedBy": assignedBy,
            "priority": priority,
            "status": "open",
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        if let due = dueDate {
            data["dueDate"] = due
        }
        
        if let resource = relatedResource {
            data["relatedResource"] = resource
        }
        
        try await docRef.setData(data)
        await loadTasks()
        return docRef.documentID
        #else
        throw NSError(domain: "TeamCollaboration", code: -1, userInfo: nil)
        #endif
    }
    
    func completeTask(taskId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("collaborationTasks").document(taskId).updateData([
            "status": "completed",
            "completedAt": FieldValue.serverTimestamp()
        ])
        await loadTasks()
        #endif
    }
    
    func markMentionRead(mentionId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("mentions").document(mentionId).updateData([
            "read": true,
            "readAt": FieldValue.serverTimestamp()
        ])
        await loadMentions()
        #endif
    }
}
