# 🚀 GitHub Webhook Auto-Deployment Setup

Dieses Setup ermöglicht automatisches Deployment deiner Plausible Analytics Installation auf dem Hetzner Server bei jedem Push zu GitHub.

## 📋 Übersicht

Wenn du Code zu GitHub pushst:
1. GitHub sendet einen Webhook an deinen Server
2. Der Webhook-Server empfängt und verifiziert die Anfrage
3. Das Deploy-Script wird automatisch ausgeführt:
   - Lädt den neuesten Code herunter
   - Baut neue Docker Images
   - Startet die Services neu
   - Führt Datenbank-Migrationen aus

## 🔧 Installation auf dem Hetzner Server

### Schritt 1: Dateien auf den Server kopieren

```bash
# Auf deinem lokalen Rechner
cd C:\Users\Atti\projekte\plausble-analytics
git add deployment/
git commit -m "Add auto-deployment setup"
git push origin master

# Auf dem Hetzner Server (via SSH)
ssh root@stats.tripleadigital.de
cd /opt/plausible
git pull origin master
```

### Schritt 2: Berechtigungen setzen

```bash
chmod +x /opt/plausible/deployment/deploy.sh
chmod +x /opt/plausible/deployment/webhook_server.py
```

### Schritt 3: Webhook Secret generieren

```bash
# Generiere ein sicheres Secret
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo "Dein Webhook Secret: $WEBHOOK_SECRET"
# WICHTIG: Speichere dieses Secret! Du brauchst es für GitHub und die systemd-Konfiguration
```

### Schritt 4: Systemd Service installieren

```bash
# Bearbeite die Service-Datei und setze dein WEBHOOK_SECRET
nano /opt/plausible/deployment/plausible-webhook.service

# Ersetze "YOUR_SECRET_HERE_CHANGE_ME" mit deinem generierten Secret
# Environment="WEBHOOK_SECRET=dein_generiertes_secret_hier"

# Kopiere die Service-Datei
cp /opt/plausible/deployment/plausible-webhook.service /etc/systemd/system/

# Lade systemd neu
systemctl daemon-reload

# Starte den Service
systemctl start plausible-webhook

# Aktiviere Autostart
systemctl enable plausible-webhook

# Prüfe den Status
systemctl status plausible-webhook
```

### Schritt 5: Nginx konfigurieren

```bash
# Öffne deine nginx-Konfiguration
nano /etc/nginx/sites-available/stats.tripleadigital.de

# Füge den location-Block aus deployment/nginx-webhook.conf hinzu
# Innerhalb deines bestehenden server { ... } Blocks

# Teste die Konfiguration
nginx -t

# Wenn OK, lade nginx neu
systemctl reload nginx
```

### Schritt 6: Log-Dateien erstellen

```bash
# Erstelle Log-Dateien mit den richtigen Berechtigungen
touch /var/log/plausible-webhook.log
touch /var/log/plausible-deploy.log
chmod 644 /var/log/plausible-webhook.log
chmod 644 /var/log/plausible-deploy.log
```

## 🔐 GitHub Webhook einrichten

### 1. Gehe zu deinem GitHub Repository
`https://github.com/attislav/plausble-analytics/settings/hooks`

### 2. Klicke auf "Add webhook"

### 3. Konfiguriere den Webhook:
- **Payload URL**: `https://stats.tripleadigital.de/github-webhook`
- **Content type**: `application/json`
- **Secret**: Dein generiertes Webhook Secret (aus Schritt 3)
- **SSL verification**: Enable SSL verification
- **Which events**: "Just the push event"
- **Active**: ✓ Aktiviert

### 4. Klicke auf "Add webhook"

## ✅ Testen

### Test 1: Webhook-Server läuft

```bash
# Auf dem Server
systemctl status plausible-webhook

# Sollte "active (running)" anzeigen
```

### Test 2: Logs prüfen

