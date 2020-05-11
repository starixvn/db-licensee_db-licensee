/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerRemoveGroupComm]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member
	@strCustID VARCHAR(MAX) OUTPUT,--member
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS  
/*  
	Created: 20120801@Henry
	Task : Remove Group Comm
	DB: DBCUST/bodb_Licensee  
   
	Revisions:     
		- 20130413@Jim: support multi langueges
		- 20131025@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140115@Hannah: separate @strCustID INPUT and OUTPUT parameter
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171024@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180924@Winnie: Remove Allbet [RedmineID: #99378]
		- 20200409@Johnson: Add comm for AB,Macau,PP,AG,GD [redmine:#131774] 
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
*/  
BEGIN  
	SET NOCOUNT ON
	
	DECLARE @SBComm DECIMAL(9,8), 
			@NGComm DECIMAL(9,8),
			@RNGComm DECIMAL(9,8),
			@ParlayComm DECIMAL(9,8),
			@AllbetComm DECIMAL(9,8),
			@MacauComm DECIMAL(9,8),
			@PPComm DECIMAL(9,8),
			@GDComm DECIMAL(9,8),
			@AGComm DECIMAL(9,8),
			@FWComm DECIMAL(9,8),
			@CustID INT, 
			@i INT	
	
	SELECT @strCustIDOriginal = ltrim(rtrim(@strCustIDOriginal))
	
	IF @strCustIDOriginal = ''
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Wrong input, please check again!'
				ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
				END
		RETURN
	END
	
	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
	INSERT INTO @TempCustID (CustID)
	SELECT CustID 
	FROM dbo.LicenseeCustComm WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT RTRIM(LTRIM(VAL)) FROM Lrf_f_StringSplit(@strCustIDOriginal,','))
			AND GroupCommID > 0
	
	IF NOT EXISTS(SELECT TOP 1 1 FROM @TempCustID)
	BEGIN
		SELECT @ErrMsg= CASE @Langkey WHEN 'en-US' THEN 'Nothing to remove!'
									  ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200004,@Langkey)
									  END			
		RETURN	
	END
	
	IF @IsRemovePlayercomm=0
	BEGIN
		SELECT @i = 0
		WHILE (@i<(SELECT MAX(ID) FROM @TempCustID))
		BEGIN
			SET @i = @i + 1
			SELECT @CustID = CustID FROM @TempCustID WHERE ID=@i
			--Get current setting
			SELECT @SBComm=SBComm,
				@NGComm=NGComm,
				@RNGComm=RNGComm,
				@ParlayComm = ParlayComm,
				@AllbetComm=AllbetComm,				
				@MacauComm=MacauComm,
				@PPComm=PPComm,
				--@GDComm=GDComm,
				--@AGComm=AGComm
				@FWComm = FWComm
			FROM dbo.LicenseeCustComm WITH (NOLOCK)
			WHERE LicenseeID = @LicenseeID AND CustID = @CustID
					
			--Update List of affected Customers               
			EXEC [Lrf_CustomerUpdMemberComm] 
				@LicenseeID=@LicenseeID,
				@strCustID=@CustID,
				@UserID=@UserID,
				@IsUpdateComm=0,
				@GroupCommID=0,
				@SBComm=@SBComm,
				@NGComm=@NGComm,
				@RNGComm=@RNGComm,
				@ParlayComm = @ParlayComm,	
				@AllbetComm=@AllbetComm,
				@MacauComm=@MacauComm,
				@PPComm=@PPComm,
				--@GDComm=@GDComm,
				--@AGComm=@AGComm,
				@FWComm = @FWComm,
				@IsUpdateNG=1,
				@IsUpdateRNG=1,			
				@IsUpdateAllbet=1,
				@IsUpdateMacau=1,
				@IsUpdatePP=1,
				--@IsUpdateGD=1,
				--@IsUpdateAG=1,
				@IsUpdateFW=1,
				@IP=@IP,
				@Langkey=@Langkey,
				@ErrCode=@ErrCode OUTPUT,
				@ErrMsg=@ErrMsg OUTPUT	
				
			IF @ErrCode<>0
			RETURN
		END
		
		UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK) 
		SET GroupCommID=0
		WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM @TempCustID)
	END
	ELSE IF @IsRemovePlayercomm=1
	BEGIN
		--Update List of affected Customers               
		EXEC [Lrf_CustomerUpdMemberComm] 
			@LicenseeID=@LicenseeID,
			@strCustID=@strCustIDOriginal,
			@UserID=@UserID,
			@GroupCommID=0,
			@SBComm=0,
			@NGComm=0,
			@RNGComm=0,
			@ParlayComm = 0,
			@AllbetComm= 0,
			@MacauComm= 0,
			@PPComm= 0,
			--@GDComm= 0,
			--@AGComm= 0,
			@FWComm= 0,
			@IsUpdateNG=1,
			@IsUpdateRNG=1,	
			@IsUpdateAllbet=1,
			@IsUpdateMacau=1,
			@IsUpdatePP=1,
			--@IsUpdateGD=1,
			--@IsUpdateAG=1,	
			@IsUpdateFW=1,
			@IP=@IP,
			@Langkey=@Langkey,
			@ErrCode=@ErrCode OUTPUT,
			@ErrMsg=@ErrMsg OUTPUT
		
		IF @ErrCode<>0
			RETURN
		
		--Update players out of LicenseeCustComm GroupCommID
		UPDATE LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
		SET 
			SBComm = 0,
			ParlayComm = 0,
			NGComm = 0,
			RNGComm = 0,
			AllbetComm= 0,
			MacauComm= 0,
			PPComm= 0,
			--GDComm= 0,
			--AGComm= 0,
			FWComm = 0,
			GroupCommID = 0
		WHERE LicenseeID = @LicenseeID 
		AND CustID IN (SELECT CustID FROM @TempCustID)
	END
		
	SELECT @StrCustID = STUFF(
                    (   SELECT  ',' + CONVERT(NVARCHAR(20), b.CustID) 
                        FROM  @TempCustID b  
						INNER JOIN CustDB.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.CustID
						WHERE a.SyncCasino = 1
                        FOR xml path('')
                    )
                    , 1
                    , 1
                    , '')
END
GO