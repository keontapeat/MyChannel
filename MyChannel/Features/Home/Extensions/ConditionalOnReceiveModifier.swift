import SwiftUI
import Combine

struct ConditionalOnReceiveModifier<P: Publisher>: ViewModifier where P.Failure == Never {
    let publisher: P?
    let action: (P.Output) -> Void

    func body(content: Content) -> some View {
        if let publisher {
            content.onReceive(publisher, perform: action)
        } else {
            content
        }
    }
}
