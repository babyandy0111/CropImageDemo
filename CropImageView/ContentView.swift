//
//  ContentView.swift
//  CropImageView
//
//  Created by andy on 2024/3/13.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationView {
      VStack {
        Spacer()
        NavigationLink(destination: ImageHome()) {
          Text("Image")
        }
        Spacer()
        NavigationLink(destination: VideoHome()) {
          Text("Video")
        }
        Spacer()
      }
    }
  }
}

#Preview {
  ContentView()
}
