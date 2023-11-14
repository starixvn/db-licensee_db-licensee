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
	

	Param's Explanation:
			+ @PlatformType: List of platform type (ex: 1,2,3,..)
				All: All
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
*/

RETURNS TABLE
RETURN
	SELECT PlatformType, betfrom
	FROM (
		VALUES	(1, 'x'),
				(2, 'a'),
				(2, 'z'),
				(2, '['),
				(3, '9'),
				(3, '>'),
				(4, 'l'),
				(4, ']'),
				(5, '%'),
				(6, 'c'),
				(6, '@'),
				(7, '7'),
				(7, '8'),
				(7, '_'),
				(7, '.'),
				(7, '$'),
				(7, '}'),
				(7, '#'),
				(8, '1'),
				(8, '4'),
				(9, '2'),
				(9, '5'),
				(10, '3'),
				(10, '6'),
				(11, 'o'),
				(11, '~'),
				(12, '0'),
				(13, 'r'),
				(14, 't'),
				(15, 'm'),
				(16, 'A000'),
				(17, 'W001'), 
				(18, 'W002'),
				(88, 'v'),
				(88, 'd'),
				(88, 'g'),
				(88, 'e'),
				(88, 'u'),
				(88, '^'),
				(88, 'A001'),
				(88, 'A002')
	) d(PlatformType, betfrom)
	WHERE @PlatformTypeList = 'All' OR (',' + @PlatformTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(3), d.PlatformType) + ',%')
GO
