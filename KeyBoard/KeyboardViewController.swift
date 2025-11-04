//
//  KeyboardViewController.swift
//  KeyBoard
//
//  Created by koteczek on 10/22/25.
//

import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    
    private var hostingController: UIHostingController<KeyboardView>?
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // --- HAPTICS NOTE ---
        // Won't work in sandbox (if ur using xcode to target ur phone for dev builds)
        // ---
        
        setupKeyboard()
    }
    
    private func setupKeyboard() {
        let keyboardView = KeyboardView(textDocumentProxy: textDocumentProxy, needsInputModeSwitchKey: needsInputModeSwitchKey, switchAction: { [weak self] in
            self?.handleInputModeList(from: self?.view ?? UIView(), with: UIEvent())
        })
        
        let hostingController = UIHostingController(rootView: keyboardView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
    }
}

// MARK: - SwiftUI Keyboard View

struct KeyboardView: View {
    let textDocumentProxy: UITextDocumentProxy
    let needsInputModeSwitchKey: Bool
    let switchAction: () -> Void
    
    // appstorage stuff (have to hardcode because apparently base views make init a nightmare
//    private let appGroupID = "group.com.koteczek.ShavianKey"
//    private let sharedDefaults = UserDefaults(suiteName: "group.com.koteczek.ShavianKey")!
    
    // BIG UI DECISIONS CONTROLLED WITH SHARED SETTINGS
    // predictions & autocorrect
    @AppStorage("proofing", store: UserDefaults(suiteName: "group.com.koteczek.ShavianKey")!) var proofing: Bool = true
    // transliterate
    @AppStorage("transliteration", store: UserDefaults(suiteName: "group.com.koteczek.ShavianKey")!) var transliteration: Bool = true
    @AppStorage("left_delete", store: UserDefaults(suiteName: "group.com.koteczek.ShavianKey")!) var left_delete: Bool = true
    
    // key width
    @State private var hz_padding: CGFloat = 6
    @State private var top_padding: CGFloat = 0
    @State private var spacing: CGFloat = 4
    @State private var keyWidth1x: CGFloat = 10
    @State private var keyWidth2x: CGFloat = 10
    
    @State private var currentMode: KeyboardMode = .shavian1
    @State private var showingModePicker = false
    @State private var lastTapTime: Date = Date.distantPast
    @State private var lastTapButton: String = ""
    @State private var longPressLocation: CGPoint = .zero
    @State private var isDeleting = false
    @State private var deleteTimer: Timer?
    
    // Prediction State
    @State private var currentWord: String = ""
    @State private var predictions: [String] = []
    @State private var predictionFlags: [Bool] = [false, false]
    @State private var dictButtonState: DictButtonState = .plus
    
    @State private var autoTranslate: Bool = false
    @State private var transliterations: [String] = []

    enum DictButtonState {
        case plus         // Word not in dict
        case checked      // Word in dict
        case pendingDelete  // user tapped checked, show 'x' as confirmation
    }
    
    
    // switch activate on tapoff
    @State private var switchButtonFrame: CGRect = .zero
    @State private var buttonFrames: [PickerMode: CGRect] = [:]
    @State private var highlightedMode: PickerMode? = nil
    @State private var gestureDragLocation: CGPoint? = nil
    @State private var longPressTimer: Timer? = nil
    
    // drag
    @State private var dragStartLocation: CGPoint? = nil
    @State private var lastDragX: CGFloat = 0
    
    @Environment(\.colorScheme) var colorScheme
    
    enum KeyboardMode: String {
        case shavian1 = "s1"
        case shavian2 = "s2"
        case symbols1 = "n1"
        case symbols2 = "n2"
        case qwerty = "q"
    }
    
    // for holding switch
    enum PickerMode: String, CaseIterable {
        case shavian1 = "s1"
        case symbols1 = "n1"
        case qwerty = "q"
        
        var displayName: String {
            switch self {
            case .shavian1: return "𐑖𐑷-1"
            case .symbols1: return "123"
            case .qwerty: return "qwe"
            }
        }
        
