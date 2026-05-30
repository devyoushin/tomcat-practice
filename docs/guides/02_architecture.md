# 02. Tomcat 아키텍처

## 전체 구조 개요

Tomcat은 계층적인 컴포넌트 구조를 가집니다.
각 컴포넌트는 server.xml에 XML 요소로 선언되어 있습니다.

```
Server
└── Service
    ├── Connector (HTTP/AJP)
    └── Engine
        └── Host (Virtual Host)
            └── Context (Web Application)
                └── Wrapper (Servlet)
```

---

## 핵심 컴포넌트

### Server
- Tomcat 인스턴스 전체를 나타내는 최상위 컴포넌트
- JVM 프로세스 하나 = Server 하나
- shutdown 포트 관리 (기본: 8005)

### Service
- 하나 이상의 Connector와 하나의 Engine을 묶는 컨테이너
- 기본 이름: `Catalina`
- 하나의 Server에 여러 Service를 가질 수 있음 (드문 경우)

### Connector
- 네트워크 요청을 받아 Engine으로 전달하는 컴포넌트
- 주요 프로토콜:
  - **HTTP/1.1**: 브라우저 직접 요청 (기본 포트: 8080)
  - **HTTPS**: SSL/TLS 암호화 HTTP (기본 포트: 8443)
  - **AJP/1.3**: Apache HTTP Server / Nginx 연동용 (기본 포트: 8009)
- 구현 방식 (I/O 모델):
  - **NIO** (Non-blocking I/O): 기본값, 대부분의 경우 권장
  - **NIO2** (Asynchronous I/O): Java NIO.2 기반, 비동기 처리
  - **APR**: Apache Portable Runtime, 네이티브 성능 (별도 라이브러리 필요)

### Engine
- 요청 처리 파이프라인의 핵심
- 들어온 요청을 적절한 Host(가상 호스트)로 라우팅
- 기본 이름: `Catalina`

### Host
- 가상 호스트 (Virtual Host)를 표현
- `name` 속성이 도메인명과 매핑
- 기본 Host: `localhost`
- webapps 디렉토리 내의 애플리케이션을 자동 배포

### Context
- 하나의 웹 애플리케이션을 나타내는 컴포넌트
- 웹 애플리케이션의 context path (URL 경로)와 실제 디렉토리를 매핑
- 예: `/myapp` → `/opt/tomcat/webapps/myapp`

### Wrapper
- 개별 Servlet 인스턴스를 감싸는 컴포넌트
- 직접 설정하지 않고 Tomcat이 내부적으로 관리

---

## 요청 처리 흐름

```
클라이언트
   │
   │ TCP 연결 (HTTP :8080)
   ▼
[Connector: HTTP/1.1 NIO]
   │
   │ Request/Response 객체 생성
   ▼
[Engine: Catalina]
   │
   │ Host 결정 (Host 헤더 기반)
   ▼
[Host: localhost]
   │
   │ Context 결정 (URL 경로 기반)
   ▼
[Context: /myapp]
   │
   │ Servlet 결정 (URL 패턴 매핑)
   ▼
[Wrapper → Servlet]
   │
   │ service(HttpServletRequest, HttpServletResponse) 호출
   ▼
[애플리케이션 코드 실행]
   │
   ▼
클라이언트 응답
```

---

## 스레드 모델

### Connector 스레드 풀

```
HTTP 요청 도착
      │
[Acceptor Thread]  ← 연결 수락 전담 (1~2개)
      │
[Poller Thread]    ← NIO 이벤트 감시 (CPU 코어 수에 비례)
      │
[Worker Thread Pool]  ← 실제 요청 처리
      │  (minSpareThreads ~ maxThreads)
      │
[Servlet 실행]
```

### 주요 스레드 파라미터

| 파라미터 | 기본값 | 설명 |
|---------|--------|------|
| maxThreads | 200 | 최대 Worker 스레드 수 |
| minSpareThreads | 10 | 최소 대기 스레드 수 |
| acceptCount | 100 | 스레드 포화 시 대기 큐 크기 |
| connectionTimeout | 20000 | 커넥션 타임아웃 (ms) |

---

## Valve (파이프라인 필터)

Valve는 요청/응답 파이프라인에 삽입되는 컴포넌트입니다.
Filter와 유사하지만 Tomcat 레벨에서 동작합니다.

```
요청 → [Valve1] → [Valve2] → [Valve3] → Servlet
응답 ← [Valve1] ← [Valve2] ← [Valve3] ← Servlet
```

### 내장 Valve 목록

| Valve | 기능 |
|-------|------|
| `AccessLogValve` | 접근 로그 기록 |
| `RemoteAddrValve` | IP 기반 접근 제어 |
| `RemoteHostValve` | 호스트명 기반 접근 제어 |
| `RequestDumperValve` | 요청/응답 전체 내용 덤프 (디버깅용) |
| `StuckThreadDetectionValve` | 장시간 블록된 스레드 감지 |
| `RewriteValve` | URL 재작성 |
| `ErrorReportValve` | 에러 페이지 처리 |

---

## Realm (인증/인가)

Realm은 사용자 인증 정보를 저장하고 검증하는 컴포넌트입니다.

| Realm | 저장소 |
|-------|--------|
| `MemoryRealm` | tomcat-users.xml 파일 |
| `JDBCRealm` | JDBC 데이터베이스 |
| `JNDIRealm` | LDAP / Active Directory |
| `DataSourceRealm` | JNDI DataSource |
| `JAASRealm` | Java Authentication and Authorization Service |

---

## Catalina 생명주기

```
[INIT]
  │  LifecycleListener 실행 (AprLifecycleListener 등)
  ▼
[START]
  │  Connector 포트 바인딩
  │  Context 초기화 (web.xml 파싱, Servlet 인스턴스 생성)
  ▼
[RUNNING]  ← 정상 운영 상태
  │
  ▼
[STOP]
  │  현재 처리 중인 요청 완료 대기
  │  Servlet destroy() 호출
  │  커넥션 풀 반납
  ▼
[DESTROY]
```

---

## 프로세스 구조

```bash
# Tomcat은 단일 JVM 프로세스로 실행됨
ps aux | grep tomcat

# 스레드 목록 확인 (java 프로세스의 스레드)
jstack $(pgrep -f tomcat) | grep "Thread"

# 힙 메모리 사용량
jmap -heap $(pgrep -f tomcat)
```

---

## Coyote / Catalina / Jasper

Tomcat 내부는 세 개의 주요 서브 프로젝트로 구성됩니다.

| 서브 프로젝트 | 역할 |
|-------------|------|
| **Coyote** | 네트워크 계층 (Connector, HTTP 파싱) |
| **Catalina** | 서블릿 컨테이너 (Engine, Host, Context 관리) |
| **Jasper** | JSP 엔진 (JSP → Java 소스 → 바이트코드 컴파일) |

```
[네트워크 요청]
      │
  [Coyote]       ← TCP 소켓, HTTP/AJP 프로토콜 처리
      │
  [Catalina]     ← 서블릿 라이프사이클, 세션, 필터, Realm
      │
  [Jasper]       ← JSP 컴파일 및 실행 (해당되는 경우)
      │
  [애플리케이션]
```
