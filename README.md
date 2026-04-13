# Apache Tomcat 완전 학습 가이드

이 디렉토리는 Apache Tomcat에 대한 심층적인 학습 자료를 담고 있습니다.
Amazon Linux 2023 환경 기준으로 작성되었습니다.

## Tomcat이란?

Apache Tomcat은 Jakarta EE(구 Java EE)의 서블릿(Servlet) 및 JSP(JavaServer Pages) 스펙을
구현한 오픈소스 웹 애플리케이션 서버입니다. Java로 작성되어 있으며,
순수 Java 웹 애플리케이션 배포에 특화되어 있습니다.

### 주요 특징
- Servlet / JSP / WebSocket 스펙 구현
- 경량 구조 (완전한 Jakarta EE 컨테이너가 아닌 Servlet 컨테이너)
- WAR(Web Application Archive) 배포 지원
- JNDI DataSource를 통한 커넥션 풀 관리
- Virtual Host를 통한 다중 도메인 호스팅
- AJP 프로토콜을 통한 Apache HTTP Server / Nginx 연동
- 클러스터링을 통한 세션 복제 및 고가용성
- JMX를 통한 런타임 모니터링

## 버전 정보

| 버전 | Servlet | JSP | Jakarta EE | 지원 상태 |
|------|---------|-----|------------|----------|
| 10.1 | 6.0 | 3.1 | 10 | 현재 LTS (권장) |
| 10.0 | 5.0 | 3.0 | 9 | EOL |
| 9.0  | 4.0 | 2.3 | 8 | 현재 안정 (Java EE 8 호환) |
| 8.5  | 3.1 | 2.3 | 7 | 지원 종료 예정 |

> Tomcat 10.x부터 패키지명이 `javax.*` → `jakarta.*`로 변경됩니다.

## 학습 순서

1. [AL2023 설치 가이드](01_installation_AL2023.md)
2. [아키텍처](02_architecture.md)
3. [디렉토리 구조](03_directory_structure.md)
4. [server.xml 설정](04_server_xml.md)
5. [web.xml 설정](05_web_xml.md)
6. [context.xml 설정](06_context_xml.md)
7. [가상 호스트](07_virtual_host.md)
8. [커넥터 (HTTP/AJP/HTTPS)](08_connector.md)
9. [클래스로더](09_classloader.md)
10. [세션 관리](10_session_management.md)
11. [JDBC 커넥션 풀 (JNDI DataSource)](11_jndi_datasource.md)
12. [SSL/TLS 설정](12_ssl_tls.md)
13. [로깅](13_logging.md)
14. [성능 튜닝](14_performance_tuning.md)
15. [보안 설정](15_security.md)
16. [클러스터링 & 세션 복제](16_clustering.md)
17. [Nginx / Apache 연동](17_integration.md)
18. [모니터링 (JMX & Manager)](18_monitoring.md)
19. [실전 예제](19_practical_examples.md)
20. [트러블슈팅](20_troubleshooting.md)

## 파일 구조

```
tomcat-practice/
├── README.md                    # 이 파일 (인덱스)
├── 01_installation_AL2023.md    # AL2023 설치 가이드
├── 02_architecture.md           # Tomcat 아키텍처
├── 03_directory_structure.md    # 디렉토리 구조
├── 04_server_xml.md             # server.xml 설정
├── 05_web_xml.md                # web.xml 설정
├── 06_context_xml.md            # context.xml 설정
├── 07_virtual_host.md           # 가상 호스트
├── 08_connector.md              # 커넥터 설정
├── 09_classloader.md            # 클래스로더
├── 10_session_management.md     # 세션 관리
├── 11_jndi_datasource.md        # JDBC 커넥션 풀
├── 12_ssl_tls.md                # SSL/TLS 설정
├── 13_logging.md                # 로깅
├── 14_performance_tuning.md     # 성능 튜닝
├── 15_security.md               # 보안 설정
├── 16_clustering.md             # 클러스터링 & 세션 복제
├── 17_integration.md            # Nginx / Apache 연동
├── 18_monitoring.md             # 모니터링
├── 19_practical_examples.md     # 실전 예제
└── 20_troubleshooting.md        # 트러블슈팅
```

## 빠른 참고

```bash
# 설정 파일 문법 검사 (configtest)
$CATALINA_HOME/bin/configtest.sh

# 서비스 시작 / 중지 / 재시작
sudo systemctl start tomcat
sudo systemctl stop tomcat
sudo systemctl restart tomcat

# 로그 실시간 확인
tail -f /opt/tomcat/logs/catalina.out

# 프로세스 확인
ps aux | grep tomcat
```
