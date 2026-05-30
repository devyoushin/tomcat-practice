# Tomcat Incident Runbook

## 1. 상태 확인

```bash
systemctl status tomcat
ps -ef | grep '[t]omcat'
ss -lntp | grep 8080
```

## 2. 로그 확인

```bash
tail -n 200 /opt/tomcat/logs/catalina.out
tail -n 200 /opt/tomcat/logs/localhost.*.log
tail -n 200 /opt/tomcat/logs/access*.log
```

## 3. JVM 확인

```bash
jcmd $(pgrep -f 'org.apache.catalina.startup.Bootstrap') VM.flags
jcmd $(pgrep -f 'org.apache.catalina.startup.Bootstrap') GC.heap_info
jcmd $(pgrep -f 'org.apache.catalina.startup.Bootstrap') Thread.print | head -200
```

## 4. 조치 기준

| 증상 | 우선 조치 |
|------|-----------|
| 포트 미리스닝 | systemd 상태와 catalina.out 확인 |
| 5xx 증가 | 애플리케이션 로그, DB 연결, thread dump 확인 |
| OOM | heap dump 확보 후 재시작 |
| 응답 지연 | thread dump, GC log, connection pool 확인 |
