// PhotoSource — 사진 라이브러리를 아는 유일한 모듈. 공개 API에 쓰기 연산 없음 (ADR 0001 결정 2).
// 게임 지식 없음 — 컨테이너를 찾고, 파일을 열거하고, 바이트를 읽는 것까지가 이 모듈의 일이다 (ADR 0002).
// 쓰기 심볼 금지는 scripts/verify-boundaries.swift가 강제한다.

/// 자리 표시 — 어댑터의 실제 구현(앨범 읽기)은 화면 세션에서 시작한다.
public enum Placeholder {}
