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
		<HRData>If none LDAP data is used, enter path to csv file with data</HRData>
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
				<UGroups>true</UGroups>
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
