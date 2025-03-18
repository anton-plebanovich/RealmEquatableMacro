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
        
        let className = classDeclSyntax.name.trimmed
        
        let memberList = classDeclSyntax.memberBlock.members
        let storedVariableDecls = memberList
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter {
                // Remove computed properties
                $0.bindings.first?.accessorBlock == nil
                // Remove static properties
                && $0.modifiers.contains { $0.name.text == "static" } == false
            }
        
        let identifierPatterns = storedVariableDecls
            .compactMap { $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self) }
        
        let variableIdentifiers = identifierPatterns.map { $0.identifier }
        let leadingTrivia = storedVariableDecls.first?.leadingTrivia ?? Trivia(pieces: [])
        
        let function = try FunctionDeclSyntax("override func isEqual(_ object: Any?) -> Bool") {
            "guard let rhs = object as? \(className) else { return false }"
            "if self === rhs { return true }"
            for (index, variableIdentifier) in variableIdentifiers.enumerated() {
                let prefix = index == 0 ? "return" : "\(leadingTrivia)&&"
                
                let baseName = storedVariableDecls[index]
                    .bindings
                    .first?
                    .initializer?
                    .value
                    .as(FunctionCallExprSyntax.self)?
                    .calledExpression
                    .as(GenericSpecializationExprSyntax.self)?
                    .expression
                    .as(DeclReferenceExprSyntax.self)?
                    .baseName
                    .text
                
                let isList = baseName == "List"
                if isList {
                    "\(raw: prefix) \(variableIdentifier.trimmed).count == rhs.\(variableIdentifier.trimmed).count && \(variableIdentifier.trimmed).enumerated().allSatisfy { $1 == rhs.\(variableIdentifier.trimmed)[$0] }"
                } else {
                    "\(raw: prefix) \(variableIdentifier.trimmed) == rhs.\(variableIdentifier.trimmed)"
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
