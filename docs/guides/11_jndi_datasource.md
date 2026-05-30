# 11. JDBC 커넥션 풀 (JNDI DataSource)

## 개요

JNDI(Java Naming and Directory Interface) DataSource를 통해
웹 애플리케이션 코드에서 DB 커넥션 풀을 컨테이너로부터 받아 사용합니다.

---

## 설정 흐름

```
conf/context.xml 또는
conf/Catalina/localhost/myapp.xml
         │
         │ <Resource name="jdbc/mydb" .../>
         ▼
Tomcat이 커넥션 풀 생성
         │
         │ java:comp/env/jdbc/mydb
         ▼
웹 앱 코드에서 JNDI Lookup
         │
         ▼
DataSource → Connection 획득 → SQL 실행
```

---

## MySQL 설정 예시

### 1. JDBC 드라이버 배치

```bash
# MySQL Connector/J 다운로드
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-8.x.x.tar.gz
tar xzf mysql-connector-j-8.x.x.tar.gz
sudo cp mysql-connector-j-8.x.x/mysql-connector-j-8.x.x.jar /opt/tomcat/lib/
sudo chown tomcat:tomcat /opt/tomcat/lib/mysql-connector-j-8.x.x.jar
```

### 2. context.xml 설정

```xml
<!-- conf/Catalina/localhost/myapp.xml 또는 conf/context.xml -->
<Context>
    <Resource
        name="jdbc/mydb"
        auth="Container"
        type="javax.sql.DataSource"
        factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"

        <!-- 드라이버 및 URL -->
        driverClassName="com.mysql.cj.jdbc.Driver"
        url="jdbc:mysql://db-host:3306/mydb?useSSL=true&amp;serverTimezone=Asia/Seoul&amp;characterEncoding=UTF-8"
        username="myuser"
        password="mypassword"

        <!-- 커넥션 풀 크기 -->
        initialSize="5"
        maxTotal="50"
        maxIdle="20"
        minIdle="5"
        maxWaitMillis="10000"

        <!-- 유효성 검사 -->
        validationQuery="SELECT 1"
        testOnBorrow="true"
        testWhileIdle="true"
        timeBetweenEvictionRunsMillis="60000"
        minEvictableIdleTimeMillis="300000"

        <!-- Abandoned 연결 처리 -->
        removeAbandoned="true"
        removeAbandonedTimeout="300"
        logAbandoned="true"
    />
</Context>
```

### 3. web.xml에 리소스 참조 등록

```xml
<!-- WEB-INF/web.xml -->
<resource-ref>
    <description>MySQL DataSource</description>
    <res-ref-name>jdbc/mydb</res-ref-name>
    <res-type>javax.sql.DataSource</res-type>
    <res-auth>Container</res-auth>
</resource-ref>
```

### 4. Java 코드에서 사용

```java
// JNDI Lookup
Context initCtx = new InitialContext();
Context envCtx = (Context) initCtx.lookup("java:comp/env");
DataSource ds = (DataSource) envCtx.lookup("jdbc/mydb");

// 또는 단축형
DataSource ds = (DataSource) new InitialContext().lookup("java:comp/env/jdbc/mydb");

// 커넥션 사용
try (Connection conn = ds.getConnection();
     PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?")) {
    ps.setInt(1, userId);
    try (ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
            // 처리
        }
    }
}
```

---

## PostgreSQL 설정 예시

```bash
# PostgreSQL JDBC 드라이버
wget https://jdbc.postgresql.org/download/postgresql-42.x.x.jar
sudo cp postgresql-42.x.x.jar /opt/tomcat/lib/
```

```xml
<Resource
    name="jdbc/pgdb"
    auth="Container"
    type="javax.sql.DataSource"
    factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
    driverClassName="org.postgresql.Driver"
    url="jdbc:postgresql://db-host:5432/mydb?ssl=true"
    username="myuser"
    password="mypassword"
    maxTotal="30"
    maxIdle="10"
    minIdle="5"
    maxWaitMillis="10000"
    validationQuery="SELECT 1"
    testOnBorrow="true" />
```

---

## Tomcat JDBC Pool vs HikariCP

### Tomcat JDBC Pool (기본 내장)

