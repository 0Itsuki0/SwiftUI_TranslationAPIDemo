//
//  CustomTranslation.swift
//  TranslationAPIDemo
//
//  Created by Itsuki on 2026/01/05.
//

import NaturalLanguage
import SwiftUI
import Translation


class CustomTranslationManager {
    static var supportedLanguages: [Locale.Language] {
        get async {
            return await self.languageAvailability.supportedLanguages
        }
    }

    static let languageAvailability = LanguageAvailability()

    private init() {}

    static func checkLanguageAvailability(
        source: Locale.Language,
        to target: Locale.Language?
    ) async throws {
        // Checks for the installation of a specific language pairing and whether it’s ready for translation.
        // The target language you want to translate content into. When set to nil, the system picks an appropriate target based on the person’s preferred languages and returns the status for those languages.
        // The framework doesn’t support translating from and to the same language. For example, you can’t translate from English (US) to English (UK).
        let status = await self.languageAvailability.status(
            from: source,
            to: target
        )
        try self.checkStatus(status)
        return
    }

    static func checkLanguageAvailability(
        text: String,
        to target: Locale.Language?
    ) async throws {
        // Use this function when you don’t know the source language and want the framework to attempt a translation based on the sample text you pass in.
        //  the system automatically tries to detect the language of the text you pass in. If it can’t, it throws a TranslationError.
        // For best results in automatic language detection, pass in a sample string of at least 20 characters in length.
        // we can also get the language ourselves with NLLanguageRecognizer
        let status = try await self.languageAvailability.status(
            for: text,
            to: target
        )
        try self.checkStatus(status)
        return
    }

    private static func checkStatus(_ status: LanguageAvailability.Status)
        throws
    {
        switch status {
        case .installed, .supported:
            return
        case .unsupported:
            throw TranslationError.unsupportedLanguagePairing
        @unknown default:
            throw TranslationError.internalError
        }
    }

    static func detectDominantLanguage(_ text: String) async -> String? {
        let languageRecognizer = NLLanguageRecognizer()
        languageRecognizer.processString(text)
        // Get the most likely language
        let dominantLanguage = languageRecognizer.dominantLanguage
        if let dominantLanguage = dominantLanguage {
            return dominantLanguage.rawValue
        }
        return nil
    }
}

struct CustomTranslationDemo: View {
    @State private var showConfigurationSheet: Bool = false

    @State private var supportedLanguages: [Locale.Language] = []
    @State private var sourceLanguage: Locale.Language?
    @State private var targetLanguage: Locale.Language?

    @State private var translatedTexts: [String] = []
    @State private var error: Error?

    @State private var configuration: TranslationSession.Configuration?
    // keep a local reference to the session because the translationTask will not run twice with the same configuration.
    // even if we set configuration back to nil and then back to the same value, ie: same target and source language.
    //
    // another option will be to call invalidate() on TranslationSession.Configuration so that  the translationTask(_:action:) function will call its action closure and translate the content again.
    @State private var session: TranslationSession?
    @State private var batch: Bool = false

    private let texts = ["I love pikachu", "Pikachu is the best!"]

