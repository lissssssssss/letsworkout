platform :ios, '16.0'
use_frameworks!
inhibit_all_warnings!

target 'LetsWorkout' do
  pod 'MediaPipeTasksVision', '~> 0.10.9'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
