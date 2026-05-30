# CLAUDE.md — tomcat-practice

Apache Tomcat을 설치하고 운영하기 위한 개인 학습 공간입니다.
Amazon Linux 2023, Java 17, Tomcat 10.x 운영을 기본 전제로 합니다.

## 프로젝트 구조

```text
tomcat-practice/
├── README.md          # 프로젝트 입구
├── CLAUDE.md          # Claude 작업 지침
├── AGENTS.md          # Codex 작업 지침
├── docs/
│   ├── README.md      # 문서 구조 안내
│   ├── install/       # 설치와 초기 실행
│   ├── architecture/  # 구조, 디렉터리, 클래스로더
│   ├── config/        # server.xml, web.xml, context.xml, virtual host
│   ├── runtime/       # connector, session, JNDI, clustering
│   ├── integrations/  # Nginx/Apache 연동
│   ├── security/      # TLS, 보안 설정
│   ├── performance/   # 성능 튜닝
│   └── operations/    # 로깅, 모니터링, 트러블슈팅, 운영 전략
└── ops/
    ├── README.md      # 운영 보조 자료 안내
    ├── config/        # setenv.sh, systemd, server.xml 운영 샘플
    ├── scripts/       # 배포/전환 스크립트
    ├── runbooks/      # 재시작, 배포, 장애 대응 절차
    └── commands/      # 자주 쓰는 점검 명령
```

## 문서 작성 규칙

- 기본 언어는 한국어로 작성합니다.
- 문서는 실무 운영 관점으로 작성합니다.
- 명령어와 설정 예시는 복사해서 실행 가능한 형태를 우선합니다.
- 설명 문서는 `docs/`에 두고, 실제 샘플/스크립트/런북은 `ops/`에 둡니다.
- 새 학습 문서는 현재 카테고리 구조에 맞춰 `docs/{category}/` 아래에 추가합니다.
- 새 운영 보조 자료는 성격에 따라 `ops/config/`, `ops/scripts/`, `ops/runbooks/`, `ops/commands/` 아래에 추가합니다.

## 자주 참조할 문서

- 문서 지도: `docs/README.md`
- 설치 시작점: `docs/install/01_installation_AL2023.md`
- 운영 자료 지도: `ops/README.md`
- 운영 전략: `docs/operations/21_production_strategies.md`
- 장애 대응: `ops/runbooks/incident.md`

## 주의사항

- 비밀번호, 토큰, 인증서 개인키는 레포에 저장하지 않습니다.
- 운영 예시에는 실제 도메인/IP/계정 대신 예시 값을 사용합니다.
- 최신 버전, 취약점, 패키지 상태처럼 변할 수 있는 정보는 공식 문서를 확인합니다.
