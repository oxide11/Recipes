import SwiftUI
import WebKit

// MARK: - Recipe Browser View

/// In-app web browser for finding and importing recipes.
/// Shows a WKWebView with a bottom toolbar containing an "Import This Recipe" button.
/// When the user taps Import, the current page URL is returned via the onImport callback.
struct RecipeBrowserView: View {
    let onImport: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var webState = WebViewState()
    @State private var addressText = "https://"
    @State private var isEditingAddress = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Address bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.footnote)

                    TextField("Search or enter website", text: $addressText)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { loadURL() }
                        .font(.footnote)

                    if webState.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if !addressText.isEmpty {
                        Button {
                            addressText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Web view
                WebView(state: webState)
                    .ignoresSafeArea(edges: .bottom)

                Divider()

                // Bottom toolbar
                HStack(spacing: 0) {
                    // Back
                    Button {
                        webState.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!webState.canGoBack)

                    // Forward
                    Button {
                        webState.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!webState.canGoForward)

                    Spacer()

                    // Import button
                    Button {
                        onImport(webState.currentURL)
                        dismiss()
                    } label: {
                        Label("Import This Recipe", systemImage: "arrow.down.doc.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.gradient, in: Capsule())
                    }
                    .disabled(webState.currentURL.isEmpty || webState.currentURL == "about:blank")

                    Spacer()

                    // Reload
                    Button {
                        webState.reload()
                    } label: {
                        Image(systemName: webState.isLoading ? "xmark" : "arrow.clockwise")
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Browse Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: webState.currentURL) { _, url in
            if !url.isEmpty && !isEditingAddress {
                addressText = url
            }
        }
    }

    private func loadURL() {
        var urlString = addressText.trimmingCharacters(in: .whitespaces)
        // If it looks like a search term rather than a URL, use Google
        if !urlString.contains(".") || urlString.contains(" ") {
            let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
            urlString = "https://www.google.com/search?q=\(encoded)+recipe"
        } else if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        webState.load(urlString)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Web View State

@Observable
final class WebViewState {
    var currentURL: String = ""
    var isLoading: Bool = false
    var canGoBack: Bool = false
    var canGoForward: Bool = false

    weak var webView: WKWebView?

    func load(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() {
        if isLoading {
            webView?.stopLoading()
        } else {
            webView?.reload()
        }
    }
}

// MARK: - WKWebView Wrapper

struct WebView: UIViewRepresentable {
    let state: WebViewState

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        state.webView = webView

        // Load a recipe-search-friendly default page
        if let url = URL(string: "https://www.google.com/search?q=recipes") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let state: WebViewState

        init(state: WebViewState) {
            self.state = state
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.currentURL = webView.url?.absoluteString ?? ""
            state.canGoBack = webView.canGoBack
            state.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.isLoading = false
        }
    }
}
