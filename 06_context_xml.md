# 06. context.xml 설정

## context.xml 위치와 우선순위

```
conf/context.xml                           ← 전역 기본값 (모든 앱에 적용)
conf/Catalina/localhost/ROOT.xml           ← ROOT 앱 전용
conf/Catalina/localhost/myapp.xml          ← myapp 전용 (가장 높은 우선순위)
webapps/myapp/META-INF/context.xml         ← WAR 내부 (앱 배포 시 복사됨)
```

---

## 전역 context.xml 기본 구조

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Context>

    <!-- WatchedResource: 변경 감지 시 앱 재로드 -->
    <WatchedResource>WEB-INF/web.xml</WatchedResource>
    <WatchedResource>WEB-INF/tomcat-web.xml</WatchedResource>
    <WatchedResource>${catalina.base}/conf/web.xml</WatchedResource>

    <!-- 세션 지속성 관리자 (서버 재시작 시 세션 유지) -->
    <Manager className="org.apache.catalina.session.PersistentManager"
             saveOnRestart="true">
        <Store className="org.apache.catalina.session.FileStore"
               directory="${catalina.base}/work/sessions" />
    </Manager>

</Context>
```

---

## Context 주요 속성

```xml
<Context
    path="/myapp"                <!-- URL 컨텍스트 경로 -->
    docBase="/opt/myapp"         <!-- 실제 파일 시스템 경로 -->
    reloadable="false"           <!-- WEB-INF/classes, WEB-INF/lib 변경 감지 재로드 (운영: false) -->
    crossContext="false"         <!-- 다른 Context 간 RequestDispatcher 공유 -->
    privileged="false"           <!-- Tomcat 내부 Valve 사용 허용 여부 -->
    antiResourceLocking="false"  <!-- Windows에서 WAR 언락 (Linux는 불필요) -->
    sessionCookieName="JSESSIONID"
    sessionCookieHttpOnly="true"
    sessionCookieSecure="true"
    useHttpOnly="true">
```

---

## 앱별 Context 파일 (conf/Catalina/localhost/myapp.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Context path="/myapp"
         docBase="/opt/myapp"
         reloadable="false">

    <!-- JNDI DataSource (DB 커넥션 풀) -->
    <Resource name="jdbc/mydb"
              auth="Container"
              type="javax.sql.DataSource"
              factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
              driverClassName="com.mysql.cj.jdbc.Driver"
              url="jdbc:mysql://localhost:3306/mydb?useSSL=false&amp;serverTimezone=UTC"
              username="dbuser"
              password="dbpassword"
              maxTotal="50"
              maxIdle="20"
              minIdle="5"
              maxWaitMillis="10000"
              validationQuery="SELECT 1"
              testOnBorrow="true"
              testWhileIdle="true"
              timeBetweenEvictionRunsMillis="60000" />

    <!-- 환경 변수 (앱에서 java:comp/env/xxx 로 참조) -->
    <Environment name="appVersion"
                 value="1.0.0"
                 type="java.lang.String"
                 override="false" />

    <!-- 접근 로그 (앱별 별도 로그) -->
    <Valve className="org.apache.catalina.valves.AccessLogValve"
           directory="${catalina.base}/logs"
           prefix="myapp_access_log"
           suffix=".txt"
           pattern="%h %l %u %t &quot;%r&quot; %s %b %D" />

</Context>
```

---

## JNDI DataSource 상세 설정

### Tomcat JDBC Connection Pool

```xml
<Resource name="jdbc/mydb"
          auth="Container"
          type="javax.sql.DataSource"
          factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"

          <!-- 드라이버 -->
          driverClassName="com.mysql.cj.jdbc.Driver"
          url="jdbc:mysql://db-host:3306/mydb?useSSL=true&amp;serverTimezone=Asia/Seoul"
          username="myuser"
          password="mypassword"

          <!-- 풀 크기 -->
          initialSize="5"            <!-- 초기 연결 수 -->
          maxTotal="50"              <!-- 최대 연결 수 (maxActive) -->
          maxIdle="20"               <!-- 최대 유휴 연결 수 -->
          minIdle="5"                <!-- 최소 유휴 연결 수 -->
          maxWaitMillis="10000"      <!-- 연결 대기 타임아웃 (ms) -->

          <!-- 연결 유효성 검사 -->
          validationQuery="SELECT 1"
          testOnBorrow="true"        <!-- 연결 빌릴 때 유효성 검사 -->
          testOnReturn="false"       <!-- 반납 시 유효성 검사 -->
          testWhileIdle="true"       <!-- 유휴 연결 주기적 검사 -->
          timeBetweenEvictionRunsMillis="60000"   <!-- 유휴 검사 주기 (ms) -->
          minEvictableIdleTimeMillis="300000"     <!-- 최소 유휴 대기 후 제거 (ms) -->

          <!-- 연결 유지 -->
          removeAbandoned="true"           <!-- 오래된 연결 자동 제거 -->
          removeAbandonedTimeout="300"     <!-- 제거 기준 시간 (초) -->
          logAbandoned="true"              <!-- 제거된 연결 로그 -->

          <!-- 기타 -->
          defaultAutoCommit="true" />
```

