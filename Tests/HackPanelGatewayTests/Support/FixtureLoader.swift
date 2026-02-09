import Foundation
import XCTest

enum FixtureLoader {
    static func data(named name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil), "Missing fixture: \(name)", file: file, line: line)
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_: T.Type, fromFixture name: String, decoder: JSONDecoder, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        do {
            let data = try data(named: name, file: file, line: line)
            return try decoder.decode(T.self, from: data)
        } catch {
            XCTFail("Failed decoding fixture \(name) as \(T.self): \(error)", file: file, line: line)
            throw error
        }
    }
}
