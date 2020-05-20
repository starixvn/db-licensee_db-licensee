/*<info serverAlias="DBCUST-bodb_Licensee" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ExecRep_00]
(
	@strCustId VARCHAR(MAX),
	@LicenseeID INT,
	@GroupCommID INT = 0,
	@MacauLicenseeID INT,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,	
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@IsUpdateGD BIT = 0,
	@IsUpdateAG BIT = 0,
	@IsUpdateFW BIT = 0,
	@SBComm DECIMAL(9,8)=0,
	@NGComm DECIMAL(9,8)=0,	
	@RNGComm DECIMAL(9,8)=0,
	@ParlayComm DECIMAL(9,8)=0,	
	@AllbetComm DECIMAL(9,8)=0,	
	@MacauComm DECIMAL(9,8)=0,	
	@PPComm DECIMAL(9,8)=0,	
	@GDComm DECIMAL(9,8)=0,	
	@AGComm DECIMAL(9,8)=0,
	@FWComm DECIMAL(9,8)=0

)
AS
/*
	Created: 20200416@Max
	Task : Support commission for 3rd party products - [Redmine: #131774]
	DB: DBCUST/bodb_Licensee
	Original: 

	Revisions:
		- 20200416@Max: Support commission for 3rd party products - [Redmine: #131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]   
	
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @xml XML

	DECLARE @TempList_Input AS TABLE (CustID INT )

	SELECT @xml = CONVERT(XML,N'<root><r t="' + REPLACE(@strCustId,',','"/><r t="') + '"/></root>"')

	INSERT INTO @TempList_Input (CustID)
	SELECT T.C.value('./@t', 'int')			
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	--Update SB
	MERGE dbo.LicenseeCustComm AS target
	USING (SELECT @LicenseeID AS LicenseeID, CustID, @SBComm AS SBComm,@ParlayComm AS ParlayComm, @GroupCommID AS GroupCommID 
			FROM  @TempList_Input
			WHERE CustID NOT IN (SELECT CustID FROM dbo.LicenseeBAHistory WITH (NOLOCK) WHERE Status ='Running') 
			) AS source
		ON (target.CustID = source.CustID)
	WHEN MATCHED THEN 
		UPDATE 
		SET target.SBComm = source.SBComm,
			target.ParlayComm = source.ParlayComm,
			target.GroupCommID = source.GroupCommID
	WHEN NOT MATCHED THEN	
		INSERT (LicenseeID,CustID,SBComm,ParlayComm,GroupCommID)
		VALUES (source.LicenseeID,source.CustID,source.SBComm,Source.ParlayComm,source.GroupCommID);
				
	-------------for BA member
	MERGE dbo.LicenseeCustComm AS target
	USING (SELECT @LicenseeID AS LicenseeID
					,CustID
					,@SBComm AS SBComm 
					,@ParlayComm AS ParlayComm
					,@GroupCommID AS GroupCommID 
			FROM @TempList_Input  
			WHERE CustID  IN (SELECT CustID FROM dbo.LicenseeBAHistory WITH (NOLOCK) WHERE Status ='Running') 
			) AS source
		ON (target.CustID = source.CustID)
	WHEN MATCHED THEN 
		UPDATE 
		SET target.SBComm = source.SBComm,
			target.ParlayComm = source.ParlayComm,
			target.GroupCommID = source.GroupCommID
	WHEN NOT MATCHED THEN	
		INSERT (LicenseeID,CustID,SBComm,ParlayComm,GroupCommID)
		VALUES (source.LicenseeID,source.CustID,source.SBComm,Source.ParlayComm,source.GroupCommID);
				
	UPDATE d
	SET SBComm = 0	
		,ParlayComm = 0
	FROM dbo.LicenseeCustComm d WITH  (ROWLOCK,UPDLOCK)
		INNER JOIN dbo.LicenseeBAHistory s WITH (NOLOCK) ON d.LicenseeId = s.LicenseeId AND d.CustID = s.CustID
		INNER JOIN @TempList_Input t ON t.CustID = d.CustID
	WHERE s.LicenseeID <> @MacauLicenseeID
		AND s.Status ='Running'

	IF (@IsUpdateNG = 1
		OR @IsUpdateRNG = 1
		OR @IsUpdateAllbet=1
		OR @IsUpdateMacau=1
		OR @IsUpdatePP=1
		OR @IsUpdateFW=1)
	BEGIN	
		UPDATE cs
			SET NGComm=CASE WHEN  @IsUpdateNG = 1 THEN @NGComm ELSE NGComm END
				, RNGComm=CASE WHEN @IsUpdateRNG = 1 THEN @RNGComm ELSE RNGComm END
				, AllbetComm=CASE WHEN @IsUpdateAllbet = 1 THEN @AllbetComm ELSE AllbetComm END
				, MacauComm= CASE WHEN @IsUpdateMacau = 1 THEN @MacauComm ELSE MacauComm END
				, PPComm= CASE WHEN @IsUpdatePP = 1 THEN @PPComm ELSE PPComm END
				, FWComm= CASE WHEN @IsUpdateFW = 1 THEN @FWComm ELSE FWComm END
		FROM dbo.LicenseeCustComm cs WITH (ROWLOCK,UPDLOCK)
			INNER JOIN @TempList_Input ip ON ip.CustID = cs.CustID
	END
	
END
GO