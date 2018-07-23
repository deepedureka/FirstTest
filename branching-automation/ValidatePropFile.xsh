# Check Out the properties file in repository
svn export svn://xisdev.xchanging.com/project/branching-automation/prop.xml 2> Error.txt
if [ -s Error.txt ]
then
		echo "Export Error for properties file"
		exit
else
		echo "Properties file exported successfully"
fi

xvalidate -xsd automation.xsd prop.xml 2> Error.txt
if [ -s Error.txt ]
then
		echo "Validation Error in properties file"
		cat Error.txt
		exit
else
		echo "Properties file validated successfully"
fi

