Pod::Spec.new do |s|
  s.name             = 'media_core_media_activity'
  s.version          = '0.1.0'
  s.summary          = 'iOS lock-screen lyrics and Dynamic Island bridge for media_core.'
  s.description      = <<-DESC
Bridges the host's playback layer to ActivityKit Live Activities, the Now
Playing card and remote commands, so a Widget Extension can render lock-screen
lyrics while every playback decision stays in Dart. The Shared subspec is the
data contract the extension renders from (spec §3, §10).
                       DESC
  s.homepage         = 'https://github.com/liuchuancong/media_core'
  s.license          = { :type => 'MIT' }
  s.author           = { 'liuchuancong' => 'noreply@example.com' }
  s.source           = { :path => '.' }

  # ActivityKit use is fully #available-gated, so the pod loads on the
  # Flutter minimum while the feature switches off below iOS 16.1.
  s.ios.deployment_target = '13.0'

  s.ios.frameworks = 'UIKit', 'MediaPlayer'
  # Live Activities ship in iOS 16.1; weak-linking keeps devices below that
  # from failing to resolve the framework at launch.
  s.ios.weak_frameworks = 'ActivityKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  # Flutter's plugin pods install the default subspec into the Runner.
  s.default_subspec = 'Plugin'

  # The Widget Extension links ONLY this: the ActivityAttributes contract the
  # extension renders from. It must stay free of Flutter and of the generated
  # bridge code — an extension target has no Flutter runtime (spec §10).
  s.subspec 'Shared' do |ss|
    ss.source_files = 'Classes/Shared/**/*'
  end

  # The full bridge: Pigeon channels, ActivityKit lifecycle, Now Playing,
  # remote commands, artwork store. Flutter-dependent, Runner-side only.
  s.subspec 'Plugin' do |ss|
    ss.source_files = 'Classes/Plugin/**/*'
    ss.dependency 'media_core_media_activity/Shared'
    ss.ios.dependency 'Flutter'
  end
end
