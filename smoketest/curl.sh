#!/bin/bash

#########################################################
#	The script for test MTW API			#
#########################################################



# Get OAT server name and create cert file

echo -ne "Please enter the OAT server name[default:localhost]: "
read HOST_NAME
if [ "$HOST_NAME" = "" ];then
	HOST_NAME=localhost
fi
echo -ne "Please enter the OAT server port[default:8443]: "
read PORT
if [ "$PORT" = "" ];then
	PORT=8443
fi
echo "$HOST_NAME $PORT"
echo "Now creating cert file for $HOST_NAME"
openssl  s_client -connect $HOST_NAME:$PORT -cipher DHE-RSA-AES256-SHA|tee  certfile.cer 

#Check the Host and Service status
wget --ca-certificate=certfile.cer https://$HOST_NAME:$PORT/HisPrivacyCAWebServices2/hisPrivacyCAWebService2?wsdl >> /dev/null

#lets warm up oat appraiser before testing or we may face strange issues
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d '{"hosts":["somedata"]}' "https://$HOST_NAME:$PORT/AttestationService/resources/PollHosts"
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d '{"hosts":["localhost"]}' "https://$HOST_NAME:$PORT/AttestationService/resources/PollHosts"
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d '{"hosts":["someotherdata"]}' "https://$HOST_NAME:$PORT/AttestationService/resources/PollHosts"
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d '{"hosts":["randomdata"]}' "https://$HOST_NAME:$PORT/AttestationService/resources/PollHosts"

if [ $? -ne 0 ];then
	echo "The host $HOST_NAME can not accessed"
	echo "Exit..."
	exit 1
fi
rm -f hisPrivacyCAWebService2?wsdl

if [ -f /tmp/Result ];then
	rm -f /tmp/Result
fi

echo "#The result about OEM" >> /tmp/Result
echo
echo "******************Add OEM normal******************************************" >> /tmp/Result
# Add OEM successful (normal)
echo -ne "Add OEM successful (normal)		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "OEM $OEM_TMP already exists in the database" /tmp/res ;then
	echo -e "Passed " >> /tmp/Result
else
	echo -e "Failed " >> /tmp/Result
fi

# Add OEM fail (normal)
echo -ne "Add OEM fail (normal)			:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $2;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $2;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res
	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        	echo "Passed" >> /tmp/Result
	else
	        echo "Failed" >> /tmp/Result
	fi
else
        echo "Passed" >> /tmp/Result
fi

echo
echo "******************Add OEM with checking boundary value********************" >> /tmp/Result
# Add OEM with null string
echo -ne "Add OEM with null string		:	" >> /tmp/Result
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d '{"Name":"","Description":"DESCRIPTION"}' "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Add OEM with edge lenth string
echo -ne "Add OEM with edge lenth string		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $3;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $3;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "OEM $OEM_TMP already exists in the database" /tmp/res;then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Add OEM with over lenth string
echo -ne "Add OEM with over lenth string		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $4;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $4;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************Edit OEM normal*****************************************" >> /tmp/Result
# Edit OEM successful (normal)
echo -ne "Edit OEM successful (normal)		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $5;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /dev/null
OEM_DESC=`awk -F ":" 'NR==12 {print $5;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo -ne "Edit OEM fail (normal)			:	" >> /tmp/Result
# Edit OEM fail (normal)
OEM_TMP=`awk -F ":" 'NR==2 {print $6;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $6;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************Edit OEM with checking boundary value******************" >> /tmp/Result
# Edit OEM with null string
echo -ne "Edit OEM with null string		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $5;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $12;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Edit OEM with edge lenth string
echo -ne "Edit OEM with edge lenth string		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $7;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /dev/null
OEM_DESC=`awk -F ":" 'NR==12 {print $7;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Edit OEM with over lenth string
echo -ne "Edit OEM with over lenth string		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $7;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $8;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************Delete OEM normal**************************************" >> /tmp/Result
# Delete OEM successful (normal)
echo -ne "Delete OEM successful (normal)		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $9;}' test.data`
OEM_DESC=`awk -F ":" 'NR==12 {print $9;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /dev/null
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/oem?Name=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete OEM fail (normal)
echo -ne "Delete non-existent OEM fail (normal)	:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $10;}' test.data`
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/oem?Name=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo -ne "Delete connected OEM fail (normal)	:	" >> /tmp/Result
MLE_TMP=mle1test
MLE_VER=v1test
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/oem?Name=$OEM_TMP" -3 > /tmp/res

	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        	echo "Passed" >> /tmp/Result
	else
	        echo "Failed" >> /tmp/Result
	fi
