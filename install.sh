#!/bin/bash

logo='
###############################################################################################
###############################################################################################
###############################################################################################
███╗   ███╗███████╗███╗   ██╗██████╗ ███████╗██╗  ██╗███████╗███████╗███████╗
████╗ ████║██╔════╝████╗  ██║██╔══██╗██╔════╝╚██╗██╔╝╚════██║╚════██║╚════██║
██╔████╔██║█████╗  ██╔██╗ ██║██║  ██║█████╗   ╚███╔╝     ██╔╝    ██╔╝    ██╔╝
██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║  ██║██╔══╝   ██╔██╗    ██╔╝    ██╔╝    ██╔╝
██║ ╚═╝ ██║███████╗██║ ╚████║██████╔╝███████╗██╔╝ ██╗   ██║     ██║     ██║
╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝     ╚═╝     ╚═╝

    ██╗███╗   ██╗███████╗████████╗ ██████╗  █████╗ ████████╗███████╗██╗    ██╗ █████╗ ██╗   ██╗
   ██╔╝████╗  ██║██╔════╝╚══██╔══╝██╔════╝ ██╔══██╗╚══██╔══╝██╔════╝██║    ██║██╔══██╗╚██╗ ██╔╝
  ██╔╝ ██╔██╗ ██║█████╗     ██║   ██║  ███╗███████║   ██║   █████╗  ██║ █╗ ██║███████║ ╚████╔╝
 ██╔╝  ██║╚██╗██║██╔══╝     ██║   ██║   ██║██╔══██║   ██║   ██╔══╝  ██║███╗██║██╔══██║  ╚██╔╝
██╔╝   ██║ ╚████║███████╗   ██║   ╚██████╔╝██║  ██║   ██║   ███████╗╚███╔███╔╝██║  ██║   ██║
╚═╝    ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝
###############################################################################################
###############################################################################################
###############################################################################################
'
print_logo() {
    while IFS= read -r line; do
        echo "$line"
        sleep 0.1
    done <<< "$logo"
}
print_logo
########################################################################################################################################################################
# Функция для вывода текста в зелёном цвете
print_green() {
    echo -e "\e[32m$1\e[0m"
}

# Функция для вывода текста в жёлтом цвете
print_yellow() {
    echo -e "\e[33m$1\e[0m"
}

# Функция для вывода текста в фиолетовом цвете
print_purple() {
    echo -e "\e[35m$1\e[0m"
}

########################################################################################################################################################################
# Выводим сообщение о сборе информации
print_green "Сбор информации о системе..."

# Получаем информацию о версии операционной системы
os_info=$(lsb_release -d | awk -F'\t' '{print $2}')
echo -n "Установленная ОС: $os_info "

# Проверяем версию ОС
if [[ "$os_info" == "Ubuntu 22.04.5 LTS" ]]; then
    print_purple "Подходит"
else
    print_yellow "Внимание: на данной версии работа скрипта не тестировалась."
fi

########################################################################################################################################################################
# Обнуляем переменную, чтобы избежать проблем с предыдущими запусками
SKIP_NETWORK_CONFIG=""

# Получаем информацию о сетевом адаптере
network_adapter=$(ip link show | awk -F': ' '/^[0-9]+: /{print $2}' | sed -n '2p')

echo "Используемый сетевой адаптер: $network_adapter"

