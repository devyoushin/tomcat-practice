# 09. 클래스로더 (ClassLoader)

## Tomcat 클래스로더 계층 구조

Java의 기본 클래스로더 위임 모델과 다르게,
Tomcat은 웹 애플리케이션 간 격리를 위한 독자적인 클래스로더 계층을 구성합니다.

```
Bootstrap ClassLoader          ← JVM 기본: rt.jar, java.* 클래스
       │
Extension ClassLoader          ← $JAVA_HOME/lib/ext
       │
System ClassLoader             ← CLASSPATH, catalina.sh에서 설정
       │
Common ClassLoader             ← $CATALINA_HOME/lib/
(공유: 모든 앱 + Tomcat 내부)
       │
    ┌──┴──┐
    │     │
 Catalina  Shared             ← Tomcat 내부 전용 / 모든 앱 공유
    │     │
    └──┬──┘
       │
 WebApp ClassLoader            ← 앱별 격리 (WEB-INF/classes, WEB-INF/lib)
(각 Context마다 독립적인 인스턴스)
```

---

## 클래스로더 탐색 순서 (웹 앱)

Tomcat의 WebApp ClassLoader는 **역위임(Inverted Delegation)** 모델을 사용합니다.
일반 Java와 달리 부모보다 자신을 먼저 탐색합니다.

```
요청 클래스: com.example.MyClass

1. Bootstrap / JVM 기본 클래스 (항상 먼저)
2. WEB-INF/classes/  ← 앱 고유 클래스 (부모보다 먼저!)
3. WEB-INF/lib/*.jar ← 앱 고유 라이브러리
4. $CATALINA_HOME/lib/ (Common ClassLoader)
5. System ClassLoader
```

이 덕분에 앱별로 서로 다른 버전의 라이브러리를 사용할 수 있습니다.

---

## 각 ClassLoader의 탐색 경로

### Bootstrap
- `$JAVA_HOME/lib/rt.jar`
- JVM 내장 클래스 (`java.*`, `javax.*` 일부)

### System ClassLoader
```bash
# catalina.sh에서 설정하는 CLASSPATH
# bootstrap.jar, tomcat-juli.jar 등
echo $CLASSPATH
```

### Common ClassLoader
```
$CATALINA_HOME/lib/
├── catalina.jar
├── catalina-ant.jar
├── servlet-api.jar
├── jsp-api.jar
├── jasper.jar
└── (여기에 추가한 JAR: 모든 앱이 공유)
    ├── mysql-connector-j-*.jar   ← JDBC 드라이버는 여기 추가 권장
    └── ...
```

### WebApp ClassLoader
```
WEB-INF/classes/   ← 앱 고유 .class 파일
WEB-INF/lib/*.jar  ← 앱 고유 라이브러리
```

---

## JDBC 드라이버 배치 위치

### 방법 1: `$CATALINA_HOME/lib/` (모든 앱 공유, 권장)

```bash
# JDBC 드라이버를 Common ClassLoader 경로에 배치
sudo cp mysql-connector-j-8.x.x.jar /opt/tomcat/lib/
sudo chown tomcat:tomcat /opt/tomcat/lib/mysql-connector-j-8.x.x.jar

# Tomcat 재시작 필요
sudo systemctl restart tomcat
```

장점: 여러 앱이 동일한 드라이버 공유, 앱 WAR 크기 감소
단점: 버전 충돌 가능성 (앱마다 다른 버전 필요 시 불리)

### 방법 2: `WEB-INF/lib/` (앱 전용)

```bash
# 앱 고유 버전이 필요할 때 WAR 내부에 포함
myapp.war
└── WEB-INF/
    └── lib/
        └── mysql-connector-j-8.x.x.jar
```

---

## 클래스 재로딩 (Hot Reload)

```xml
<!-- context.xml 또는 앱별 Context 설정 -->
<Context reloadable="true">
    <!-- true: WEB-INF/classes, WEB-INF/lib 변경 감지 시 자동 재로딩 -->
    <!-- 개발 환경: true / 운영 환경: false (성능 저하) -->
</Context>
```

```bash
# 수동 재로딩 (Manager App)
curl -u admin:password \
  "http://localhost:8080/manager/text/reload?path=/myapp"
```

---

## 클래스 충돌 문제 해결

### 증상
- `ClassCastException`: 같은 클래스인데 캐스팅 실패
- `ClassNotFoundException`: 클래스를 찾을 수 없음
- `NoClassDefFoundError`: 클래스 정의를 찾을 수 없음

### 원인 파악

```bash
# 어떤 ClassLoader가 로드했는지 확인 (Java 코드)
System.out.println(SomeClass.class.getClassLoader());

# 클래스 파일 위치 확인
getClass().getProtectionDomain().getCodeSource().getLocation()
```

### context.xml의 `<Loader>` 설정

```xml
<!-- 클래스 탐색 순서 변경: 부모 우선 (표준 Java 위임 모델) -->
<Context>
    <Loader className="org.apache.catalina.loader.WebappClassLoader"
            delegate="true" />
    <!-- delegate="true": 부모 ClassLoader 먼저 탐색 (기본: false) -->
</Context>
```

---

## 메모리 누수 방지

### 일반적인 누수 원인
- `ThreadLocal` 미정리
- JDBC 드라이버 등록 해제 미처리
- 로깅 프레임워크 정적 참조

### Tomcat 자동 감지 (JreMemoryLeakPreventionListener)

```xml
<!-- server.xml -->
<Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
<Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
```

### 앱에서 JDBC 드라이버 직접 해제

```java
// ServletContextListener.contextDestroyed()
@Override
public void contextDestroyed(ServletContextEvent sce) {
    // JDBC 드라이버 해제 (java.sql.DriverManager)
    Enumeration<Driver> drivers = DriverManager.getDrivers();
    while (drivers.hasMoreElements()) {
        Driver driver = drivers.nextElement();
        try {
            DriverManager.deregisterDriver(driver);
        } catch (SQLException e) {
            // 로그 처리
        }
    }
}
```

---

## catalina.properties에서 ClassLoader 설정

```properties
# $CATALINA_HOME/conf/catalina.properties

# Common ClassLoader 추가 경로
common.loader="${catalina.base}/lib","${catalina.base}/lib/*.jar","${catalina.home}/lib","${catalina.home}/lib/*.jar"

# Server ClassLoader (Tomcat 내부 전용)
server.loader=

# Shared ClassLoader (모든 앱 공유, Server 전용 제외)
shared.loader=
```

```bash
# 특정 디렉토리를 shared loader에 추가 (예: /opt/shared-libs)
# catalina.properties 수정
shared.loader=/opt/shared-libs/*.jar
```
