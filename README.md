# tomcat-practice

Apache Tomcat을 설치하고 운영하기 위한 개인 학습 공간입니다.

## 어디서 시작할까

- 문서 지도: `docs/README.md`
- 첫 문서: `docs/install/01_installation_AL2023.md`
- 운영 보조 자료: `ops/README.md`

## 구조

| 경로 | 내용 |
|------|------|
| `docs/` | 설치, 아키텍처, 설정, 런타임, 연동, 보안, 성능, 운영 문서 |
| `ops/` | 설정 예시, 운영 메모, 런북을 둘 공간 |

## 빠른 명령

```bash
$CATALINA_HOME/bin/configtest.sh
systemctl restart tomcat
tail -f /opt/tomcat/logs/catalina.out
```