### HikariCP 사용 (Tomcat 기본 풀 대체)

```xml
<!-- lib/ 에 HikariCP JAR 추가 필요 -->
<Resource name="jdbc/mydb"
          auth="Container"
          type="com.zaxxer.hikari.HikariDataSource"
          factory="com.zaxxer.hikari.HikariJNDIFactory"
          driverClassName="com.mysql.cj.jdbc.Driver"
          jdbcUrl="jdbc:mysql://localhost:3306/mydb"
          username="myuser"
          password="mypassword"
          maximumPoolSize="50"
          minimumIdle="5"
          connectionTimeout="30000"
          idleTimeout="600000"
          maxLifetime="1800000"
          connectionTestQuery="SELECT 1" />
```

---

## 세션 관리 설정

### 기본 메모리 세션 (DeltaManager)

```xml
<Context>
    <!-- 기본: 메모리 저장 (재시작 시 세션 삭제) -->
    <Manager className="org.apache.catalina.session.StandardManager"
             maxActiveSessions="-1"        <!-- 최대 세션 수 (-1: 무제한) -->
             sessionIdLength="32" />
</Context>
```

### 파일 기반 세션 지속성

```xml
<Context>
    <!-- 재시작해도 세션 유지 -->
    <Manager className="org.apache.catalina.session.PersistentManager"
             saveOnRestart="true"
             maxIdleBackup="60"            <!-- 60초 유휴 시 파일에 백업 -->
             minIdleSwap="60"
             maxIdleSwap="600">
        <Store className="org.apache.catalina.session.FileStore"
               directory="${catalina.base}/work/sessions" />
    </Manager>
</Context>
```

### JDBC 기반 세션 (분산 환경)

```xml
<Context>
    <Manager className="org.apache.catalina.session.PersistentManager">
        <Store className="org.apache.catalina.session.JDBCStore"
               driverName="com.mysql.cj.jdbc.Driver"
               connectionURL="jdbc:mysql://db-host:3306/tomcat_sessions"
               connectionName="sessionuser"
               connectionPassword="sessionpass"
               sessionTable="tomcat_sessions"
               sessionIdCol="session_id"
               sessionDataCol="session_data"
               sessionValidCol="session_valid"
               sessionMaxInactiveCol="max_inactive"
               sessionLastAccessedCol="last_access" />
    </Manager>
</Context>
```

```sql
-- 세션 테이블 생성 SQL
CREATE TABLE tomcat_sessions (
    session_id     VARCHAR(100) NOT NULL PRIMARY KEY,
    valid_session  CHAR(1)      NOT NULL,
    max_inactive   INT          NOT NULL,
    last_access    BIGINT       NOT NULL,
    app_name       VARCHAR(255),
    session_data   MEDIUMBLOB,
    KEY kapp_name  (app_name)
);
```

---

## 환경 변수 설정

```xml
<Context>
    <!-- String 타입 -->
    <Environment name="appEnv"
                 value="production"
                 type="java.lang.String"
                 override="false" />

    <!-- Integer 타입 -->
    <Environment name="maxRetry"
                 value="3"
                 type="java.lang.Integer"
                 override="false" />

    <!-- Boolean 타입 -->
    <Environment name="debugMode"
                 value="false"
                 type="java.lang.Boolean"
                 override="false" />
</Context>
```

Java 코드에서 참조:

```java
Context ctx = new InitialContext();
String env = (String) ctx.lookup("java:comp/env/appEnv");
```

---

## 리소스 참조

```xml
<!-- 외부 디렉토리를 웹 앱 리소스로 마운트 -->
<Context docBase="/opt/myapp">
    <!-- /uploads URL을 /data/uploads 실제 경로로 매핑 -->
    <Resources>
        <PreResources className="org.apache.catalina.webresources.DirResourceSet"
                      base="/data/uploads"
                      webAppMount="/uploads"
                      internalPath="/" />
    </Resources>
</Context>
```
