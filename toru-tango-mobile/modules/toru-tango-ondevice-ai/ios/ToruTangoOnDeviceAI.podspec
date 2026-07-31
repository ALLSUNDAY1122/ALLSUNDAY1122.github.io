Pod::Spec.new do |spec|
  spec.name = 'ToruTangoOnDeviceAI'
  spec.version = '1.0.0'
  spec.summary = 'Apple Foundation Models card generation for Toru Tango'
  spec.description = 'Local Expo module that generates study cards on device and falls back to deterministic extraction.'
  spec.author = 'ALLSUNDAY1122'
  spec.homepage = 'https://allsunday1122.github.io/toru-tango/'
  spec.license = { :type => 'MIT' }
  spec.platforms = { :ios => '16.4' }
  spec.swift_version = '5.9'
  spec.source = { :git => 'https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git' }
  spec.static_framework = true

  spec.dependency 'ExpoModulesCore'

  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }

  spec.source_files = '**/*.{h,m,mm,swift,hpp,cpp}'
end
