//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Андрей Гавриков on 06.10.2021.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    @State var selectedEmojis = Set<EmojiArtModel.Emoji>()
    
    let defaultEmojidFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            PaletteChoser(emojiFontSize: defaultEmojidFontSize)
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale())
                        .position(convertFromEmojiCoordinates((0,0), in: geometry))
                ).gesture(doubleTapToZoom(in: geometry.size).exclusively(before: tapToClearSelection()))

                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        Group {
                            if selectedEmojis.index(matching: emoji) != nil {
                                Text(emoji.text).overlay(Rectangle().stroke())
                            } else {
                                Text(emoji.text)
                            }
                        }
                        .scaleEffect(zoomScale(for: emoji))
                        .font(.system(size: fontSize(for: emoji)))
                        .position(position(for: emoji, in: geometry))
                        .gesture(moveGesture(for: emoji).simultaneously(with: tapToToggleSelection(of: emoji)))
                    }
                }
            }
            .clipped()
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                drop(providers: providers, at: location, in: geometry)
            }
            .gesture(zoomGesture().simultaneously(with: panGesture()))
            .alert(item: $alertToShow) { alertToShow in
                alertToShow.alert()
            }
            .onChange(of: document.backgroundImageFetchStatus) { status in
                switch status {
                case .failed(let url):
                    showBackgroundImageFetchFailAlert(url)
                default:
                    break
                }
            }
        }
    }
    
    @State private var alertToShow: IdentifiableAlert?
    
    private func showBackgroundImageFetchFailAlert (_ url: URL) {
        alertToShow = IdentifiableAlert(id: "fetch failed: " + url.absoluteString, alert: {
            Alert(
                title: Text("Background Image Fetch"),
                message: Text("Couldn't load image from \(url)."),
                dismissButton: Alert.Button.default(Text("OK"))
                )
        })
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojidFontSize / zoomScale()
                    )
                }
            }
        }
        return found
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint (
            x: (location.x - panOffset().width - center.x) / zoomScale(),
            y: (location.y - -panOffset().height - center.y) / zoomScale()
        )
        return (Int(location.x), Int(location.y))
        
        
    }
    
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), emoji: emoji, in: geometry)
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), emoji: EmojiArtModel.Emoji? = nil, in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale() + panOffset(for: emoji).width,
            y: center.y + CGFloat(location.y) * zoomScale() + panOffset(for: emoji).height
        )
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }

    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    @GestureState private var getsureMoveOffset: (CGSize, EmojiArtModel.Emoji?) = (CGSize.zero, nil)
    
    
    private func panOffset(for emoji: EmojiArtModel.Emoji? = nil) -> CGSize {
        let (getsureOffset, getsureEmoji) = getsureMoveOffset
        if emoji == nil || getsureEmoji == nil {
            return (steadyStatePanOffset + gesturePanOffset) * zoomScale()
        } else {
            // not selected but dragged
            if selectedEmojis.index(matching: emoji!) == nil && emoji!.id == getsureEmoji!.id {
                return (steadyStatePanOffset + gesturePanOffset + getsureOffset) * zoomScale()
            //dragged selection
            } else if selectedEmojis.index(matching: emoji!) != nil && selectedEmojis.index(matching: getsureEmoji!) != nil {
                return (steadyStatePanOffset + gesturePanOffset + getsureOffset) * zoomScale()
            //else
            } else {
                return (steadyStatePanOffset + gesturePanOffset) * zoomScale()
            }
        }
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _  in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale()
            }
            .onEnded {
                finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale())
            }
    }
    
    private func moveGesture(for emoji: EmojiArtModel.Emoji) -> some Gesture {
        DragGesture()
            .updating($getsureMoveOffset) { latestDragGestureValue, getsureMoveOffset, _  in
                getsureMoveOffset = (latestDragGestureValue.translation / zoomScale(), emoji)
            }
            .onEnded {
            finalDragGestureValue in
            if selectedEmojis.index(matching: emoji) != nil {
                for selectedEmoji in selectedEmojis {
                    document.moveEmoji(selectedEmoji, by: finalDragGestureValue.translation / zoomScale())
                }
                // move selection
            } else {
                document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale())
            }
        }
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    
    private func zoomScale(for emoji: EmojiArtModel.Emoji? = nil) -> CGFloat {
        if selectedEmojis.isEmpty {
            return steadyStateZoomScale * gestureZoomScale
        } else if emoji == nil {
            return steadyStateZoomScale
        } else if selectedEmojis.index(matching: emoji!) == nil {
            return steadyStateZoomScale
        } else {
            return steadyStateZoomScale * gestureZoomScale
        }
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { gestureScaleAtEnd in
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                } else {
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: gestureScaleAtEnd)
                    }
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation {
                zoomToFit(document.backgroundImage, in: size)
            }
        }
    }
    
    private func tapToToggleSelection(of emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture().onEnded {
            selectedEmojis.toggleMembership(of: emoji)
        }
    }
    
    private func tapToClearSelection() -> some Gesture {
        TapGesture().onEnded  {
            selectedEmojis.removeAll()
        }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
   
}





struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
