/*
	exec Lbs_Rpt_GetTotalTicket
	@InputDate='2012-08-01 00:00:00:000',
	@showSB=1,@ShowRB=1,@ShowNG=1,@ResellerID=0,@LicenseeID=0,
	@BalanceUpDay='2012-08-04 00:00:00:000',
	@MoveBetsDay='2012-08-06 00:00:00:000'
*/
ALTER PROCEDURE [dbo].[Lbs_Rpt_GetTotalTicket]    
	@InputDate  SMALLDATETIME,    
	@showSB		BIT=1,
	@ShowRB		BIT=0,
	@ShowNG		BIT=0,
	@ShowLC 	BIT=0,
	@ShowVS		BIT=0,
	@ShowCS  	BIT=0, -- RNG Casino
	@ResellerID INT =0,
	@LicenseeID INT = 0, 
	@BalanceUpDay SMALLDATETIME,  
	@MoveBetsDay SMALLDATETIME    
AS    
/*  Created: Henry    
 Date: 2011-01-04    
    Task : Get Total tickets of Licensees    
    DB: DB052.bodb02    
     
    Revisions:    
  - 20110112@Jamie: Exclude the VOID, REJECT , REFUND to match sum_winloss  
  - 20110223@Henry: Exclude Racing bets for Licensee  
  - 20110516@Henry: change bettype to new range
  - 20110818@Henry: Add option to show: Sportsbook, Number Game
  - 20110824@Henry: Add Filter Reseller
  - 20111013@Henry: Change to use rptLicWinloss2
  - 20111117@Henry: Add show racebook
  - 20120208@Jim:   Replace  @ResellerName by @ResellerID
  - 20120221@Henry: FDL billing 222223, 733333, 222225, 722222, 755555, Indo from the 1st Feb 2012; 789y from the 1st March 2012
  - 20120301@Henry: Turn hard-code into table
  - 20120405@Henry: Get resellerID to calculate the rate
  - 20120515@Henry: exclude customercategory 28 - BARM
  - 20120704@Henry: Map Licensee with System
  - 20120816@Jim: add live casino
  - 20120905@Henry: add Virtual Sports
  - 20121122@Jim: fix bug sportbook bettype range 
  - 20130527@Jim: support RNG Casino
 Param's Explanation:    
  
*/    
BEGIN    
	SET NOCOUNT ON    
		
	DECLARE @FromDate DATETIME  
	DECLARE @ToDate DATETIME  
	
	DECLARE @data AS TABLE (ResellerID INT,LicenseeID INT, betcount INT)  
	DECLARE @bettype AS TABLE (bettype INT PRIMARY KEY) 
	
	DECLARE @tmpLicenseeReseller AS TABLE (ResellerID INT ,LicenseeID INT)

	SET @FromDate = CAST (year(@InputDate) AS VARCHAR(10)) + '-' + CAST (month(@InputDate) AS VARCHAR(10)) + '-01'  
	SET @ToDate = CAST(CONVERT(VARCHAR(10),  DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,@FromDate)+1,0)), 111) AS DATETIME)   

	INSERT INTO @tmpLicenseeReseller (ResellerID,LicenseeID)
	SELECT lr.ResellerID,lr.LicenseeID FROM bodb_licensee.dbo.LicenseeReseller lr (NOLOCK)
	INNER JOIN bodb_licensee.dbo.Resellers r WITH (NOLOCK) ON lr.ResellerID = r.ResellerID
	WHERE (@ResellerID=0 OR lr.ResellerID = @ResellerID) AND (@LicenseeID = 0 OR LicenseeID = @LicenseeID)
	
	INSERT INTO @bettype
	SELECT typeid FROM dbo.bettype 
	WHERE (
			(@showSB=1 AND typeid  between 121 and 999)
			OR (@showSB=1 AND typeid<31)
			OR (@showRB=1 AND typeid between 31 and 33)
			OR (@showNG=1 AND typeid between 81 and 120)
			OR (@showLC=1 AND typeid between 1101 and 1199)
			OR (@showVS=1 AND typeid between 1201 and 1299)
			OR (@showCS=1 AND typeid=71)
		    )	
		
	IF (@ShowSB = 1 OR @ShowNG = 1 OR @ShowRB = 1 OR @ShowLC=1 OR @ShowVS=1 OR @ShowCS=1)
	BEGIN
		--exclude BA & FDL & PIH...
		IF EXISTS(SELECT 1 FROM @tmpLicenseeReseller lr INNER JOIN bodb_licensee.dbo.licensees l WITH (nolock) ON lr.licenseeid=l.licenseeid  WHERE l.IsDeposit=1 AND lr.ResellerID<>3)
		BEGIN
			INSERT INTO @data 
			SELECT	
				lr.ResellerID,lr.LicenseeID,
				SUM(BetCount) AS betcount
			FROM @tmpLicenseeReseller lr
				INNER JOIN bodb_licensee.dbo.licensees lic WITH ( NOLOCK) ON lic.licenseeid=lr.licenseeid
				INNER JOIN bodb_Licensee.dbo.rpt_Betting b WITH ( NOLOCK) ON lr.LicenseeID = b.siteID
				INNER JOIN bodb_Licensee.dbo.SystemLicensee sl (NOLOCK) ON lic.LicenseeID=sl.LicenseeID 
				INNER JOIN bodb_Licensee.dbo.Systems s (NOLOCK) ON sl.SystemID=s.ID
				INNER JOIN @bettype bet ON b.bettype=bet.bettype
			WHERE 
				b.rptDate BETWEEN @FromDate AND @ToDate
				AND lr.ResellerID<>3
				AND lic.isdeposit=1
				AND sl.IsActive = 1
				AND s.SystemName='Accounting'
				AND @FromDate>=isnull(lic.AffectedDate,'1999-01-01')
				AND b.status NOT IN (-1,103)
				AND CurrencyID<>20
				GROUP BY lr.ResellerID,lr.licenseeid		
		END	
	
		--BA
		IF @ShowSB = 1 AND EXISTS(SELECT 1 FROM @tmpLicenseeReseller WHERE ResellerID = 3)
		BEGIN
			INSERT INTO @data 
			SELECT	
				lr.ResellerID,lr.LicenseeID,
				SUM(BetCount) AS betcount
			FROM @tmpLicenseeReseller lr	
				INNER JOIN bodb_licensee.dbo.licensees lic WITH ( NOLOCK) ON lic.licenseeid=lr.licenseeid
				INNER JOIN bodb_Licensee.dbo.rpt_Betting_BA b WITH ( NOLOCK) ON lr.LicenseeID = b.siteID
				INNER JOIN bodb_Licensee.dbo.SystemLicensee sl (NOLOCK) ON lic.LicenseeID=sl.LicenseeID 
				INNER JOIN bodb_Licensee.dbo.Systems s (NOLOCK) ON sl.SystemID=s.ID
			WHERE 
				b.rptDate BETWEEN @FromDate AND @ToDate
				AND lr.ResellerID=3
				AND lic.isdeposit=1
				AND sl.IsActive = 1
				AND s.SystemName='Accounting'
				AND @FromDate>=isnull(lic.AffectedDate,'1999-01-01')
				AND b.status NOT IN (-1,103)
				AND CurrencyID<>20
			GROUP BY lr.ResellerID,lr.licenseeid	
		END
	
		--FDL, PIH..
		IF EXISTS(SELECT 1 FROM @tmpLicenseeReseller lr inner JOIN bodb_licensee.dbo.licensees l WITH (nolock) ON lr.licenseeid=l.licenseeid where l.IsDeposit=0)
		BEGIN
			INSERT INTO @data 
			SELECT	
				lr.ResellerID,lr.LicenseeID,
				SUM(BetCount) AS betcount
			FROM @tmpLicenseeReseller lr
				INNER JOIN bodb_Licensee.dbo.labels lb WITH (NOLOCK) ON lr.LicenseeID=lb.LicenseeID
				INNER JOIN bodb_Licensee.dbo.rpt_Betting b WITH ( NOLOCK) ON b.siteID=lb.LabelID
				INNER JOIN bodb_licensee.dbo.licensees lic WITH ( NOLOCK) ON lic.licenseeid=lr.licenseeid
				INNER JOIN bodb_Licensee.dbo.SystemLicensee sl (NOLOCK) ON lic.LicenseeID=sl.LicenseeID 
				INNER JOIN bodb_Licensee.dbo.Systems s (NOLOCK) ON sl.SystemID=s.ID
				INNER JOIN @bettype bet ON b.bettype=bet.bettype
			WHERE 
				b.rptDate BETWEEN @FromDate AND @ToDate
				AND b.status NOT IN (-1,103)
				AND CurrencyID<>20
				AND lic.isdeposit=0
				AND sl.IsActive = 1
				AND s.SystemName='Accounting'
				AND @FromDate>=isnull(lb.AffectedDate,'1999-01-01')
				AND lr.ResellerID<>3
				AND isnull(b.customercategory,-1) NOT IN (27 ,28)
			GROUP BY lr.ResellerID,lr.LicenseeID
		END
	
		
	END

	SELECT  
		r.ResellerID,
		r.ResellerName,
		l.LicenseeName, 
		ISNULL(SUM(d.betcount),0) AS BetCount  
	FROM @data d   
		INNER JOIN bodb_licensee.dbo.Resellers r ON d.ResellerID = r.ResellerID
		INNER JOIN bodb_licensee.dbo.Licensees l WITH (NOLOCK) ON l.LicenseeID = d.LicenseeID
	GROUP BY r.ResellerID,r.ResellerName, l.LicenseeName  
	ORDER BY r.ResellerName, l.LicenseeName
	  
END
GO

GRANT EXECUTE ON [dbo].[Lbs_Rpt_GetTotalTicket] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lbs_Rpt_GetTotalTicket] TO [vnteam]
