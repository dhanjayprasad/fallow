// OllamaModels.swift
// Detects locally available Ollama models for kwaainet serve.
// Part of Fallow. MIT licence.

import Foundation
import OSLog

package enum OllamaModels {

    /// Returns the best available Ollama model for the local machine,
    /// preferring smaller/faster models for low-RAM systems.
    /// Returns nil if no Ollama models are installed.
    package static func bestAvailable() -> String? {
        let all = available()
        if all.isEmpty { return nil }

        // Prefer smaller models for safety on low-RAM Macs.
        // Order: known fast/small families first, then any available.
        let preferredOrder = ["llama3.2", "gemma3", "qwen2.5", "phi", "mistral", "llama3.1", "llama3", "gemma4"]
        for prefix in preferredOrder {
            if let match = all.first(where: { $0.hasPrefix("\(prefix):") }) {
                return match
            }
        }
        return all.first
    }

    /// Returns all locally installed Ollama models as "name:tag" strings.
    package static func available() -> [String] {
        let fm = FileManager.default
        let library = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".ollama/models/manifests/registry.ollama.ai/library")

        guard let modelDirs = try? fm.contentsOfDirectory(atPath: library.path) else {
            return []
        }

        var result: [String] = []
        for modelName in modelDirs where !modelName.hasPrefix(".") {
            let modelPath = library.appendingPathComponent(modelName)
            guard let tags = try? fm.contentsOfDirectory(atPath: modelPath.path) else { continue }
            for tag in tags where !tag.hasPrefix(".") {
                result.append("\(modelName):\(tag)")
            }
        }
        return result.sorted()
    }
}
