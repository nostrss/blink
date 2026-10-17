# 처음부터 App Sandbox를 켜고 개발한다

직접 배포(Developer ID + 공증, GitHub Release)를 먼저 하고 Mac App Store에도 배포한다. App Store는 샌드박스가 필수라서, 나중에 코드를 고치지 않고 넘어갈 수 있도록 직접 배포 버전도 처음부터 샌드박스 안에서 만든다. 그래서 입력소스를 앱이 직접 "전환"하는 기능이나 접근성 권한이 필요한 기능은 쓰지 않는다. 로그인 항목은 `SMAppService.mainApp`만 쓴다. (2026-10-17 결정)
