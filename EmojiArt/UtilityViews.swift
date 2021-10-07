//
//  UtilityViews.swift
//  EmojiArt
//
//  Created by Андрей Гавриков on 06.10.2021.
//

import SwiftUI

struct OptionalImage: View {
    var uiImage: UIImage?
    
    var body: some View {
        if uiImage != nil {
            Image(uiImage: uiImage!)
        }
    }
}