# Получаем текущие настройки адаптера
ip_address=$(ip addr show "$network_adapter" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
ip_info=$(ip addr show "$network_adapter")
mask=$(echo "$ip_info" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f2)
gateway_info=$(ip route | grep default | awk '{print $3}')
dns_info=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')

# Выводим информацию о текущих настройках адаптера
echo "Настройки адаптера $network_adapter:"
echo "IP-адрес: $ip_address"
echo "Маска: $mask"
echo "Шлюз: $gateway_info"
echo "DNS: $dns_info"
echo ""

########################################################################################################################################################################

# Определение файла конфигурации netplan
CONFIG_FILE=$(ls /etc/netplan/*.yaml | head -n 1)

if [ -z "$CONFIG_FILE" ]; then
    echo "Не удалось найти файл конфигурации netplan."
    exit 1
fi

# Цикл для выбора варианта настройки
while true; do
    echo "Выберите вариант настройки статической адресации:"
    echo "1) Настроить статическую адресацию с текущими настройками"
    echo -e "2) Настроить статическую адресацию со своими настройками \e[33m(Внимание: при смене IP-адреса на другой пропадёт доступ к сессии. Скрипт завершит работу после смены IP-адреса)\e[0m"
    echo "3) Пропустить данный этап настройки"

    read -p "Введите номер варианта (1, 2 или 3): " choice

    case $choice in
        1)
            STATIC_IP=$ip_address
            NETMASK=$mask
            GATEWAY=$gateway_info
            DNS=$dns_info
            break
            ;;
        2)
            read -p "Введите статический IP: " STATIC_IP
            read -p "Введите маску подсети (например, 24 для 255.255.255.0): " NETMASK
            read -p "Введите шлюз: " GATEWAY
            read -p "Введите DNS-сервер (через запятую, если несколько): " DNS
            break
            ;;
        3)
            SKIP_NETWORK_CONFIG=true
            break
            ;;
        *)
            echo -e "\e[31mНеверный выбор. Пожалуйста, попробуйте снова.\e[0m"
            ;;
    esac
done

# Если настройка сети не была пропущена, применяем новые настройки
if [ -z "$SKIP_NETWORK_CONFIG" ]; then
    # Создание резервной копии текущих настроек
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    # Запись новых настроек в файл конфигурации netplan
    {
        echo "network:"
        echo "  version: 2"
        echo "  renderer: networkd"
        echo "  ethernets:"
        echo "    $network_adapter:"
        echo "      dhcp4: no"
        echo "      addresses: [$STATIC_IP/$NETMASK]"
        echo "      routes:"
        echo "        - to: 0.0.0.0/0"
        echo "          via: $GATEWAY"
        echo "      nameservers:"
        echo "        addresses: [$DNS]"
    } | sudo tee "$CONFIG_FILE" > /dev/null 2>&1

    # Применение новых настроек
    sudo netplan apply 2>/dev/null

    echo "Статическая настройка сети завершена."

    # Проверка, был ли выбран вариант 2
    if [[ "$choice" -eq 2 ]]; then
        echo -e "\e[32mНастройка сети завершена. Скрипт завершает работу.\e[0m"
        exit 0
    fi
else
    echo -e "\e[32mНастройка сети пропущена.\e[0m"
fi

########################################################################################################################################################################
########################################################################################################################################################################
########################################################################################################################################################################

# Установка dnscrypt-proxy без интерактивных диалогов и без вывода сообщений
echo -e "\e[32mУстановка dnscrypt-proxy...\e[0m"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dnscrypt-proxy > /dev/null 2>&1

# Проверка, установлен ли dnscrypt-proxy
if dpkg -l | grep -q dnscrypt-proxy; then
    echo -e "\e[32mdnscrypt-proxy установлен успешно.\e[0m"
else
    echo -e "\e[31mОшибка: dnscrypt-proxy не установлен.\e[0m"
    exit 1
fi

# Заменяем старые настройки в файле конфигурации dnscrypt-proxy
sudo sed -i "s/^listen_addresses.*/listen_addresses = ['127.0.0.53:5354']/" /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sudo sed -i "s/^server_names.*/server_names = ['google', 'cloudflare', 'scaleway-fr', 'yandex']/" /etc/dnscrypt-proxy/dnscrypt-proxy.toml

# Заменяем строки в файле сокета dnscrypt-proxy
sudo sed -i "s/^ListenStream.*/ListenStream=127.0.0.53:5353/" /lib/systemd/system/dnscrypt-proxy.socket
sudo sed -i "s/^ListenDatagram.*/ListenDatagram=127.0.0.53:5353/" /lib/systemd/system/dnscrypt-proxy.socket

# Перезагрузка службы dnscrypt-proxy для применения изменений
sudo systemctl daemon-reload
sudo systemctl restart dnscrypt-proxy

# Проверка, активна ли служба dnscrypt-proxy
if systemctl is-active --quiet dnscrypt-proxy; then
    echo -e "\e[32mНастройки dnscrypt-proxy обновлены, cлужба активна.\e[0m"
else
    echo -e "\e[31mОшибка: служба dnscrypt-proxy не активна.\e[0m"
fi

# Перезагрузка сокета dnscrypt-proxy
sudo systemctl daemon-reload
sudo systemctl restart dnscrypt-proxy.socket

# Проверка, активен ли сокет dnscrypt-proxy
if systemctl is-active --quiet dnscrypt-proxy.socket; then
    echo -e "\e[32mСокет dnscrypt-proxy активен.\e[0m"
else
    echo -e "\e[31mОшибка: сокет dnscrypt-proxy не активен.\e[0m"
fi
########################################################################################################################################################################
# Установка dnsmasq без интерактивных диалогов и без вывода сообщений
echo -e "\e[32mУстановка dnsmasq...\e[0m"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq > /dev/null 2>&1

# Проверка, установлен ли dnsmasq
if dpkg -l | grep -q dnsmasq; then
    echo -e "\e[32mdnsmasq установлен успешно.\e[0m"
else
    echo -e "\e[31mОшибка: dnsmasq не установлен.\e[0m"
    exit 1
fi

# Меняем конфигурацию dnsmasq
echo "server=127.0.0.53#5354" | sudo tee -a /etc/dnsmasq.conf > /dev/null 2>&1

# Проверка, успешно ли добавлена строка в конфигурацию
if grep -q "server=127.0.0.53#5354" /etc/dnsmasq.conf; then
    echo -e "\e[32mКонфигурация dnsmasq обновлена успешно.\e[0m"
else
    echo -e "\e[31mОшибка: не удалось обновить конфигурацию dnsmasq.\e[0m"
    exit 1
fi

# Скачиваем файл с доменами и сохраняем его
echo -e "\e[32mСкачивание файла с доменами...\e[0m"
sudo curl -o /etc/dnsmasq.d/domains.lst https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-dnsmasq-ipset.lst > /dev/null 2>&1

# Проверка, успешно ли скачан файл
if [ -f /etc/dnsmasq.d/domains.lst ]; then
    echo -e "\e[32mФайл с доменами скачан успешно.\e[0m"
else
    echo -e "\e[31mОшибка: файл с доменами не был скачан.\e[0m"
    exit 1
fi

# Отключаем штатный resolved
echo -e "\e[32mОтключение systemd-resolved...\e[0m"
sudo systemctl disable systemd-resolved > /dev/null 2>&1
sudo systemctl stop systemd-resolved > /dev/null 2>&1

# Удаляем штатный resolv.conf и создаём новый с указанием нашего dnsmasq
echo -e "\e[32mНастройка resolv.conf...\e[0m"
sudo rm /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null

# Перезапускаем dnsmasq для применения изменений
echo -e "\e[32mПерезапуск dnsmasq...\e[0m"
sudo systemctl restart dnsmasq > /dev/null 2>&1

# Проверка статуса dnsmasq
echo -e "\e[32mПроверка статуса dnsmasq...\e[0m"
if systemctl status dnsmasq | grep -q "active (running)"; then
    echo -e "\e[32mdnsmasq работает корректно.\e[0m"
else
    echo -e "\e[31mОшибка: dnsmasq не работает.\e[0m"
    exit 1
fi
########################################################################################################################################################################
# Установка sing-box
echo -e "\e[32mУстановка sing-box...\e[0m"

# Добавляем GPG ключ
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc

# Добавляем репозиторий
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null

# Обновляем список пакетов
sudo apt-get update > /dev/null 2>&1

# Устанавливаем sing-box
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sing-box > /dev/null 2>&1

# Проверка, установлен ли sing-box
if dpkg -l | grep -q sing-box; then
    echo -e "\e[32msing-box установлен успешно.\e[0m"
else
    echo -e "\e[31mОшибка: sing-box не установлен.\e[0m"
    exit 1
fi

########################################################################################################################################################################
# Установка jq без интерактивных диалогов и без вывода сообщений
echo -e "\e[32mУстановка jq...\e[0m"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y jq > /dev/null 2>&1

# Проверка, установлен ли dnsmasq
if dpkg -l | grep -q jq; then
    echo -e "\e[32mjq установлен успешно.\e[0m"
else
    echo -e "\e[31mОшибка: jq не установлен.\e[0m"
    exit 1
fi
########################################################################################################################################################################
# Настройка sing-box
sing_box_configuration_VLESS_AVTO() {
    local vless_link

    # Запрашиваем ссылку VLESS до тех пор, пока она не будет корректной
    while true; do
        echo "Пожалуйста, поместите ссылку VLESS (начиная с 'vless://') и нажмите Enter:"
        read -r vless_link

        # Проверяем, начинается ли строка с vless://
        if [[ $vless_link == vless://* ]]; then
            break  # Выходим из цикла, если ссылка корректная
        else
            echo -e "\e[31mОшибка: Некорректный формат строки. Она должна начинаться с 'vless://'.\e[0m"
        fi
    done

    local input=$vless_link
    # Убираем vless://
    local trimmed=${input#vless://}

    # Разбираем части строки
    local uuid=$(echo "$trimmed" | cut -d@ -f1)
    local host_port=$(echo "$trimmed" | cut -d@ -f2 | cut -d? -f1)
    local host=$(echo "$host_port" | cut -d: -f1)
    local port=$(echo "$host_port" | cut -d: -f2)
    local params=$(echo "$trimmed" | cut -d? -f2 | sed 's/#.*//')

    # Парсим параметры из query string
    local flow=$(echo "$params" | grep -oP '(?<=flow=)[^&]*')
    local sni=$(echo "$params" | grep -oP '(?<=sni=)[^&]*')
    local fingerprint=$(echo "$params" | grep -oP '(?<=fp=)[^&]*')
    local public_key=$(echo "$params" | grep -oP '(?<=pbk=)[^&]*')
    local short_id=$(echo "$params" | grep -oP '(?<=sid=)[^&]*')

    # Сохранение JSON в переменную
    json_output=$(jq -n --arg uuid "$uuid" \
          --arg host "$host" \
          --argjson port "$port" \
          --arg flow "$flow" \
          --arg sni "$sni" \
          --arg fingerprint "$fingerprint" \
          --arg public_key "$public_key" \
          --arg short_id "$short_id" \
    '{
        "log": {
          "level": "debug"
        },
        "inbounds": [
          {
            "type": "tun",
            "interface_name": "tun0",
            "domain_strategy": "ipv4_only",
            "inet4_address": "172.16.250.1/30",
            "auto_route": false,
            "strict_route": false,
            "sniff": true
          }
        ],
        "outbounds": [
          {
            "type": "vless",
            "server": $host,
            "server_port": $port,
            "uuid": $uuid,
            "flow": $flow,
            "tls": {
              "enabled": true,
              "insecure": false,
              "server_name": $sni,
              "utls": {
                "enabled": true,
                "fingerprint": $fingerprint
              },
              "reality": {
                "enabled": true,
                "public_key": $public_key,
                "short_id": $short_id
              }
            }
          }
        ],
        "route": {
          "auto_detect_interface": true
        }
    }')

    # Путь к конфигурационному файлу
    config_path="/etc/sing-box/config.json"

    # Проверяем, существует ли файл конфигурации
    if [[ -f "$config_path" ]]; then
        # Создаём резервную копию с временной меткой
        backup_path="${config_path}.$(date +%Y%m%d%H%M%S).bak"
        echo -e "\e[32mСоздаю резервную копию: $backup_path\e[0m"
        cp "$config_path" "$backup_path"
    fi

    # Записываем новый JSON в файл
    echo "$json_output" > "$config_path"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[32mНовый конфигурационный файл успешно записан в $config_path\e[0m"
    else
        echo "\e[31mОшибка записи в $config_path\e[0m"
        exit 1
    fi
}

sing_box_configuration_VLESS() {
    # Запрашиваем параметры у пользователя
    read -p "Введите UUID: " uuid
    read -p "Введите сервер (hostname или IP): " host
    read -p "Введите порт: " port
    read -p "Введите flow (например, xtls-rprx-vision): " flow
    read -p "Введите server_name (если есть, оставьте пустым, если нет): " sni
    read -p "Введите fingerprint (если есть, оставьте пустым, если нет): " fingerprint
    read -p "Введите public_key (если есть, оставьте пустым, если нет): " public_key
    read -p "Введите short_id (если есть, оставьте пустым, если нет): " short_id

    # Сохранение JSON в переменную
    json_output=$(jq -n --arg uuid "$uuid" \
          --arg host "$host" \
          --argjson port "$port" \
          --arg flow "$flow" \
          --arg sni "$sni" \
          --arg fingerprint "$fingerprint" \
          --arg public_key "$public_key" \
          --arg short_id "$short_id" \
    '{
        "log": {
          "level": "debug"
        },
        "inbounds": [
          {
            "type": "tun",
            "interface_name": "tun0",
            "domain_strategy": "ipv4_only",
            "inet4_address": "172.16.250.1/30",
            "auto_route": false,
            "strict_route": false,
            "sniff": true
          }
        ],
        "outbounds": [
          {
            "type": "vless",
            "server": $host,
            "server_port": $port,
            "uuid": $uuid,
            "flow": $flow,
            "tls": {
              "enabled": true,
              "insecure": false,
              "server_name": $sni,
              "utls": {
                "enabled": true,
                "fingerprint": $fingerprint
              },
              "reality": {
                "enabled": true,
                "public_key": $public_key,
                "short_id": $short_id
              }
            }
          }
        ],
        "route": {
          "auto_detect_interface": true
        }
    }')

    # Путь к конфигурационному файлу
    config_path="/etc/sing-box/config.json"

    # Проверяем, существует ли файл конфигурации
    if [[ -f "$config_path" ]]; then
        # Создаём резервную копию с временной меткой
        backup_path="${config_path}.$(date +%Y%m%d%H%M%S).bak"
        echo -e "\e[32mСоздаю резервную копию: $backup_path\e[0m"
        cp "$config_path" "$backup_path"
    fi

    # Записываем новый JSON в файл
    echo "$json_output" > "$config_path"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[32mНовый конфигурационный файл успешно записан в $config_path\e[0m"
    else
        echo "\e[31mОшибка записи в $config_path\e[0m"
        exit 1
    fi
}

sing_box_configuration_menu() {
    echo -e "\e[32mНастройка sing-box...\e[0m"
    echo "Выберите протокол для настройки sing-box:"
    echo "1) VLESS (автоматическая настройка по ссылке)"
    echo "2) VLESS (ручная настройка с указанием полей)"
    echo "3) Пропуск, (другой протокол)"

    choice=""
    while true; do
        read -p "Введите номер варианта (1-3): " choice
        case $choice in
            1)
                choice=VLESS_AVTO
                break
                ;;
            2)
                choice=VLESS
                break
                ;;
            3)
                echo -e "\e[33mВы выбрали пропуск или другой протокол.\e[0m"
                sleep 2  # Задержка на 2 секунды
                echo "На текущий момент автоматическая конфигурация JSON файла для sing-box реализована только для протокола VLESS."
                sleep 2  # Задержка на 2 секунды
                echo "Вы можете самостоятельно создать config.json для своего протокола."
                sleep 2  # Задержка на 2 секунды
                echo "Для этого отредактируйте файл конфигурации, который находится по пути /etc/sing-box/config.json."
                sleep 2  # Задержка на 2 секунды
                break
                ;;
            *)
                echo -e "\e[31mОшибка: неверный выбор. Пожалуйста, выберите номер от 1 до 3.\e[0m"
                ;;
        esac
    done

    if [ "$choice" == 'VLESS_AVTO' ]; then
        sing_box_configuration_VLESS_AVTO
    elif [ "$choice" == 'VLESS' ]; then
        sing_box_configuration_VLESS
    fi
}
sing_box_configuration_menu



