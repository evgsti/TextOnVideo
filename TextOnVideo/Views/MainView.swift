//
//  ContentView.swift
//  TextOnVideo
//
//  Created by Евгений on 15.12.2024.
//

import SwiftUI
import AVKit

struct MainView: View {
    @StateObject private var viewModel = ServiceFactory.makeMainViewModel()
    private let space: CGFloat = 16
    
    var body: some View {
        NavigationView {
            VStack(spacing: space) {
                videoPreviewSection
                actionButton
                Spacer()
            }
            .navigationTitle("Text on video")
            .sheet(isPresented: $viewModel.showVideoPicker) {
                VideoPicker(videoURL: $viewModel.videoURL, isLoading: $viewModel.isLoading)
            }
        }
    }
    
    private var videoPreviewSection: some View {
        let height: CGFloat = 300
        
        return ZStack {
            if viewModel.isLoading {
                Rectangle()
                    .fill(.bar)
                    .frame(height: height)
                    .overlay {
                        ProgressView("Загрузка видео...")
                            .controlSize(.extraLarge)
                    }
            } else if let videoURL = viewModel.videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: height)
            } else {
                Rectangle()
                    .fill(.bar)
                    .frame(height: height)
                    .overlay {
                        Text("Видео не выбрано")
                            .font(.title)
                    }
            }
        }
    }
    
    private var actionButton: some View {
        Group {
            if viewModel.showSuccessMessage {
                VStack(spacing: space) {
                    Button("Выбрать новое видео") {
                        viewModel.showSuccessMessage = false
                        viewModel.videoURL = nil
                        viewModel.showVideoPicker = true
                    }
                    
                    Text("Видео успешно сохранено в галерею!")
                        .foregroundColor(.green)
                        .font(.headline)
                }
            } else if viewModel.isProcessing {
                ProgressView("Обработка...")
                    .controlSize(.extraLarge)
            } else if viewModel.videoURL != nil {
                Button("Обработать видео") {
                    Task {
                        await viewModel.processVideo()
                    }
                }
            } else {
                Button("Выбрать видео") {
                    viewModel.showVideoPicker = true
                }
                .opacity(viewModel.isLoading ? 0 : 1)
            }
        }
    }
}

#Preview {
    MainView()
}
