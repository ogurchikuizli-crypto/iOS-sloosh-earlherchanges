import SwiftUI

// MARK: - Suggest Logo Sheet

struct SuggestLogoSheet: View {
    let details: MediaDetailsDto
    @Environment(\.dismiss) private var dismiss

    @State private var logos: [MediaImageItemDto] = []
    @State private var selectedLogoUrl: String? = nil
    @State private var commentText: String = ""
    @State private var selectedLanguageFilter: String = "ALL"
    @State private var isLoading: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var errorMessage: String? = nil

    private var effectiveBackdropUrl: String? {
        details.displayBackdropUrl ?? details.backdrop
    }

    private var currentLogoUrl: String? {
        details.displayLogoUrl ?? details.logo
    }

    private var effectiveId: String {
        if let tmdb = details.externalIds?.tmdb ?? details.ids?.tmdb, tmdb > 0 {
            return "\(tmdb)"
        }
        if let kp = details.externalIds?.kp ?? details.ids?.kp, kp > 0 {
            return "kp_\(kp)"
        }
        return details.id ?? ""
    }

    private var mediaType: String {
        let isTv = details.type?.lowercased() == "tv" || (details.seasons != nil && !(details.seasons?.isEmpty ?? true))
        return isTv ? "tv" : "movie"
    }

    private var filteredLogos: [MediaImageItemDto] {
        if selectedLanguageFilter == "ALL" {
            return logos
        }
        return logos.filter { item in
            let lang = (item.iso6391 ?? item.iso_639_1 ?? "").uppercased()
            if selectedLanguageFilter == "NONE" {
                return lang.isEmpty || lang == "XX"
            }
            return lang == selectedLanguageFilter
        }
    }

    private var availableLanguages: [String] {
        var set = Set<String>()
        for l in logos {
            let lang = (l.iso6391 ?? l.iso_639_1 ?? "").uppercased()
            if !lang.isEmpty && lang != "XX" {
                set.insert(lang)
            }
        }
        var list = ["ALL"]
        if set.contains("RU") { list.append("RU") }
        if set.contains("EN") { list.append("EN") }
        for other in set.sorted() where other != "RU" && other != "EN" {
            list.append(other)
        }
        list.append("NONE")
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 1. Live Preview on Backdrop
                    livePreviewSection
                        .padding(.horizontal, 16)

                    // 2. Language Filters
                    if !availableLanguages.isEmpty {
                        languageFilterSection
                    }

                    // 3. Available TMDB Logos Grid
                    logosGridSection
                        .padding(.horizontal, 16)

                    // 4. Optional Comment Field
                    commentSection
                        .padding(.horizontal, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Предложить логотип")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .glassForeground()
                    }
                    .tint(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submitSuggestion() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Text("Отправить")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(selectedLogoUrl != nil ? Color.green : Color.white.opacity(0.4))
                        }
                    }
                    .disabled(selectedLogoUrl == nil || isSubmitting)
                    .tint(.white)
                }
            }
            .task {
                if let preloaded = details.availableLogos, !preloaded.isEmpty {
                    self.logos = preloaded
                }
                await loadLogos()
            }
            .alert("Предложение отправлено", isPresented: $showSuccessAlert) {
                Button("ОК") {
                    dismiss()
                }
            } message: {
                Text("Спасибо! Мы проверим предложенный логотип и обновим оформление.")
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground { Color.clear.glassEffect(in: .rect) }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Live Preview Section

    private var livePreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Предпросмотр")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ZStack(alignment: .bottomLeading) {
                // Backdrop
                if let bg = effectiveBackdropUrl, let url = URL(string: bg) {
                    AsyncCachedImage(url: url) {
                        Color.black.opacity(0.3)
                    } content: { img in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } fallback: {
                        Color.black.opacity(0.3)
                    }
                    .frame(height: 180)
                    .clipped()
                } else {
                    Color.black.opacity(0.4)
                        .frame(height: 180)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Logo Overlay
                let previewLogo = selectedLogoUrl ?? currentLogoUrl
                if let logoStr = previewLogo, let lUrl = URL(string: logoStr) {
                    AsyncCachedImage(url: lUrl) {
                        ProgressView()
                            .controlSize(.small)
                    } content: { img in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 60)
                            .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 2)
                    } fallback: {
                        Text(details.title ?? "Без логотипа")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(16)
                } else {
                    Text(details.title ?? "Без логотипа")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(16)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Language Filters

    private var languageFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableLanguages, id: \.self) { lang in
                    let title: String = {
                        switch lang {
                        case "ALL": return "Все"
                        case "RU": return "🇷🇺 RU"
                        case "EN": return "🇬🇧 EN"
                        case "NONE": return "Без текста"
                        default: return lang
                        }
                    }()
                    let isSelected = selectedLanguageFilter == lang

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedLanguageFilter = lang
                    } label: {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.green.opacity(0.3) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.green : Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Logos Grid

    private var logosGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Выберите подходящий логотип")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("\(filteredLogos.count) шт.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            if filteredLogos.isEmpty && !isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Логотипы не найдены в TMDB")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(filteredLogos) { item in
                        logoCell(item)
                    }
                }
            }
        }
    }

    private func logoCell(_ item: MediaImageItemDto) -> some View {
        let isSelected = selectedLogoUrl == item.url
        let isCurrent = currentLogoUrl == item.url

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if selectedLogoUrl == item.url {
                selectedLogoUrl = nil
            } else {
                selectedLogoUrl = item.url
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    if let u = URL(string: item.url) {
                        AsyncCachedImage(url: u) {
                            ProgressView().controlSize(.small)
                        } content: { img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 50)
                        } fallback: {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                    }

                    // Metadata row
                    HStack(spacing: 4) {
                        if let lang = item.iso6391 ?? item.iso_639_1, !lang.isEmpty {
                            Text(lang.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Spacer()
                        if let w = item.width, let h = item.height {
                            Text("\(w)x\(h)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? Color.green : (isCurrent ? Color.blue.opacity(0.5) : Color.white.opacity(0.12)),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                        .padding(6)
                } else if isCurrent {
                    Text("Текущий")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comment Section

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Комментарий (необязательно)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("Например: текущее лого на английском или обрезано", text: $commentText)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func loadLogos() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let res = try await MoviesApi.shared.getMediaImages(id: effectiveId, type: mediaType)
            if let incoming = res.data?.logos, !incoming.isEmpty {
                var merged = incoming
                for existing in self.logos {
                    if !merged.contains(where: { $0.url == existing.url }) {
                        merged.append(existing)
                    }
                }
                self.logos = merged
            }
        } catch {
            print("[SuggestLogoSheet] loadLogos error: \(error)")
        }
    }

    private func submitSuggestion() async {
        guard let suggested = selectedLogoUrl else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await LogoReportsRepository.shared.submitReport(
                mediaId: details.id ?? effectiveId,
                mediaTitle: details.title ?? details.originalTitle ?? "Фильм",
                mediaType: mediaType,
                kpId: details.externalIds?.kp ?? details.ids?.kp,
                tmdbId: details.externalIds?.tmdb ?? details.ids?.tmdb,
                currentLogoUrl: currentLogoUrl,
                suggestedLogoUrl: suggested,
                comment: commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : commentText
            )
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
