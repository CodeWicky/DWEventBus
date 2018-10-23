Pod::Spec.new do |s|
s.name = 'DWEventBus'
s.version = '1.0.0'
s.license = { :type => 'MIT', :file => 'LICENSE' }
s.summary = '灵活的事件总线，支持弱类型及联合事件，观察者释放后自动移除订阅关系等。A flexible event bus who supports subType/unite event,and remove subscribe when the observer dealloced.'
s.homepage = 'https://github.com/CodeWicky/DWEventBus'
s.authors = { 'codeWicky' => 'codewicky@163.com' }
s.source = { :git => 'https://github.com/CodeWicky/DWEventBus.git', :tag => s.version.to_s }
s.requires_arc = true
s.ios.deployment_target = '7.0'
s.source_files = 'DWEventBus/**/{DWEventBus}.{h,m}'
s.frameworks = 'Foundation'

end