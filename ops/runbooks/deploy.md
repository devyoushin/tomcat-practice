# Tomcat Deploy Runbook

## 배포 전

```bash
$CATALINA_HOME/bin/configtest.sh
systemctl status tomcat
ls -lh /opt/tomcat/webapps
```

## 단일 서버 배포

```bash
sudo systemctl stop tomcat
sudo cp /tmp/myapp.war /opt/tomcat/webapps/myapp.war
sudo chown tomcat:tomcat /opt/tomcat/webapps/myapp.war
sudo systemctl start tomcat
```

## 검증

```bash
curl -fsS http://127.0.0.1:8080/myapp/
tail -n 200 /opt/tomcat/logs/catalina.out
```

## 실패 시

```bash
sudo systemctl stop tomcat
sudo cp /backup/myapp.war /opt/tomcat/webapps/myapp.war
sudo chown tomcat:tomcat /opt/tomcat/webapps/myapp.war
sudo systemctl start tomcat
```