```xml
<Resource factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
          ...
          <!-- Tomcat 고유 속성 -->
          jdbcInterceptors="org.apache.tomcat.jdbc.pool.interceptor.ConnectionState;
                            org.apache.tomcat.jdbc.pool.interceptor.StatementFinalizer"
          useEquals="true"
          fairQueue="true" />
```

### HikariCP (성능 우수, 권장)

```bash
# lib/ 에 HikariCP JAR 배치
sudo cp HikariCP-*.jar /opt/tomcat/lib/
sudo cp slf4j-api-*.jar /opt/tomcat/lib/
sudo cp slf4j-simple-*.jar /opt/tomcat/lib/  # 또는 logback
```

```xml
<Resource
    name="jdbc/mydb"
    auth="Container"
    type="com.zaxxer.hikari.HikariDataSource"
    factory="com.zaxxer.hikari.HikariJNDIFactory"

    driverClassName="com.mysql.cj.jdbc.Driver"
    jdbcUrl="jdbc:mysql://db-host:3306/mydb?useSSL=true&amp;serverTimezone=Asia/Seoul"
    username="myuser"
    password="mypassword"

    <!-- HikariCP 설정 -->
    maximumPoolSize="50"
    minimumIdle="10"
    connectionTimeout="30000"       <!-- 커넥션 획득 타임아웃 (ms) -->
    idleTimeout="600000"            <!-- 유휴 커넥션 제거 시간 (ms) -->
    maxLifetime="1800000"           <!-- 커넥션 최대 수명 (ms) -->
    keepaliveTime="30000"           <!-- Keepalive 주기 (ms) -->
    connectionTestQuery="SELECT 1"  <!-- Java 6 드라이버용, 아니면 불필요 -->
    poolName="HikariPool-myapp"
    autoCommit="true" />
```

---

## 커넥션 풀 파라미터 설명

| 파라미터 | 설명 | 권장값 |
|---------|------|--------|
| `maxTotal` (maxActive) | 최대 커넥션 수 | CPU 코어 수 × 2 ~ 50 |
| `minIdle` | 최소 유휴 커넥션 수 | 5 ~ 10 |
| `maxIdle` | 최대 유휴 커넥션 수 | maxTotal의 50% |
| `maxWaitMillis` | 커넥션 대기 타임아웃 | 5000 ~ 10000ms |
| `testOnBorrow` | 대여 시 유효성 검사 | true (안정성 필요 시) |
| `validationQuery` | 유효성 검사 SQL | `SELECT 1` |
| `removeAbandoned` | 오래된 연결 자동 제거 | true |
| `removeAbandonedTimeout` | 제거 기준 시간 | 300초 |

---

## 비밀번호 암호화

패스워드를 평문으로 context.xml에 저장하지 않으려면:

### 방법 1: 환경 변수 참조

```xml
<!-- server.xml에서 시스템 속성 설정 -->
<Resource name="jdbc/mydb"
          ...
          password="${DB_PASSWORD}" />
```

```bash
# setenv.sh에서 환경 변수 설정
export CATALINA_OPTS="$CATALINA_OPTS -DDB_PASSWORD=실제패스워드"
```

### 방법 2: 커스텀 DataSourceFactory

```java
// EncryptedDataSourceFactory.java
public class EncryptedDataSourceFactory
    extends org.apache.tomcat.jdbc.pool.DataSourceFactory {

    @Override
    public DataSource createDataSource(Properties properties, ...) {
        String encryptedPwd = properties.getProperty("password");
        properties.setProperty("password", decrypt(encryptedPwd));
        return super.createDataSource(properties, ...);
    }

    private String decrypt(String encrypted) {
        // 복호화 로직
    }
}
```

```xml
<Resource factory="com.example.EncryptedDataSourceFactory"
          password="ENC(암호화된값)" ... />
```

---

## 커넥션 풀 모니터링

```bash
# Manager App Status 페이지에서 DB 풀 상태 확인
# http://localhost:8080/manager/status

# JMX로 확인
# MBean: Catalina:type=DataSource,host=localhost,context=/myapp,class=javax.sql.DataSource,name="jdbc/mydb"
# - numActive: 사용 중인 커넥션 수
# - numIdle: 유휴 커넥션 수
# - maxTotal: 최대 커넥션 수
```

```java
// 코드에서 풀 상태 확인
BasicDataSource ds = (BasicDataSource) dataSource;
int active = ds.getNumActive();
int idle   = ds.getNumIdle();
int max    = ds.getMaxTotal();
```
