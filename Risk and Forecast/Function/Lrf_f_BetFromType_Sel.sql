/*<info serverAlias="DBEXT-bodb02" selecters="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[Lrf_f_BetFromType_Sel]
(
	@PlatformType	TINYINT = 0
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
*/

RETURNS TABLE
RETURN
	SELECT PlatformType, betfrom
	FROM (
		VALUES	(1, 'd'),
				(2, 'a'),
				(3, 'e'),
				(4, 'm'),
				(3, 'u'),
				(5, 'l'),
				(5, '_'),
				(1, 'g'),
				(6, 'r'),
				(7, 'x'),
				(2, 'z'),
				(8, 'o'),
				(9, 'c'),
				(9, '@'),
				(10, 't'),
				(11, '0'),
				(12, '1'),
				(13, '2'),
				(14, '3'),
				(88, 'v'),
				(12, '4'),
				(13, '5'),
				(14, '6'),
				(15, '%'),
				(88, '7')
	) d(PlatformType, betfrom)
	WHERE @PlatformType = 0 OR d.PlatformType = @PlatformType
GO