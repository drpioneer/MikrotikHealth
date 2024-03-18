# Device status view script
# Script uses ideas by Enternight, Jotne, rextended, Sertik, Brook, drPioneer
# https://github.com/drpioneer/MikrotikHealth/blob/main/health.rsc
# https://forummikrotik.ru/viewtopic.php?p=91302#p91302
# tested on ROS 6.49.10 & 7.12
# updated 2024/03/18

:do {
  # general info reading function # https://forummikrotik.ru/viewtopic.php?p=45743#p45743
  :local GenInfo do={
    /system identity;
    :local ident ([print as-value]->"name");
    /system health;
    :local volt ([print as-value]->"voltage");
    :local tempC ([print as-value]->"temperature");
    :local currFW ""; :local upgrFW "";
    :do {/system routerboard;
      :set currFW ([print as-value]->"current-firmware");
      :set upgrFW ([print as-value]->"upgrade-firmware")} on-error={};
    /system resource;
    :local uptime ([print as-value]->"uptime");
    :local arch ([print as-value]->"architecture-name");
    :local cpu ([print as-value]->"cpu");
    :local hddTotal ([print as-value]->"total-hdd-space");
    :local hddFree ([print as-value]->"free-hdd-space");
    :local badBlock ([print as-value]->"bad-blocks");
    :local memTotal ([print as-value]->"total-memory");
    :local memFree ([print as-value]->"free-memory");
    :local cpuZ ([print as-value]->"cpu-load");
    :local ros ([print as-value]->"version");
    :local board ([print as-value]->"board-name");
    :if ([:pick $ros 0 1]="7") do={:set tempC ([/system health print as-value]->0->"value")}
    :local msg "Id $ident\r\nBrd $board\r\nRos $ros";
    :if ($currFW!=$upgrFW) do={:set msg "$msg\r\n**Fw not updated"}
    :set msg "$msg\r\nArch $arch\r\nCpu $cpu";
    :if ($cpuZ<90) do={:set msg "$msg\r\nCpuLoad $cpuZ%"} else={:set msg "$msg\r\n**large Cpu usage $cpuZ%"}
    :set memFree ($memFree/($memTotal/100));
    :if ($memFree>17) do={:set msg "$msg\r\nMemFree $memFree%"} else={:set msg "$msg\r\n**low free Mem $memFree%"}
    :set hddFree ($hddFree/($hddTotal/100));
    :if ($hddFree>6) do={:set msg "$msg\r\nHddFree $hddFree%"} else={:set msg "$msg\r\n**low free Hdd $hddFree%"}
    :if ([:len $badBlock]>0) do={
      :if ($badBlock=0) do={:set msg "$msg\r\nBadBlck $badBlock%"} else={:set msg "$msg\r\n**present Bad blocks $badBlock%"}}
    :if ([:len $volt]>0) do={
      :local smplVolt ($volt/10); :local lowVolt (($volt-$smplVolt*10)*10); :local inVolt "$smplVolt.$[:pick $lowVolt 0 3]";
      :if ($smplVolt>4 && $smplVolt<53) do={:set msg "$msg\r\nPwr $inVolt V"} else={:set msg "$msg\r\n**bad Pwr $inVolt V"}}
    :if ([:len $tempC]>0) do={
      :if ($tempC<70) do={:set msg "$msg\r\nTemp $tempC C"} else={:set msg "$msg\r\n**abnorm Temp $tempC C"}}
    :return "$msg\r\nUpt $uptime";
  }

  # ppp info reading function
  :local PPPInfo do={
    :local msg ""; :local cnt 1;
    :foreach pppInt in={"-client";"-server"} do={ 
      :foreach pppTps in={"l2tp";"pptp";"ovpn";"ppp";"sstp";"pppoe"} do={ 
        :local pppType ($pppTps.$pppInt);
        :foreach pppConn in=[[:parse "[/interface $pppType find]"]] do={
          :local vpnName [[:parse "[/interface $pppType get $pppConn name]"]];
          :local vpnComm [[:parse "[/interface $pppType get $pppConn comment]"]];
          :local callrID ""; :local connTo "";
          :if ($pppType~"-server") do={:set callrID  [[:parse "[/interface $pppType get $pppConn client-address]"]]}
          :local vpnType  [/interface get $vpnName type]; :local iType $vpnType;
          :set vpnType [:pick $vpnType ([:find $vpnType "-"] +1) [:len $vpnType]];
          :if ($pppTps!="pppoe" && $vpnType="out" && $iType!="ppp-out") do={
            :set connTo "$[[:parse "[/interface $pppType get $vpnName connect-to]"]]"}
          :local vpnState [[:parse "[/interface $pppType monitor $pppConn once as-value]"]];
          :local vpnStatu ($vpnState->"status");
          :local locAddr ($vpnState->"local-address");
          :local remAddr ($vpnState->"remote-address");
          :local upTime ($vpnState->"uptime");
          :if ([:len [find key="terminating" in=$vpnStatu]]>0) do={:set vpnStatu "disabled"}
          :if ([:typeof $vpnStatu]="nothing") do={:set vpnStatu "unplugged"}
          :if ($vpnStatu!="unplugged" && $vpnStatu!="disabled") do={
            :set msg "$msg\r\n>>>PPPinfo$cnt:\r\nTyp $pppType\r\nNam $vpnName";
            :if ([:len $callrID]>0) do={:set msg "$msg\r\nFrm $callrID"}
            :if ([:len $connTo ]>0) do={:set msg "$msg\r\nTo $connTo"}
            :if ([:len $vpnComm]>0) do={:set msg "$msg\r\nCmnt $vpnComm"}
            :set msg ("$msg\r\nLcl $locAddr\r\nRmt $remAddr\r\nUpt $upTime");
            :set cnt (cnt+1)}}}}
    :return $msg;
  }

  # gateways info reading function
  :local GwInfo do={
    # digit conversion function via SI-prefix # https://forum.mikrotik.com/viewtopic.php?t=182904#p910512
    :local NumSiPrefix do={
      :if ([:len $1]=0) do={:return "0b"}
      :local inp [:tonum $1]; :local cnt 0;
      :while ($inp>1000) do={:set $inp ($inp>>10); :set $cnt ($cnt+1)}
      :return ($inp.[:pick [:toarray "b,Kb,Mb,Gb,Tb,Pb,Eb,Zb,Yb"] $cnt])}
    :local msg ""; :local routeISP [/ip route find dst-address="0.0.0.0/0"];
    :if ([:len $routeISP]=0) do={:return "\r\n>>>WAN not found"}
    :foreach inetGate in=$routeISP do={
      :local ifGate [:tostr [/ip route get $inetGate vrf-interface]];
      :if ([:len $ifGate]>0) do={
        :local rxReport [$NumSiPrefix [/interface get [find name=$ifGate] rx-byte]];
        :local txReport [$NumSiPrefix [/interface get [find name=$ifGate] tx-byte]];
        :set msg "$msg\r\n>>>TraffVia:\r\n'$ifGate'\r\nrx/tx $rxReport/$txReport"}}
    :return $msg;
  }

  # external IP address return function (in case of double NAT) # https://forummikrotik.ru/viewtopic.php?p=65345#p65345
  :local ExtIP do={
    :local urlString "http://checkip.dyndns.org"; :local httpResp ""; :local cnt 0;
    :do {
      :do {:set httpResp [/tool fetch mode=http url=$urlString as-value output=user]} on-error={}
      :set cnt ($cnt+1);
    } while ([:len $httpResp]=0 && cnt<4);
    :if ([:len $httpResp]!=0) do={
      :local content ($httpResp->"data");
      :if ([:len $content]!=0) do={:return [:pick $content ([:find $content "dress: " -1]+7) [:find $content "</body>" -1]]}}
    :return "Unknown";
  }

  # main body
  :local message ">>>HealthRep:\r\n$[$GenInfo]$[$PPPInfo]$[$GwInfo]\r\n>>>ExternIp\r\n$[$ExtIP]";
  :log warning $message; :put $message;
} on-error={:log warning ("Error, can't show health status"); :put ("Error, can't show health status")}
