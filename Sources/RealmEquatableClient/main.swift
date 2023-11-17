import RealmEquatable
import Foundation

@RealmEquatable
class MyClass: NSObject {
    let string: String = ""
}

let asd1 = MyClass()
let asd2 = MyClass()
print(asd1 == asd1)
print(asd1 == asd2)
