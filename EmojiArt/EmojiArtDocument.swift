//
//  EmojiArtDocument.swift
//  EmojiArt
//
//  Created by Андрей Гавриков on 06.10.2021.
//

import SwiftUI

class EmojiArtDocument: ObservableObject {
    @Published private(set) var emojiArt: EmojiArtModel {
        didSet {
            scheduleAutosave()
            if emojiArt.background != oldValue.background {
                fetchBackgroundImageDataIfNecessary()
            }
        }
    }
    
    private var autosaveTimer: Timer?
    
    private func scheduleAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: Autosave.coalescingInerval, repeats: false) { _ in
            self.autosave()
        }
    }
    
    
    private struct Autosave {
        static let filename = "Autosaved.emojiart"
        static var url: URL? {
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return documentDirectory?.appendingPathComponent(filename)
        }
        static let coalescingInerval = 5.0
    }
    
    private func autosave() {
        if let url = Autosave.url {
            save(to: url)
        }
    }
    
    private func save(to url: URL) {
        let thisfunction = "\(String(describing: self)).\(#function)"
        do {
            let data: Data = try emojiArt.json()
            print(String(data: data, encoding: .utf8) ?? "nil")
            try data.write(to: url)
            print("sucess!")
        } catch let encodingError where encodingError is EncodingError {
            print("\(thisfunction) coldn't encode \(encodingError.localizedDescription)")
        } catch {
            print("\(thisfunction) error = \(error)")
        }
    }
    
    init () {
        if let url = Autosave.url, let autosaveEmojiArt = try? EmojiArtModel(url: url) {
            emojiArt = autosaveEmojiArt
            fetchBackgroundImageDataIfNecessary()
        } else {
        emojiArt = EmojiArtModel()
        }
    }
    
    var emojis: [EmojiArtModel.Emoji] { emojiArt.emojis }
    
    var background: EmojiArtModel.Background {emojiArt.background }
    
    @Published var backgroundImage: UIImage?
    @Published var backgroundImageFetchStatus = BackgroundImageFetchStatus.idle
    
    enum BackgroundImageFetchStatus : Equatable{
        case idle
        case fetching
        case failed(URL)
    }
    
    
    private func fetchBackgroundImageDataIfNecessary() {
        backgroundImage = nil
        switch emojiArt.background {
        case .url(let url):
            backgroundImageFetchStatus = .fetching
            DispatchQueue.global(qos: .userInitiated).async {
                let imageData = try? Data(contentsOf: url)
                    DispatchQueue.main.async { [weak self] in
                        if self?.emojiArt.background == EmojiArtModel.Background.url(url) {
                            self?.backgroundImageFetchStatus = .idle
                            if imageData != nil {
                                self?.backgroundImage = UIImage(data: imageData!)
                            }
                            if self?.backgroundImage == nil {
                                self?.backgroundImageFetchStatus = .failed(url)
                            }
                        }
                    }
            }
        case .imageData(let data):
            backgroundImage = UIImage(data: data)
        case .blank:
            break
        }
    }
    
    // MARK: Intent(s)
    func setBackground (_ background: EmojiArtModel.Background) {
        emojiArt.background = background
        print("background set to \(background)")
    }
    func addEmoji(_ emoji: String, at location: (x: Int, y: Int), size: CGFloat) {
        emojiArt.addEmoji(emoji, at: location, size: Int(size))
    }
    func moveEmoji(_ emoji: EmojiArtModel.Emoji, by offset: CGSize) {
        if let index = emojiArt.emojis.index(matching: emoji) {
            emojiArt.emojis[index].x += Int(offset.width)
            emojiArt.emojis[index].y += Int(offset.height)
        }
    }
    
    func deleteEmoji(_ emoji: EmojiArtModel.Emoji) {
        if let index = emojiArt.emojis.index(matching: emoji) {
            emojiArt.emojis.remove(at: index)
        }
    }
    
    func scaleEmoji(_ emoji: EmojiArtModel.Emoji, by scale: CGFloat) {
        if let index = emojiArt.emojis.index(matching: emoji) {
            emojiArt.emojis[index].size = Int((CGFloat(emojiArt.emojis[index].size) * scale).rounded(.toNearestOrAwayFromZero))
        }
    }
}
