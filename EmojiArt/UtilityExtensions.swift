//
//  UtilityExtensions.swift
//  EmojiArt
//
//  Created by Андрей Гавриков on 06.10.2021.
//

import SwiftUI

extension Collection where Element: Identifiable {
    func index(matching element: Element) -> Self.Index? {
        firstIndex(where: {$0.id == element.id})
    }
}
