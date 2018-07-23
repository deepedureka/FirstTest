#!/bin/xmlsh

PROP_XML=prop.xml
SubjectDate=`date +"%d/%m/%Y"`

# Check Out the properties file in repository
svn export svn://xisdev.xchanging.com/project/branching-automation/prop.xml 2> Error.txt
if [ -s Error.txt ]
then
		echo "Export Error for properties file"
		cat Error.txt
		rm Error.txt
		exit
else
		echo "Properties file exported successfully"
fi
	
xvalidate -xsd automation.xsd $PROP_XML 2> Error.txt
if [ -s Error.txt ]
then
		echo "Validation Error in properties file"
		ERROR=0
		MAIL_TO="XTSI-XIS-ITC-RCM@xchanging.com"
		SUBJECT_ERROR="Properties File Validation Error - $SubjectDate"
		BODY="Error Validating Properties file. PFA the Error Log."
		java -jar Email.jar $MAIL_TO " " $SUBJECT_ERROR $BODY $ERROR
		rm Error.txt
		exit
else
		echo "Properties file validated successfully"
fi

ERROR=0
NO_ERROR=1
SUBJECT_ERROR="Branching Automation Alert!! - $SubjectDate"
SUBJECT_NOERROR="Branching Automation Done - $SubjectDate"
FLAG=0

# Parsing XML file

MAIL_CC=(`xcat $PROP_XML | xquery '//project/@mailCC/string()'`)

mailTo=(`xcat $PROP_XML | xquery '//project/target/@mailTo/string()'`)

repos=(`xcat $PROP_XML | xquery '//project/target/@repos/string()'`)

branch=(`xcat $PROP_XML | xquery '//project/target/@branch/string()'`)

sourceBranch=(`xcat $PROP_XML | xquery '//project/target/source/@branch/string()'`)

sourceBranchRevision=(`xcat $PROP_XML | xquery '//project/target/source/@revision/string()'`)

# Initialise count to zero
component_count=1

echo "Repo name is : $repos"
    
