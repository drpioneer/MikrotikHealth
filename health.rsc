# Device status view script
# Script uses ideas by Enternight, Sertik, drPioneer
# https://forummikrotik.ru/viewtopic.php?p=84984#p84984
# tested on ROS 6.49.5
# updated 2022/04/27

:do {
    # Digit conversion function via SI-prefix
    # How to use: :put [$NumSiPrefix 648007421264];
    :local NumSiPrefix do={
        :local inp [:tonum $1];
        :local cnt 0;
        :while ($inp > 1024) do={
            :set $inp ($inp/1024);
            :set $cnt ($cnt+1);
        }
        :return ($inp.[:pick [:toarray "B,Kb,Mb,Gb,Tb,Pb,Eb,Zb,Yb"] $cnt]);
    }

    # Defining variables
    :local hddTotal [/system resource get total-hdd-spac];
    :local hddFree  [/system resource get free-hdd-space];
    :local badBlock [/system resource get bad-blocks];
    :local memTotal [/system resource get total-memory];
    :local memFree  [/system resource get free-memory];
    :local cpuZ     [/system resource get cpu-load];
    :local currFW   [/system routerbo get upgrade-firmwa];
    :local upgrFW   [/system routerbo get current-firmwa];
    :if ([/system resource get board-name]!="CHR") do={
        :local tempC [/system health get temperature];
        :local volt  [/system health get voltage];
    }
    :local smplVolt ($volt/10);
    :local lowVolt  (($volt-($smplVolt*10))*10);
    :local inVolt   ("$smplVolt.$[:pick $lowVolt 0 3]");
    :local message  "Health report:\r\nID $[system identity get name]";

    #General information
    :set   message  ("$message \r\nUptime $[system resource get uptime]");
    :set   message  ("$message \r\nModel $[system resource get board-name]");
    :set   message  ("$message \r\nROS $[system resource get version]");
    :if ($currFW != $upgrFW) do={set message ("$message \r\n*FW not updated*")}
    :set   message  ("$message \r\nArch $[/system resource get arch]");
    :set   message  ("$message \r\nCPU $[/system resource get cpu]");
    :set   hddFree  ($hddFree/($hddTotal/100));
    :set   memFree  ($memFree/($memTotal/100));
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

    # Connections information
    :local pppInteract {"-client";"-server"};
    :local pppTypes {"l2tp";"pptp";"ovpn";"ppp";"sstp";"pppoe"};
    :foreach pppInt in=$pppInteract do={ 
        :foreach pppTps in=$pppTypes do={ 
            :local pppType ($pppTps.$pppInt);
            :foreach pppConn in=[[:parse "[/interface $pppType find]"]] do={
                :local vpnName  [[:parse "[/interface $pppType get $pppConn name]"]];
                :local vpnComm  [[:parse "[/interface $pppType get $pppConn comment]"]];
                :local vpnType [/interface get $vpnName type];
                :local iType $vpnType;
                :local connTo  "";
                :set vpnType [:pick $vpnType ([:find $vpnType "-"] +1) [:len $vpnType]];
                :if ($vpnType="out" && $iType!="ppp-out") do={
                    :set connTo ("to $[[:parse "[/interface $pppType get $vpnName connect-to]"]]");
                }
                :local vpnState [[:parse "[/interface $pppType monitor $pppConn once as-value]"]];
                :local vpnStatu ($vpnState->"status");
                :local locAddr  ($vpnState->"local-address");
                :local remAddr  ($vpnState->"remote-address");
                :local upTime   ($vpnState->"uptime");
                :if ([:len [find key="terminating" in=$vpnStatu]] > 0) do={:set vpnStatu "disabled"}
                :if ([:typeof $vpnStatu]="nothing") do={:set vpnStatu "unplugged"}
                :if ($vpnStatu!="unplugged" && $vpnStatu!="disabled") do={
                    :set message ("$message\r\nConnect info:\r\n'$vpnName'\r\nType $pppType");
                    :if ([:len $connTo]  > 0) do={:set message ("$message\r\n$connTo")}
                    :if ([:len $vpnComm] > 0) do={:set message ("$message\r\nComment $vpnComm")}
                    :set message ("$message\r\nLcl $locAddr\r\nRmt $remAddr\r\nUptime $upTime");
                }
            }
        }
    }

    # Gateways information
    :local routeISP [/ip route find dst-address=0.0.0.0/0];
    :if ([:len $routeISP] > 0) do={
        :local gwList [:toarray ""];
        :local count 0;
        :foreach inetGate in=$routeISP do={
            :local gwStatus [:tostr [/ip route get $inetGate gateway-status]];
            :if ([:len $gwStatus] > 0) do={
                :if ([:len [:find $gwStatus "unreachable"]]=0 && [:len [:find $gwStatus "inactive"]]=0) do={

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
                            :local checkIf [:len [find key=$ifaceISP in=$gwList]];
                            :if ($checkIf = 0) do={
                                :set ($gwList->$count) $ifaceISP;
                                :set count ($count+1);
                                :local gbRxReport [$NumSiPrefix [/interface get $ifaceISP rx-byte]];
                                :local gbTxReport [$NumSiPrefix [/interface get $ifaceISP tx-byte]];
                                :set message ("$message\r\nTraffic via:\r\n'$ifaceISP'\r\nRx/Tx $gbRxReport/$gbTxReport");
                            }
                        }
                    }
                }
            }
        }
    } else={:set message ("$message \r\nWAN iface not found")}

    # Output of message
    :put $message;
    :log warning $message;
} on-error={:log warning ("Error, can't show health status")}

