import XCTest
@testable import Claude_Dashboard

final class FileAttachmentTests: XCTestCase {
    func testFileTypeFromExtension() {
        XCTAssertEqual(FileAttachment.fileType(for: "photo.png"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.jpg"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.jpeg"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.gif"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.svg"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.webp"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "doc.pdf"), .pdf)
        XCTAssertEqual(FileAttachment.fileType(for: "main.swift"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "app.py"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "index.js"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "index.ts"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "main.go"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "main.rs"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "readme.md"), .text)
        XCTAssertEqual(FileAttachment.fileType(for: "notes.txt"), .text)
        XCTAssertEqual(FileAttachment.fileType(for: "data.bin"), .other)
        XCTAssertEqual(FileAttachment.fileType(for: "noextension"), .other)
    }

    func testEquatableByID() {
        let id = UUID()
        let a = FileAttachment(id: id, url: URL(fileURLWithPath: "/a.txt"), fileName: "a.txt", fileType: .text, fileSize: 100, thumbnailData: nil)
        let b = FileAttachment(id: id, url: URL(fileURLWithPath: "/b.txt"), fileName: "b.txt", fileType: .code, fileSize: 200, thumbnailData: nil)
        XCTAssertEqual(a, b, "Equality is by ID only")
    }

    func testHashableByID() {
        let id = UUID()
        let a = FileAttachment(id: id, url: URL(fileURLWithPath: "/a.txt"), fileName: "a.txt", fileType: .text, fileSize: 100, thumbnailData: nil)
        let b = FileAttachment(id: id, url: URL(fileURLWithPath: "/b.txt"), fileName: "b.txt", fileType: .code, fileSize: 200, thumbnailData: nil)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testFileSizeLimits() {
        XCTAssertTrue(FileAttachment.isWithinSizeLimit(bytes: 1_000_000))
        XCTAssertFalse(FileAttachment.isWithinSizeLimit(bytes: 1_000_001))
    }
}