TOTAL_COMPONENTS=${#repos}
echo  $TOTAL_COMPONENTS

# while count is less than MAX components
while [ $component_count -le $TOTAL_COMPONENTS ]                 
do
	FLAG=0
	echo "${repos[$component_count]}" | grep "svn://xisdev.xchanging.com/project/new" 
	
	if [ $? -eq 0 ]
	then
		BASE_BRANCH=${repos[$component_count]}/${sourceBranch[$component_count]}
	
		LOCAL_FOLDER=`echo ${branch[$component_count]} | cut -d/ -f2`
	
		ENV_BRANCH=${repos[$component_count]}/${branch[$component_count]}
    
		SOURCE_BRANCHREVISION=${sourceBranchRevision[$component_count]}
	
		MAIL_TO=${mailTo[$component_count]}
	
		BACKUP="_backup"
	
		ENV_BRANCH_RENAME=${ENV_BRANCH}${BACKUP}
	else
		BASE_BRANCH=${repos[$component_count]}${sourceBranch[$component_count]}
	
		LOCAL_FOLDER=`echo ${branch[$component_count]} | cut -d/ -f2`
	
		ENV_BRANCH=${repos[$component_count]}${branch[$component_count]}
    
		SOURCE_BRANCHREVISION=${sourceBranchRevision[$component_count]}
	
		MAIL_TO=${mailTo[$component_count]}
	
		BACKUP="_backup"
	
		ENV_BRANCH_RENAME=${ENV_BRANCH}${BACKUP}
	fi
	
	# Execute the Rename Command
	svn -m "[SIR 137730 - PRN saxenam] Renamed folder as backup folder" mv $ENV_BRANCH $ENV_BRANCH_RENAME
	
	# Execute the Copy Command
    svn cp -r $SOURCE_BRANCHREVISION -m "[SIR 137730 - PRN saxenam] Created from ${sourceBranch[$component_count]} at revision $SOURCE_BRANCHREVISION" $BASE_BRANCH $ENV_BRANCH 2> Error.txt
	
	if [ -s Error.txt ]
    then
		echo "Error Copying from Maintenance Branch $BASE_BRANCH revision $SOURCE_BRANCHREVISION to $ENV_BRANCH"
		BODY="Error Copying from Maintenance Branch $BASE_BRANCH revision $SOURCE_BRANCHREVISION to $ENV_BRANCH. PFA the Error Log."
		java -jar Email.jar $MAIL_TO $MAIL_CC $SUBJECT_ERROR $BODY $ERROR
		component_count=`expr ${component_count} + 1`		
		continue
	else
		echo "Copying from branch $BASE_BRANCH to $ENV_BRANCH"
    fi

	# Check Out the dev folder in repository
   	svn co $ENV_BRANCH 2> Error.txt
	
 	if [ -s Error.txt ]
    then
		echo "Error Checking out $ENV_BRANCH"
		BODY="Error Checking out $ENV_BRANCH. PFA the Error Log."
		java -jar Email.jar $MAIL_TO $MAIL_CC $SUBJECT_ERROR $BODY $ERROR
		component_count=`expr ${component_count} + 1`
		continue
	else
			echo "Checked-out $ENV_BRANCH"
	fi

	includeJar=(`xcat $PROP_XML | xquery '//project/target['$component_count']/jar/include/@path/string()'`)
	
	if [ {$includeJar} ]
	then
		jar_count=1
		TOTAL_JARS=${#includeJar}
		
		while [ $jar_count -le $TOTAL_JARS ]
		do 
			JAR_PATH=${includeJar[$jar_count]}
			
			JAR_NAME=`echo $JAR_PATH | cut -d/ -f3`
				
			ABSOLUTE_JAR_PATH=${ENV_BRANCH_RENAME}${JAR_PATH}
				
			echo JAR: $ABSOLUTE_JAR_PATH $JAR_NAME
				
			# Check Out the properties file in repository
			svn export $ABSOLUTE_JAR_PATH 2> Error.txt
			
			if [ -s Error.txt ]
			then
				echo "Export Error for Jar file"
				cat Error.txt
				rm Error.txt
				jar_count=`expr ${jar_count} + 1`
				continue				
			else
				echo "Jar file exported successfully"
			fi
				
			# Increament to next jar
			jar_count=`expr ${jar_count} + 1`	
		done
		
		# Check In the working folder
		svn ci -m "[SIR 137730 - PRN saxenam] Committed $JAR_NAME" $LOCAL_FOLDER 2> Error.txt
			
		if [ -s Error.txt ]
		then
			FLAG=1
			echo "Error Checking-in $JAR_NAME"
			BODY="Error Checking-in $JAR_NAME. PFA the Error Log."
			java -jar Email.jar $MAIL_TO $MAIL_CC $SUBJECT_ERROR $BODY $ERROR
		else
			echo "Checked-in $JAR_NAME"			
		fi
	fi
	
	includeBranch=(`xcat $PROP_XML | xquery '//project/target['$component_count']/source/include/@branch/string()'`)
	
	if [ {$includeBranch} ]
	then 
		includefromRevision=(`xcat $PROP_XML | xquery '//project/target['$component_count']/source/include/@fromRevision/string()'`)		
		includetoRevision=(`xcat $PROP_XML | xquery '//project/target['$component_count']/source/include/@toRevision/string()'`)
		feature_count=1
		TOTAL_FEATURES=${#includeBranch}
		echo $TOTAL_FEATURES
	
		while [ $feature_count -le $TOTAL_FEATURES ]
		do 
			echo "${repos[$component_count]}" | grep "svn://xisdev.xchanging.com/project/new"	
			if [ $? -eq 0 ]
			then
				SOURCE_PATH=${repos[$component_count]}/${includeBranch[$feature_count]}
			else
				SOURCE_PATH=${repos[$component_count]}${includeBranch[$feature_count]}
			fi
			
			# Execute the Merge Command
			svn merge $SOURCE_PATH -r ${includefromRevision[$feature_count]}:${includetoRevision[$feature_count]} $LOCAL_FOLDER 2> Error.txt
			 
			if [ -s Error.txt ]
			then
				FLAG=1
				echo "Error Merging from $SOURCE_PATH revision ${includefromRevision[$feature_count]} to ${includetoRevision[$feature_count]}"
				BODY="Error Merging from $SOURCE_PATH revision ${includefromRevision[$feature_count]} to ${includetoRevision[$feature_count]}. PFA the Error Log."
				java -jar Email.jar $MAIL_TO $MAIL_CC $SUBJECT_ERROR $BODY $ERROR
				feature_count=`expr $feature_count + 1`
				continue 
			else
				echo "Merged from $SOURCE_PATH from revision ${includefromRevision[$feature_count]} to revision ${includetoRevision[$feature_count]}"
			fi
			
			# Check In the working folder
			svn ci -m "[SIR 137730 - PRN saxenam] Merged from ${includeBranch[$feature_count]} revision ${includefromRevision[$feature_count]} to ${includetoRevision[$feature_count]}" $LOCAL_FOLDER 2> Error.txt
			
			if [ -s Error.txt ]
			then
				FLAG=1
				echo "Error Checking-in ${includeBranch[$feature_count]} to $ENV_BRANCH"
				BODY="Error Checking-in ${includeBranch[$feature_count]} to $ENV_BRANCH. PFA the Error Log."
				java -jar Email.jar $MAIL_TO $MAIL_CC $SUBJECT_ERROR $BODY $ERROR
				feature_count=`expr $feature_count + 1`
				continue
			else
				echo "Checked-in ${includeBranch[$feature_count]} to $ENV_BRANCH"			
			fi
			
			# Increament to next feature
			feature_count=`expr $feature_count + 1`
		done		
	fi
	
	rm -rf $LOCAL_FOLDER
	
	if [ $FLAG -eq 0 ]
	then
		BODY="Branching Automation was successfully completed for $ENV_BRANCH."
		java -jar Email.jar $MAIL_TO " " $SUBJECT_NOERROR $BODY $NO_ERROR			
	fi
		
	# Execute the Delete Command	
	svn delete -m "[SIR 137730 - PRN saxenam] Deleted branch $ENV_BRANCH_RENAME" --force $ENV_BRANCH_RENAME 2> Error.txt
	
	if [ -s Error.txt ]
	then
		echo "Delete Error for branch $ENV_BRANCH_RENAME"
		BODY="Delete Error for branch $ENV_BRANCH_RENAME. PFA the Error Log."
		java -jar Email.jar $MAIL_TO $MAIL_CC $SUBJECT_ERROR $BODY $ERROR
		component_count=`expr ${component_count} + 1`
		continue
	else
		echo "Deleted branch $ENV_BRANCH_RENAME"
	fi
	
	# Increament to next component
	component_count=`expr ${component_count} + 1`
	
done
rm Error.txt
echo END