        var toKeyboardMode: KeyboardMode {
            switch self {
            case .shavian1: return .shavian1
            case .symbols1: return .symbols1
            case .qwerty: return .qwerty
            }
        }
    }
    
    var body: some View {
        ZStack {
            keyboardLayout
                .padding(.horizontal, hz_padding)
                .padding(.top, top_padding)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                updateKeyWidths(for: geo.size.width)
                            }
                            .onChange(of: geo.size.width) { _, newWidth in
                                updateKeyWidths(for: newWidth)
                            }
                    }
                )
            
            if showingModePicker {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                modePickerOverlay(
                    buttonFrames: $buttonFrames,
                    highlightedMode: highlightedMode
                )
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var keyboardLayout: some View {
        switch currentMode {
        case .shavian1:
            shavianLayout(mode: .shavian1)
        case .shavian2:
            shavianLayout(mode: .shavian2)
        case .symbols1:
            symbolsLayout(mode: .symbols1)
        case .symbols2:
            symbolsLayout(mode: .symbols2)
        case .qwerty:
            qwertyLayout()
        }
    }
    
    private func modePickerOverlay(
        buttonFrames: Binding<[PickerMode: CGRect]>,
        highlightedMode: PickerMode?
    ) -> some View {
        
        GeometryReader { geometry in
            VStack(spacing: 6) {
                ForEach(PickerMode.allCases, id: \.self) { mode in
                    
                    Text(mode.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 70, height: 32)
                        .background(
                            // current selection (is your finger on this "button" (textview plus drag gesture is nightmarish, hate that it works)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(highlightedMode == mode ? Color.blue : Color.clear)
                                .background(.ultraThinMaterial)
                        )
                        .cornerRadius(5)
                        .background(
                            GeometryReader { btnGeo in
                                Color.clear
                                    .onAppear {
                                        buttonFrames.wrappedValue[mode] = btnGeo.frame(in: .global)
                                    }
                                    .onChange(of: btnGeo.frame(in: .global)) { _, newFrame in
                                        buttonFrames.wrappedValue[mode] = newFrame
                                    }
                            }
                        )
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            )
            .position(x: 55, y: 75)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Shavian Layout
    
    private func shavianLayout(mode: KeyboardMode) -> some View {
        let keys: [String]
        if mode == .shavian1 {
            keys = shavianMap
        } else { // .shavian2
            // Create the alternate key set by mapping over the base map
            keys = shavianMap.map { pairDict[from: $0] ?? $0 }
        }
        
        return VStack(spacing: 6) {
            
            // Prediction and autocorrect
            // I'm leaning towards keeping all UI in the view controller? so the logic for display...
            
            predictionBar
            
            /*
             SW1a:
             𐑐    𐑑    𐑒    𐑓    𐑔    𐑕    𐑖    𐑗    𐑘    𐑙
             𐑤    𐑯    𐑦    𐑲    𐑨    𐑩    𐑳    𐑵    𐑬    𐑭
             􀣊    𐑸    𐑺       􁁺       􀆛        𐑼    𐑿    ·

             SW1b:
             𐑚    𐑛    𐑜    𐑝    𐑞    𐑟    𐑠    𐑡    𐑢    𐑣
             𐑮    𐑥    𐑰    𐑱    𐑧    𐑪    𐑴    𐑫    𐑶    𐑷
             􀣊    𐑹    𐑻       􁁺       􀆛        𐑽    𐑾    ⸰⁠⁠
             
             */
            // Row 1
            HStack(spacing: spacing) {
                ForEach(0..<10, id: \.self) { i in
                    keyButton(keys[i], alternateKey: mode == .shavian1 ? pairDict[from: keys[i]] : pairDict[to: keys[i]])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
            
            // Row 2
            HStack(spacing: spacing) {
                ForEach(10..<20, id: \.self) { i in
                    keyButton(keys[i], alternateKey: mode == .shavian1 ? pairDict[from: keys[i]] : pairDict[to: keys[i]])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
            
            // Row 3: THIS WAS REDONE, hopefully working
            HStack(spacing: spacing) {
                switchButton()
                    .frame(width: keyWidth1x)
                
                keyButton(keys[20], alternateKey: mode == .shavian1 ? pairDict[from: keys[20]] : pairDict[to: keys[20]])
                    .frame(width: keyWidth1x)
                keyButton(keys[21], alternateKey: mode == .shavian1 ? pairDict[from: keys[21]] : pairDict[to: keys[21]])
                    .frame(width: keyWidth1x)
                
                if left_delete {
                    deleteKeyButton()
                        .frame(width: keyWidth2x)
                    spaceKeyButton()
                        .frame(width: keyWidth2x)
                } else {
                    spaceKeyButton()
                        .frame(width: keyWidth2x)
                    deleteKeyButton()
                        .frame(width: keyWidth2x)
                }
                
                keyButton(keys[22], alternateKey: mode == .shavian1 ? pairDict[from: keys[22]] : pairDict[to: keys[22]])
                    .frame(width: keyWidth1x)
                keyButton(keys[23], alternateKey: mode == .shavian1 ? pairDict[from: keys[23]] : pairDict[to: keys[23]])
                    .frame(width: keyWidth1x)
                keyButton(keys[24], alternateKey: mode == .shavian1 ? pairDict[from: keys[24]] : pairDict[to: keys[24]])
                    .frame(width: keyWidth1x)
            }
            .frame(height: 42)
        }
    }
    
    // MARK: - Symbols Layout
    
    private func symbolsLayout(mode: KeyboardMode) -> some View {
        let keys: [String]
        if mode == .symbols1 {
            keys = symbolsMap
        } else { // .symbols2
            keys = symbolsMap.map { pairDict[from: $0] ?? $0 }
        }
        
        return VStack(spacing: 6) {
            
            predictionBar
            
            
            /*
             yes starting with 0 was a purposeful choice
             SW2a:
             0    1    2    3    4    5    6    7    8    9
             ~    =    /    -    :    {    [    (    <    «
             􀣊    .    ,       􁁺       􀆛        !    ?    ‘

             SW2a:
             °    !    @    #    $    %    ^    &    *    |
             ☭    +    \    _    ;    }    ]    )    >    »
             􀣊    .    ,       􁁺       􀆛        !    ?    `

             */
            // Row 1
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { i in
                    keyButton(keys[i], alternateKey: mode == .symbols1 ? pairDict[from: keys[i]] : pairDict[to: keys[i]])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
            
            // Row 2
            HStack(spacing: 4) {
                ForEach(10..<20, id: \.self) { i in
                    // FIX 2: Correct alternateKey logic
                    keyButton(keys[i], alternateKey: mode == .symbols1 ? pairDict[from: keys[i]] : pairDict[to: keys[i]])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
            
            // Row 3: REFACTORED
            HStack(spacing: 4) {
                switchButton()
                    .frame(width: keyWidth1x)
                
                keyButton(keys[20], alternateKey: mode == .symbols1 ? pairDict[from: keys[20]] : pairDict[to: keys[20]])
                    .frame(width: keyWidth1x)
                keyButton(keys[21], alternateKey: mode == .symbols1 ? pairDict[from: keys[21]] : pairDict[to: keys[21]])
                    .frame(width: keyWidth1x)
                
                if left_delete {
                    deleteKeyButton()
                        .frame(width: keyWidth2x)
                    spaceKeyButton()
                        .frame(width: keyWidth2x)
                } else {
                    spaceKeyButton()
                        .frame(width: keyWidth2x)
                    deleteKeyButton()
                        .frame(width: keyWidth2x)
                }
                
                keyButton(keys[22], alternateKey: mode == .symbols1 ? pairDict[from: keys[22]] : pairDict[to: keys[22]])
                    .frame(width: keyWidth1x)
                keyButton(keys[23], alternateKey: mode == .symbols1 ? pairDict[from: keys[23]] : pairDict[to: keys[23]])
                    .frame(width: keyWidth1x)
                keyButton(keys[24], alternateKey: mode == .symbols1 ? pairDict[from: keys[24]] : pairDict[to: keys[24]])
                    .frame(width: keyWidth1x)
            }
            .frame(height: 42)
        }
    }
    
    // MARK: - QWERTY Layout
    
    // INCREDIBLY BROKEN AND USELESS BUT NOT GONNA BOTHER FIXING UNTIL I REFACTOR FROM
    // ARRAY BASED LAYOUT TO DICT BASED (paired characters for mapping alternates, including
    // qwerty => QWERTY and # => $)
    private func qwertyLayout() -> some View {
        VStack(spacing: 6) {
            
            if transliteration {
                transliterationBar
            }
            
            
            // Row 1
            HStack(spacing: spacing) {
                ForEach(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], id: \.self) { key in
                    keyButton(key, alternateKey: pairDict[to: key])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
            
            // Row 2
            HStack(spacing: spacing) {
                switchButton()
                    .frame(width: keyWidth1x)
                ForEach(["a", "s", "d", "f", "g", "h", "j", "k", "l"], id: \.self) { key in
                    keyButton(key, alternateKey: pairDict[to: key])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
            
            // Row 3
            HStack(spacing: spacing) {
                shiftButton()
                    .frame(width: keyWidth1x) // Use @State var
                ForEach(["z", "x", "c", "v", "b", "n", "m"], id: \.self) { key in
                    keyButton(key, alternateKey: pairDict[to: key])
                        .frame(width: keyWidth1x) // Use @State var
                }
                deleteButton()
                    .frame(width: keyWidth1x) // Use @State var
            }
            .frame(height: 42)
        }
    }
    
    // MARK: - Prediction Bar
        
    @ViewBuilder
    private var predictionBar: some View {
        if proofing {
            HStack(spacing: 0) {
                // Left suggestion (word3)
                predictionButton(for: 2)
                
                verticalDivider
                
                // Center suggestion (word1 - autocorrect)
                predictionButton(for: 0, highlighted: predictionFlags.first ?? false)
                
                verticalDivider
                
                // Right suggestion (word2)
                predictionButton(for: 1)
                
                verticalDivider
                
                // Dictionary status button
                dictionaryButton.frame(minWidth: 42)
            }
            .frame(height: 38)
            .padding(.horizontal, 4)
            .background(.clear)
        }
    }
    
    @ViewBuilder
    private func predictionButton(for index: Int, highlighted: Bool = false) -> some View {
        let text = (predictions.count > index) ? predictions[index] : ""
        
        Button(action: {
            guard !text.isEmpty else { return }
            replaceCurrentWord(with: text, addSpace: true)
        }) {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(highlighted ? (colorScheme == .dark ? .black : .white) : (colorScheme == .dark ? .white : .black))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(highlighted ? .blue : .clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
    }
    
    @ViewBuilder
    private var dictionaryButton: some View {
        let wordExists = predictionFlags.count > 1 ? predictionFlags[1] : false
        
        Button(action: {
            handleDictButtonTap(wordExists: wordExists)
        }) {
            Image(dictButtonImageName(wordExists: wordExists))
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        // Disable if no word is typed
        .disabled(currentWord.isEmpty)
    }
    
    private var verticalDivider: some View {
        Divider()
            .frame(width: 1, height: 20)
            .background(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
    }
    
    // MARK: - Transliteration Bar

    @ViewBuilder
    private var transliterationBar: some View {
        // Check the setting from AppStorage
        if transliteration {
            HStack(spacing: 8) {
                // Autotranslate Icon Button
                Button(action: {
                    autoTranslate.toggle()
                    playHaptic(style: .light)
                }) {
                    Image(colorScheme == .dark ? "translate.dark" : "translate")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .padding(6)
                        .background(
                            // "Liquid glass" glow effect
                            Circle()
                                .fill(Color.blue.opacity(autoTranslate ? 0.3 : 0.0))
                                .animation(.easeInOut, value: autoTranslate)
                        )
                }
                .buttonStyle(.plain)
                
                // Current Word Display
                Text("«\(currentWord)»")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                // Arrow Separator
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))

                // Scrollable Transliteration Buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(transliterations, id: \.self) { shavianWord in
                            Button(action: {
                                replaceCurrentWord(with: shavianWord, addSpace: true)
                                playHaptic(style: .light)
                            }) {
                                Text(shavianWord)
                                    .font(.custom("InterAlia-Regular", size: 18))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(height: 38)
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Key Buttons
    
    private func updateKeyWidths(for width: CGFloat) {
        guard width > 0 else { return }
        
        let widthFrame = width - (hz_padding * 2) // 375 for 12mini, 402 for 17... ANNOYING
        let cellNumber = 10
        let spacers = spacing * CGFloat((cellNumber - 1))
        let keyTotalWidth = widthFrame - spacers
        
        let cellWidth: CGFloat = keyTotalWidth / CGFloat(cellNumber)
        self.keyWidth1x = cellWidth
        self.keyWidth2x = (cellWidth * 2) + spacing
    }
    
    private func keyButton(_ key: String, alternateKey: String?) -> some View {
        Button(action: {
            handleKeyTap(key, altKey: alternateKey)
        }) {
            Text(key)
                .font(key.count == 1 && key.first?.isLetter == true ? .custom("InterAlia-Regular", size: 22) : .system(size: 20)) // not positive interalia is actually being used honestly
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .background(keyButtonStyle)
    }
    
    // DOESN"T WORK ON INIT SOMETIMES NEED TO DEBUG
    private func switchButton() -> some View {
        Image(systemName: "mount")
            .font(.system(size: 16))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(keyButtonStyle)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if self.gestureDragLocation == nil {
                            self.gestureDragLocation = value.startLocation
                            
                            self.buttonFrames.removeAll()
                            
                            self.longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showingModePicker = true
                                }
                            }
                        }

                        self.gestureDragLocation = value.location
                        
                        if showingModePicker {
                            var currentHighlight: PickerMode? = nil
                            
                            for (mode, frame) in buttonFrames {
                                if frame.contains(value.location) {
                                    currentHighlight = mode
                                    break
                                }
                            }
                            
                            if self.highlightedMode != currentHighlight {
                                self.highlightedMode = currentHighlight
                                
                                let generator = UISelectionFeedbackGenerator()
                                generator.prepare()
                                generator.selectionChanged()
                            }
                        }
                    }
                    .onEnded { value in
                        longPressTimer?.invalidate()
                        longPressTimer = nil
                        
                        if showingModePicker {
                            if let mode = highlightedMode {
                                currentMode = mode.toKeyboardMode
                                playHaptic(style: .light)
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingModePicker = false
                            }
                            
                        } else {
                            let distance = hypot(value.translation.width, value.translation.height)
                            if distance < 10 {
                                handleSwitchTap()
                            }
                        }
                        
                        self.gestureDragLocation = nil
                        self.highlightedMode = nil
                        self.buttonFrames.removeAll()
                    }
            )
    }
    
    private func deleteKeyButton() -> some View {
        Image(systemName: "delete.left")
            .font(.system(size: 20))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 42)
            .background(keyButtonStyle)
            .onTapGesture {
                textDocumentProxy.deleteBackward()
                updateSuggestions()
                playHaptic(style: .medium)
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 10, pressing: { isPressing in
                if !isPressing {
                    stopDeletingContinuously()
                    updateSuggestions()
                }
            }, perform: {
                startDeletingContinuously()
            })
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        if self.dragStartLocation == nil {
                            self.dragStartLocation = value.startLocation
                            self.lastDragX = value.startLocation.x
                        }
                        
                        let xDiff = value.location.x - self.lastDragX
                        let cursorMoveThreshold: CGFloat = 20
                        
                        // Move cursor left/right based on drag
                        if abs(xDiff) > cursorMoveThreshold {
                            if xDiff > 0 {
                                textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
                            } else {
                                textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
                            }
                            self.lastDragX = value.location.x
                            let generator = UISelectionFeedbackGenerator()
                            generator.prepare()
                            generator.selectionChanged()
                        }
                    }
                    .onEnded { value in
                        // reset state
                        self.dragStartLocation = nil
                        self.lastDragX = 0
                    }
            )
    }
    
    private func spaceKeyButton() -> some View {
        Image(systemName: "space")
            .font(.system(size: 16))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 42)
            .background(keyButtonStyle)
            .onTapGesture {
                let autotranslateActive = transliteration && autoTranslate && !transliterations.isEmpty
                let autocorrectActive = proofing && (predictionFlags.first ?? false) && !predictions.isEmpty

                if autotranslateActive {
                    replaceCurrentWord(with: transliterations[0], addSpace: true)
                } else if autocorrectActive {
                    replaceCurrentWord(with: predictions[0], addSpace: true)
                } else {
                    insertText(" ")
                    updateSuggestions();
                }

                playHaptic(style: .light)
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let translation = value.translation
                        if abs(translation.height) < 40 && abs(translation.width) > 50 {
                            handleSwipe(translation, velocity: value.predictedEndTranslation)
                        }
                    }
            )
    }
    
    private func shiftButton() -> some View {
        Button(action: {}) {
            Image(systemName: "shift")
                .font(.system(size: 20))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 42)
        //.frame(maxWidth: 45)
        .background(keyButtonStyle)
    }
    
    private func deleteButton() -> some View {
        // QWERTY delete button
        Image(systemName: "delete.left")
            .font(.system(size: 20))
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 42)
            .background(keyButtonStyle)
            .onTapGesture {
                textDocumentProxy.deleteBackward()
                playHaptic(style: .medium)
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 10, pressing: { isPressing in
                if !isPressing {
                    stopDeletingContinuously()
                }
            }, perform: {
                startDeletingContinuously()
            })
    }
    
    // MARK: - Button Styles
    
    private var keyButtonStyle: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.white)
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 0.5, y: 1)
    }
    
    private var accentButtonStyle: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.blue)
            .shadow(color: .black.opacity(0.1), radius: 0.5, y: 1)
    }
    
    // MARK: - Actions
    
    private func proof(word: String) -> ([String], [Bool]) {
        // --- THIS IS A PLACEHOLDER ---
        if word == "𐑐" {
            return (["𐑐𐑰𐑐𐑩𐑤", "𐑐𐑸𐑑", "𐑐𐑱"], [true, false])
        }
        if word == "𐑖" {
            return (["𐑖𐑱", "𐑖𐑷", "𐑖𐑰"], [false, true])
        }
        
        return (["", "", "«\(getCurrentWord())»"], [false, false])
    }
    
    private func add_word(word: String) {
        print("Adding to dict: \(word)")
    }
    
    private func del_word(word: String) {
        print("Deleting from dict: \(word)")
    }
    
    private func getCurrentWord() -> String {
        guard let context = textDocumentProxy.documentContextBeforeInput else { return "" }
        
        if let lastWord = context.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).last {
            return String(lastWord)
        }
        return ""
    }
    
    private func updatePredictions() {
        guard proofing else { return }
        let word = getCurrentWord()
        
        if word == currentWord { return } // No change
        
        self.currentWord = word
        
        if word.isEmpty {
            self.predictions = ["", "", ""]
            self.predictionFlags = [false, false]
            self.dictButtonState = .plus
            return
        }

        let (preds, flags) = proof(word: word)
        
        var displayPreds = preds
        while displayPreds.count < 3 {
            displayPreds.append("")
        }
        
        self.predictions = displayPreds
        self.predictionFlags = flags
        
        // dict button state based on proof() result
        let wordExists = flags.count > 1 ? flags[1] : false
        self.dictButtonState = wordExists ? .checked : .plus
    }
    
    private func replaceCurrentWord(with replacement: String, addSpace: Bool = true) {
        let wordToReplace = getCurrentWord()
        for _ in 0..<wordToReplace.count {
            textDocumentProxy.deleteBackward()
        }
        let textToInsert = addSpace ? replacement + " " : replacement
        insertText(textToInsert)
        updateSuggestions() // Update all suggestion bars after replacement
    }
    
    private func handleDictButtonTap(wordExists: Bool) {
        switch dictButtonState {
        case .plus:
            // didn't exist, adding it
            add_word(word: currentWord)
            dictButtonState = .checked
            playHaptic(style: .medium)
        case .checked:
            // exists, user is flagging for deletion
            dictButtonState = .pendingDelete
            playHaptic(style: .light)
        case .pendingDelete:
            // confirmed deletion
            del_word(word: currentWord)
            dictButtonState = .plus
            playHaptic(style: .medium)
        }
    }
    
    private func dictButtonImageName(wordExists: Bool) -> String {
        switch dictButtonState {
        case .plus:
            return colorScheme == .dark ? "dict.plus.dark" : "dict.plus"
        case .checked:
            return colorScheme == .dark ? "dict.check.dark" : "dict.check"
        case .pendingDelete:
            return colorScheme == .dark ? "dict.x.dark" : "dict.x"
        }
    }
    
    private func updateSuggestions() {
        updatePredictions()
        updateTransliterations()
    }

    private func transliterate(word: String) -> [String] {
        // --- THIS IS A PLACEHOLDER ---
        if word.lowercased() == "hello" {
            return ["𐑣𐑧𐑤𐑴"]
        }
        if word.lowercased() == "world" {
            return ["𐑢𐑻𐑤𐑛", "𐑢𐑻𐑤𐑛"]
        }
        if word.lowercased() == "shavian" {
            return ["·𐑖𐑱𐑝𐑾𐑯", "𐑖𐑱𐑝𐑾𐑯"]
        }

        return []
    }

    private func updateTransliterations() {
        guard transliteration else { return }
        let word = getCurrentWord()

        if word.isEmpty {
            self.transliterations = []
            return
        }

        let results = transliterate(word: word)
        self.transliterations = results
    }
    
    private func handleKeyTap(_ key: String, altKey: String?) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.3 && lastTapButton == key && altKey != nil {
            // double tap for character pair
            textDocumentProxy.deleteBackward()
            insertText(altKey!)
            playHaptic(style: .light)
        } else {
            insertText(key)
            playHaptic(style: .light)
        }
        updateSuggestions()
        lastTapTime = now
        lastTapButton = key
    }
    
    private func handleSwitchTap() {
        playHaptic(style: .light)
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.3 && lastTapButton == "SW" {
            // double tap to switch between shavian and symbols
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                switch currentMode {
                case .shavian1, .shavian2:
                    currentMode = .symbols1
                case .symbols1, .symbols2:
                    currentMode = .shavian1
                case .qwerty:
                    currentMode = .shavian1
                }
            }
        } else {
            // switch between a and b submodes
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                switch currentMode {
                case .shavian1:
                    currentMode = .shavian2
                case .shavian2:
                    currentMode = .shavian1
                case .symbols1:
                    currentMode = .symbols2
                case .symbols2:
                    currentMode = .symbols1
                case .qwerty:
                    currentMode = .shavian1
                }
            }
        }
        
        lastTapTime = now
        lastTapButton = "SW"
    }
    
    private func handleSwipe(_ translation: CGSize, velocity: CGSize) {
        // Swipe right = Enter, Swipe left = Tab
        // threshold needs works
        if abs(translation.width) > 50 {
            if translation.width > 0 {
                insertText("\n")
                playHaptic(style: .light)
            } else {
                insertText("\t")
                playHaptic(style: .light)
            }
        }
    }
    
    private func startDeletingContinuously() {
        guard !isDeleting else { return }
        isDeleting = true
        
        textDocumentProxy.deleteBackward()
        playHaptic(style: .light)
        
        // repeated deletes
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.isDeleting {
                self.textDocumentProxy.deleteBackward()
                self.updateSuggestions()
                self.playHaptic(style: .light)
            } else {
                self.deleteTimer?.invalidate()
                self.deleteTimer = nil
            }
        }
    }
    
    private func stopDeletingContinuously() {
        isDeleting = false
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
    
    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }
    
    private func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Key Data
    
    // pair dict
    
    private let pairDict: BidiMap<String, String> = BidiMap( [
        // shavian pairs
        "𐑐":"𐑚", "𐑑":"𐑛", "𐑒":"𐑜", "𐑓":"𐑝", "𐑔":"𐑞", "𐑕":"𐑟", "𐑖":"𐑠", "𐑗":"𐑡", "𐑘":"𐑢", "𐑙":"𐑣",
        "𐑤":"𐑮", "𐑯":"𐑥", "𐑦":"𐑰", "𐑲":"𐑱", "𐑨":"𐑧", "𐑩":"𐑪", "𐑳":"𐑴", "𐑵":"𐑫", "𐑬":"𐑶", "𐑭":"𐑷",
        "𐑸":"𐑹", "𐑺":"𐑻", "𐑼":"𐑽", "𐑿":"𐑾", "·":"⸰",
        
        // symbols and numbers pairs
        "0":"°", "1":"!", "2":"@", "3":"#", "4":"$", "5":"%", "6":"^", "7":"&", "8":"*", "9":"|",
        "~":"☭", "=":"+", "/":"\\", "-":"_", ":":";", "{":"}", "[":"]", "(":")", "<":">", "«":"»",
        "'":"`",
        
        // qwerty
        "a":"A", "b":"B", "c":"C", "d":"D", "e":"E", "f":"F", "g":"G", "h":"H", "i":"I", "j":"J",
        "k":"K", "l":"L", "m":"M", "n":"N", "o":"O", "p":"P", "q":"Q", "r":"R", "s":"S", "t":"T",
        "u":"U", "v":"V", "w":"W", "x":"X", "y":"Y", "z":"Z"
    ] )!
    
    private let shavianMap = [
        "𐑐", "𐑑", "𐑒", "𐑓", "𐑔", "𐑕", "𐑖", "𐑗", "𐑘", "𐑙",
        "𐑤", "𐑯", "𐑦", "𐑲", "𐑨", "𐑩", "𐑳", "𐑵", "𐑬", "𐑭",
        "𐑸", "𐑺", "𐑼", "𐑿", "·"
    ]
    
    private let symbolsMap: [String] = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "~", "=", "/", "-", ":", "{", "[", "(", "<", "«",
        ".", ",", "!", "?", "'"
    ]
    
    private let qwertyMap: [String] = [
        "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
        "a", "s", "d", "f", "g", "h", "j", "k", "l",
        "z", "x", "c", "v", "b", "n", "m"
    ]
}


