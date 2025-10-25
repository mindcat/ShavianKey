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
    
    @State private var currentMode: KeyboardMode = .shavian1
    @State private var showingModePicker = false
    @State private var lastTapTime: Date = Date()
    @State private var lastTapButton: String = ""
    @State private var longPressLocation: CGPoint = .zero
    @State private var isDeleting = false
    @State private var deleteTimer: Timer?
    
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
                .padding(.horizontal, 3)
                .padding(.vertical, 6)
            
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
        let keys = mode == .shavian1 ? shavian1aKeys : shavian1bKeys
        
        return VStack(spacing: 6) {
            
            // Prediction and autocorrect
            // I'm leaning towards keeping all UI in the view controller? so the logic for display...
            
            
            
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
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { i in
                    keyButton(keys[i], alternateKey: mode == .shavian1 ? shavian1bKeys[i] : shavian1aKeys[i])
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 42)
            
            // Row 2
            HStack(spacing: 4) {
                ForEach(10..<20, id: \.self) { i in
                    keyButton(keys[i], alternateKey: mode == .shavian1 ? shavian1bKeys[i] : shavian1aKeys[i])
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 42)
            
            // Row 3: COME BACK AND REDO THIS AND REMEMBER DRY
            GeometryReader { geo in
                let spacing: CGFloat = 4
                let totalSpacing = spacing * 9
                let keyWidth1x = floor((geo.size.width - totalSpacing) / 10)
                let keyWidth2x = (keyWidth1x * 2) + spacing + 2 // fucked up TEMPORARY fix
                
                HStack(spacing: spacing) {
                    switchButton()
                        .frame(width: keyWidth1x)
                    
                    keyButton(keys[20], alternateKey: mode == .shavian1 ? shavian1bKeys[20] : shavian1aKeys[20])
                        .frame(width: keyWidth1x)
                    keyButton(keys[21], alternateKey: mode == .shavian1 ? shavian1bKeys[21] : shavian1aKeys[21])
                        .frame(width: keyWidth1x)
                    
                    deleteKeyButton()
                        .frame(width: keyWidth2x)
                    
                    spaceKeyButton()
                        .frame(width: keyWidth2x)
                    
                    keyButton(keys[22], alternateKey: mode == .shavian1 ? shavian1bKeys[22] : shavian1aKeys[22])
                        .frame(width: keyWidth1x)
                    keyButton(keys[23], alternateKey: mode == .shavian1 ? shavian1bKeys[23] : shavian1aKeys[23])
                        .frame(width: keyWidth1x)
                    // this key needs to become a function so more punctuation can be accessed from shavian...
                    keyButton(keys[24], alternateKey: mode == .shavian1 ? shavian1bKeys[24] : shavian1aKeys[24])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
        }
    }
    
    // MARK: - Symbols Layout
    
    private func symbolsLayout(mode: KeyboardMode) -> some View {
        let keys = mode == .symbols1 ? symbols2aKeys : symbols2bKeys
        
        return VStack(spacing: 6) {
            
            
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
                    keyButton(keys[i], alternateKey: mode == .symbols1 ? symbols2bKeys[i] : symbols2aKeys[i])
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 42)
            
            // Row 2
            HStack(spacing: 4) {
                ForEach(10..<20, id: \.self) { i in
                    keyButton(keys[i], alternateKey: mode == .symbols1 ? symbols2bKeys[i] : symbols2aKeys[i])
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 42)
            
            // Row 3: COME BACK AND REDO THIS AND REMEMBER DRY
            GeometryReader { geo in
                // 8 items = 7 gaps. 10 key units total (1,1,1,2,2,1,1,1)... but the 1x keys are a little too skinny on this row
                let spacing: CGFloat = 4
                let totalSpacing = spacing * 9
                let keyWidth1x = floor((geo.size.width - totalSpacing) / 10)
                let keyWidth2x = (keyWidth1x * 2) + spacing + 2
                
                HStack(spacing: spacing) {
                    switchButton()
                        .frame(width: keyWidth1x)
                    
                    keyButton(keys[20], alternateKey: mode == .symbols1 ? symbols2bKeys[20] : symbols2aKeys[20])
                        .frame(width: keyWidth1x)
                    keyButton(keys[21], alternateKey: mode == .symbols1 ? symbols2bKeys[21] : symbols2aKeys[21])
                        .frame(width: keyWidth1x)
                    
                    deleteKeyButton()
                        .frame(width: keyWidth2x)
                    
                    spaceKeyButton()
                        .frame(width: keyWidth2x)
                    
                    keyButton(keys[22], alternateKey: mode == .symbols1 ? symbols2bKeys[22] : symbols2aKeys[22])
                        .frame(width: keyWidth1x)
                    keyButton(keys[23], alternateKey: mode == .symbols1 ? symbols2bKeys[23] : symbols2aKeys[23])
                        .frame(width: keyWidth1x)
                    keyButton(keys[24], alternateKey: mode == .symbols1 ? symbols2bKeys[24] : symbols2aKeys[24])
                        .frame(width: keyWidth1x)
                }
            }
            .frame(height: 42)
        }
    }
    
    // MARK: - QWERTY Layout
    
    // INCREDIBLY BROKEN AND USELESS BUT NOT GONNA BOTHER FIXING UNTIL I REFACTOR FROM
    // ARRAY BASED LAYOUT TO DICT BASED (paired characters for mapping alternates, including
    // qwerty => QWERTY and # => $)
    private func qwertyLayout() -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            // Row 1 (10 keys) is our base
            let keyWidth1x = floor((geo.size.width - 9 * spacing) / 10)
            // Row 2 has 9 keys, needs padding
//            let row2Padding = (keyWidth1x + spacing) / 2.0
            // Row 3 (Shift + 7 keys + Del) has 9 items, 8 gaps
            let keyWidthShift = floor((geo.size.width - (8 * spacing) - (7 * keyWidth1x)) / 2)
            // Row 4 (Switch + Space + Return) has 3 items, 2 gaps
            let keyWidthSpace = floor(geo.size.width - (2 * spacing) - (2 * keyWidthShift))
            
            VStack(spacing: 6) {
                // Row 1
                HStack(spacing: spacing) {
                    ForEach(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], id: \.self) { key in
                        keyButton(key, alternateKey: nil)
                            .frame(width: keyWidth1x)
                    }
                }
                .frame(height: 42)
                
                // Row 2
                HStack(spacing: spacing) {
//                    Spacer().frame(width: row2Padding)
                    switchButton()
                        .frame(width: keyWidth1x)
                    ForEach(["A", "S", "D", "F", "G", "H", "J", "K", "L"], id: \.self) { key in
                        keyButton(key, alternateKey: nil)
                            .frame(width: keyWidth1x)
                    }
//                    Spacer().frame(width: row2Padding)
                }
                .frame(height: 42)
                
                // Row 3
                HStack(spacing: spacing) {
                    shiftButton()
                        .frame(width: keyWidthShift)
                    ForEach(["Z", "X", "C", "V", "B", "N", "M"], id: \.self) { key in
                        keyButton(key, alternateKey: nil)
                            .frame(width: keyWidth1x)
                    }
                    deleteButton()
                        .frame(width: keyWidthShift)
                }
                .frame(height: 42)
            }
        }
    }
    
    // MARK: - Key Buttons
    
    private func keyButton(_ key: String, alternateKey: String?) -> some View {
        Button(action: {
            handleKeyTap(key, alternateKey: alternateKey)
        }) {
            Text(key)
                .font(key.count == 1 && key.first?.isLetter == true ? .custom("InterAlia-Regular", size: 22) : .system(size: 20)) // Use system font for symbols
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
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        self.switchButtonFrame = geo.frame(in: .global)
                    }
                }
                .background(keyButtonStyle)
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        // drag start
                        if self.gestureDragLocation == nil {
                            self.gestureDragLocation = value.startLocation
                            
                            self.buttonFrames.removeAll()
                            
                            self.longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showingModePicker = true
                                }
                            }
                        }

                        // during drag move
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
                        // on drag end, can't believe there wasnt an out of the box solution for this jesus
                        
                        // not necessary if my code is clean. alas!
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
                            if switchButtonFrame.contains(value.location) {
                                handleSwitchTap()
                            }
                        }
                        
                        // reset
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
                playHaptic(style: .medium)
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 10, pressing: { isPressing in
                if !isPressing {
                    stopDeletingContinuously()
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
                insertText(" ")
                playHaptic(style: .light)
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let translation = value.translation
                        if abs(translation.height) < 40 && abs(translation.width) > 50 { // Loosened y-axis constraint
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
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 10, pressing: { isPressing in // Was missing
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
    
    private func handleKeyTap(_ key: String, alternateKey: String?) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.3 && lastTapButton == key && alternateKey != nil {
            // double tap for character pair
            textDocumentProxy.deleteBackward()
            insertText(alternateKey!)
            playHaptic(style: .light)
        } else {
            insertText(key)
            playHaptic(style: .light)
        }
        
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
            // Single tap - switch between a and b submodes
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
        
        // Initial delete
        textDocumentProxy.deleteBackward()
        playHaptic(style: .light)
        
        // repeated deletes
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.isDeleting {
                self.textDocumentProxy.deleteBackward()
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
        // We can attempt to play, but system sandbox may prevent it.
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Key Data
    
    private let shavian1aKeys = [
        "𐑐", "𐑑", "𐑒", "𐑓", "𐑔", "𐑕", "𐑖", "𐑗", "𐑘", "𐑙",
        "𐑤", "𐑯", "𐑦", "𐑲", "𐑨", "𐑩", "𐑳", "𐑵", "𐑬", "𐑭",
        "𐑸", "𐑺", "𐑼", "𐑿", "·"
    ]
    
    private let shavian1bKeys = [
        "𐑚", "𐑛", "𐑜", "𐑝", "𐑞", "𐑟", "𐑠", "𐑡", "𐑢", "𐑣",
        "𐑮", "𐑥", "𐑰", "𐑱", "𐑧", "𐑪", "𐑴", "𐑫", "𐑶", "𐑷",
        "𐑹", "𐑻", "𐑽", "𐑾", "⸰"
    ]
    
    private let symbols2aKeys = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "~", "=", "/", "-", ":", "{", "[", "(", "<", "«",
        ".", ",", "!", "?", "'"
    ]
    
    private let symbols2bKeys = [
        "°", "!", "@", "#", "$", "%", "^", "&", "*", "|",
        "☭", "+", "\\", "_", ";", "}", "]", ")", ">", "»",
        ".", ",", "!", "?", "`"
    ]
}

