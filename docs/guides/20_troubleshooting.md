# 20. 트러블슈팅

## 시작 실패

### 증상: 서비스 시작 안 됨

```bash
# 1. systemd 상태 확인
sudo systemctl status tomcat
sudo journalctl -xe -u tomcat

# 2. catalina.out 확인 (가장 중요)
sudo tail -100 /opt/tomcat/logs/catalina.out

# 3. 포트 충돌 확인
sudo ss -tlnp | grep :8080
sudo fuser 8080/tcp

# 4. 설정 파일 문법 오류 확인
sudo -u tomcat /opt/tomcat/bin/configtest.sh
```

### 증상: 포트 이미 사용 중

```bash
# 어떤 프로세스가 8080 사용 중인지 확인
sudo ss -tlnp | grep :8080
sudo fuser -v 8080/tcp

# PID 확인 후 프로세스 종료
sudo kill -9 <PID>

# 또는 Tomcat 포트 변경 (server.xml)
<Connector port="8090" .../>
```

### 증상: JAVA_HOME 설정 오류

```bash
# 오류: Cannot find java
# JAVA_HOME 확인
echo $JAVA_HOME
java -version
which java

# setenv.sh에 명시적으로 설정
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64' >> /opt/tomcat/bin/setenv.sh
```

---

## 애플리케이션 배포 오류

### 증상: WAR 배포 후 404

```bash
# webapps/ 디렉토리 확인
ls /opt/tomcat/webapps/

# WAR 압축 해제 여부 확인 (unpackWARs="true" 필요)
# WEB-INF/web.xml 유무 확인
ls /opt/tomcat/webapps/myapp/WEB-INF/

# localhost.YYYY-MM-DD.log 확인 (앱별 오류)
cat /opt/tomcat/logs/localhost.$(date +%Y-%m-%d).log

# Context 설정 오류 확인
sudo -u tomcat /opt/tomcat/bin/configtest.sh
```

### 증상: 클래스 로딩 오류

```bash
# catalina.out에서 ClassNotFoundException 확인
grep "ClassNotFoundException\|NoClassDefFoundError" /opt/tomcat/logs/catalina.out

# WEB-INF/lib 확인
ls /opt/tomcat/webapps/myapp/WEB-INF/lib/

# 충돌 클래스 확인 (같은 클래스가 여러 JAR에 존재하는 경우)
find /opt/tomcat -name "*.jar" -exec jar -tf {} \; 2>/dev/null | grep "com/example/MyClass" | sort
```

### 증상: Tomcat 10에서 javax.servlet 오류

```
jakarta.servlet 패키지로 변경 필요
```

```bash
# 오류: java.lang.ClassNotFoundException: javax.servlet.http.HttpServlet
# Tomcat 10+는 jakarta.servlet 사용 (javax.servlet 제거됨)

# 해결 방법 1: Tomcat 9로 다운그레이드
# 해결 방법 2: 코드에서 javax.* → jakarta.* 변경
# 해결 방법 3: jakarta-migration 도구 사용
java -jar jakartaee-migration-1.0.6-shaded.jar myapp.war myapp-jakarta.war
```

---

## OutOfMemoryError (OOM)

### 힙 메모리 부족

```bash
# 오류: java.lang.OutOfMemoryError: Java heap space

# 1. 현재 힙 사용량 확인
jmap -heap $(pgrep -f tomcat)

# 2. 힙 크기 증가 (setenv.sh)
export CATALINA_OPTS="-Xms1g -Xmx4g ..."

# 3. 힙 덤프 분석 (OOM 시 자동 덤프 활성화)
export CATALINA_OPTS="$CATALINA_OPTS -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/heap.hprof"

# 4. 힙 덤프를 Eclipse MAT 또는 VisualVM으로 분석
# 메모리 누수 가능성 있는 객체 확인
```

### Metaspace 부족

```bash
# 오류: java.lang.OutOfMemoryError: Metaspace

# 클래스 로딩 수 확인 (너무 많으면 MetaspaceSize 증가)
jstat -class $(pgrep -f tomcat)

# 해결: MetaspaceSize 증가
export CATALINA_OPTS="$CATALINA_OPTS -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"
```

