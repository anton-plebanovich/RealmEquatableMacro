import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(RealmEquatableMacros)
import RealmEquatableMacros

let testMacros: [String: Macro.Type] = [
    "RealmEquatable": RealmEquatable.self,
]
#endif

final class RealmEquatableTests: XCTestCase {
    
    func testMacro() throws {
        #if canImport(RealmEquatableMacros)
        assertMacroExpansion(
            """
            @RealmEquatable
            class MyClass: NSObject {
                private static let privateStaticString: String = ""
                static let staticString: String = ""
                let string: String = ""
                let int: Int = 0
                @objc dynamic var dynamicString: String!
                @objc dynamic var dynamicInt: String!
                var computed: Int { int }
                let list = List<MyOtherClass>()
            }
            """,
            expandedSource: """
            class MyClass: NSObject {
                private static let privateStaticString: String = ""
                static let staticString: String = ""
                let string: String = ""
                let int: Int = 0
                @objc dynamic var dynamicString: String!
                @objc dynamic var dynamicInt: String!
                var computed: Int { int }
                let list = List<MyOtherClass>()
            
                override func isEqual(_ object: Any?) -> Bool {
                    guard let rhs = object as? MyClass else {
                        return false
                    }
                    if self === rhs {
                        return true
                    }
                    return string == rhs.string
                    && int == rhs.int
                    && dynamicString == rhs.dynamicString
                    && dynamicInt == rhs.dynamicInt
                    && list.count == rhs.list.count && list.enumerated().allSatisfy { $1 == rhs.list[$0] }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
