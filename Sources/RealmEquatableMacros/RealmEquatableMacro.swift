import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// TODO: DOC
// https://github.com/apple/swift/blob/main/test/Macros/Inputs/syntax_macro_definitions.swift#L1309
public struct RealmEquatable: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
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
        let leadingSpacesTrivia = leadingTrivia.compactMap {
            switch $0 {
            case .spaces: return Trivia(pieces: [$0])
            default: return nil
            }
        }.first ?? Trivia(pieces: [.spaces(4)])
        
        let function = try FunctionDeclSyntax("static func ==(lhs: \(className), rhs: \(className)) -> Bool") {
            for (index, variableIdentifier) in variableIdentifiers.enumerated() {
                if index == 0 {
                    "lhs.\(variableIdentifier) == rhs.\(variableIdentifier)"
                } else {
                    "\(leadingTrivia)\(leadingSpacesTrivia)&& lhs.\(variableIdentifier) == rhs.\(variableIdentifier)"
                }
            }
        }
        
        let ext = try ExtensionDeclSyntax("extension \(className)") {
            function
        }
        
        return [ext]
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