else
	echo "Add MLE fail" >> /tmp/Result
fi

echo
echo "******************Delete OEM with checking boundary value*****************" >> /tmp/Result
# Delete OEM with null string
echo -ne "Delete OEM with null string		:	" >> /tmp/Result
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/oem?Name=" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete OEM with edge lenth string
echo -ne "Delete OEM with edge lenth string	:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $11;}' test.data`
OEM_DESC=`awk -F ":" 'NR==2 {print $12;}' test.data`
INFO=`echo "{\"Name\":\"$OEM_TMP\",\"Description\":\"$OEM_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/oem" -3 > /dev/null
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/oem?Name=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************View OEM************************************************" >> /tmp/Result
# View OEM
echo -ne "View OEM				:	" >> /tmp/Result
curl --cacert certfile.cer -H "Content-Type: application/json" -X GET https://$HOST_NAME:$PORT/WLMService/resources/oem -3 > /tmp/res
VIEW=`awk -F "\"" '{print $2;}' /tmp/res`

if [ "$VIEW" = "oem" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo 
echo
echo "#The result about OS" >> /tmp/Result
echo
echo "******************Add OS normal*******************************************" >> /tmp/Result
# Add OS successful (normal)
echo -ne "Add OS successful (normal)		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "OS $OS_TMP$OS_VER already exists in the database" /tmp/res;then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Add OS fail (normal)
echo -ne "Add OS fail (normal)			:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $2;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $2;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $2;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
	        echo "Passed" >> /tmp/Result
	else
	        echo "Failed" >> /tmp/Result
	fi
else
	echo "Passed" >> /tmp/Result
fi

echo
echo "******************Add OS with checking boundary value*********************" >> /tmp/Result
# Add OS with null string
echo -ne "Add OS with null string			:	" >> /tmp/Result
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d '{"Name":"","Version":"","Description":"DESCRIPTION"}' "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Add OS with edge lenth string
echo -ne "Add OS with edge lenth string		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $3;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $3;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $3;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "OS $OS_TMP$OS_VER already exists in the database" /tmp/res ;then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Add OS with over lenth string
echo -ne "Add OS with over lenth string		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $4;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $4;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $4;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************Edit OS normal******************************************" >> /tmp/Result
# Edit OS successful (normal)
echo -ne "Edit OS successful (normal)		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $5;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $5;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /dev/null
OS_DESC=`awk -F ":" 'NR==12 {print $5;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo -ne "Edit OS fail (normal)			:	" >> /tmp/Result
# Edit OS fail (normal)
OS_TMP=`awk -F ":" 'NR==3 {print $6;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $6;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************Edit OS with checking boundary value******************" >> /tmp/Result
# Edit OS with null string
echo -ne "Edit OS with null string		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $5;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $5;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $12;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Edit OS with edge lenth string
echo -ne "Edit OS with edge lenth string		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $5;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $5;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $7;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Edit OS with over lenth string
echo -ne "Edit OS with over lenth string		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $5;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $5;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $8;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************Delete OS normal**************************************" >> /tmp/Result
# Delete OS successful (normal)
echo -ne "Delete OS successful (normal)		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $9;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $9;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $9;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /dev/null
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/os?Name=$OS_TMP&Version=$OS_VER" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete OS fail (normal)
echo -ne "Delete non-existent OS fail (normal)	:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $10;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $10;}' test.data`
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/os?Name=$OS_TMP&Version=$OS_VER" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi
echo -ne "Delete connected OS fail (normal)	:	" >> /tmp/Result
MLE_TMP=mle2test
MLE_VER=v2test
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OsName\":\"$OS_TMP\",\"OsVersion\":\"$OS_VER\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"VMM\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/os?Name=$OS_TMP&Version=$OS_VER" -3 > /tmp/res
	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
		echo "Passed" >> /tmp/Result
	else
	   	echo "Failed" >> /tmp/Result
	fi
