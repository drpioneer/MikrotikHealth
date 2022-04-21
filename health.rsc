# Script view health of device by Enternight
# https://forummikrotik.ru/viewtopic.php?t=7924
# tested on ROS 6.49.5
# updated 2022/04/21

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
    :if ($memFree > 17) do={:set message ("$message \r\nMem free $memFree%");
    } else={:set message ("$message \r\n*Low free mem $memFree%*")}
    :if ($hddFree > 6) do={:set message ("$message \r\nHDD free $hddFree%");
    } else={:set message ("$message \r\n*Low free HDD $hddFree%*")}
    :if ([:len $badBlock] > 0) do={
        :if ($badBlock = 0) do={:set message ("$message \r\nBad blocks $badBlock%");
        } else={:set message ("$message \r\n*Present bad blocks $badBlock%*")}
    }
    :if ([:len $volt] > 0) do={
        :if ($smplVolt > 4 && $smplVolt < 50) do={:set message ("$message \r\nVoltage $inVolt V");
        } else={:set message ("$message \r\n*Bad voltage $inVolt V*")}
    }
    :if ([:len $tempC] > 0) do={
        :if ($tempC > 10 && $tempC < 40) do={:set message ("$message \r\nTemp $tempC C");
        } else={:set message ("$message \r\n*Abnorm temp $tempC C*")}
    }

    :local routeISP [/ip route find dst-address=0.0.0.0/0];
    :if ([:len $routeISP] > 0) do={

        # Listing all gateways
        :local gwList [:toarray ""];
        :local count 0;
        :foreach inetGate in=$routeISP do={
            :local gwStatus [:tostr [/ip route get $inetGate gateway-status]];
            :if ([:len $gwStatus] > 0) do={
                :if (([:len [:find $gwStatus "unreachable"]] = 0) && ([:len [:find $gwStatus "inactive"]] = 0)) do={
    
                    # Formation of interface name
                    :local ifaceISP "";
                    :foreach idName in=[/interface find] do={
                        :local ifName [/interface get $idName name];
                        :if ([:len [find key=$ifName in=$gwStatus]] > 0) do={:set ifaceISP $ifName}
                    }
                    :if ([:len $ifaceISP] > 0) do={
    
                        # Checking the interface for entering the Bridge
                        :if ([:len [/interface bridge find name=$ifaceISP]] > 0) do={
                            :local ipAddrGW [:tostr [/ip route get $inetGate gateway]];
                            :if ([:find $ipAddrGW "%"] > 0) do={
                                :set $ipAddrGW [:pick $ipAddrGW ([:len [:pick $ipAddrGW 0 [:find $ipAddrGW "%"]] ] +1) [:len $ipAddrGW]];
                            }
                            :if ($ipAddrGW~"[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}") do={
                                :local mcAddrGate [/ip arp get [find address=$ipAddrGW interface=$ifaceISP] mac-address];
                                :if ($mcAddrGate~"[0-F][0-F]:[0-F][0-F]:[0-F][0-F]:[0-F][0-F]:[0-F][0-F]:[0-F][0-F]") do={
                                    :set ifaceISP [/interface bridge host get [find mac-address=$mcAddrGate] interface];

                                } else={:set ifaceISP ""}
                            } else={:set ifaceISP ""}
                        }
                        :if ([:len $ifaceISP] > 0) do={
    
                            # Checking the repetition of interface name
                            :local check [:len [find key=$ifaceISP in=$gwList]];
                            :if ($check = 0) do={
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
            }
        }
    } else={:set message ("$message \r\nWAN iface not found")}
    :put $message;
    :log warning $message;
} on-error={:log warning ("Error, can't show health status")}
