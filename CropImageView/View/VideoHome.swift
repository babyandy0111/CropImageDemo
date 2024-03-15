//
//  VideoHome.swift
//  CropImageView
//
//  Created by andy.wang on 2024/3/15.
//

import AVKit
import PhotosUI
import SwiftUI
import ffmpegkit

struct Movie: Transferable {
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .movie) { movie in
      SentTransferredFile(movie.url)
    } importing: { received in
      let copy = URL.documentsDirectory.appending(path: "movie.mp4")

      if FileManager.default.fileExists(atPath: copy.path()) {
        try FileManager.default.removeItem(at: copy)
      }

      try FileManager.default.copyItem(at: received.file, to: copy)
      return Self.init(url: copy)
    }
  }
}
struct VideoHome: View {
  enum LoadState {
    case unknown, loading
    case loaded(Movie)
    case test(String)
    case failed
  }

  @State private var selectedItem: PhotosPickerItem?
  @State private var loadState = LoadState.unknown

  var body: some View {
    VStack {
      PhotosPicker("Select movie", selection: $selectedItem, matching: .videos)

      switch loadState {
      case .unknown:
        EmptyView()
      case .loading:
        ProgressView()
      case .loaded(let movie):
        VideoPlayer(player: AVPlayer(url: movie.url))
          .scaledToFit()
          .frame(width: 300, height: 300)
      case .test(let url):
        Text(url)
        VideoPlayer(player: AVPlayer(url: URL(string: url)!))
          .scaledToFit()
          .frame(width: 300, height: 300)
      case .failed:
        Text("Import failed")
      }
    }
    .onChange(of: selectedItem) { _, _ in
      Task {
        do {
          loadState = .loading

          if let movie = try await selectedItem?.loadTransferable(type: Movie.self) {
            let url = syncCommand(url: movie.url)
            loadState = .test(url)
          } else {
            loadState = .failed
          }
        } catch {
          loadState = .failed
        }
      }
    }
  }
}

func syncCommand(url: URL) -> String {
  guard
    let outputPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
  else { return "" }
  let output = outputPath.appendingPathComponent("file1.mp4")

  print("url: \(url.path)")
  print("output: \(output.path)")

  guard let session = FFmpegKit.execute("-loglevel quiet -y -i \(url.path) \"\(output.path)\"") else {
    print("!! Failed to create session")
    return ""
  }
  let returnCode = session.getReturnCode()
  if ReturnCode.isSuccess(returnCode) {

  } else if ReturnCode.isCancel(returnCode) {

  } else {
    print(
      "Command failed with state \(FFmpegKitConfig.sessionState(toString: session.getState()) ?? "Unknown") and rc \(returnCode?.description ?? "Unknown").\(session.getFailStackTrace() ?? "Unknown")"
    )
  }

  return output.path
}

func loadImageFromDocumentsDirectory(fileName: String) -> UIImage? {
  let fileManager = FileManager.default
  if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    .first
  {
    let fileURL = documentsDirectory.appendingPathComponent(fileName)
    if let imageData = try? Data(contentsOf: fileURL) {
      return UIImage(data: imageData)
    }
  }
  return nil
}

#Preview {
  VideoHome()
}