else
	echo "Add MLE fail" >> /tmp/Result
fi
echo
echo "******************Delete OS with checking boundary value*****************" >> /tmp/Result
# Delete OS with null string
echo -ne "Delete OS with null string		:	" >> /tmp/Result
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/os?Name=&Version=" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete OS with edge lenth string
echo -ne "Delete OS with edge lenth string	:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $11;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $11;}' test.data`
OS_DESC=`awk -F ":" 'NR==12 {print $11;}' test.data`
INFO=`echo "{\"Name\":\"$OS_TMP\",\"Version\":\"$OS_VER\",\"Description\":\"$OS_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/os" -3 > /dev/null
curl --cacert certfile.cer -H "Content-Type: application/json" -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/os?Name=$OS_TMP&Version=$OS_VER" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************View OS************************************************" >> /tmp/Result
# View OS
echo -ne "View OS					:	" >> /tmp/Result
curl --cacert certfile.cer -H "Content-Type: application/json" -X GET https://$HOST_NAME:$PORT/WLMService/resources/os -3 > /tmp/res
VIEW=`awk -F "\"" '{print $2;}' /tmp/res`

if [ "$VIEW" = "os" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo
echo "#The result about MLE" >> /tmp/Result
echo
echo "******************Add MLE normal******************************************" >> /tmp/Result
# Add MLE successful (VMM)
echo -ne "Add MLE successful (VMM)		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OsName\":\"$OS_TMP\",\"OsVersion\":\"$OS_VER\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"VMM\",\"Description\":\"Test\"}"`
echo $INFO
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "MLE Name $MLE_TMP Version $MLE_VER already exists in the database" /tmp/res;then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Add MLE fail (VMM)
echo -ne "Add existed MLE fail (VMM)		:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==7 {print $2;}' test.data`
MLE_VER=`awk -F ":" 'NR==8 {print $2;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OsName\":\"$OS_TMP\",\"OsVersion\":\"$OS_VER\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"VMM\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
	        echo "Passed" >> /tmp/Result
	else
	        echo "Failed" >> /tmp/Result
	fi
else
	echo "Passed" >> /tmp/Result
fi
# Add MLE successful (BIOS)
echo -ne "Add MLE successful (BIOS)		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "MLE Name $MLE_TMP Version $MLE_VER already exists in the database" /tmp/res;then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Add MLE fail (BIOS)
echo -ne "Add existed MLE fail (BIOS)		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $2;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $2;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
	        echo "Passed" >> /tmp/Result
	else
	        echo "Failed" >> /tmp/Result
	fi
else
        echo "Passed" >> /tmp/Result
fi

# Add MLE fail when wrong mle 
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE1_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE2_TMP=`awk -F ":" 'NR==6 {print $1;}' test.data`
MLE1_VER=`awk -F ":" 'NR==7 {print $2;}' test.data`
MLE2_VER=`awk -F ":" 'NR==8 {print $2;}' test.data`
INFO1=`echo "{\"Name\":\"$MLE2_TMP\",\"Version\":\"$MLE2_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"ODA\",\"Description\":\"Test\"}"`
INFO2=`echo "{\"Name\":\"$MLE1_TMP\",\"Version\":\"$MLE1_VER\",\"OsName\":\"$OS_TMP\",\"OsVersion\":\"$OS_VER\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"ODA\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO1 "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO2 "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/rest
echo -ne "Add MLE fail (type is not BIOS)	:	" >> /tmp/Result

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
	echo "Passed" >> /tmp/Result
