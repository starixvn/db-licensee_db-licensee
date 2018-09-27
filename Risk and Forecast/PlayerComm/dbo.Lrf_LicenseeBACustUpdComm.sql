/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
USE CustDB
GO
  
ALTER PROCEDURE Lrf_LicenseeBACustUpdComm
	@LicenseeID INT,
	@CustID INT,--member
	@IsBA BIT
AS
/*
	Created: 20150508@Jim
	Task : Update SB Commission WHEN BA is ON/OFF
	DB: DBCUST/CUSTDB
	Revision:
		- 20151005@Jim:HotFix #45031
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
*/
BEGIN
	DECLARE @SBComm [decimal](9,8), @ParlayComm [decimal](9,8)
	SELECT  @SBComm = 0 , @ParlayComm = 0
		
	SELECT @SBComm = lgc.SBComm
		   ,@ParlayComm = lgc.ParlayComm
	FROM bodb_Licensee.dbo.LicenseeCustComm lcs WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.LicenseeGroupComm lgc WITH (NOLOCK) ON lcs.GroupCommID = lgc.id AND lcs.LicenseeID = lgc.Licenseeid
	WHERE lcs.LicenseeID = @LicenseeID AND CustID = @CustID	   
	  
	IF (@IsBA =1 )	--- Turn-on BA
	BEGIN 
		IF  NOT EXISTS (SELECT 1 FROM bodb_Licensee.dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
		BEGIN
			UPDATE bodb_Licensee.dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
			SET SBComm      =  0
				,ParlayComm =  0
			WHERE LicenseeID = @LicenseeID AND CustID = @CustID	   	
		END

		IF  NOT EXISTS (SELECT 1 FROM bodb_Licensee.dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
		BEGIN
			EXEC  dbo.Lrf_LicenseeBACust_Playerdiscount_Upd @CustID = @CustID,@SBComm=0, @ParlayComm = 0
		END
	END
	ELSE IF (@IsBA = 0 ) -- Turn-off BA
	BEGIN 	
		UPDATE bodb_Licensee.dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET SBComm      = @SBComm
			,ParlayComm = @ParlayComm
		WHERE LicenseeID = @LicenseeID AND CustID = @CustID	   	

		IF  NOT EXISTS (SELECT 1 FROM bodb_Licensee.dbo.licensees WITH (NOLOCK) WHERE LicenseeName='Macaubet' AND LicenseeId=@LicenseeID )	
		BEGIN
			EXEC  dbo.Lrf_LicenseeBACust_Playerdiscount_Upd @CustID = @CustID,@SBComm=@SBComm, @ParlayComm = @ParlayComm
		END				   
	END	
END
GO 
