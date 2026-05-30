# AGENTS.md — tomcat-practice

이 레포는 Apache Tomcat 학습 문서와 운영 보조 자료를 관리합니다.
Codex로 작업할 때 아래 규칙을 우선 적용합니다.

## 기본 작업 흐름

1. 요청 범위를 짧게 확인합니다.
2. 파일 검색은 `rg`와 `find`를 우선 사용합니다.
3. 변경은 필요한 파일에만 작게 적용합니다.
4. 문서 경로가 바뀌면 `README.md`, `docs/README.md`, `ops/README.md`, `CLAUDE.md`의 참조를 함께 확인합니다.
5. 가능한 검증을 실행합니다.

## 구조 기준

| 경로 | 역할 |
|------|------|
| `README.md` | 프로젝트 입구 |
| `docs/` | 개념 설명과 학습 문서 |
| `ops/` | 실제 운영 샘플, 스크립트, 런북, 점검 명령 |
| `CLAUDE.md` | Claude용 프로젝트 지침 |
| `AGENTS.md` | Codex용 작업 지침 |

## 문서 배치 기준

- 설치 문서: `docs/install/`
- 구조 설명: `docs/architecture/`
- 설정 설명: `docs/config/`
- 런타임 기능: `docs/runtime/`
- 연동 문서: `docs/integrations/`
- 보안 문서: `docs/security/`
- 성능 문서: `docs/performance/`
- 운영 설명 문서: `docs/operations/`
- 실제 설정 샘플: `ops/config/`
- 실행 스크립트: `ops/scripts/`
- 운영 절차: `ops/runbooks/`
- 점검 명령: `ops/commands/`

## 작성 규칙

- 기본 언어는 한국어입니다.
- 명령어와 설정은 코드블록에 언어 태그를 붙입니다.
- 운영 예시는 실제 비밀값을 포함하지 않습니다.
- 새 파일을 추가하면 가장 가까운 README에 위치와 목적을 반영합니다.
- 파괴적 명령이나 대량 삭제는 사용자 요청 없이는 실행하지 않습니다.
