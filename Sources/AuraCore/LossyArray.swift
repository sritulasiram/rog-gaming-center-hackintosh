import Foundation

/// Decodes an array while skipping elements that fail to decode, so one
/// unreadable entry (e.g. a preset saved by a newer version) doesn't discard the rest.
public struct LossyArray<Element: Decodable>: Decodable {
    public let elements: [Element]

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                // A failed decode doesn't advance the container; consume the bad element.
                _ = try? container.decode(Skipped.self)
            }
        }
        self.elements = elements
    }

    private struct Skipped: Decodable {
        init(from decoder: Decoder) throws {}
    }
}
