# qs-odbc-udc-util

### An alternative solution for Global Active Directory Synchronization with Qlik Sense

---
## Problem
Qlik Sense supports multiple active directory  (AD) connections by allowing a user directory connector (udc) to be created for each domain in an AD forest.  Unfortunately, multiple AD forests tend to have universal groups, and these groups do not import for the users who are not part of the same domain as the group.

>For example: 

>A user from domain **b** is a member of a universal group in domain **a**.  When a udc for domain **a** is created in Qlik Sense, the domain **a** users and the universal groups created in domain **a** are imported to the Qlik Sense Repository.

>Another udc is created for domain **b**.  Domain **b** users and the groups for which they are members of in domain **b** are imported.  The groups for which they are members of in domain **a** are **NOT** imported into the Qlik Sense Repository.

As a result, universal groups do not show up for all the appropriate members of the universal group if their domain is different than the group's origin domain.

## Solution
The qs-odbc-udc-util tool (so needs a better name) is a set of Windows Powershell modules and a script.  It reaches into Active Directory LDAPs, parses groups, and creates the appropriate user and attribute files (in csv format) for each domain in an Active Directory forest.  The resulting user and attribute csv files can be used to establish ODBC user directory connectors in the Qlik Sense QMC.

## Configuration
The qs-odbc-udc-util uses an xml file named settings.xml to provide configuration information to the powershell script that performs the work.  The settings file needs to be completed before running the script.

### XML File Structure
```xml
<Settings>
<!--If Qlik Sense service account is a domain account, add it here so it will be included in the user csv file. -->
  <ServiceAccounts>
        <Account>
            <UserId>UserId</UserId>
            <DisplayName>DisplayName</DisplayName>
        </Account>
  </ServiceAccounts>
  <ServiceAccountDomain>DomainName</ServiceAccountDomain>
<!--If no LDAP attributes are used, enter path to csv file with data to map attributes to users-->
	<Files>
<!--		<AttributeData></AttributeData>
-->
	</Files>
<!--path to output directory for user and attribute csv files-->	
	<Directories>
		<Output>c:/path/to/output/files</Output>
	</Directories>
	<LDAP>
		<Servers>
			<Server>
				<Name>domainName</Name>
				<LDAP>LDAP://example.com</LDAP>
				<Paths>
					<Path>ou=groups,dc=example,dc=com</Path>
					<Path>ou=otherGroups,dc=example,dc=com</Path>
				</Paths>
<!--If a different account than the current logged in user OR the process will be run not logged in, enter domain\userid and password for account to access ldap -->
<!--				<Security>
					<UserId>user</UserId>
					<Password>password</Password>
				</Security>
-->
				<Groups>
					<Group type="inline">InlineGroup1</Group>
					<Group type="inline">InlineGroup2</Group>
					<Group type="file">path to csv file with list of groups</Group>
				</Groups>
			</Server>
<!--If multiple servers have universal groups required for Qlik Sense, add additional server entries using the following elements -->	
<!--			<Server>
				<Name></Name>
				<Paths></Paths>
				<Security></Security>
				<Groups></Groups>
			</Server>
-->
		</Servers>
	</LDAP>
	<Domains>
		<Domain>
			<Name>DomainOne</Name>
			<LDAP>http://domainone.example.com</LDAP>
			<Paths>
                		<Path>OU=buried_group,OU=in_an_OU,DC=domainone,DC=example,DC=com</Path>
                		<Path>OU=another_buried_group,OU=in_an_OU,DC=domainone,DC=example,DC=com</Path>
            		</Paths>
<!--Only used when AttributeData file is NOT supplied, enter the attributes to pull from the ldap for addition to the attribute csv-->
			<Attributes>
				<Attribute>memberof</Attribute>
				<Attribute>mail</Attribute>
			</Attributes>
		</Domain>
		<Domain>
			<Name>DomainTwo</Name>
			<LDAP>http://domaintwo.example.com</LDAP>
			<Paths>
				<Path>OU=buried_group,OU=in_an_OU,DC=domaintwo,DC=example,DC=com</Path>
				<Path>OU=another_buried_group,OU=in_an_OU,DC=domaintwo,DC=example,DC=com</Path>
			</Paths>
<!--Only used when AttributeData file is NOT supplied, enter the attributes to pull from the ldap for addition to the attribute csv-->
			<Attributes>
				<Attribute>memberof</Attribute>
				<Attribute>mail</Attribute>
			</Attributes>
		</Domain>
	</Domains>		
</Settings>
```
### Interpreting the XML File
The Settings.xml file contains the following sections:

#### ServiceAccounts
The ServiceAccounts section allows for manually entered accounts into the users csv file.  The ServiceAccountDomain element contains the friendly name of the domain these users will be added to.

#### ServiceAccount (default:disabled)
When a domain account is used for the service account for running Qlik Sense, by default it is the rootadmin of the Qlik Sense Site.  If the account is not included in the udc for the userdirectory name, it will be denied access.  This element ensures the account is included. 

#### Files
The Files section is used when an external file containing attributes is mapped to users from the LDAP.  The case for this may be when an LDAP is not the source of record for user attributes.  If an external file is referenced, use the `AttributeDataFile` element tag and supply the path and name of the file.

##### Requirements
* Use the AttributeDataFile Element
* Specify full path to file **e.g.** c:/docs/info.csv
* File in csv format

##### AttributeDataFile file structure

UserId | Type | Value
-------|------|------
abc123 |email | abc123@example.com
abc123 |role  | developer

#### Directories
The Directories section specifies the output path for files created by the script.  Currently, only one output path is supported.
##### Requirements
* Use the Output Element for the output path
* Specify full path to file **e.g.** c:/output
* File in csv format 

#### LDAP
The LDAP section contains a number of settings for connecting and traversing LDAPs for user information.  LDAP connections are referenced in Server elements.  Each Server element refers to a specific LDAP where the script will perform the extraction and parsing of users into user and attribute csvs.

Server elements may contain the following information:
* **`<Name>`** - The element (required) containing the friendly domain name for the server.
* **`<LDAP>`** - The element (required) containing the LDAP server connection.  `LDAP://example.com`
* **`<Paths><Path>`** - Path elements (required) contain the starting point for the LDAP to connection.  This is a good option to supply multiple organizational units that contain groups.  The tool will loop through each path and connect to the LDAP to begin searching for groups.
* **`<Security>`** - The Security element (optional) stores user and password information for an LDAP connection.  If omitted, the user context the script is run will be used to connect to the LDAP.
* **`<Groups><Group`** `type="inline||file"`**`>`** - The Group element identifies universal groups to search for users.  An inline attribute indicates a group provided in the settings file.  A file attribute indicates a csv file containing group names is used.  When using the file attribute the full path to the csv file containing group names is required. 

#### Domains
The Domains section facilitates two functions; adding users that are not part of the local groups scoped in the Server section, and adding attributes to the users found in local groups scoped in the Server section.

Domain elements contain the following information:
* **`<Name>`** - The friendly name of domain to be searched.
* **`<LDAP>`** - The address for the LDAP
* **`<Paths><Path>`** - LDAP paths to search for users
* **`<Attributes><Attribute>`** - Used when an AttributeDataFile is NOT supplied, identify the attributes to be pulled from the LDAP and added to the attributes csv file.

## Usage

**Note: Domains to be run on must exist in the Domains section of the settings file.

From a Powershell shell, enter .\MainGenerator.ps1 domainName (e.g. .\MainGenerator americas).
To run for multiple domains, edit the runall.ps1 file and use the sample line in the file as a reference.
