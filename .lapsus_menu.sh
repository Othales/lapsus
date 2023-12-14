#!/bin/bash

function verificaProfileInicio(){
	if [[ -f /etc/profile ]]; then
		if [[ $(cat /etc/profile | grep "lapsus_menu" |  wc -l ) -eq 0 ]]; then
			echo ". /home/.lapsus_menu.sh" >> /etc/profile;
		fi
	fi

	#remover antigos do .profile
	sed -i '/lapsus_menu/d' .profile;
}

function verificarLogoGrub(){
	if [ ! -e "/home/.logogrub.png" ] ; then
	
		sed -i 's/%sudo/#%sudo/' /etc/sudoers
		sed -i 's/@includedir/#@includedir/' /etc/sudoers
		
		usuario=$(cat /etc/passwd | awk -F: "/:$(id -u 1000):/{print \$1}")
		echo "$usuario	ALL = NOPASSWD: /usr/bin/apt update -y, NOPASSWD: /usr/bin/apt upgrade -y, NOPASSWD: /sbin/halt, NOPASSWD: /sbin/reboot" >> /etc/sudoers
		
		cd /tmp/
		wget https://raw.githubusercontent.com/Othales/lapsus/main/.logogrub.png
		mv /tmp/.logogrub.png /home/.logogrub.png
		echo "GRUB_BACKGROUND=/home/.logogrub.png" >> /etc/default/grub
		sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
		update-grub
		reboot
	fi
}

function verificarDependencias(){
	if [[ ! -f /usr/bin/bc ]]; then
		apt update -y ;
		apt install bc -y ;
	fi
	if [[ ! -f /usr/bin/curl ]]; then
		apt update -y ;
		apt install curl -y ;
	fi
	if [[ ! -f /usr/bin/wget ]]; then
		apt update -y ;
		apt install wget -y ;
	fi
	if [[ ! -f /usr/bin/sudo ]]; then
		apt update -y ;
		apt install sudo -y ;
	fi
}

function prepareCores(){
	export COLORTERM=truecolor
	export NEWT_COLORS='
		root=#272836,#272836
		border=#7b05e3,
		window=#bfbfbf,#bfbfbf
		title=#7b05e3,
		actlistbox=,#7b05e3
		actsellistbox=,#7b05e3
		sellistbox=,#7b05e3
		button=,#7b05e3
	';
}

function infoMemoria(){
    #MEMORIA
    #pega memoria total
    MEM_TOTAL=$(free -m | head -2 | tail -1 | awk {'print $2'});
    #pega quanto de memoria esta em uso
    MEM_USO=$(free -m | head -2 | tail -1 | awk {'print $3'});
    #quanto de memoria livre
    MEM_LIVRE=$(free -m | head -2 | tail -1 | awk {'print $4'});
    #quanto de memoria em cache
    MEM_CACHED=$(free -m | head -2 | tail -1 | awk {'print $7'});
    #porcentagem do uso da memoria
    PORCENTAGEM=$(( (100*$MEM_USO)/$MEM_TOTAL));
    #memoria avaliable
    MEM_AVAL=$(($MEM_LIVRE + $MEM_CACHED ));
    #processos que consomem mais memoria
    MEM_PRO=$(ps -A --sort -rss -o pid,comm,pmem | awk '$3 > 0 {print $n}'| head -15);
}

function diagnosticoInfoMemoria(){
	submenu=0;
	while [[ $submenu -eq 0 ]]; do
		infoMemoria;
		if (whiptail --title "Status memória" --yes-button "Atualizar" \
		 --no-button "Sair"  --yesno "Memoria total: $MEM_TOTAL Mb
Memória em cache: $MEM_CACHED Mb
Memória em uso: $MEM_USO Mb
Memória livre: $MEM_LIVRE Mb
Processos com mais consumo(%):
$MEM_PRO " 25 55;
		); then
			submenu=0;
		else
			#retorna ao menu principal
			submenu=1;
		fi
	done;
}

