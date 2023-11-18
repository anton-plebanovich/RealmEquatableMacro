import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// TODO: DOC
public struct RealmEquatable: MemberMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDeclSyntax = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: ErrorDiagnosticMessage(
                        id: "unsupported-type",
                        message: "'RealmEquatable' macro can only be applied to classes"
                    )
                )
            )
            
            return []
        }
        
        let className = classDeclSyntax.name
        
        let memberList = classDeclSyntax.memberBlock.members
        let variableDecls = memberList.compactMap { $0.decl.as(VariableDeclSyntax.self) }
        let identifierPatterns = variableDecls.compactMap { $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self) }
        let variableIdentifiers = identifierPatterns.map { $0.identifier }
        let leadingTrivia = variableDecls.first?.leadingTrivia ?? Trivia(pieces: [])
        
        let function = try FunctionDeclSyntax("override func isEqual(_ object: Any?) -> Bool") {
            "if super.isEqual(object) { return true }"
            "guard let rhs = object as? \(className) else { return false }"
            for (index, variableIdentifier) in variableIdentifiers.enumerated() {
                if index == 0 {
                    "return \(variableIdentifier) == rhs.\(variableIdentifier)"
                } else {
                    "\(leadingTrivia)&& \(variableIdentifier) == rhs.\(variableIdentifier)"
                }
            }
        }
        
        return [DeclSyntax(function)]
    }
}

@main
struct RealmEquatablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RealmEquatable.self,
    ]
}

private struct InvalidDeclarationTypeError: Error {}

private struct ErrorDiagnosticMessage: DiagnosticMessage, Error {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity
    
    init(id: String, message: String) {
        self.message = message
        diagnosticID = MessageID(domain: "com.anton.plebanovich.realm.equatable", id: id)
        severity = .error
    }
}
