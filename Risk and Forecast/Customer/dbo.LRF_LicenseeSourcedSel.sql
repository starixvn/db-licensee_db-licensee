/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb_licensee
GO

ALTER PROCEDURE [dbo].[Lrf_LicenseeSourcedSel]
	@SiteName NVARCHAR(50) = ''
	, @LicenseeID INT = 0 
	, @FromDate SMALLDATETIME = ''
	, @ToDate SMALLDATETIME = ''
AS 

/*
	Created: 20170925@Sophia
	Task: Get Sourced Agent list [Redmine: #82797]
	DB: DBLIC/bodb_Licensee
	Revisions:
		- 20170925@Sophia: Initial SP   
		- 20180313@Sophia: Change the name SourcedID and get RoleId, EffectiveDate [Redmine: #91738]
		- 20180320@Harper: Add more parameter @ToDate [Redmine: #91738]
		- 20180706@Joseph: Add more parameter @FromDate [Redmine: #97913]
 */
	 
BEGIN 
	SET NOCOUNT ON 

	SELECT  SourcedLicenseeID, SourcedID, RoleId, SourcedCurrencyID, EffectiveDate, EndDate
	FROM	bodb_Licensee.dbo.LicenseeSourcedSetting WITH (NOLOCK) 
	WHERE   (SiteName = @SiteName OR @SiteName = '')
			AND (LicenseeID = @LicenseeID OR @LicenseeID = 0)  
			AND (@FromDate = '' OR @ToDate = '' OR (@FromDate <= EndDate AND EffectiveDate <= @ToDate))
			AND IsActive = 1 
END    

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