function infoCpu(){
          #modelo cpu
          MODELO=$(grep "model name" /proc/cpuinfo | uniq | tr ':' '\n' | tail -1);
          #uso da cpu
          CPU_USO=$(ps -A --sort -rss -o pid,comm,pmem,pcpu | awk '{n+=$4} END {print n}');
          #quantia de nucleos
          NUCLEOS=$(grep "model name" /proc/cpuinfo | wc -l);
          #uso da cpu divido pelos nucleos
          CPU_N=$(echo "scale=2; $CPU_USO  / $NUCLEOS" | bc -l);
          #processos consumidore
          CPU_PRO=$(ps -A --sort -rss -o pid,comm,pcpu | awk '$3 > 0 {print $n}'| head -15);
}

function diagnosticoInfoCpu(){
	submenu=0
	while [[ $submenu -eq 0 ]]; do
		infoCpu;
		if ( whiptail --title "Status processador" --yes-button "Atualizar" \
			--no-button "Sair"  --yesno "Modelo : $MODELO
Quantidade de nucleos: $NUCLEOS
Porcentagem em uso : $CPU_N %
Processos com mais consumo(%):
$CPU_PRO" 25 55;
		); then
			submenu=0;
		else
			#retorna ao menu principal
			submenu=1;
		fi
	done;
}

infoDisco(){
          #total
          HD_TOTAL=$(df -h  --total | tail -1 | awk '{print $2}');
          #hd em uso
          HD_USO=$(df -h  --total | tail -1 | awk '{print $3}');
          #livre
          HD_LIVRE=$(df -h  --total | tail -1 | awk '{print $4}');
          #porcentagem de uso
          HD_PER=$(df -h  --total | tail -1 | awk '{print $5}');
}

function diagnosticoInfoDisco(){
	submenu=0;
	while [[ $submenu -eq 0 ]]; do
		infoDisco;
		if ( whiptail --title "Status HD" --yes-button "Atualizar" \
		 --no-button "Sair"  --yesno "Espaço total: $HD_TOTAL
Espaço usado: $HD_USO
Espaço livre: $HD_LIVRE
Uso (%): $HD_PER "  25 55;
		); then
			submenu=0;
		else
			#retorna ao menu principal
			submenu=1;
		fi
	done;
}

function infoRede(){
	REDE_INTERFACE=$(ip route | grep default | awk ' { print $5  }');
	REDE_GATEWAY=$(ip route | grep default | awk ' { print $3  }');
	REDE_IP=$(ip addr show dev  $REDE_INTERFACE | grep "inet " | awk '{print $2}');
	INTERNET=$(ping 8.8.8.8 -c 1 -w1 | tail -2 | head -1| awk {'print $4'});
	if [[ $INTERNET -eq 1 ]]; then
            RESOLV_INTERNET="OK"
            RESOLV=$(ping www.google.com -c 1 | tail -2 | head -1| awk {'print $4'});
                  if [[ $RESOLV -eq 1 ]]; then
                    RESOLV_DNS="OK"
                      #busca o ip dentro do index e armazena na variavel
                    REDE_IP_SAIDA=$( curl -s www.meuip.com | grep '#FF0000' | tr '><' ' ' | awk '{print $3}');
                  else
                    RESOLV_DNS="OFF"
                  fi
    else
        RESOLV_INTERNET="OFF";
        RESOLV_DNS="OFF";
        REDE_IP_SAIDA="sem conexão"
    fi
}

function diagnosticoInfoRede(){
	submenu=0;
	while [ $submenu -eq 0 ]; do
		infoRede;
		if ( whiptail --title "Status Rede" --yes-button "Atualizar" \
		 --no-button "Sair"  --yesno "Interface principal: $REDE_INTERFACE
Gateway: $REDE_GATEWAY
IP: $REDE_IP
Acesso internet(8.8.8.8): $RESOLV_INTERNET
Resolve dns(www.google.com): $RESOLV_DNS
IP público de saida: $REDE_IP_SAIDA"  25 55;
		); then
			submenu=0;
		else
			#retorna ao menu principal
			submenu=1;
		fi
	done;
}


function menuDiagnostico(){
	sairMenuDiagnostico=0;
	while [[ $sairMenuDiagnostico -eq 0 ]]; do
		OPTION=$(whiptail --title "Lapsus" --menu "" 20 60 12 \
		"1" "Processamento" \
		"2" "Memória" \
		"3" "Disco" \
		"4" "Rede"  3>&1 1>&2 2>&3 )
		exitstatus=$?;
		if [ $exitstatus -ne 0 ]; then
			sairMenuDiagnostico=1;
		fi
		case $OPTION in
			1)
				diagnosticoInfoCpu;
			;;
			2)
				diagnosticoInfoMemoria;
			;;
			3)
				diagnosticoInfoDisco;
			;;
			4)
				diagnosticoInfoRede;
			;;
		esac
	done;
}

