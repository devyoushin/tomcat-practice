# 03. 디렉토리 구조

## Tomcat 기본 디렉토리

```
/opt/tomcat/                  ← CATALINA_HOME / CATALINA_BASE
├── bin/                      ← 실행 스크립트 및 바이너리
│   ├── catalina.sh           ← 핵심 시작/중지 스크립트
│   ├── startup.sh            ← catalina.sh start 래퍼
│   ├── shutdown.sh           ← catalina.sh stop 래퍼
│   ├── setenv.sh             ← 환경변수 설정 (직접 작성)
│   ├── configtest.sh         ← 설정 파일 문법 검사
│   ├── version.sh            ← 버전 정보 출력
│   ├── digest.sh             ← 패스워드 해시 생성
│   ├── tool-wrapper.sh       ← Java 도구 래퍼
│   ├── bootstrap.jar         ← Tomcat 기동 클래스
│   ├── tomcat-juli.jar       ← 로깅 라이브러리
│   └── commons-daemon-*.jar  ← jsvc(데몬) 지원
│
├── conf/                     ← 설정 파일
│   ├── server.xml            ← 핵심 설정 (Connector, Engine, Host)
│   ├── web.xml               ← 전역 서블릿/필터 설정 (기본 서블릿 포함)
│   ├── context.xml           ← 전역 Context 설정
│   ├── tomcat-users.xml      ← 사용자/역할 정의 (Manager App 등)
│   ├── logging.properties    ← 로깅 설정
│   ├── jaspic-providers.xml  ← JASPIC 인증 제공자
│   └── Catalina/             ← 호스트별 설정 디렉토리
│       └── localhost/        ← localhost 호스트 설정
│           └── myapp.xml     ← 앱별 Context 설정 파일
│
├── lib/                      ← 공유 라이브러리 (모든 앱 공유)
│   ├── catalina.jar          ← Catalina 코어
│   ├── servlet-api.jar       ← Servlet API
│   ├── jasper.jar            ← Jasper (JSP 엔진)
│   ├── jsp-api.jar           ← JSP API
│   ├── el-api.jar            ← Expression Language API
│   ├── tomcat-api.jar        ← Tomcat API
│   └── *.jar                 ← 기타 공유 라이브러리
│                               (JDBC 드라이버 등을 여기에 추가)
│
├── logs/                     ← 로그 파일
│   ├── catalina.out          ← JVM stdout/stderr (가장 중요)
│   ├── catalina.YYYY-MM-DD.log ← Catalina 내부 로그
│   ├── localhost.YYYY-MM-DD.log ← 호스트 레벨 로그
│   ├── manager.YYYY-MM-DD.log  ← Manager App 로그
│   ├── host-manager.YYYY-MM-DD.log ← Host Manager 로그
│   └── localhost_access_log.YYYY-MM-DD.txt ← 접근 로그
│
├── temp/                     ← JVM 임시 파일 (java.io.tmpdir)
│   └── tomcat.pid            ← PID 파일 (setenv.sh에서 설정)
│
├── webapps/                  ← 웹 애플리케이션 배포 디렉토리
│   ├── ROOT/                 ← 기본 앱 (/ 경로)
│   ├── manager/              ← Tomcat Manager App
│   ├── host-manager/         ← Host Manager App
│   ├── examples/             ← 예제 앱 (보안상 삭제 권장)
│   ├── docs/                 ← 문서 앱 (보안상 삭제 권장)
│   └── myapp/                ← 배포한 웹 애플리케이션
│       └── WEB-INF/
│           ├── web.xml       ← 앱별 서블릿 설정
│           ├── classes/      ← 컴파일된 Java 클래스
│           └── lib/          ← 앱 전용 라이브러리
│
└── work/                     ← JSP 컴파일 결과물 (Jasper 캐시)
    └── Catalina/
        └── localhost/
            └── myapp/        ← myapp의 JSP 컴파일 파일
```

---

## CATALINA_HOME vs CATALINA_BASE

