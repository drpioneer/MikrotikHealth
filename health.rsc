# Script view health of device by Enternight
# https://forummikrotik.ru/viewtopic.php?t=7924
# tested on ROS 6.49.5
# updated 2022/04/08

:do {
    :local hddTotal [/system resource get total-hdd-space ];
    :local hddFree  [/system resource get free-hdd-space  ];
    :local badBlock [/system resource get bad-blocks      ];
    :local memTotal [/system resource get total-memory    ];
    :local memFree  [/system resource get free-memory     ];
    :local cpuZ     [/system resource get cpu-load        ];
    :local currFW   [/system routerbo get upgrade-firmware];
    :local upgrFW   [/system routerbo get current-firmware];
    :local tempC    [/system health   get temperature     ];
    :local volt     [/system health   get voltage         ];
    :local smplVolt ($volt/10);
    :local lowVolt  (($volt-($smplVolt*10))*10);
    :local inVolt   ("$smplVolt.$[:pick $lowVolt 0 3]");
    :set   hddFree  ($hddFree/($hddTotal/100));
    :set   memFree  ($memFree/($memTotal/100));
    :local message  "Health report:\r\nID $[system identity get name]";
    :set   message  ("$message \r\nDevice $[system resource get board-name]");
    :set   message  ("$message \r\nROS v.$[system resource get version]");
    :if ($currFW != $upgrFW) do={set message ("$message \r\n*FW is not updated*")}
    :set   message  ("$message \r\nUptime $[system resource get uptime]");
    :if ($cpuZ     < 90) do={:set message ("$message \r\nCPU load $cpuZ%")}       else={:set message ("$message \r\n*Large CPU usage $cpuZ%*")}
    :if ($hddFree  > 6 ) do={:set message ("$message \r\nHDD free $hddFree%")}    else={:set message ("$message \r\n*Low free HDD $hddFree%*")}
    :if ($badBlock = 0 ) do={:set message ("$message \r\nBad blocks $badBlock%")} else={:set message ("$message \r\n*Present bad blocks $badBlock%*")}
    :if ($memFree  > 20) do={:set message ("$message \r\nMemory free $memFree%")} else={:set message ("$message \r\n*Low free memory $memFree%*")}
    :if ([:len $volt]  > 0) do={:set message ("$message \r\nVoltage $inVolt V")}
    :if ([:len $tempC] > 0) do={:set message ("$message \r\nTemperature $[system health get temperature] C")}
    :local macAddrGate "";
    :local routeISP  [/ip route find dst-address=0.0.0.0/0];
    :if ([:len $routeISP] > 0) do={  
        :foreach inetGate in=$routeISP do={
            :local interfaceISP [/ip route get $inetGate vrf-interface];
            :local ipAddrGate   [/ip route get $inetGate gateway];
            :if ([:len [/interface bridge find name=$interfaceISP]] > 0) do={
                :set macAddrGate  [/ip arp get [find address=$ipAddrGate interface=$interfaceISP] mac-address];
                :set interfaceISP [/interface bridge host get [find mac-address=$macAddrGate] interface];
            }
            :local rxByte [/interface get $interfaceISP rx-byte];
            :local txByte [/interface get $interfaceISP tx-byte];
            :local simpleGbRxReport ($rxByte/1073741824);
            :local simpleGbTxReport ($txByte/1073741824);
            :local lowGbRxReport ((($rxByte-($simpleGbRxReport*1073741824))*1000000000)/1048576);
            :local lowGbTxReport ((($txByte-($simpleGbTxReport*1073741824))*1000000000)/1048576);
            :local gbRxReport ("$simpleGbRxReport.$[:pick $lowGbRxReport 0 2]");
            :local gbTxReport ("$simpleGbTxReport.$[:pick $lowGbTxReport 0 2]");
            :set message ("$message \r\nTraffic of '$interfaceISP'\r\nRx/Tx $gbRxReport/$gbTxReport Gb");
        }
    } else={:set message ("$message \r\nThere is no interface for internet access.")}
    :put $message;
    :log warning $message;
} on-error={:log warning ("Script error. Script couldn't show the health status.")}
