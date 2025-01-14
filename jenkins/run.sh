#!/bin/sh -e

JENKINS_USER=${JENKINS_ADMIN_LOGIN:-admin};
JENKINS_PASSWORD=${JENKINS_ADMIN_PASSWORD:-admin};
JENKINS_HOST="localhost";
JENKINS_PORT="8080";
JENKINS_API="http://$JENKINS_USER:$JENKINS_PASSWORD@$JENKINS_HOST:$JENKINS_PORT";
JENKINS_CLI=/jenkins-cli.jar
LOCATION_CONFIG="/var/jenkins_home/jenkins.model.JenkinsLocationConfiguration.xml";
JENKINS_URL_CONFIG=${JENKINS_URL_CONFIG:-"http:\\/\\/127.0.0.1:8181\\/"};

bash -x /usr/local/bin/jenkins.sh &

# Download Jenkins cli
cmd="curl -sSL --fail ${JENKINS_API}/jnlpJars/jenkins-cli.jar -o ${JENKINS_CLI}"
while : ; do
    $cmd
    [[ $? -eq 0 ]] && break
	sleep 5;
done

java -jar ${JENKINS_CLI} -s $JENKINS_API version

echo "Trying to import jobs to jenkins"

# create jenkins job if not exists or update otherwise
for job in `ls -1 /jobs/*.xml`; do
	JOB_NAME=$(basename ${job} .xml)
	java -jar ${JENKINS_CLI} -s $JENKINS_API list-jobs | grep -qw $JOB_NAME
	if [ $? -eq 0 ]; then
		echo "$JOB_NAME exists, updating..."
		cat ${job} | java -jar ${JENKINS_CLI} -s $JENKINS_API update-job ${JOB_NAME}
	elif [ $? -eq 1 ]; then
		echo "${job} is not exists. Creating..."
		java -jar ${JENKINS_CLI} -s $JENKINS_API create-job $JOB_NAME < ${job}
		if [ $? -eq 0 ]; then
			echo "Job $JOB_NAME successfuly added"
		else
			echo "Job $JOB_NAME was not imported: error code $?"
		fi
	fi
done

# echo "Trying to change Jenkins Url"

# if ! grep "<jenkinsUrl>$JENKINS_URL_CONFIG</jenkinsUrl>" $LOCATION_CONFIG; then 
# 	sed -i "s/<jenkinsUrl>.*</<jenkinsUrl>$JENKINS_URL_CONFIG</g" $LOCATION_CONFIG;
# 		echo "jenkins_url was changed to $JENKINS_URL_CONFIG";
# 	else echo "jenkins_url is $JENKINS_URL_CONFIG";
# fi

echo "Move security.groovy to init.groovy.d/"
cp /usr/share/jenkins/ref/init.groovy.d/security.groovy /var/jenkins_home/init.groovy.d/security.groovy

echo "configure-markup-formatter.groovy to init.groovy.d/"
cp /usr/share/jenkins/ref/init.groovy.d/configure-markup-formatter.groovy /var/jenkins_home/init.groovy.d/configure-markup-formatter.groovy

echo "Restarting Jenkins"

java -jar ${JENKINS_CLI} -s $JENKINS_API restart
wait $!