| 변수 | 의미 | 포함 디렉토리 |
|------|------|--------------|
| `CATALINA_HOME` | Tomcat 바이너리가 설치된 위치 | `bin/`, `lib/` |
| `CATALINA_BASE` | Tomcat 인스턴스 설정/데이터 위치 | `conf/`, `logs/`, `webapps/`, `work/`, `temp/` |

단일 인스턴스 운영 시에는 두 값이 같습니다.
다중 인스턴스(하나의 바이너리로 여러 Tomcat 운영) 시에는 분리합니다.

```bash
# 다중 인스턴스 예시
export CATALINA_HOME=/opt/tomcat          # 공유 바이너리
export CATALINA_BASE=/opt/tomcat-instance1  # 인스턴스1 설정

# 인스턴스1 시작
$CATALINA_HOME/bin/startup.sh
```

---

## conf/ 주요 파일 역할

### server.xml
Tomcat 서버 전체 구조를 정의합니다.
- Connector (포트, 프로토콜, 스레드 풀)
- Engine, Host, Context
- Valve, Realm 설정

### web.xml (전역)
모든 웹 애플리케이션에 공통으로 적용되는 서블릿/필터/MIME 타입 설정입니다.
- DefaultServlet (정적 파일 서빙)
- JspServlet (JSP 처리)
- MIME 타입 매핑

### context.xml (전역)
모든 웹 애플리케이션에 공통으로 적용되는 Context 설정입니다.
- 세션 지속성 설정
- WatchedResource 설정

### tomcat-users.xml
Manager App, Host Manager 등 내장 애플리케이션 접근 계정을 정의합니다.

### logging.properties
java.util.logging 기반의 로깅 설정입니다.

---

## 웹 애플리케이션 구조 (WAR)

```
myapp.war
└── (압축 해제 후)
    myapp/
    ├── index.html              ← 정적 파일 (웹 루트)
    ├── css/, js/, images/      ← 정적 리소스
    ├── *.jsp                   ← JSP 파일
    └── WEB-INF/                ← 클라이언트에서 직접 접근 불가
        ├── web.xml             ← 앱별 서블릿/필터/리스너 설정
        ├── classes/            ← 컴파일된 .class 파일
        │   └── com/example/
        │       └── MyServlet.class
        └── lib/                ← 앱 전용 JAR 라이브러리
            └── mybatis-*.jar
```

---

## 설정 파일 우선순위

Context 설정은 여러 곳에서 지정할 수 있으며, 우선순위가 있습니다.

```
높은 우선순위
    ↑
    │  1. conf/Catalina/localhost/myapp.xml  (호스트별 Context 파일)
    │  2. WAR/META-INF/context.xml           (앱 내부 Context 설정)
    │  3. conf/context.xml                   (전역 기본값)
    ↓
낮은 우선순위
```

---

## 주요 스크립트 사용법

```bash
# 시작
/opt/tomcat/bin/startup.sh

# 중지
/opt/tomcat/bin/shutdown.sh

# 강제 중지 (응답 없을 때)
/opt/tomcat/bin/catalina.sh stop -force

# 설정 문법 검사
/opt/tomcat/bin/configtest.sh

# 버전 확인
/opt/tomcat/bin/version.sh

# 패스워드 해시 생성 (tomcat-users.xml용)
/opt/tomcat/bin/digest.sh -a SHA-256 "mypassword"
# SHA-256 해시값 출력

# foreground 실행 (디버깅 시)
/opt/tomcat/bin/catalina.sh run
```

---

## 불필요한 앱 제거 (보안)

```bash
# 기본 포함된 앱 중 운영 환경에서 제거 권장
sudo rm -rf /opt/tomcat/webapps/examples
sudo rm -rf /opt/tomcat/webapps/docs
sudo rm -rf /opt/tomcat/webapps/host-manager  # Host Manager 불필요 시

# ROOT 앱도 커스텀 앱으로 교체하거나 내용 비우기
sudo rm -rf /opt/tomcat/webapps/ROOT/*
```
