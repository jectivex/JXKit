# JXKit

A pure swift interface the `JavaScriptCore` C API with support for `Codable`.

This permits JSC to be used on platforms where the Objective-C runtime is unavailable (e.g., Linux).

The API is a mostly drop-in replacement. E.g.:

```swift
import JavaScriptCore

let jsc = JSContext()
let value: JXValue = jsc.evaluateScript("1+2")
```

becomes:

```swift
import JXKit

let jsc = JXContext()
let value: JXValue = jsc.evaluateScript("1+2")
```