    var body: some View {
        List {
            Section {
                Text(
                    """
                    - Translate with `TranslationSession`
                    - Custom UI, single Text, Multiple Texts
                    - Will **NOT** work on simulators

                    Careful Points:
                    - `TranslationSession` will no be created twice with the same `Configuration`, even after setting the configuration back to `nil` once. Make sure to save it as a state.
                    - When trying to define languages ahead of time, make sure that the ones defined, for example, using `Locale.current.language` is one of the supported ones. Sometimes, the language itself might be supported, but in a different region, for example, `US` instead of `JP`
                    """
                )
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
            }

            if let error {
                Section {
                    Text(error.localizedDescription)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.red)
                }
            }

            Section("Original") {
                ForEach(texts, id: \.self) { text in
                    Text(verbatim: text)
                }

                Button(
                    action: {
                        showConfigurationSheet = true
                    },
                    label: {
                        Text("Configure Language")
                    }
                )

            }

            Section {
                Toggle(
                    isOn: $batch,
                    label: {
                        Text("Batch")
                    }
                )
            }

            Section {
                Button(
                    action: {
                        self.error = nil
                        self.translatedTexts = []
                        if let session = self.session,
                            session.sourceLanguage == self.sourceLanguage,
                            session.targetLanguage == self.targetLanguage
                        {
                            Task {
                                await self.translate(session)
                            }
                        } else {
                            self.configuration = .init(
                                source: sourceLanguage,
                                target: targetLanguage
                            )
                            self.session = nil
                        }
                    },
                    label: {

                        Text(self.batch ? "Translate All" : "Translate First")
                    }
                )
                .listRowInsets(.all, 0)
                .listRowBackground(Color.clear)
                .buttonSizing(.flexible)
                .buttonStyle(.borderedProminent)
                // configuration: A configuration for a TranslationSession. When this configuration is non-nil and changes, the action runs providing an instance of TranslationSession to perform translations.
                .translationTask(
                    configuration,
                    action: { session in
                        await self.translate(session)
                    }
                )
            }

            if !translatedTexts.isEmpty {
                Section("Translated") {

                    ForEach(translatedTexts, id: \.self) { translatedText in
                        Text(verbatim: translatedText)
                    }
                }
            }

        }
        .navigationTitle("Custom Translation")
        .navigationBarTitleDisplayMode(.large)
        .task {
            self.supportedLanguages =
                await CustomTranslationManager.supportedLanguages
            guard
                let languageIdentifier =
                    await CustomTranslationManager.detectDominantLanguage(
                        self.texts.joined(separator: "\n")
                    )
            else {
                return
            }
            // not using the following because the languageIdentifier will not contain script information and therefore does not necessarily match the supportedLanguages
            // Locale.Language.init(identifier: languageIdentifier)
            if let first = self.supportedLanguages.first(where: {
                $0.languageCode?.identifier.contains(languageIdentifier) == true
            }) {
                self.sourceLanguage = first
            }

            // Locale.current.language may have a different region that the supportedLanguages, for example, for language code en, it might have a region JP, but the one available will be US
            guard
                let preferredTargetLanguage = Locale.preferredLanguages.map({
                    Locale.Language(identifier: $0)
                }).first(where: {
                    $0.languageCode != self.sourceLanguage?.languageCode
                })
            else {
                return
            }
            // perfect match
            if let first = self.supportedLanguages.first(where: {
                $0 == preferredTargetLanguage
            }) {
                self.targetLanguage = first
            }
            
            // only language code
            if let targetLanguageCode = preferredTargetLanguage.languageCode,
                let first = self.supportedLanguages.first(where: {
                    $0.languageCode == targetLanguageCode
                })
            {
                self.targetLanguage = first
            }
        }
        .sheet(
            isPresented: $showConfigurationSheet,
            content: {
                ConfigurationSheet(
                    supportedLanguages: $supportedLanguages,
                    sourceLanguage: $sourceLanguage,
                    targetLanguage: $targetLanguage,
                    text: self.texts.joined(separator: "\n")
                )
            }
        )

    }

    private func translate(_ session: TranslationSession) async {
        // keep a local reference to the session because the translationTask will not run twice with the same configuration.
        // even if we set configuration back to nil and then back to the same value, ie: same target and source language.
        //
        // another option will be to call invalidate() on TranslationSession.Configuration so that  the translationTask(_:action:) function will call its action closure and translate the content again.

        self.session = session

        do {
            // Asks for permission to download translation languages without doing any translations.
            // If you call this function when the sourceLanguage is nil, it throws unableToIdentifyLanguage error, since there’s no sample text to identify which source language to use for translation.
            // Optional. If we don't call this, the system will still present the download UI when we call translate(:) or translations(from:)
            if sourceLanguage != nil {
                try await session.prepareTranslation()
            }
            if batch == false, let first = self.texts.first {
                let response = try await session.translate(
                    first
                )
                self.translatedTexts = [response.targetText]
            } else {
                let requests: [TranslationSession.Request] =
                    self.texts.map({
                        .init(sourceText: $0)
                    })
                // we can also use translate(batch: [TranslationSession.Request]) -> TranslationSession.BatchResponse
                // ti Translate multiple strings of text of the same language, returning a sequence of responses as they're available.
                let response = try await session.translations(
                    from: requests
                )
                self.translatedTexts = response.map(
                    \.targetText
                )
            }
        } catch (let error) {
            self.error = error
        }

    }
}

private struct ConfigurationSheet: View {
    @Binding var supportedLanguages: [Locale.Language]
    @Binding var sourceLanguage: Locale.Language?
    @Binding var targetLanguage: Locale.Language?

    var text: String

    @State private var error: Error?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Section {
                        Text(error.localizedDescription)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    languagePicker(selection: $sourceLanguage, title: "Source")
                    languagePicker(selection: $targetLanguage, title: "Target")
                }

                Section {
                    Button(
                        action: {
                            Task {
                                do {
                                    if let sourceLanguage {
                                        try await CustomTranslationManager
                                            .checkLanguageAvailability(
                                                source: sourceLanguage,
                                                to: targetLanguage
                                            )
                                    } else {
                                        try await CustomTranslationManager
                                            .checkLanguageAvailability(
                                                text: text,
                                                to: targetLanguage
                                            )
                                    }
                                    self.dismiss()
                                } catch (let error) {
                                    self.error = error
                                }
                            }
                        },
                        label: {
                            Text("Confirm")
                                .padding(.vertical, 4)
                                .fontWeight(.semibold)
                        }
                    )
                    .listRowInsets(.all, 0)
                    .listRowBackground(Color.clear)
                    .buttonSizing(.flexible)
                    .buttonStyle(.borderedProminent)
                }
            }
            .contentMargins(.top, 16)
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(
                    placement: .topBarTrailing,
                    content: {
                        Button(
                            action: {
                                self.dismiss()
                            },
                            label: {
                                Image(systemName: "xmark")
                            }
                        )
                        .buttonStyle(.borderedProminent)
                    }
                )
            })
        }
    }

    @ViewBuilder
    private func languagePicker(
        selection: Binding<Locale.Language?>,
        title: String
    )
        -> some View
    {
        Picker(title, selection: selection) {
            Text("Auto Detect")
                .tag(nil as Locale.Language?)

            ForEach(
                supportedLanguages,
                id: \.maximalIdentifier,
                content: { language in
                    Text(language.stringRepresentation)
                        .tag(language)
                }
            )
        }
    }
}

extension Locale.Language {
    var stringRepresentation: String {
        if let languageCode, let region {
            return "\(languageCode)-\(region)"
        }
        return self.minimalIdentifier
    }
}
