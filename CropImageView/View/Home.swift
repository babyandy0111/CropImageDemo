//
//  Home.swift
//  CropImageView
//
//  Created by andy on 2024/3/13.
//

import SwiftUI

struct Home: View {
    @State private var showPicker: Bool = false
    @State private var croppedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                if let croppedImage {
                    Image(uiImage: croppedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 400)
                } else {
                    Text("No image select")
                        .font(.caption)
                        .foregroundColor(.gray)

                }
            }
                .navigationTitle("test crop")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button {
                        showPicker.toggle()
                    } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.callout)
                    }
                        .tint(.black)
                }
            }
                .cropImagePicker(options: [.circle, .square, .rectangle, .custom(.init(width: 300, height: 300))], show: $showPicker, croppedImage: $croppedImage)
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
    }
}
