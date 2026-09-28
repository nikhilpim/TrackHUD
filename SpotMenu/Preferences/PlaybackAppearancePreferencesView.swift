import SwiftUI

struct PlaybackAppearancePreferencesView: View {
    @ObservedObject var model: PlaybackAppearancePreferencesModel
    @ObservedObject var musicPlayerPreferencesModel: MusicPlayerPreferencesModel
    @ObservedObject var playbackModel: PlaybackModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Player Design").font(.headline)
                Picker("Player Design", selection: $model.layout) {
                    ForEach(PlaybackLayout.allCases) { layout in
                        Text(layout.title).tag(layout)
                    }
                }
                .pickerStyle(.segmented)

                if model.layout == .bottomBar {
                    barSettings
                } else {
                    squareSettings
                }

                Divider()
                Text("Live Preview").font(.headline)
                HStack {
                    Spacer(minLength: 0)
                    PlaybackView(
                        model: playbackModel,
                        preferences: model,
                        musicPlayerPreferencesModel: musicPlayerPreferencesModel
                    )
                    Spacer(minLength: 0)
                }
                Text("Changes apply immediately and are saved. All bar styles keep the same size and position.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 560)
            .padding(20)
        }
    }

    private var barSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bar Style · \(BarStyle.allCases.count) choices").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(BarStyle.allCases) { style in
                    Button { model.barStyle = style } label: {
                        HStack(spacing: 6) {
                            if style == .rotation {
                                Image(systemName: "shuffle").font(.system(size: 9, weight: .semibold))
                            } else {
                                Circle().fill(style.accent).frame(width: 7, height: 7)
                            }
                            Text(style.title).font(.system(size: 12, weight: .medium, design: style.fontDesign))
                            Spacer(minLength: 0)
                            if model.barStyle == style { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 38)
                        .foregroundStyle(style.foreground)
                        .background(style.background, in: RoundedRectangle(cornerRadius: 9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(model.barStyle == style ? style.accent : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.title)
                    .accessibilityAddTraits(model.barStyle == style ? .isSelected : [])
                }
            }
            Text(model.barStyle.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
            if model.barStyle == .rotation {
                Text("Now: \(model.rotationTheme.title) · cycles through all \(BarStyle.rotationThemes.count) themes on track changes. Pausing, seeking, and artwork refreshes do not change themes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Album-art Lighting", isOn: $model.albumLighting)
            Toggle("Song Entrance", isOn: $model.songEntrance)
            Toggle("Physical Interaction", isOn: $model.physicalInteraction)
            Toggle("Focus Mode — compact until hovered", isOn: $model.focusMode)
            if model.focusMode {
                Picker("Focus Anchor", selection: $model.focusAnchor) {
                    ForEach(FocusAnchor.allCases) { anchor in
                        Text(anchor.title).tag(anchor)
                    }
                }
                Text("The chosen corner stays fixed when folding and unfolding. Automatic chooses the nearest screen corner; Bottom Right keeps the token at the right edge and unfolds to the left.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Focus Mode shrinks the actual window to an album-art jewel. Hover to unfold; it folds back after you leave. Drag from the top edge. The preview below stays expanded.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Colors are extracted once per cover and cached locally. Full-color artwork stays unchanged.")
                .font(.caption).foregroundStyle(.secondary)

            Text("Visualizer Motion")
                .font(.headline)
                .padding(.top, 8)
            Picker("Visualizer Motion", selection: $model.visualizerMotion) {
                ForEach(VisualizerMotion.allCases) { motion in
                    Text(motion.title).tag(motion)
                }
            }
            .pickerStyle(.segmented)
            Text("Off keeps everything still. Gentle adds subtle motion. Lively adds each theme’s signature effects. New materials and album covers share a 1.8-second wipe once artwork is ready; controls stay in place. Hover bends reflections; clicks send a ripple.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("All motion is decorative and respects Reduce Motion. SpotMenu does not capture audio, your microphone, or your screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var squareSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            ColorPicker("Hover Tint Color", selection: Binding(
                get: { Color(model.hoverTintColor) },
                set: { model.hoverTintColor = NSColor($0) }
            ))
            Picker("Foreground Color", selection: $model.foregroundColor) {
                ForEach(PlaybackAppearancePreferencesModel.ForegroundColorOption.allCases) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text("Blur Intensity")
            Slider(value: $model.blurIntensity, in: 0...1)
            Text("Hover Tint Opacity")
            Slider(value: $model.hoverTintOpacity, in: 0...1)
        }
    }
}

#Preview {
    PlaybackAppearancePreferencesView(
        model: PlaybackAppearancePreferencesModel(),
        musicPlayerPreferencesModel: MusicPlayerPreferencesModel(),
        playbackModel: PlaybackModel(preferences: MusicPlayerPreferencesModel())
    )
}
