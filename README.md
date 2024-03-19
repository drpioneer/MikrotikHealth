# MikrotikHealth - скрипт вывода информации о текущем состоянии Mikrotik

Код скрипта содержит в себе всё необходимое для работы и не имеет зависимостей от сторонних функций и скриптов.
Скрипт не требует никакой настройки, запускай и пользуйся!
Работа скрипта сводится к сбору и выводу информации о:

- важных параметрах устройства
- критических отклонениях параметров
- активных VPN-соединениях
- трафике через шлюз, в случае когда шлюз один

Собранная информация выводится в терминал и журнал устройства.
Вывод производится построчно и максимально коротко, это сделано в угоду удобства чтения отчёта на экране смартфона в Телеграм.
Трансляцию отчёта в Телеграм можно производить при помощи TLGRM ( https://github.com/drpioneer/MikrotikTelegramMessageHandler ).
Имеются ограничения в работе: скрипт не обучен работе с GRE, IPIP, VRRF, MPLS, GUARD.
