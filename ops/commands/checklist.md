# Tomcat Commands

## 서비스

```bash
systemctl status tomcat
systemctl restart tomcat
journalctl -u tomcat -n 200 --no-pager
```

## 포트와 프로세스

```bash
ps -ef | grep '[t]omcat'
ss -lntp | grep -E '8080|8443|8009'
```

## 로그

```bash
tail -f /opt/tomcat/logs/catalina.out
tail -f /opt/tomcat/logs/access*.log
tail -f /opt/tomcat/logs/gc.log
```

## JVM

```bash
jcmd $(pgrep -f 'org.apache.catalina.startup.Bootstrap') VM.version
jcmd $(pgrep -f 'org.apache.catalina.startup.Bootstrap') GC.heap_info
jcmd $(pgrep -f 'org.apache.catalina.startup.Bootstrap') Thread.print
```