else 
	echo "Failed" >> /tmp/Result
fi

echo -ne "Add MLE fail (type is not VMM)	:	" >> /tmp/Result

if [ "`awk '$1 ~/True/' /tmp/rest`" != "True" ];then
	echo "Passed" >> /tmp/Result
else
	echo "Failed" >> /tmp/Result
fi

# Add MLE fail with non-existed OEM/OS
INFO1=`echo "{\"Name\":\"$MLE2_TMP\",\"Version\":\"$MLE2_VER\",\"OemName\":\"nexted1\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"ODA\",\"Description\":\"Test\"}"`
INFO2=`echo "{\"Name\":\"$MLE1_TMP\",\"Version\":\"$MLE1_VER\",\"OsName\":\"nexted2\",\"OsVersion\":\"$OS_VER\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"ODA\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO1 "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO2 "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/rest
echo -ne "Add MLE fail with non-existed OEM	:	" >> tmp/Result

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
	echo "Passed" >> /tmp/Result
else
	echo "Failed" >> /tmp/Result
fi

echo -ne "Add MLE fail with non-existed OS	:	" >> /tmp/Result

if [ "`awk '$1 ~/True/' /tmp/rest`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Add MLE with PCR
echo -ne "Add MLE with PCR			:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $5;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $5;}' test.data`
PCR_N=`awk -F ":" 'NR==9 {print $1;}' test.data`
PCR_D=`awk -F ":" 'NR==10 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\",\"MLE_Manifests\":[{\"Name\":\"$PCR_N\",\"Value\":\"$PCR_D\"}]}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "*******************Add MLE with checking boundary value*************************" >> /tmp/Result
# Add MLE with checking boundary value
echo -ne "Add MLE with null string		:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"\",\"Version\":\"\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo -ne "Add MLE with edge lenth string	:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $3;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $3;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "MLE Name $MLE_TMP Version $MLE_VER already exists in the database" /tmp/res;then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo -ne "Add MLE with over lenth string	:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $4;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $4;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "*******************Edit MLE (Normal)********************************************"	>> /tmp/Result
# Edit MLE successful (Normal)
echo -ne "Edit MLE successful (normal)		:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $5;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $5;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /dev/null
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Update\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/resx

if [ "`awk '$1 ~/True/' /tmp/resx`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo -ne "Edit MLE fail (normal)		:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $6;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $6;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "*******************Edit MLE with checking boundary value***********************" >> /tmp/Result
# Edit existed MLE with null string
echo -ne "Edit MLE with null string		:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $5;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $5;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Edit existed MLE with edge string
echo -ne "Edit MLE with edge lenth string	:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $5;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $5;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_DESC=`awk -F ":" 'NR==12 {print $7;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"$MLE_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Edit existed MLE with over string
echo -ne "Edit MLE with over lenth string	:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $5;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $5;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_DESC=`awk -F ":" 'NR==12 {print $8;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"$MLE_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo "******************Delete MLE Normal**********************************************" >> /tmp/Result
# Delete existent MLE successful
echo -ne "Delete existent MLE successful	:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $9;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $9;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"$MLE_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/WLMService/resources/mles?mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP"  -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete non-existent MLE fail
echo -ne "Delete non-existent MLE fail		:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $10;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $10;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/WLMService/resources/mles?mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP"  -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete MLE with connected to PCR
echo -ne "Delete MLE with connected to PCR	:	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $5;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $5;}' test.data`
PCR_N=`awk -F ":" 'NR==9 {print $1;}' test.data`
PCR_D=`awk -F ":" 'NR==10 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\",\"MLE_Manifests\":[{\"Name\":\"$PCR_N\",\"Value\":\"$PCR_D\"}]}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/WLMService/resources/mles?mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP"  -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete MLE with connected to HOST
echo -ne "Delete MLE with connected to HOST	:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $2;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $2;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $2;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $2;}' test.data`
INFO=`echo "{\"HostName\":\"histest\",\"IPAddress\":\"192.168.0.1\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /dev/null
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/WLMService/resources/mles?mleName=$BIOS_TMP&mleVersion=$BIOS_VER&oemName=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "*****************Delete MLE with checking boundary value********************" >> /tmp/Result
# Delete existed MLE with null string
echo -ne "Delete existed MLE with null string	:	" >> /tmp/Result
curl --cacert certfile.cer -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/mles?mleName=&mleVersion=&oemName=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Delete existed MLE with edge lenth string
echo -ne "Delete MLE with edge lenth string	:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $11;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $11;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"$MLE_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /dev/null
curl --cacert certfile.cer -X DELETE "https://$HOST_NAME:$PORT/WLMService/resources/mles?mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "******************View/Search MLE********************************************" >> /tmp/Result
# View MLE (BIOS)
echo -ne "View MLE (BIOS)			:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
curl --cacert ./certfile.cer -H "Content-Type: application/json" -X GET "https://$HOST_NAME:$PORT/WLMService/resources/mles/manifest?mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP" -3 > /tmp/res
VIEW=`awk -F "\"" '{print $2;}' /tmp/res`

if [ "$VIEW" = "Attestation_Type" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# View MLE (VMM)
echo -ne "View MLE (VMM)			:	" >> /tmp/Result
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
curl --cacert ./certfile.cer -H "Content-Type: application/json" -X GET "https://$HOST_NAME:$PORT/WLMService/resources/mles/manifest?mleName=$MLE_TMP&mleVersion=$MLE_VER&osName=$OS_TMP&osVersion=$OS_VER" -3 > /tmp/res
VIEW=`awk -F "\"" '{print $2;}' /tmp/res`

if [ "$VIEW" = "Attestation_Type" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

# Search MLE
echo -ne "Search MLE (normal)			:	" >> /tmp/Result
curl --cacert ./certfile.cer -H "Content-Type: application/json"-X GET "https://$HOST_NAME:$PORT/WLMService/resources/mles?searchCriteria=mle" -3 > /tmp/res
VIEW=`awk -F "\"" '{print $2;}' /tmp/res`

if [ "$VIEW" = "mleBean" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo
echo "#The result about PCR_WHITE_LIST" >> /tmp/Result
# Add a PCR successful
echo
echo "******************Add PCR normal********************************************" >> /tmp/Result
echo -ne "Add a PCR successful (normal)		:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $1;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "PCR $PCR_NUM exists in the database" /tmp/res;then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Add a PCR fail which exists
echo -ne "Add a PCR fail which exists		:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $2;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
	        echo -e "Passed " >> /tmp/Result
	else
	      	echo -e "Failed " >> /tmp/Result
	fi
else
	echo "Passed" >> /tmp/Result
fi
# Add a PCR fail with non-exist MLE
echo -ne "Add a PCR fail with non-exist MLE	:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $9;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $9;}' test.data`
PCR_NUM=`awk -F ":" 'NR==9 {print $1;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $9;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "*******************Add PCR with checking boundary value**********************" >> /tmp/Result
# Add PCR with null string
echo -ne "Add PCR with null string		:	" >> /tmp/Result
PCR_VALUE=`awk -F ":" 'NR==10 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Add PCR with edge lenth string
echo -ne "Add PCR with edge lenth string	:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $3;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $3;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Add PCR with over lenth string
echo -ne "Add PCR with over lenth string	:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $4;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $4;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "******************Update PCR Normal****************************************" >> /tmp/Result
# Update existent PCR successful
echo -ne "Update existent PCR successful	:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $5;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /dev/null
PCR_VALUE=`awk -F ":" 'NR==10 {print $5;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Update nonexistent PCR fail
echo -ne "Update nonexistent PCR fail		:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $6;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"osName\":\"$OS_TMP\",\"osVersion\":\"$OS_VER\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Update all PCR which connect to one MLE record
echo -ne "Update all PCR			 :	" >> /tmp/Result
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
PCR_N1=`awk -F ":" 'NR==9 {print $1;}' test.data`
PCR_D1=`awk -F ":" 'NR==10 {print $1;}' test.data`
PCR_N2=`awk -F ":" 'NR==9 {print $2;}' test.data`
PCR_D2=`awk -F ":" 'NR==10 {print $2;}' test.data`
INFO=`echo "{\"Name\":\"$MLE_TMP\",\"Version\":\"$MLE_VER\",\"OemName\":\"$OEM_TMP\",\"Attestation_Type\":\"PCR\",\"MLE_Type\":\"BIOS\",\"Description\":\"Test\",\"MLE_Manifests\":[{\"Name\":\"$PCR_N1\",\"Value\":\"$PCR_D1\"},{\"Name\":\"$PCR_N2\",\"Value\":\"$PCR_D2\"}]}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo "Passed" >> /tmp/Result
else
        echo "Failed" >> /tmp/Result
