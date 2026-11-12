// 쓰기 실패 알림. 저장·게시·지우기가 실패를 드러내는 한 가지 꼴 — 제목 한 줄과 `확인` 하나.

import SwiftUI

extension View {
    /// 디스크 쓰기 실패를 알린다. `확인`이 닫고, 닫으면서 `acknowledge`를 부른다.
    func writeFailureAlert(_ title: String, isPresented: Binding<Bool>,
                           acknowledge: @escaping () -> Void = {}) -> some View {
        alert(title, isPresented: isPresented) {
            Button(Wording.acknowledge, action: acknowledge)
        }
    }
}
