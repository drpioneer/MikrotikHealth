# Device status view script
# Script uses ideas by Enternight, Sertik, drPioneer
# https://forummikrotik.ru/viewtopic.php?p=84984#p84984
# tested on ROS 6.49.5
# updated 2022/07/22

:do {
    # Digit conversion function via SI-prefix
    # How to use: :put [$NumSiPrefix 648007421264];
    :local NumSiPrefix do={
        :local inp [:tonum $1];
        :local cnt 0;
        :while ($inp>1024) do={
            :set $inp ($inp>>10);
            :set $cnt ($cnt+1);
        }
        :return ($inp.[:pick [:toarray "B,Kb,Mb,Gb,Tb,Pb,Eb,Zb,Yb"] $cnt]);
    }

    # Defining variables
    :local tempC    0;
    :local volt     0;
    :local smplVolt 0;
    :local lowVolt  0;
    :local inVolt   0;
    :local hddTotal 0;
    :local hddFree  0;
    :local badBlock 0;
    :local memTotal 0;
    :local memFree  0;
    :local cpuZ     0;
    :local currFW   "";
    :local upgrFW   "";

    :do {
        :set hddTotal [/system resource get total-hdd-spac];
        :set hddFree  [/system resource get free-hdd-space];
        :set badBlock [/system resource get bad-blocks];
        :set memTotal [/system resource get total-memory];
        :set memFree  [/system resource get free-memory];
        :set cpuZ     [/system resource get cpu-load];
        :set currFW   [/system routerbo get upgrade-firmwa];
        :set upgrFW   [/system routerbo get current-firmwa];
        :if ([/system resource get board-name]!="CHR") do={
            :set tempC [/system health get temperature];
            :set volt  [/system health get voltage];
        }
        :set smplVolt ($volt/10);
        :set lowVolt (($volt-($smplVolt*10))*10);
        :set inVolt ("$smplVolt.$[:pick $lowVolt 0 3]");
    } on-error={
        :put ("Error defining variables");
        :log warning ("Error defining variables");
    }
    :local message  ">>>Health report:\r\nID $[system identity get name]";

    # General information
    :do {
        :set message ("$message\r\nuptime $[system resource get uptime]");
        :set message ("$message\r\nmodel $[system resource get board-name]");
        :set message ("$message\r\nROS $[system resource get version]");
        :if ($currFW!=$upgrFW) do={:set message ("$message\r\n*FW not updated*")}
        :set message ("$message\r\narch $[/system resource get arch]");
        :set message ("$message\r\nCPU $[/system resource get cpu]");
        :set hddFree ($hddFree/($hddTotal/100));
        :set memFree ($memFree/($memTotal/100));
        :if ($cpuZ<90) do={:set message ("$message\r\nCPU load $cpuZ%");
        } else={:set message ("$message\r\n*large CPU usage $cpuZ%*")}
        :if ($memFree>17) do={:set message ("$message\r\nmem free $memFree%");
        } else={:set message ("$message\r\n*low free mem $memFree%*")}
        :if ($hddFree>6) do={:set message ("$message\r\nHDD free $hddFree%");
        } else={:set message ("$message\r\n*low free HDD $hddFree%*")}
        :if ([:len $badBlock]>0) do={
            :if ($badBlock=0) do={:set message ("$message\r\nbad blocks $badBlock%");
            } else={:set message ("$message\r\n*present bad blocks $badBlock%*")}
        }
        :if ($volt>0) do={
            :if ($smplVolt>4 && $smplVolt<50) do={:set message ("$message\r\nvoltage $inVolt V");
            } else={:set message ("$message\r\n*bad voltage $inVolt V*")}
        }
        :if ($tempC>0) do={
            :if ($tempC>4 && $tempC<50) do={:set message ("$message\r\ntemperature $tempC C");
            } else={:set message ("$message\r\n*abnorm temp $tempC C*")}
        }
    } on-error={
        :put ("Error general information");
        :log warning ("Error general information");
    }

    # Connections information
    :do {
        :local pppInteract {"-client";"-server"};
        :local pppTypes {"l2tp";"pptp";"ovpn";"ppp";"sstp";"pppoe"};
        :foreach pppInt in=$pppInteract do={ 
            :foreach pppTps in=$pppTypes do={ 
                :local pppType ($pppTps.$pppInt);
                :foreach pppConn in=[[:parse "[/interface $pppType find]"]] do={
                    :local vpnName [[:parse "[/interface $pppType get $pppConn name]"]];
                    :local vpnComm [[:parse "[/interface $pppType get $pppConn comment]"]];
                    :local callrID "";
                    :if ($pppType~"-server") do={:set callrID  [[:parse "[/interface $pppType get $pppConn client-address]"]]}
                    :local vpnType [/interface get $vpnName type];
                    :local iType $vpnType;
                    :local connTo "";
                    :set vpnType [:pick $vpnType ([:find $vpnType "-"] +1) [:len $vpnType]];
                    :if ($vpnType="out" && $iType!="ppp-out") do={
                        :set connTo ("to $[[:parse "[/interface $pppType get $vpnName connect-to]"]]")}
                    :local vpnState [[:parse "[/interface $pppType monitor $pppConn once as-value]"]];
                    :local vpnStatu ($vpnState->"status");
                    :local locAddr ($vpnState->"local-address");
                    :local remAddr ($vpnState->"remote-address");
                    :local upTime ($vpnState->"uptime");
                    :if ([:len [find key="terminating" in=$vpnStatu]] > 0) do={:set vpnStatu "disabled"}
                    :if ([:typeof $vpnStatu]="nothing") do={:set vpnStatu "unplugged"}
                    :if ($vpnStatu!="unplugged" && $vpnStatu!="disabled") do={
                        :set message ("$message\r\n>>>Connect info:\r\n'$vpnName'\r\ntype $pppType");
                        :if ([:len $callrID]>0) do={:set message ("$message\r\nfrom $callrID")}
                        :if ([:len $connTo ]>0) do={:set message ("$message\r\n$connTo")}
                        :if ([:len $vpnComm]>0) do={:set message ("$message\r\nComment $vpnComm")}
                        :set message ("$message\r\nlcl $locAddr\r\nrmt $remAddr\r\nuptime $upTime");
                    }
                }
            }
        }
    } on-error={
        :put ("Error connection information");
        :log warning ("Error connection information");
    }

    # Gateways information
    :do {
        :local routeISP [/ip route find dst-address=0.0.0.0/0];
        :if ([:len $routeISP]>0) do={
            :local gwList [:toarray ""];
            :local count 0;
            :foreach inetGate in=$routeISP do={
                :local gwStatus [:tostr [/ip route get $inetGate gateway-status]];
                :if ([:len $gwStatus]>0) do={
                    :if ([:len [:find $gwStatus "unreachable"]]=0 && [:len [:find $gwStatus "inactive"]]=0) do={
    
                        # Formation of interface name
                        :local ifaceISP "";
                        :foreach idName in=[/interface find] do={
                            :local ifName [/interface get $idName name];
                            :if ([:len [find key=$ifName in=$gwStatus]]>0) do={:set ifaceISP $ifName}
                        }
                        :if ([:len $ifaceISP]>0) do={
    
                            # Checking the interface for entering the Bridge
                            :if ([:len [/interface bridge find name=$ifaceISP]]>0) do={
                                :local ipAddrGW [:tostr [/ip route get $inetGate gateway]];
                                :if ([:find $ipAddrGW "%"]>0) do={
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
                                :if ($checkIf=0) do={
                                    :set ($gwList->$count) $ifaceISP;
                                    :set count ($count+1);
                                    :local gbRxReport [$NumSiPrefix [/interface get $ifaceISP rx-byte]];
                                    :local gbTxReport [$NumSiPrefix [/interface get $ifaceISP tx-byte]];
                                    :set message ("$message\r\n>>>Traffic via:\r\n'$ifaceISP'\r\nrx/tx $gbRxReport/$gbTxReport");
                                }
                            }
                        }
                    }
                }
            }
        } else={:set message ("$message\r\nWAN iface not found")}
    } on-error={
        :put ("Error gateways information");
        :log warning ("Error gateways information");
    }

    # Output of message
    :put $message;
    :log warning $message;
} on-error={
    :log warning ("Error, can't show health status");
    :put ("Error, can't show health status");
}
