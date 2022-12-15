/*<info serverAlias="DBWH-bodb_DWRS" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_AbnormalBet_ListLicenseeByDate
AS
/*	Created by: Evan
	Task : Support "Abnormal Bet" on Bell notification (#174308)
	DB: DBDW2/bodb_dwrs 
	Revisions:
		20221202@Evan: Initial sp [RedmineID: #174308]	
	Note: Provide info list of licensees have abnormal bet to setting bell notification
*/
BEGIN
	SET NOCOUNT ON  
	
	DECLARE @BalanceUpDay DATETIME,
			@MaxDate DATE
	DECLARE @SiteIDs TABLE (SiteID INT, CreatedDate DATE)

	SELECT @MaxDate = CONVERT(DATE,CURRENT_TIMESTAMP,112)
	
	SELECT @BalanceUpDay = BalanceUpDay  
	FROM OPENQUERY(DBACC,'EXEC bodb02.dbo.Age_SelBalanceUpDay')  

	INSERT INTO @SiteIDs (SiteID, CreatedDate)
	SELECT DISTINCT SiteID , CreatedDate
	FROM bodb_Account.dbo.FactSiteAbnormalBet WITH(NOLOCK) 
	WHERE CreatedDate >= @BalanceUpDay AND CreatedDate < @MaxDate
	
	SELECT STRING_AGG(b.site,',') AS LicenseeName, CreatedDate
	FROM @SiteIDs a 
		INNER JOIN bodb_Account.dbo.tbl_Site b WITH(NOLOCK) ON a.SiteID = b.siteid
	GROUP BY CreatedDate
	
END
GO
