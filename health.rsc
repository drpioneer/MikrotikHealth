# Script view health of device by Enternight
# https://forummikrotik.ru/viewtopic.php?t=7924
# tested on ROS 6.49
# updated 2021/10/26

:do {
    :local nameISP   "ISP";
    :local message   "Health report of";
    :local hddTotal  [ /system resource get total-hdd-space; ];
    :local hddFree   [ /system resource get free-hdd-space;  ];
    :local memTotal  [ /system resource get total-memory;    ];
    :local memFree   [ /system resource get free-memory;     ];
    :local tempC     [ /system health   get temperature;     ];
    :local volt      [ /system health   get voltage;         ];
    :local simplvolt ($volt / 10);
    :local lowvolt  (($volt - ($simplvolt * 10)) * 10);
    :local involt    ("$simplvolt.$[:pick $lowvolt 0 3]");
    :set   hddFree   ( $hddFree / ($hddTotal / 100) );
    :set   memFree   ( $memFree / ($memTotal / 100) );
    :set   message   ("$message \r\n$[/system identity get name]:");
    :set   message   ("$message \r\nDevice $[ /system resource get board-name; ]");
    :set   message   ("$message \r\nROS $[ /system resource get version; ];");
    :set   message   ("$message \r\nCPU load: $[ /system resource get cpu-load; ]%");
    :set   message   ("$message \r\nHDD free: $hddFree%");
    :set   message   ("$message \r\nBad blocks: $[ /system resource get bad-blocks; ]%");
    :set   message   ("$message \r\nMem free: $memFree%");
    if ([:len $volt ] > 0) do={ :set message ("$message \r\nVoltage: $involt V"); }
    if ([:len $tempC] > 0) do={ :set message ("$message \r\nTemperature: $[ /system health get temperature; ] C"); }
    :set   message   ("$message \r\nUptime: $[ /system resource get uptime; ]");
    if ([/ip address find interface~$nameISP;] != "") do={
        :foreach internet in=[ /ip address find interface~$nameISP; ] do={
            :do {
                :local interfaceISP [ /ip address get $internet interface; ];
                :local rxByte       [ /interface  get $interfaceISP rx-byte; ];
                :local txByte       [ /interface  get $interfaceISP tx-byte; ];
                :local simpleGbRxReport ($rxByte / 1073741824 );
                :local simpleGbTxReport ($txByte / 1073741824);
                :local lowGbRxReport  ((($rxByte - ($simpleGbRxReport * 1073741824)) * 1000000000) / 1048576);
                :local lowGbTxReport  ((($txByte - ($simpleGbTxReport * 1073741824)) * 1000000000) / 1048576);
                :local gbRxReport ("$simpleGbRxReport.$[:pick $lowGbRxReport 0 2]");
                :local gbTxReport ("$simpleGbTxReport.$[:pick $lowGbTxReport 0 2]");
                :set message ("$message \r\n'$interfaceISP' traffic:\r\nRx/Tx: $gbRxReport/$gbTxReport Gb");
            } on-error={ :set message ("$message \r\nScript error. Disappeared interface '$nameISP'."); }
        }
    } else={ :set message ("$message \r\nActive interface '$nameISP' was not found."); }
    :put $message;
    :log warning $message;
} on-error={ :log warning ("Script error. Script couldn't show the health status."); }