fi

echo
echo "********************Update PCR with checking boundary value******************************" >> /tmp/Result
# Update PCR with null string
echo -ne "Update PCR with null string		:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $5;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $12;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Update PCR with over lenth string
echo -ne "Update PCR with over lenth string	:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $5;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $8;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "**********************Delete PCR Normal************************************************" >> /tmp/Result
# Delete PCR successful
echo -ne "Delete PCR successful			:	" >> /tmp/Result
PCR_NUM=`awk -F ":" 'NR==9 {print $9;}' test.data`
PCR_VALUE=`awk -F ":" 'NR==10 {print $9;}' test.data`
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
INFO=`echo "{\"pcrName\":\"$PCR_NUM\",\"pcrDigest\":\"$PCR_VALUE\",\"mleName\":\"$MLE_TMP\",\"mleVersion\":\"$MLE_VER\",\"oemName\":\"$OEM_TMP\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr" -3 > /tmp/res
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr?pcrName=$PCR_NUM&mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Delete PCR fail
echo -ne "Delete PCR fail			:	" >> /tmp/Result
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr?pcrName=$PCR_NUM&mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "**********************Delete PCR with checking boundary value***************************" >> /tmp/Result
# Delete PCR with null string
echo -ne "Delete PCR with null string		:	" >> /tmp/Result
MLE_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
MLE_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/WLMService/resources/mles/whitelist/pcr?pcrName=&mleName=$MLE_TMP&mleVersion=$MLE_VER&oemName=$OEM_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "#The result about HOST" >> /tmp/Result
echo
echo "***********************Add Host Normal***************************************************" >> /tmp/Result
# Add Host successful
echo -ne "Add Host successful			:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $1;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.1\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "HOST $HOST_TMP already exists in the database" /tmp/res;then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Add Host fail (noraml)
echo -ne "Add Host fail (normal)		:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $2;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.1\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res
if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
	curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

	if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
	        echo -e "Passed " >> /tmp/Result
	else
	        echo -e "Failed " >> /tmp/Result
	fi
else
	echo "Passed" >> /tmp/Result
fi

# Add Host with nonexistent MLE
echo -ne "Add Host with nonexistent MLE		:	" >> /tmp/Result
BIOS_TMP=`awk -F ":" 'NR==5 {print $9;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $9;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $9;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $9;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.1\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "*********************Add Host with checking boundary value*****************************" >> /tmp/Result
# Add Host with null string
echo -ne "Add Host with null string		:	" >> /tmp/Result
INFO=`echo "{\"HostName\":\"\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Add Host with edgelenth string
echo -ne "Add Host with edgelenth string	:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $3;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ] || grep -q "HOST $HOST_TMP already exists in the database" /tmp/res;then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Add Host with over lenth string
echo -ne "Add Host with over lenth string	:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $4;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "********************Edit Host Normal*************************************************" >> /tmp/Result
# Edit Host successful
echo -ne "Edit Host successful			:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $5;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
HOST_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"$HOST_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res
HOST_DESC=`awk -F ":" 'NR==12 {print $5;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"$HOST_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Edit Host fail
echo -ne "Edit Host fail			:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $6;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
HOST_DESC=`awk -F ":" 'NR==12 {print $1;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"$HOST_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo
echo "*********************Edit Host with checking boundary value******************************" >> /tmp/Result
# Edit HOST with null string
echo -ne "Edit HOST with null string		:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $5;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"\"}"`
curl --cacert certfile.cer -H "Content-type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

