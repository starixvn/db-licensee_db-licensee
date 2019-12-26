/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/
CREATE FUNCTION [dbo].[f_PlatformWinLoss_BetFromType_Sel]
(
	@PlatformType	TINYINT = 0
)
/*  
	Create: 20191226 
	Description: Get BetFrom Type  
	DB: DBEXT.bodb02, DBACC.bodb02
    
	Revisions:  	  
		- 20191226@Vickie: Get BetFrom by PlatformType [Redmine: #125824]
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
				(1, 'g'),
				(6, 'r'),
				(7, 'x'),
				(2, 'z'),
				(8, 'o'),
				(9, 'c'),
				(10, 't'),
				(11, '0'),
				(88, 'v')
	) d(PlatformType, betfrom)
	WHERE d.PlatformType = @PlatformType OR @PlatformType = 0
GO