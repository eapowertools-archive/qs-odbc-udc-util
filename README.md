# qs-odbc-udc-util

###An alternative solution for Global Active Directory Synchronization with Qlik Sense

---
##Problem
Qlik Sense supports multiple active directory  (AD) connections by allowing a user directory connector (udc) to be created for each domain in an AD forest.  Unfortunately, multiple AD forests tend to have universal groups, and these groups do not import for the users who are not part of the same domain as the group.

>For example: 

>A user from domain **b** is a member of a universal group in domain **a**.  When a udc for domain **a** is created in Qlik Sense, the domain **a** users and the universal groups created in domain **a** are imported to the Qlik Sense Repository.

>Another udc is created for domain **b**.  Domain **b** users and the groups for which they are members of in domain **b** are imported.  The groups for which they are members of in domain **a** are **NOT** imported into the Qlik Sense Repository.

As a result, universal groups do not show up for all the appropriate members of the universal group if their domain is different than the group's origin domain.

##Solution
The qs-odbc-udc-util tool (so needs a better name) is a Windows Powershell script.  It reaches into Active Directory LDAPs, parses universal groups, and creates the appropriate user and attribute files (in csv format) for each domain in an Active Directory forest.  The resulting user and attribute csv files can be used to establish ODBC user directory connectors in the Qlik Sense QMC.

##Configuration
The qs-odbc-udc-util uses an xml file named settings.xml to provide configuration information to the powershell script that performs the work.

###XML File Structure
```xml
<Settings>
	<Files>
		<HRData>If no LDAP attributes are used, enter path to csv file with data to map attributes to users</HRData>
	</Files>
	<Directories>
		<Output>path to output directory for user and attribute csv files</Output>
	</Directories>
	<LDAP>
		<Servers>
			<Server>
				<Name>LDAP://example.com</Name>
				<Paths>
					<Path>ou=groups,dc=example,dc=com</Path>
					<Path>ou=otherGroups,dc=example,dc=com</Path>
				</Paths>
				<Security>
					<UserId>user</UserId>
					<Password>password</Password>
				</Security>
				<Groups>
					<Group type="inline">InlineGroup1</Group>
					<Group type="inline">InlineGroup2</Group>
					<Group type="file">path to csv file with list of groups</Group>
				</Groups>
			</Server>
		</Servers>
	</LDAP>
	<Domains>
		<Domain>DomainOne</Domain>
		<Domain>DomainTwo</Domain>
		<Domain>DomainThree</Domain>
	</Domains>		
</Settings>
```
###Interpreting the XML File
The Settings.xml file contains the following sections:

####Files
The Files section is used when an external file containing attributes is mapped to users from the LDAP.  The case for this may be when an LDAP is not the source of record for user attributes.  If an external file is referenced, use the `HRData` element tag and supply the path and name of the file.

#####Requirements
* Use the HRData Element
* Specify full path to file **e.g.** c:/docs/info.csv
* File in csv format

#####HRData file structure

UserId | Type | Value
-------|------|------
abc123 |email | abc123@example.com
abc123 |role  | developer

####Directories
The Directories section specifies the output path for files created by the script.  Currently, only one output path is supported.
#####Requirements
* Use the Output Element for the output path
* Specify full path to file **e.g.** c:/output
* File in csv format 

####LDAP
The LDAP section contains a number of settings for connecting and traversing LDAPs for user information.  LDAP connections are referenced in Server elements.  Each Server element refers to a specific LDAP where the script will perform the extraction and parsing of users into user and attribute csvs.

Server elements may contain the following information:
* **`<Name>`** - The Name element (required) containing the LDAP server connection.  `LDAP://example.com`
* **`<Paths><Path>`** - Path elements (required) contain the starting point for the LDAP to connection.  This is a good option to supply multiple organizational units that contain groups.  The tool will loop through each path and connect to the LDAP to begin searching for groups.
* **`<Security>`** - The Security element (optional) stores user and password information for an LDAP connection.  If omitted, the user context the script is run will be used to connect to the LDAP.
* **`<Groups><Group`** `type="inline||file"`**`>`** - The Group element identifies universal groups to search for users.  An inline attribute indicates a group provided in the settings file.  A file attribute indicates a csv file containing group names is used.  When using the file attribute the full path to the csv file containing group names is required. 

####Domains
The Domains section contains the domains to evaluate universal group members origin to properly place them in the correct user and attributes csv file.
