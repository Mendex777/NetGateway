#!/bin/bash

echo "███╗   ███╗███████╗███╗   ██╗██████╗ ███████╗██╗  ██╗███████╗███████╗███████╗                  "
echo "████╗ ████║██╔════╝████╗  ██║██╔══██╗██╔════╝╚██╗██╔╝╚════██║╚════██║╚════██║                  "
echo "██╔████╔██║█████╗  ██╔██╗ ██║██║  ██║█████╗   ╚███╔╝     ██╔╝    ██╔╝    ██╔╝                  "
echo "██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║  ██║██╔══╝   ██╔██╗    ██╔╝    ██╔╝    ██╔╝                   "
echo "██║ ╚═╝ ██║███████╗██║ ╚████║██████╔╝███████╗██╔╝ ██╗   ██║     ██║     ██║                    "
echo "╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝     ╚═╝     ╚═╝                    "
echo "                                                                                                "
echo "    ██╗███╗   ██╗███████╗████████╗ ██████╗  █████╗ ████████╗███████╗██╗    ██╗ █████╗ ██╗   ██╗"
echo "   ██╔╝████╗  ██║██╔════╝╚══██╔══╝██╔════╝ ██╔══██╗╚══██╔══╝██╔════╝██║    ██║██╔══██╗╚██╗ ██╔╝"
echo "  ██╔╝ ██╔██╗ ██║█████╗     ██║   ██║  ███╗███████║   ██║   █████╗  ██║ █╗ ██║███████║ ╚████╔╝ "
echo " ██╔╝  ██║╚██╗██║██╔══╝     ██║   ██║   ██║██╔══██║   ██║   ██╔══╝  ██║███╗██║██╔══██║  ╚██╔╝  "
echo "██╔╝   ██║ ╚████║███████╗   ██║   ╚██████╔╝██║  ██║   ██║   ███████╗╚███╔███╔╝██║  ██║   ██║   "
echo "╚═╝    ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝   "
########################################################################################################################################################################

# Функция для получения текущих настроек сети
get_current_settings() {
    # Получаем список всех активных интерфейсов
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)

    if [ -z "$INTERFACE" ]; then
        echo "Нет активных сетевых интерфейсов."
        exit 1
    fi

    # Получаем IP-адрес и маску подсети для выбранного интерфейса
    CURRENT_IP=$(ip -o -f inet addr show $INTERFACE | awk '{print $4}' | cut -d'/' -f1)
    CURRENT_NETMASK=$(ip -o -f inet addr show $INTERFACE | awk '{print $4}' | cut -d'/' -f2)

    # Проверяем, есть ли IP-адрес
    if [ -z "$CURRENT_IP" ]; then
        echo "Интерфейс $INTERFACE не имеет назначенного IP-адреса."
        exit 1
    fi

    GATEWAY=$(ip route | grep default | awk '{print $3}')
    DNS=$(systemd-resolve --status | grep "DNS Servers" | awk '{print $3}' | head -n 1)
}

# Получение текущих настроек
get_current_settings

# Вывод текущих настроек
echo "Текущие настройки сети:"
echo "Интерфейс: $INTERFACE"
echo "Текущий IP: $CURRENT_IP"
echo "Маска подсети: $CURRENT_NETMASK"
echo "Шлюз: $GATEWAY"
echo "DNS: $DNS"
echo ""

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
    echo "2) Настроить статическую адресацию со своими настройками"
    echo "3) Пропустить данный этап настройки"

    read -p "Введите номер варианта (1, 2 или 3): " choice

    case $choice in
        1)
            STATIC_IP=$CURRENT_IP
            NETMASK=$CURRENT_NETMASK
            GATEWAY=$GATEWAY
            DNS=$DNS
            break
            ;;
        2)
            read -p "Введите статический IP: " STATIC_IP
            read -p "Введите маску подсети (например, 24 для 255.255.255.0): " NETMASK
            read -p "Введите шлюз: " GATEWAY
            read -p "Введите DNS-сервер: " DNS
            break
            ;;
        3)
            echo "Настройка сети пропущена."
            SKIP_NETWORK_CONFIG=true
            break
            ;;
        *)
            echo "Неверный выбор. Пожалуйста, попробуйте снова."
            ;;
    esac
done

# Если настройка сети не была пропущена, применяем новые настройки
if [ -z "$SKIP_NETWORK_CONFIG" ]; then
    # Создание резервной копии текущих настроек
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    # Запись новых настроек в файл конфигурации netplan
    echo "network:" | sudo tee "$CONFIG_FILE"
    echo "  version: 2" | sudo tee -a "$CONFIG_FILE"
    echo "  renderer: networkd" | sudo tee -a "$CONFIG_FILE"
    echo "  ethernets:" | sudo tee -a "$CONFIG_FILE"
    echo "    $INTERFACE:" | sudo tee -a "$CONFIG_FILE"
    echo "      dhcp4: no" | sudo tee -a "$CONFIG_FILE"
    echo "      addresses: [$STATIC_IP/$NETMASK]" | sudo tee -a "$CONFIG_FILE"
    echo "      gateway4: $GATEWAY" | sudo tee -a "$CONFIG_FILE"
    echo "      nameservers:" | sudo tee -a "$CONFIG_FILE"
    echo "        addresses: [$DNS]" | sudo tee -a "$CONFIG_FILE"

    # Применение новых настроек
    sudo netplan apply

    echo "Статическая настройка сети завершена."
else
    echo "Пропускаем настройку сети."
fi

# Установка и настройка dnscrypt-proxy
sudo apt update
sudo apt install -y dnscrypt-proxy

# Заменяем старые настройки в файле конфигурации dnscrypt-proxy
sudo sed -i "s/^listen_addresses.*/listen_addresses = ['127.0.0.53:5354']/" /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sudo sed -i "s/^server_names.*/server_names = ['google', 'cloudflare', 'scaleway-fr', 'yandex']/" /etc/dnscrypt-proxy/dnscrypt-proxy.toml

# Заменяем строки в файле сокета dnscrypt-proxy
sudo sed -i "s/^ListenStream.*/ListenStream=127.0.0.53:5353/" /lib/systemd/system/dnscrypt-proxy.socket
sudo sed -i "s/^ListenDatagram.*/ListenDatagram=127.0.0.53:5353/" /lib/systemd/system/dnscrypt-proxy.socket

# Перезапускаем службу
sudo systemctl daemon-reload
sudo systemctl restart dnscrypt-proxy.socket
sudo systemctl restart dnscrypt-proxy
sudo systemctl status dnscrypt-proxy.socket
sudo systemctl status dnscrypt-proxy

echo "Установка и настройка dnscrypt-proxy завершена."

# Установка и настройка dnsmasq
sudo apt install -y dnsmasq

# После установки служба dnsmasq попытается запуститься автоматически и выдаст ошибку, это нормально.

# Меняем конфигурацию dnsmasq
echo "server=127.0.0.53#5354" | sudo tee -a /etc/dnsmasq.conf

# Скачиваем файл с доменами и сохраняем его
sudo curl -o /etc/dnsmasq.d/domains.lst https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Russia/inside-dnsmasq-ipset.lst

# Отключаем штатный resolved
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# В этот момент у нас на машине пропадёт доступ в интернет

# Удаляем штатный resolv.conf и создаём новый с указанием нашего dnsmasq
sudo rm /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Перезапускаем службу (теперь доступ в интернет должен появиться)
sudo systemctl restart dnsmasq
sudo systemctl status dnsmasq

echo "Установка и настройка dnsmasq завершена."
