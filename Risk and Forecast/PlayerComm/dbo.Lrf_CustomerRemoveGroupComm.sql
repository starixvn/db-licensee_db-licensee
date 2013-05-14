set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_CustomerRemoveGroupComm]
	@LicenseeID INT,
	@strCustID VARCHAR(MAX),--member
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS  
/*  
 * Created: 20120801@Henry
 * Task : Remove Group Comm
 * DB: DB052.bodb_Licensee  
 *  
 * Revisions:     
	-20130413@Jim: support multi langueges
	
*/  
BEGIN  
	DECLARE @SBComm DECIMAL(9,8) , @RacingComm DECIMAL(9,8) ,@NGComm DECIMAL(9,8),@CustID INT, @i INT
	
	
	SELECT @strCustID = ltrim(rtrim(@strCustID))
	
	IF @strCustID = ''
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Wrong input, please check again!'
				ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
				END
		RETURN
	END
	
	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
	INSERT INTO @TempCustID (CustID)
	SELECT CustID 
	FROM LicenseeCustComm WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT RTRIM(LTRIM(VAL)) FROM strSplit(@strCustID,','))
			AND GroupCommID > 0
	
	IF NOT EXISTS(
		SELECT TOP 1 1 FROM @TempCustID
	)
	BEGIN
		SELECT @ErrMsg= CASE @Langkey WHEN 'en-US' THEN 'Nothing to remove!'
									  ELSE [bodb02].[dbo].[Lrf_f_Get_MsgNamebyMsgID](200004,@Langkey)
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
			SELECT @SBComm=SBComm,@NGComm=NGComm,@RacingComm=RacingComm
			FROM LicenseeCustComm WITH (NOLOCK)
			WHERE LicenseeID = @LicenseeID AND CustID = @CustID
					
			--Update List of affected Customers               
			EXEC [Lrf_CustomerUpdMemberComm] @LicenseeID=@LicenseeID,@strCustID=@CustID,@UserID=@UserID,@IsUpdateComm=0,@GroupCommID=0,@SBComm=@SBComm,@NGComm=@NGComm,@RacingComm=@RacingComm,@IsUpdateNG=1,@IsUpdateRacing=1,@IP=@IP,@Langkey=@Langkey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT	
			IF @ErrCode<>0
			RETURN
		END
	
		
		UPDATE LicenseeCustComm WITH (ROWLOCK,UPDLOCK) SET GroupCommID=0
		WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM @TempCustID)
	END
	ELSE IF @IsRemovePlayercomm=1
	BEGIN
		--Update List of affected Customers               
		EXEC [Lrf_CustomerUpdMemberComm] @LicenseeID=@LicenseeID,@strCustID=@strCustID,@UserID=@UserID,@GroupCommID=0,@SBComm=0,@NGComm=0,@RacingComm=0,@IsUpdateNG=1,@IsUpdateRacing=1,@IP=@IP,@Langkey=@Langkey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
		
		IF @ErrCode<>0
			RETURN
		
		--Delete players out of LicenseeCustComm
		DELETE FROM LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
			WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM @TempCustID)
	END
	
	

END

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerRemoveGroupComm] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerRemoveGroupComm] TO [vnteam]    