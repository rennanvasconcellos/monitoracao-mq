#!/bin/bash

rm -f lista-situacao-qmgrs.txt
rm -f sucesso.txt
rm -f falha.txt
rm -f sucesso-qmgrs.txt
rm -f falha-qmgrs.txt
rm -f tudao.txt
rm -f todos-qmgrs.txt
rm -f qmgrs.txt
rm -f resultado-falha.txt
cp servidores.txt servidores.txt.bkp

# Verifica se no servidor  está excutando serviço REST  (webconsole). Em caso positivo não será monitorado pois este puglin de monitoracao precisa da webconsole em execução para executar as  chamadas REST.

for SERVIDOR in $(cat servidores.txt)
                        do
                        STATUS_WEBCONSOLE=$(curl --connect-timeout 5 -s -k -i -u USUARIO:SENHA "https://$SERVIDOR:9443/ibmmq/console" | grep HTTP | awk '{print $2}')

			if [ -z $STATUS_WEBCONSOLE ]
				then
					echo "WARN: Nao foi possivel verificar dos qmgrs, pois o servidor $SERVIDOR nao esta com a webconsole em execucao"
				sed -i s/"$SERVIDOR"// servidores.txt
				 
			fi
done


CLUSTER=$(cat servidores.txt.bkp)

for SERVIDOR in $(cat servidores.txt)
do
        QMGRS=$(curl --connect-timeout 5 -s -k -u USUARIO:SENHA "https://"$SERVIDOR":9443/ibmmq/rest/v1/admin/qmgr" | grep QM | awk '{print $2}' | cut -d "\"" -f 2)

TODOS_QMGRS=$(echo -e "${QMGRS// /}")

echo "$TODOS_QMGRS" >> qmgrs.txt

TODOS_QMGRS=$(cat qmgrs.txt | sort | uniq)
echo $TODOS_QMGRS > todos-qmgrs.txt
done

for SERVIDORES in $(cat servidores.txt)
        do
                for QMGR in $(cat todos-qmgrs.txt)
                        do
                        STATUS_QMGR=$(curl --connect-timeout 5 -s -k -i -u USUARIO:SENHA "https://$SERVIDORES:9443/ibmmq/rest/v1/admin/qmgr/$QMGR/queue/SYSTEM.ADMIN.COMMAND.QUEUE?status=*" | grep HTTP | awk '{print $2}')
			echo  "$QMGR $STATUS_QMGR" | sort | uniq >> lista-situacao-qmgrs.txt
			SUCESSO=$(cat lista-situacao-qmgrs.txt | awk '{print $1 " " $2}' | grep "$QMGR" | grep "200" >> sucesso.txt)
			FALHA=$(cat lista-situacao-qmgrs.txt | awk '{print $1 " " $2}' | grep "$QMGR" | grep -E "404|503" >> falha.txt)
                done
done

for i in $(cat todos-qmgrs.txt) 
do 
	TESTE=$(grep $i sucesso.txt | wc -l)
	if [ $TESTE -eq 0 ]
	then
		echo "$i" >> resultado-falha.txt
        fi
done

if [ -e resultado-falha.txt ]
	then
		echo "ERRO! Foi detectado falha no(s) seguinte(s) Qmgr(s) no cluster "$CLUSTER""
	cat resultado-falha.txt | sort | uniq
	cp servidores.txt.bkp servidores.txt
                rm -f servidores.txt.bkp
		exit 3
			else
			echo "Queue managers em execucao no cluster "$CLUSTER""		
			cat sucesso.txt | awk '{print "OK - " $1}' | sort | uniq
			cp servidores.txt.bkp servidores.txt
			rm -f servidores.txt.bkp
			exit 0
fi
