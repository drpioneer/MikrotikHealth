# Script view health of device by Enternight
# https://forummikrotik.ru/viewtopic.php?t=7924
# tested on ROS 6.49.5
# updated 2022/04/19

:do {
    :local hddTotal [/system resource get total-hdd-spac];
    :local hddFree  [/system resource get free-hdd-space];
    :local badBlock [/system resource get bad-blocks    ];
    :local memTotal [/system resource get total-memory  ];
    :local memFree  [/system resource get free-memory   ];
    :local cpuZ     [/system resource get cpu-load      ];
    :local currFW   [/system routerbo get upgrade-firmwa];
    :local upgrFW   [/system routerbo get current-firmwa];
    :local tempC    [/system health   get temperature   ];
    :local volt     [/system health   get voltage       ];
    :local smplVolt ($volt/10);
    :local lowVolt  (($volt-($smplVolt*10))*10);
    :local inVolt   ("$smplVolt.$[:pick $lowVolt 0 3]");
    :set   hddFree  ($hddFree/($hddTotal/100));
    :set   memFree  ($memFree/($memTotal/100));
    :local message  "Health report:\r\nID $[system identity get name]";
    :set   message  ("$message \r\nModel $[system resource get board-name]");
    :set   message  ("$message \r\nROS v.$[system resource get version]");
    :if ($currFW != $upgrFW) do={set message ("$message \r\n*FW is not updated*")}
    :set   message  ("$message \r\nUptime $[system resource get uptime]");
    :if ($cpuZ < 90) do={:set message ("$message \r\nCPU load $cpuZ%");
    } else={:set message ("$message \r\n*Large CPU usage $cpuZ%*")}
    :if ($hddFree > 6) do={:set message ("$message \r\nHDD free $hddFree%");
    } else={:set message ("$message \r\n*Low free HDD $hddFree%*")}
    :if ($badBlock = 0) do={:set message ("$message \r\nBad blocks $badBlock%");
    } else={:set message ("$message \r\n*Present bad blocks $badBlock%*")}
    :if ($memFree > 17) do={:set message ("$message \r\nMem free $memFree%");
    } else={:set message ("$message \r\n*Low free mem $memFree%*")}
    :if ([:len $volt] > 0) do={:set message ("$message \r\nVoltage $inVolt V")}
    :if ([:len $tempC] > 0) do={:set message ("$message \r\nTemp $[system health get temperature] C")}
    :local gwList [:toarray ""];
    :local count 0;

    # Listing all gateways
    :foreach inetGate in=[/ip route find dst-address=0.0.0.0/0] do={
        :local gwStatus [:tostr [/ip route get $inetGate gateway-status]];
        
        # Eliminating unreachable gateways
        :if ([:len [:find $gwStatus "unreachable"]] = 0) do={
        
            # Formation of interface name
            :local ifaceISP [:pick $gwStatus 0 ([:find $gwStatus "reachable"] -1)];
            :if ([:find $gwStatus "via"] > 0) do={
                :set $ifaceISP [:pick $gwStatus ([:len [:pick $gwStatus 0 [:find $gwStatus "via"]] ] +5) [:len $gwStatus]];
            }
            
            # Checking the presence of interface
            :if ([:len $ifaceISP] > 0) do={
            
                # Checking the interface for entering the Bridge
                :if ([:len [/interface bridge find name=$ifaceISP]] > 0) do={
                    :local ipAddrGate [/ip route get $inetGate gateway];
                    :local mcAddrGate [/ip arp get [find address=$ipAddrGate interface=$ifaceISP] mac-address];
                    :set ifaceISP [/interface bridge host get [find mac-address=$mcAddrGate] interface];
                }
                
                # Checking the repetition of interface name
                :if ([:len [find key=$ifaceISP in=$gwList ]] = 0) do={
                    :set ($gwList->$count) $ifaceISP;
                    :set count ($count+1);
                    :local rxByte [/interface get $ifaceISP rx-byte];
                    :local txByte [/interface get $ifaceISP tx-byte];
                    :local simpleGbRxReport ($rxByte/1073741824);
                    :local simpleGbTxReport ($txByte/1073741824);
                    :local lowGbRxReport ((($rxByte-($simpleGbRxReport*1073741824))*1000000000)/1048576);
                    :local lowGbTxReport ((($txByte-($simpleGbTxReport*1073741824))*1000000000)/1048576);
                    :local gbRxReport ("$simpleGbRxReport.$[:pick $lowGbRxReport 0 2]");
                    :local gbTxReport ("$simpleGbTxReport.$[:pick $lowGbTxReport 0 2]");
                    :set message ("$message \r\nTraffic via\r\n'$ifaceISP'\r\nRx/Tx $gbRxReport/$gbTxReport Gb");
                }
            }
        }
    }
    :put $message;
    :log warning $message;
} on-error={:log warning ("Script error. Script couldn't show the health status.")}