```bash
# Webhook-Server Logs
tail -f /var/log/plausible-webhook.log

# Deployment Logs
tail -f /var/log/plausible-deploy.log
```

### Test 3: Manueller Test

```bash
# Mache eine kleine Änderung und pushe
echo "# Test" >> README.md
git add README.md
git commit -m "Test auto-deployment"
git push origin master

# Prüfe auf dem Server die Logs:
tail -f /var/log/plausible-webhook.log
tail -f /var/log/plausible-deploy.log
```

### Test 4: GitHub Webhook-Status prüfen

Gehe zu: `https://github.com/attislav/plausble-analytics/settings/hooks`
- Klicke auf deinen Webhook
- Scrolle zu "Recent Deliveries"
- Prüfe ob der Request erfolgreich war (grünes ✓)

## 📊 Monitoring

### Logs anschauen

```bash
# Live-Logs
journalctl -u plausible-webhook -f

# Letzte 100 Zeilen
journalctl -u plausible-webhook -n 100

# Deployment Logs
tail -100 /var/log/plausible-deploy.log
```

### Service neu starten

```bash
systemctl restart plausible-webhook
```

### Service stoppen

```bash
systemctl stop plausible-webhook
```

## 🛠️ Troubleshooting

### Webhook kommt nicht an?

1. Prüfe nginx-Konfiguration:
   ```bash
   nginx -t
   systemctl status nginx
   ```

2. Prüfe ob Port 9000 läuft:
   ```bash
   netstat -tlnp | grep 9000
   ```

3. Prüfe Firewall:
   ```bash
   ufw status
   # Port 443 sollte offen sein (HTTPS)
   ```

### Deployment schlägt fehl?

1. Prüfe Berechtigungen:
   ```bash
   ls -la /opt/plausible/deployment/deploy.sh
   ```

2. Teste Deploy-Script manuell:
   ```bash
   /opt/plausible/deployment/deploy.sh
   ```

3. Prüfe Docker:
   ```bash
   docker-compose ps
   docker-compose logs
   ```

### Logs zeigen Fehler?

```bash
# Webhook-Server Logs
journalctl -u plausible-webhook -n 50

# Deployment Logs
tail -50 /var/log/plausible-deploy.log

# Nginx Error Logs
tail -50 /var/log/nginx/error.log
```

## 🔒 Sicherheit

- ✅ HMAC-SHA256 Signatur-Verifizierung aktiviert
- ✅ Webhook läuft nur auf localhost (127.0.0.1)
- ✅ Nginx als Reverse Proxy mit SSL
- ✅ Secret wird in Environment Variable gespeichert
- ⚠️ Optional: GitHub IP-Whitelist in nginx aktivieren (siehe nginx-webhook.conf)

## 📝 Wartung

### Secret ändern

```bash
# Neues Secret generieren
NEW_SECRET=$(openssl rand -hex 32)

# In systemd Service aktualisieren
nano /etc/systemd/system/plausible-webhook.service

# Service neu laden
systemctl daemon-reload
systemctl restart plausible-webhook

# In GitHub Webhook aktualisieren
# Gehe zu: https://github.com/attislav/plausble-analytics/settings/hooks
```

## 📚 Weitere Informationen

- GitHub Webhooks Doku: https://docs.github.com/en/webhooks
- GitHub IP-Ranges: https://api.github.com/meta
- Plausible Docs: https://plausible.io/docs

---

## 🎯 Workflow nach dem Setup

Nach erfolgreichem Setup musst du **nichts mehr manuell machen**:

1. ✏️ Du machst Änderungen lokal
2. 💾 `git commit -m "Deine Änderung"`
3. 📤 `git push origin master`
4. 🤖 **Automatisches Deployment läuft!**
5. ✅ Nach ~2 Minuten ist die Änderung live auf stats.tripleadigital.de

Du kannst den Fortschritt in den Logs verfolgen:
```bash
ssh root@stats.tripleadigital.de "tail -f /var/log/plausible-deploy.log"
```
