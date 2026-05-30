# tomcat-practice

Amazon Linux 2023 기준으로 Apache Tomcat 설치, 설정 파일, 커넥터, 세션, JNDI, TLS, 성능 튜닝, 운영 전략을 정리한 개인 학습 문서입니다.

## 빠른 시작

- 처음 볼 문서: `docs/install/01_installation_AL2023.md`
- 전체 흐름: 설치 -> 아키텍처 -> 설정 파일 -> 커넥터/세션/JNDI -> 보안/성능/운영
- 운영 보조 자료: `ops/`

## 구조

```text
tomcat-practice/
├── README.md
├── docs/
│   ├── README.md
│   ├── install/
│   ├── architecture/
│   ├── config/
│   ├── runtime/
│   ├── integrations/
│   ├── security/
│   ├── performance/
│   └── operations/
└── ops/           # 운영 보조 자료
```

## 주요 문서

| 범위 | 문서 |
|------|------|
| 시작 | `docs/install/01_installation_AL2023.md`, `docs/architecture/02_architecture.md` |
| 설정 | `docs/architecture/03_directory_structure.md`, `docs/config/04_server_xml.md`, `docs/config/05_web_xml.md` |
| 애플리케이션 운영 | `docs/config/06_context_xml.md`, `docs/runtime/10_session_management.md`, `docs/runtime/11_jndi_datasource.md` |
| 연동 | `docs/runtime/08_connector.md`, `docs/integrations/17_integration.md` |
| 운영 | `docs/operations/13_logging.md`, `docs/operations/18_monitoring.md`, `docs/operations/21_production_strategies.md` |

## 빠른 명령

```bash
$CATALINA_HOME/bin/configtest.sh
systemctl restart tomcat
tail -f /opt/tomcat/logs/catalina.out
ps aux | grep tomcat
```
