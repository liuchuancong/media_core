Pod::Spec.new do |s|
  s.name             = 'media_core_audio'
  s.version          = '0.1.0'
  s.summary          = 'Music playback for media_core: lyrics, desktop lyrics, background playback, downloads.'
  s.description      = <<-DESC
Desktop-lyric overlay window for media_core's music module: a borderless
always-on-top panel with hover controls, dragging and click-through locking.
                       DESC
  s.homepage         = 'https://github.com/liuchuancong/media_core'
  s.license          = { :type => 'MIT' }
  s.author           = { 'liuchuancong' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'

  s.osx.deployment_target = '10.14'

  s.osx.dependency 'FlutterMacOS'

  s.osx.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
