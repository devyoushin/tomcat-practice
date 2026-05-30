# Tomcat Restart Runbook

## 사전 확인

```bash
systemctl status tomcat
$CATALINA_HOME/bin/configtest.sh
df -h
free -m
```

## 재시작

```bash
sudo systemctl restart tomcat
```

## 검증

```bash
systemctl status tomcat
tail -n 100 /opt/tomcat/logs/catalina.out
curl -fsS http://127.0.0.1:8080/
```

## 롤백 기준

- 서비스가 기동하지 않음
- 헬스체크 실패
- 5xx 급증
- GC pause 또는 CPU 사용률 급증