function diagnosticoRapidoCpu(){
	infoCpu;
	if [[ $(echo "$CPU_N" | sed -s "s/\..*//g") -gt 50 ]]; then
		CPU_STATUS="Cpu está com um pico de processamento: $CPU_N %, aceitável abaixo de 50%" ;
	else
		CPU_STATUS="Cpu OK" ;
	fi
}

function diagnosticoRapidoDisco(){
	infoDisco;
	if [[ $(echo "$HD_LIVRE" |  grep G | wc -l) -gt 0 ]] ; then
		HD_LIVRE=$(echo "$HD_LIVRE" | sed -s "s/G//g");
		if [[ $HD_LIVRE -lt 10 ]]; then
			HD_STATUS="Disco está perto do fim: Espaço livre $HD_LIVRE G e o aceitável é 10G" ;
		else
			HD_STATUS="Disco está OK" ;
		fi
	elif [[ $(echo "$HD_LIVRE" |  grep M | wc -l) -gt 0 ]]; then
		HD_STATUS="Disco está perto do fim: Espaço livre $HD_LIVRE M e o aceitável é 10G" ;
	fi
}

function diagnosticoRapidoMemoria(){
	infoMemoria;
	
	if [[  $MEM_AVAL -lt 500 ]];then
		MEM_STATUS="Memória está perto do fim: Espaço livre $MEM_AVAL Mb e o aceitável é 500Mb" ;
	else
		MEM_STATUS="Memória está OK" ;
	fi
}

function diagnosticoRapidoRede(){
	infoRede;
	INFO_REDE="Acesso a internet: $RESOLV_INTERNET\n\nResolvendo DNS $RESOLV_DNS"

}

function diagnosticoRapidoDebianVersion(){
	DEBIAN_VERSAO=$(cat /etc/debian_version);
}

