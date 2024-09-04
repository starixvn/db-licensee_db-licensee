/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="vnteam" isFunction="0"></info>*/
USE bodb_Licensee
GO
  
ALTER PROCEDURE Lrf_LicenseeBACustUpdComm
	@LicenseeID INT,
	@CustID INT,--member
	@IsBA BIT
AS
/*
	Created: 20150508@Jim
	Task : Update SB Commission WHEN BA is ON/OFF
	DB: DBCUST/bodb_Licensee
	Revision:
		- 20151005@Jim:HotFix #45031
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20240403@Johnson: Restructure Commission [redmine:#179088]
*/
BEGIN
	DECLARE @SBComm [decimal](9,8), @ParlayComm [decimal](9,8)
	SELECT  @SBComm = 0 , @ParlayComm = 0
		
	SELECT @SBComm = ISNULL(MAX(CASE WHEN lgc.SportType = 1 AND lgc.BetType = 1 THEN lgc.Discount ELSE 0 END),0),
		   @ParlayComm = ISNULL(MAX(CASE WHEN lgc.SportType = 1 AND lgc.BetType = 9 THEN lgc.Discount ELSE 0 END),0)
	FROM LicenseeCustDiscount lcs WITH(NOLOCK)
		INNER JOIN dbo.LicenseeGroupDiscountDetail lgc WITH (NOLOCK) ON lcs.GroupDiscountID = lgc.GroupDiscountID AND lcs.LicenseeID = lgc.Licenseeid
	WHERE lcs.LicenseeID = @LicenseeID AND CustID = @CustID	   
	  
	IF (@IsBA =1 )	--- Turn-on BA
	BEGIN 		
		IF  NOT EXISTS (SELECT 1 FROM dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
		BEGIN
			EXEC  CustDB.dbo.Lrf_LicenseeBACust_Playerdiscount_Upd @CustID = @CustID,@SBComm=0, @ParlayComm = 0
		END
	END
	ELSE IF (@IsBA = 0 ) -- Turn-off BA
	BEGIN 			
		IF  NOT EXISTS (SELECT 1 FROM dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
		BEGIN
			EXEC  CustDB.dbo.Lrf_LicenseeBACust_Playerdiscount_Upd @CustID = @CustID,@SBComm=@SBComm, @ParlayComm = @ParlayComm
		END				   
	END	
END
GO 