### 스레드 OOM

```bash
# 오류: java.lang.OutOfMemoryError: unable to create new native thread

# 현재 스레드 수 확인
cat /proc/$(pgrep -f tomcat)/status | grep Threads

# OS 제한 확인
ulimit -u  # 최대 프로세스/스레드 수
cat /proc/sys/kernel/threads-max

# 해결: maxThreads 감소 또는 OS 한계 증가
```

---

## 느린 응답 / 스레드 교착

### 스레드 덤프 분석

```bash
# 스레드 덤프 수집 (10초 간격으로 3회)
for i in 1 2 3; do
    jstack $(pgrep -f tomcat) > /tmp/thread_dump_${i}.txt
    sleep 10
done

# 교착 상태 확인
grep -A5 "deadlock\|BLOCKED" /tmp/thread_dump_1.txt

# 오래 실행 중인 요청 확인 (StuckThreadDetectionValve 설정 필요)
grep "appears to have stuck" /opt/tomcat/logs/catalina.out
```

### DB 커넥션 풀 고갈

```bash
# 증상: 요청이 maxWaitMillis 후 에러
# 오류: Cannot get a connection, pool error Timeout waiting for idle object

# 현재 DB 연결 수 확인 (MySQL)
mysql -u root -p -e "SHOW STATUS LIKE 'Threads_connected';"
mysql -u root -p -e "SHOW PROCESSLIST;"

# 커넥션 풀 크기 증가 (context.xml)
# maxTotal 값 증가
# removeAbandoned="true" 활성화 (누수된 커넥션 자동 회수)
```

---

## 메모리 누수

```bash
# 증상: 시간이 지남에 따라 메모리 계속 증가, OOM 발생

# 1. 힙 히스토그램으로 증가하는 클래스 확인
jmap -histo:live $(pgrep -f tomcat) | head -30

# 2. 주요 원인
# - ThreadLocal 미정리
# - 정적(static) 컬렉션에 객체 계속 추가
# - JDBC 드라이버 deregister 미처리
# - 이벤트 리스너 등록 후 해제 미처리
# - 캐시에서 객체 제거 미처리

# 3. ThreadLocal 누수 확인
# catalina.out에서 ThreadLocal 관련 경고 확인
grep -i "ThreadLocal" /opt/tomcat/logs/catalina.out

# 4. 앱 재배포(undeploy/deploy) 시 메모리 해제 여부 확인
# 재배포 전후 jmap 비교
```

---

## 자주 발생하는 오류 목록

### ClassCastException

```bash
# 원인: 같은 클래스가 다른 ClassLoader에서 로드됨
# 해결:
# - lib/에 배치한 클래스가 WEB-INF/lib/에도 있는지 확인
# - 클래스 배치 위치 통일
```

### Connection reset by peer

```bash
# 원인: 클라이언트가 응답을 받기 전에 연결 종료
# 주로 타임아웃, 클라이언트 종료 등 정상적 경우도 포함
# catalina.out에서 반복 발생 시 connectionTimeout 조정
```

### PermGen space (Java 8 이하)

```bash
# Java 8+에서는 Metaspace로 대체됨
# Java 7 이하: -XX:MaxPermSize=256m
```

---

## 진단 명령어 모음

```bash
# Tomcat 프로세스 정보
ps -ef | grep tomcat
ls -la /proc/$(pgrep -f tomcat)/fd | wc -l  # 파일 디스크립터 수

# 로그 요약
grep -c "ERROR\|SEVERE\|Exception" /opt/tomcat/logs/catalina.out  # 에러 수
grep -h "SEVERE\|ERROR" /opt/tomcat/logs/catalina.out | tail -20  # 최근 에러

# GC 상태
jstat -gc $(pgrep -f tomcat) 1000 10  # 1초마다 10회

# 힙 메모리 사용률 (빠른 확인)
jcmd $(pgrep -f tomcat) GC.heap_info

# 클래스 로딩 수
jstat -class $(pgrep -f tomcat)

# 포트 연결 상태
sudo ss -s  # 소켓 요약
sudo ss -tn | grep 8080 | awk '{print $1}' | sort | uniq -c  # 상태별 연결 수
```