//struct BidiMap<F:Hashable,T:Hashable>
//{
//   private var _forward  : [F:T]? = nil
//   private var _backward : [T:F]? = nil
//
//   var forward:[F:T]
//   {
//      mutating get
//      {
//        _forward = _forward ?? [F:T](uniqueKeysWithValues:_backward?.map{($1,$0)} ?? [] )
//        return _forward!
//      }
//      set { _forward = newValue; _backward = nil }
//   }
//
//   var backward:[T:F]
//   {
//      mutating get
//      {
//        _backward = _backward ?? [T:F](uniqueKeysWithValues:_forward?.map{($1,$0)} ?? [] )
//        return _backward!
//      }
//      set { _backward = newValue; _forward = nil }
//   }
//
//   init(_ dict:[F:T] = [:])
//   { forward = dict  }
//
//   init(_ values:[(F,T)])
//   { forward = [F:T](uniqueKeysWithValues:values) }
//
//   subscript(_ key:T) -> F?
//   { mutating get { return backward[key] } set{ backward[key] = newValue } }
//
//   subscript(_ key:F) -> T?
//   { mutating get { return forward[key]  } set{ forward[key]  = newValue } }
//
//   subscript(to key:T) -> F?
//   { mutating get { return backward[key] } set{ backward[key] = newValue } }
//
//   subscript(from key:F) -> T?
//   { mutating get { return forward[key]  } set{ forward[key]  = newValue } }
//
//   var count:Int { return _forward?.count ?? _backward?.count ?? 0 }
//}






// PROOFING


