USE [bodb_licensee]
GO

ALTER PROCEDURE [dbo].[Lrf_GetActiveDomain]
	-- Add the parameters for the stored procedure here

AS
/*
Created		: 
Task		: Get active domain
DB			: DBLIC.bodb_Licensee

Revisions:
	- 20140617@Don: Add column [Protocol] into table LrfDomain
		
*/
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	--SELECT TOP 1 'http://'+ DomainName +'/sso.aspx' AS Domain 
	SELECT TOP 1 Protocol + '://'+ DomainName +'/sso.aspx' AS Domain 
	FROM LrfDomain
	WHERE IsActive = 1
END

GO
GRANT EXECUTE ON [dbo].[Lrf_GetActiveDomain] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetActiveDomain] TO [vnteam] 