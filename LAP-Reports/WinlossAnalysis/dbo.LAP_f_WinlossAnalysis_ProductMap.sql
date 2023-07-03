/*<info serverAlias="DBEXT-bodb02" selecters="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="1" isNested="1"></info>*/
CREATE FUNCTION [dbo].[LAP_f_WinlossAnalysis_ProductMap] (
	@IsViewCOOnlyCheck BIT, 
	@SBBACheck INT, 
	@Product3rdId INT, 
	@TicketType TINYINT
)
RETURNS INT
AS
/*
	Created: 20230209@Bobby
	Task: 190474 - LAP - Winloss Analysis - Enhance perf
	DB: DBEXT.bodb02

	Revisions:
		- 20230703@Bobby: Created [RedmineID: #190474]
		
*/
BEGIN
	RETURN 
		CASE 
			WHEN @Product3rdId IN (63,69) THEN 0
			WHEN @IsViewCOOnlyCheck = 1 AND @Product3rdId = 0 AND @SBBACheck & 4 = 4 AND @TicketType = 1 THEN -99 --Cashout 
			WHEN @IsViewCOOnlyCheck = 1 AND @Product3rdId = 3 AND @SBBACheck & 8 = 8 AND @TicketType = 1 THEN -99 --Cashout  
			ELSE @Product3rdId 
		END
END