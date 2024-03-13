//
//  CustomImagePicker.swift
//  CropImageView
//
//  Created by andy on 2024/3/13.
//
import UIKit
import SwiftUI
import PhotosUI


extension View {
    @ViewBuilder
    func cropImagePicker(options: [Crop], show: Binding<Bool>, croppedImage: Binding<UIImage?>) -> some View {
        CustomImagePicker(options: options, show: show, croppedImage: croppedImage) {
            self
        }
    }

    // 只是個簡單裁減範例
    @ViewBuilder
    func frame(_ size: CGSize) -> some View {
        self.frame(width: size.width, height: size.height)
    }

    func haptics(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
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
    @State private var selectedImage: UIImage?
    @State private var showDialog: Bool = false
    @State private var selectedCropType: Crop = .circle
    @State private var showCropView: Bool = false

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
                            selectedImage = image
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
                    selectedCropType = options[index]
                    showCropView.toggle()
                }
            }
        }
            .fullScreenCover(isPresented: $showCropView) {
            selectedImage = nil
        } content: {
            CropView(crop: selectedCropType, image: selectedImage) { croppedImage, status in
                if let croppedImage {
                    self.croppedImage = croppedImage
                }
            }
        }
    }
}

// 建立剪裁的View
struct CropView: View {
    var crop: Crop
    var image: UIImage?
    var onCrop: (UIImage?, Bool) -> ()

    // 關閉當前頁面
    @Environment(\.dismiss) private var dismiss

    // 手勢屬性
    @State private var scale: CGFloat = 1 // 放大預設倍數
    @State private var lastScale: CGFloat = 0 // 最後放大預設倍數
    @State private var offset: CGSize = .zero // 位置
    @State private var lastStoredOffset: CGSize = .zero // 最後位置
    @GestureState private var isInteracting: Bool = false // 互動

    var body: some View {
        NavigationStack {
            ImageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { Color.black.ignoresSafeArea() }
                .navigationTitle("crop view")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                ToolbarItem (placement: .navigationBarTrailing) {
                    Button {
                        let renderer = ImageRenderer(content: ImageView(true))
                        renderer.proposedSize = .init(crop.size())
                        if let image = renderer.uiImage {
                            onCrop(image, true)
                        } else {
                            onCrop(nil, false)
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                }

                ToolbarItem (placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // 顯示選取圖片
    @ViewBuilder
    func ImageView(_ hideGrids: Bool = false) -> some View {
        let cropSize = crop.size()
        GeometryReader {
            let size = $0.size

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(content: {
                    GeometryReader { proxy in
                        let rect = proxy.frame(in: .named("CROPVIEW"))

                        Color.clear
                            .onChange(of: isInteracting) { oldValue, newValue in

                            // 這邊要進行拖動時判斷，超過就要拉回
                            withAnimation(.easeInOut(duration: 0.2)) {
                                // 先處理 mix x,y
                                if rect.minX > 0 {
                                    offset.width = (offset.width - rect.minX)
                                    haptics(.medium)
                                }

                                if rect.minY > 0 {
                                    offset.height = (offset.height - rect.minY)
                                    haptics(.medium)
                                }

                                // 接續處理 max x,y
                                if rect.maxX < size.width {
                                    offset.width = (rect.minX - offset.width)
                                    haptics(.medium)
                                }

                                if rect.maxY < size.height {
                                    offset.height = (rect.minY - offset.height)
                                    haptics(.medium)
                                }
                            }


                            // true 拖動, false 停止拖動
                            if !newValue {
                                lastStoredOffset = offset
                            }
                        }
                    }
                }).frame(size)

            }
        }
            .scaleEffect(scale) // 值來至於 MagnifyGesture onChanged中的變動
        .offset(offset) // 值來至於 DragGesture onChanged中的變動
        .overlay(content: {
            if !hideGrids {
                Grids()
            }
        })
            .coordinateSpace(name: "CROPVIEW")
            .gesture(
            DragGesture().updating($isInteracting, body: { _, out, _ in
                out = true
            }).onChanged({ value in
                let translation = value.translation
                offset = CGSize(width: translation.width + lastStoredOffset.width, height: translation.height + lastStoredOffset.height)

            })
        )
            .gesture(
            MagnificationGesture().updating($isInteracting, body: { _, out, _ in
                out = true
            }).onChanged({ value in
                let updatedScale = value + lastScale
                scale = (updatedScale < 1 ? 1 : updatedScale)
            }).onEnded({ value in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if scale < 1 {
                        scale = 1
                        lastScale = 0
                    } else {
                        lastScale = scale - 1
                    }
                }
            })
        )
            .frame(cropSize)
            .cornerRadius(crop == .circle ? cropSize.height / 2 : 0)
    }

    // 來個比例線條吧
    @ViewBuilder
    func Grids() -> some View {
        ZStack {
            HStack {
                ForEach(1...5, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 1)
                        .frame(maxWidth: .infinity)

                }
            }
        }

        ZStack {
            HStack {
                ForEach(1...8, id: \.self) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.7))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity)

                }
            }
        }
    }
}

struct CustomImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        CropView(crop: .square, image: UIImage(named: "1")) { _, _ in

        }
    }
}
