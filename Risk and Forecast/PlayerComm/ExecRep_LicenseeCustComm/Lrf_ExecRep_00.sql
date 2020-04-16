/*<info serverAlias="DBCUST-bodb_Licensee" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ExecRep_00]
(
	@strCustId VARCHAR(MAX),
	@MacauLicenseeID INT,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,	
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	@IsUpdateGD BIT = 0,
	@IsUpdateAG BIT = 0,
	@SBComm DECIMAL(9,8)=0,
	@NGComm DECIMAL(9,8)=0,	
	@RNGComm DECIMAL(9,8)=0,
	@ParlayComm DECIMAL(9,8)=0,	
	@AllbetComm DECIMAL(9,8)=0,	
	@MacauComm DECIMAL(9,8)=0,	
	@PPComm DECIMAL(9,8)=0,	
	@GDComm DECIMAL(9,8)=0,	
	@AGComm DECIMAL(9,8)=0

)
AS
/*
	Created: 20200416@Max
	Task : Support commission for 3rd party products - [Redmine: #131774]
	DB: DBCUST/bodb_Licensee
	Original: 

	Revisions:
		- 20200416@Max: Support commission for 3rd party products - [Redmine: #131774] 
	
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @LicenseeID INT,
		@GroupCommID INT = 0

	DECLARE @TempList AS TABLE (CustID INT PRIMARY KEY)
	DECLARE @tmpCommHistory TABLE(Custid INT,Comm DECIMAL(9,8))

	INSERT INTO @TempList (CustID)
	SELECT val
	FROM Lrf_f_StringSplit(@strCustId, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)
	
	--Update SB
	MERGE dbo.LicenseeCustComm AS target
	USING (SELECT @LicenseeID AS LicenseeID, CustID, @SBComm AS SBComm,@ParlayComm AS ParlayComm, @GroupCommID AS GroupCommID 
			FROM  @TempList --@TempCustID???  
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
			FROM @TempList --@TempCustID???   
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
	WHERE s.LicenseeID <>	@MacauLicenseeID
		AND d.CustiD IN(SELECT CustID FROM @TempList)
		AND s.Status ='Running'

	--NG
	IF @IsUpdateNG=1 
	BEGIN
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
			SET NGComm=@NGComm
		WHERE CustID IN (SELECT CustID FROM @TempList)
	END

	--RNG 
	IF @IsUpdateRNG=1
	BEGIN
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
			SET RNGComm=@RNGComm
		WHERE CustID IN (SELECT CustID FROM @TempList)
	END			
			
	--Allbet 
	IF @IsUpdateAllbet=1
	BEGIN
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
			SET AllbetComm=@AllbetComm
		WHERE CustID IN (SELECT CustID FROM @TempList)
	END	
			
	--Macau 
	IF @IsUpdateMacau=1
	BEGIN
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
			SET MacauComm=@MacauComm
		WHERE CustID IN (SELECT CustID FROM @TempList)
	END	
			
	--PP 
	IF @IsUpdatePP=1
	BEGIN
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET PPComm=@PPComm					
		WHERE CustID IN (SELECT CustID FROM @TempList)
	END
			
	--GD 
	IF @IsUpdateGD=1
	BEGIN
		DELETE @tmpCommHistory
				
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET GDComm=@GDComm
		OUTPUT INSERTED.custid, INSERTED.GDComm 
		INTO @tmpCommHistory(custid,Comm)
		WHERE CustID IN (SELECT CustID FROM @TempList)
				
		INSERT INTO LicenseeCustComm_History(CustID,UpdatedTime,ProductID,Comm)
		SELECT custid,GETDATE(),11,ISNULL(Comm,0)
		FROM @tmpCommHistory
	END
			
	--AG 
	IF @IsUpdateAG=1
	BEGIN
		DELETE @tmpCommHistory
				
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET AGComm=@AGComm
		OUTPUT INSERTED.custid, INSERTED.AGComm 
		INTO @tmpCommHistory(custid,Comm)
		WHERE CustID IN (SELECT CustID FROM @TempList)
				
		INSERT INTO LicenseeCustComm_History(CustID,UpdatedTime,ProductID,Comm)
		SELECT custid,GETDATE(),10,ISNULL(Comm,0)
		FROM @tmpCommHistory
	END
END
GO