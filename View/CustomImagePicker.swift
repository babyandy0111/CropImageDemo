//
//  CustomImagePicker.swift
//  CropImageView
//
//  Created by andy on 2024/3/13.
//

import SwiftUI
import PhotosUI


extension View {
    @ViewBuilder
    func cropImagePicker(options: [Crop], show: Binding<Bool>, croppedImage: Binding<UIImage?>) -> some View {
        CustomImagePicker(options: options, show: show, croppedImage: croppedImage) {
            self
        }
    }
}


fileprivate struct CustomImagePicker<Content: View>: View {
    var content: Content
    var options: [Crop]
    @Binding var show: Bool
    @Binding var croppedImage: UIImage?

    init(options: [Crop], show: Binding<Bool>, croppedImage: Binding<UIImage?>, @ViewBuilder content: @escaping () -> Content) {
        self.content = content()
        self._show = show
        self._croppedImage = croppedImage
        self.options = options
    }

    @State private var photosItem: PhotosPickerItem?
    @State private var selectImage: UIImage?
    @State private var showDialog: Bool = false

    var body: some View {
        content
            .photosPicker(isPresented: $show, selection: $photosItem)
            .onChange(of: photosItem) { oldValue, newValue in
            // 拿取照片檔案
            if let newValue {
                Task {
                    if let imageData = try? await newValue.loadTransferable(type: Data.self), let image = UIImage(data: imageData) {
                        // 更新UI
                        await MainActor.run(body: {
                            selectImage = image
                            showDialog.toggle()
                        })
                    }
                }
            }

        }
            .confirmationDialog("", isPresented: $showDialog) {
            // 顯示所有的遮罩
            ForEach(options.indices, id: \.self) { index in
                Button(options[index].name()) {

                }
            }
        }
    }
}

struct CustomImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