#Edit existed HOST with edge string
echo -ne "Edit existed HOST with edge string	:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $5;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
HOST_DESC=`awk -F ":" 'NR==12 {print $7;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"$HOST_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Edit HOST with overlenth string
echo -ne "Edit HOST with overlenth string	:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $5;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
HOST_DESC=`awk -F ":" 'NR==12 {print $8;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"$HOST_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X PUT -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo 
echo "********************Delete Host Normal*****************************************" >> /tmp/Result
# Delete Host successful
echo -ne "Delete Host successful		:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $9;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
HOST_DESC=`awk -F ":" 'NR==12 {print $7;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"$HOST_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /dev/null
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/AttestationService/resources/hosts?hostName=$HOST_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Delete Host fail
echo -ne "Delete Host fail 			:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $10;}' test.data`
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/AttestationService/resources/hosts?hostName=$HOST_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

echo 
echo "********************Delete HOST with checking boundary value********************" >> /tmp/Result
# Delete HOST with null string
echo -ne "Delete HOST with null string		:	" >> /tmp/Result
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/AttestationService/resources/hosts?hostName=" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" != "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

# Delete HOST with edge lenth string
echo -ne "Delete HOST with edge lenth string	:	" >> /tmp/Result
HOST_TMP=`awk -F ":" 'NR==11 {print $11;}' test.data`
OS_TMP=`awk -F ":" 'NR==3 {print $1;}' test.data`
OS_VER=`awk -F ":" 'NR==4 {print $1;}' test.data`
VMM_TMP=`awk -F ":" 'NR==7 {print $1;}' test.data`
VMM_VER=`awk -F ":" 'NR==8 {print $1;}' test.data`
OEM_TMP=`awk -F ":" 'NR==2 {print $1;}' test.data`
BIOS_TMP=`awk -F ":" 'NR==5 {print $1;}' test.data`
BIOS_VER=`awk -F ":" 'NR==6 {print $1;}' test.data`
HOST_DESC=`awk -F ":" 'NR==12 {print $7;}' test.data`
INFO=`echo "{\"HostName\":\"$HOST_TMP\",\"IPAddress\":\"192.168.0.2\",\"Port\":\"8080\",\"BIOS_Name\":\"$BIOS_TMP\",\"BIOS_Version\":\"$BIOS_VER\",\"BIOS_Oem\":\"$OEM_TMP\",\"VMM_Name\":\"$VMM_TMP\",\"VMM_Version\":\"$VMM_VER\",\"VMM_OSName\":\"$OS_TMP\",\"VMM_OSVersion\":\"$OS_VER\",\"Email\":\"\",\"AddOn_Connection_String\":\"\",\"Description\":\"$HOST_DESC\"}"`
curl --cacert certfile.cer -H "Content-Type: application/json" -X POST -d $INFO "https://$HOST_NAME:$PORT/AttestationService/resources/hosts" -3 > /dev/null
curl --cacert certfile.cer -X DELETE  "https://$HOST_NAME:$PORT/AttestationService/resources/hosts?hostName=$HOST_TMP" -3 > /tmp/res

if [ "`awk '$1 ~/True/' /tmp/res`" = "True" ];then
        echo -e "Passed " >> /tmp/Result
else
        echo -e "Failed " >> /tmp/Result
fi