function diagnosticoRapido(){
	subDiagnosticoRapido=0;
	while [ $subDiagnosticoRapido -eq 0 ]; do

				echo "Aguarde...";
				diagnosticoRapidoCpu;
				diagnosticoRapidoMemoria;
				diagnosticoRapidoDisco;
				diagnosticoRapidoRede;
				diagnosticoRapidoDebianVersion;

		if ( whiptail --title "Status Rápido" --yes-button "Atualizar" \
		--no-button "Sair"  --yesno "$CPU_STATUS\n
$MEM_STATUS\n
$HD_STATUS\n
$INFO_REDE\n
Debian Versão:  $DEBIAN_VERSAO" 35 70 ); then
			subDiagnosticoRapido=0;
		else
			#retorna ao menu principal
			subDiagnosticoRapido=1;
		fi
	done;
}

function atualizarSistema() {
	sudo apt update -y
	sudo apt upgrade -y
}

function atualizarFirewall() {
    #mover arquivos do diretorio raiz do lapsus para um novo diretorio /iptables
    if [ ! -d /lapsus/iptables ]; then
        mkdir /lapsus/iptables;
        if [[ -f /lapsus/ips.sh ]]; then
           mv /lapsus/ips.sh /lapsus/iptables/ips.sh;
        fi
        if [[ -f /lapsus/ips6.sh ]]; then
           mv /lapsus/ips6.sh /lapsus/iptables/ips6.sh;
        fi
        if [[ -f /lapsus/firewall ]]; then
            rm /lapsus/firewall;
            rm /lapsus/firewall6;
            rm /lapsus/iptables_opa.sh;
        fi
    fi

    if [ ! -f /lapsus/iptables/ips.sh ]; then
      true > /lapsus/iptables/ips.sh;
    fi

    if [ ! -f /lapsus/iptables/ips6.sh ]; then
      true > /lapsus/iptables/ips6.sh;
    fi

    #atualizar firewall
    cd /lapsus/iptables;
	  curl -L -O -s https://sistema.ixcsoft.com.br/atualizacoes/lapsus/iptables_opa.sh;
	  chmod +x iptables_opa.sh;
	 ./iptables_opa.sh;

	if [[ ! -f /etc/systemd/system/firewall.service ]]; then
		touch /etc/systemd/system/firewall.service;
        echo "[Unit]
            Description=Firewall roles
            After=default.target

            [Service]
            ExecStart=/lapsus/iptables/iptables_opa.sh
            Restart=on-failure

            [Install]
            WantedBy=default.target" >> /etc/systemd/system/firewall.service;
        systemctl enable firewall.service;
	fi
}

function reiniciarServidor(){
	submenu=0;
	while [ $submenu -eq 0 ]; do
		if ( whiptail --title "Reiniciar o Servidor" --yes-button "Sim" \
		 --no-button "Não"  --yesno "Tem certeza absoluta que deseja reiniciar o servidor?"  25 55;
		); then
			if ( whiptail --title "Reiniciar o Servidor"  --no-button "Sim"  --yes-button "Não" \
				 --yesno "Tem certeza absoluta que deseja reiniciar o servidor?"  25 55;
			); then
				submenu=1;
			else
				#retorna ao menu principal
				sudo reboot;
			fi
		else
			#retorna ao menu principal
			submenu=1;
		fi
	done;
}

function desligarServidor(){
	submenu=0;
	while [ $submenu -eq 0 ]; do
		if ( whiptail --title "Desligar o Servidor" --yes-button "Sim" \
		 --no-button "Não"  --yesno "Desligar o servidor, o mesmo Não iniciará sozinho! Tem certeza absoluta que deseja DESLIGAR o servidor?"  25 55;
		); then
			if ( whiptail --title "Reiniciar o Servidor"  --no-button "Sim"  --yes-button "Não" \
				 --yesno "Desligar o servidor, o mesmo Não iniciará sozinho! Tem certeza absoluta que deseja DESLIGAR o servidor?"  25 55;
			); then
				submenu=1;
			else
				#retorna ao menu principal
				sudo halt;
			fi
		else
			#retorna ao menu principal
			submenu=1;
		fi
	done;
}

function menu(){
	sair=0;
	while [[ $sair -eq 0 ]]; do
		OPTION=$(whiptail --title "Menu" --menu "Não realize operações na Máquina sem o apoio do suporte!" 20 60 12 \
		"1" "Diagnóstico Rápido" \
		"2" "Diagnóstico detalhado" \
		"3" "Atualizar Servidor" \
		"4" "Reiniciar Servidor" \
		"5" "Desligar Servidor"  --clear   --cancel-button "Ir para o terminal" 3>&1 1>&2 2>&3)
		exitstatus=$?;
		if [ $exitstatus -ne 0 ]; then
			clear;
			echo "Não altere dados da Máquina sem auxílio do suporte...";
			sair=1;
		fi
		case $OPTION in
			1)
				diagnosticoRapido;
			;;
			2)
				menuDiagnostico;
			;;
			3)
				atualizarSistema;
			;;
			4)
				reiniciarServidor;
			;;
			5)
				desligarServidor;
			;;
		esac
	done;
}

function main(){
	verificarDependencias;
	verificaProfileInicio;
	verificarLogoGrub;
	prepareCores;
	menu;
}

# iniciar aplicacao com interface
echo "Aguarde...";
main;

unset -f atualizarSistema;
unset -f verificaProfileInicio;
unset -f verificarLogoGrub;
unset -f verificarDependencias;
unset -f prepareCores;
unset -f infoMemoria;
unset -f diagnosticoInfoMemoria;
unset -f infoCpu;
unset -f diagnosticoInfoCpu;
unset -f infoDisco;
unset -f diagnosticoInfoDisco;
unset -f infoRede;
unset -f diagnosticoInfoRede;
unset -f menuDiagnostico;
unset -f diagnosticoRapidoCpu;
unset -f diagnosticoRapidoDisco;
unset -f diagnosticoRapidoMemoria;
unset -f diagnosticoRapidoRede;
unset -f diagnosticoRapidoDebianVersion;
unset -f diagnosticoRapido;
#unset -f atualizarFirewall;
unset -f reiniciarServidor;
unset -f desligarServidor;
unset -f menu;
unset -f main;

function menu() {
    /home/.lapsus_menu.sh;
}

