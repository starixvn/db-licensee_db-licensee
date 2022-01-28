/*<info serverAlias="DBPLO-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER FUNCTION [dbo].[Lrf_f_MappingAuditSite]
(
	@AuditSiteName VARCHAR(50)
)
RETURNS VARCHAR(50)
AS 
/*  Created: 20220118@Sol
    Description: LAP - Return list sport from gamedetail table
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20220118@Sol: Initial function - [RedmineID: #166056]
    
*/
BEGIN
	
	DECLARE @SiteName VARCHAR(50)

	SELECT @SiteName = CASE 
							WHEN @AuditSiteName = '12B' THEN '12Bet'
							WHEN @AuditSiteName = 'IvoryBet' THEN 'ivorysport'
							ELSE @AuditSiteName
						END

	RETURN @SiteName

END