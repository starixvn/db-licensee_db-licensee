/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02" executers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[Lrf_f_GroupProductCode]
(
	@ProductCodes	VARCHAR(500) = ''
)
RETURNS VARCHAR(500)
AS

/*
	Created: 20211109@Kos
	DB: DBEXT.bodb02, DBACC.bodb02, DBBOF.bodb02
	Task: Group product code

	Revisions:
		- 20211109@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
*/

BEGIN
	IF ',' + @ProductCodes + ',' LIKE '%,SB,%'
	BEGIN
		SET @ProductCodes = @ProductCodes + ',SLT'
	END

	RETURN @ProductCodes
END
GO