@testable import Core

extension File {
    /// A convenient way to create a file without a `real` file
    init(data: String, absolutePath: String = "/test/file.cte") {
        self.data = data
        self.absolutePath = absolutePath
    }
}
