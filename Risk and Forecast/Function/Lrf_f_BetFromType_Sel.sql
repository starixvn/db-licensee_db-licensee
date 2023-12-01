/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBSID-bodb02" selecters="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[Lrf_f_BetFromType_Sel]
(
	@PlatformTypeList	VARCHAR(100) = 'All'
)

/*
	Create: 20191226 
	Description: Get BetFrom Type
	DB: DBEXT.bodb02

	Revisions:
		- 20191226@Vickie: Get BetFrom by PlatformType [Redmine: #125824]
		- 20200228@Vickie: Integrate 3 new betfrom [Redmine: #129253]
		- 20200622@Hogan: Integrate 3 new betfrom 4, 5, 6 [Redmine: #136107]
		- 20210120@Mark: Integrate new betfrom 7 [Redmine: #149108]
		- 20210305@Mark: Integrate new betfrom _, @, %(Mobile Euro) [Redmine: #151019]
		- 20210412@Mark: Support Add New Betfrom 8 9 [RedmineID: #152158]
		- 20210518@Mark: Support multiple selection on Platform filter [Redmine: #153102]
		- 20210527@Hogan: Support Add 2 New Betfroms # $ [RedmineID: #155922]
		- 20211014@Kos: Support add 2 New Betfroms [ and ] [RedmineID: #162388]
		- 20211231@Hogan: Using betfrom '.' instead of betfrom '#' [RedmineID: #166689]
		- 20220708@Hogan: Support add new betfrom '}' [RedmineID: #174895]
		- 20220801@Victoria: Add DBSID-bodb02 to metadata [Redmine: #175297]
		- 20230602@Evan: Support add new betfrom '#'&'A000' [Redmine: #188811]
		- 20230811@Evan: Support add new betfrom W001, W002 & adjust A000 [Redmine: #191840]
		- 20231030@Evan: Support Revert betfrom % & W002 [Redmine: #196175]
		- 20231103@Evan: Support add new betfrom A001,A002 [Redmine: #196463]
		- 20231122@Evan: Handle betfrom for Jollysports [Redmine: #197192]	
	

	Param's Explanation:
			+ @PlatformType: List of platform type (ex: 1,2,3,..)
				All: All
				-- Normal site
				1: Desktop New Asia
				2: Desktop China
				3: Desktop Others
				4: Mobile Standard
				5: Mobile Euro
				6: Mobile Compact
				7: Mobile Others
				8: E-Sports Desktop	
				9: E-Sports Mobile
				10: E-Sports APP
				11: Mobile APP
				12: Native APP
				13: Tablet
				14: Deep Link
				15: WAP
				16: Chat Room
				17: Desktop Galaxy
				18: Mobile Galaxy
				88: Others
				-- Jollysports
				91: Desktop
				92: Mobile
				99: Others

*/

RETURNS TABLE
RETURN
	SELECT PlatformType, betfrom, d.SpecialPlatform
	FROM (
		VALUES	
				-- Normal licensees
				(1, 'x',0),
				(2, 'a',0),
				(2, 'z',0),
				(2, '[',0),
				(3, '9',0),
				(3, '>',0),
				(4, 'l',0),
				(4, ']',0),
				(5, '%',0),
				(6, 'c',0),
				(6, '@',0),
				(7, '7',0),
				(7, '8',0),
				(7, '_',0),
				(7, '.',0),
				(7, '$',0),
				(7, '}',0),
				(7, '#',0),
				(8, '1',0),
				(8, '4',0),
				(9, '2',0),
				(9, '5',0),
				(10, '3',0),
				(10, '6',0),
				(11, 'o',0),
				(11, '~',0),
				(12, '0',0),
				(13, 'r',0),
				(14, 't',0),
				(15, 'm',0),
				(16, 'A000',0),
				(17, 'W001',0), 
				(18, 'W002',0),
				(88, 'v',0),
				(88, 'd',0),
				(88, 'g',0),
				(88, 'e',0),
				(88, 'u',0),
				(88, '^',0),
				(88, 'A001',0),
				(88, 'A002',0),

				-- Jollysports licensee
				(99, 'x',2),
				(99, 'a',2),
				(99, 'z',2),
				(99, '[',2),
				(99, '9',2),
				(99, '>',2),
				(99, 'l',2),
				(99, ']',2),
				(99, '%',2),
				(99, 'c',2),
				(99, '@',2),
				(99, '7',2),
				(99, '8',2),
				(99, '_',2),
				(99, '.',2),
				(99, '$',2),
				(99, '}',2),
				(99, '#',2),
				(99, '1',2),
				(99, '4',2),
				(99, '2',2),
				(99, '5',2),
				(99, '3',2),
				(99, '6',2),
				(99, 'o',2),
				(99, '~',2),
				(99, '0',2),
				(99, 'r',2),
				(99, 't',2),
				(99, 'm',2),
				(99, 'A000',2),
				(99, 'W001',2), 
				(99, 'W002',2),
				(99, 'v',2),
				(99, 'd',2),
				(99, 'g',2),
				(99, 'e',2),
				(99, 'u',2),
				(99, '^',2),
				(91, 'A001',2),
				(92, 'A002',2)
	) d(PlatformType, betfrom, SpecialPlatform)
	WHERE @PlatformTypeList = 'All' OR (',' + @PlatformTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(3), d.PlatformType) + ',%')
GO