[English](README.md) | Русский

# CoreServerKit

Bash-скрипт для начальной настройки и защиты Ubuntu/Debian серверов.

## Требования

* Ubuntu 20.04+ или Debian 11+
* Root-доступ
* Интернет-соединение

## Установка

**Через Git:**

```bash
git clone https://github.com/cs-eliseev/CoreServerKit.git
cd CoreServerKit
chmod +x server-init.sh
```

**Через curl:**

```bash
curl -L https://github.com/cs-eliseev/CoreServerKit/archive/refs/heads/main.tar.gz | tar -xz
cd CoreServerKit-main
chmod +x server-init.sh
```

## Использование

```bash
sudo ./server-init.sh [OPTION]
```

| Опция               | Описание                                            |
|---------------------|-----------------------------------------------------|
| `-u`, `--user`      | Создать sudo-пользователя                           |
| `-k`, `--ssh-key`   | Добавить или сгенерировать SSH-ключ                 |
| `-s`, `--security`  | Настройка безопасности (SSH, UFW, fail2ban)         |
| `-t`, `--speedtest` | Установить Ookla Speedtest CLI                      |
| `-U`, `--update`    | Обновить систему                                    |
| `-V`, `--verify`    | Проверить текущую конфигурацию                      |
| `-d`, `--defaults`  | Полный цикл без вопросов, все значения по умолчанию |

Без опций запускается полный цикл в интерактивном режиме.

## Что делает скрипт

**Пользователь** — создаёт пользователя с сгенерированными именем и паролем, добавляет в sudo.

**SSH-ключ** — добавляет существующий ключ или генерирует пару Ed25519.

**Безопасность** — меняет SSH-порт, отключает вход по паролю и root-доступ, настраивает UFW (запрет входящих, DROP ICMP), устанавливает fail2ban (5 попыток, бан 10 мин).

**Обновление** — `apt update` + `apt upgrade`.

**Верификация** — проверяет пользователя, SSH-ключи, конфиг sshd, UFW, fail2ban, speedtest.

## Логи

```
/var/log/server-init.log         # Подробный лог выполнения
/var/log/server-init-changes.log # История изменений по запускам
```

## Если потеряли доступ по SSH

Подключитесь через консоль и восстановите конфиг:

```bash
cp /etc/ssh/sshd_config.*.bak /etc/ssh/sshd_config
systemctl restart ssh
ufw disable
```

## Лицензия

[MIT](LICENSE)
