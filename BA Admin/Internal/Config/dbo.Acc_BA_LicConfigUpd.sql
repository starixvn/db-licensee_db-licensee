/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb_Licensee
GO

ALTER PROCEDURE [dbo].[Acc_BA_LicConfigUpd]
(
	@LicenseeID		INT,
	@groupa DECIMAL(9,8) = 0,
	@groupb DECIMAL(9,8) = 0,
	@groupc DECIMAL(9,8) = 0,
	@groupd DECIMAL(9,8) = 0,
	--@ugroup VARCHAR(3),
	@1x2Comm DECIMAL(9,8) = 0,
	@OtherComm DECIMAL(9,8) = 0,	
	@EnableBA BIT = 0,
	@UserID			INT,
	@IP				VARCHAR(40),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
)
AS
/* 
	Date: 20110606
	Task : Update Commission Template of a Licensee 
	DB: DBCUST/bodb_Licensee
	Original:

	Revisions:
		- 20110707@Henry: Add/Remove ProductID in LicenseeProduct3rd when enable/disable BA
		- 20110823@Johnson: change to use commission by group for handicap, odd/even, over/under bettype
		- 20110906@Henry: update all BA members to normal when disable BA
		- 20111118@Jim: change  ugroup variable reference and update commission separate by currency 
		- 20111209@Henry: hardcode Alog members to just only allow group a
		- 20120208@Jim:  hardcode to change point spread for members (group a and group d)
		- 20120215@Henry: add more customer for hard-code group a
		- 20120223@Jim: add more customer for spread member (group a and group d)
		- 20120403@Jim: get SpecialCust from LicenseeSpecialCust replace for hard-code
		- 20120426@Henry: fix bug due to update wrong groupcomm in LicenseeBAHistory
		- 20130123@Daniel: Change link server alias
		- 20170519@Harper: Fix duplicate key when setting BA [RedmineID: #76420]
		- 20180809@Sophia: HA - remove LicenseeCustInfo table [Redmine: #99464]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20180914@Helen: Hotfix - CHANGE link server to update BA Member - DBCUST/CUSTDB - [Redmine:101501]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]

	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	--Check permission 	
	EXEC NAP_UserControl.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[BACommSetting]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
	--Check exist in Licensees
	IF NOT EXISTS (SELECT 1 FROM Licensees WITH (nolock) WHERE LicenseeID = @LicenseeID)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid Licensee, please check again!'
		RETURN
	END
	--Check NOT exist in LicenseeBAConfig
	IF NOT EXISTS (SELECT 1 FROM LicenseeBAConfig WITH (nolock) WHERE LicenseeID = @LicenseeID)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'This licensee does NOT have any settings!'
		RETURN
	END
	--Get old VALUES
	DECLARE 
		@currency int , 
		@ugroup VARCHAR(3),
		@groupa_Old DECIMAL(9,8) ,
		@groupb_Old DECIMAL(9,8) ,
		@groupc_Old DECIMAL(9,8) ,
		@groupd_Old DECIMAL(9,8) ,
		@1x2Comm_Old DECIMAL(9,8),
		@OtherComm_Old DECIMAL(9,8),	
		@EnableBA_Old BIT,
		@FlagUpdateComm BIT,
		@FlagUpdateBAStatus BIT,
		@ModifyDate DATETIME

	SET @FlagUpdateComm = 0
	SET @FlagUpdateBAStatus=0
	SET @ModifyDate = GETDATE()
	
	SELECT
		@groupa_Old = lb.groupa,
		@groupb_Old = lb.groupb,
		@groupc_Old = lb.groupc,
		@groupd_Old = lb.groupd,
		@1x2Comm_Old = lb.[1x2Comm],
		@OtherComm_Old = lb.OtherComm,		
		@EnableBA_Old = lb.EnableBA
	 FROM LicenseeBAConfig lb WITH (nolock)
	
	WHERE lb.LicenseeID = @LicenseeID
	
	--Compare the old VALUES VS new VALUES, if different then update
	--Commission
	IF @groupa_Old = @groupa AND @groupb_Old = @groupb AND @groupc_Old = @groupc AND  @groupd_Old = @groupd
			AND  @1x2Comm_Old = @1x2Comm AND @OtherComm_Old = @OtherComm
		SET @FlagUpdateComm = 0
	ELSE
		SET @FlagUpdateComm = 1
		
	--Enable/Disable BA
	IF @EnableBA_Old = @EnableBA
		SET @FlagUpdateBAStatus = 0
	ELSE
		SET @FlagUpdateBAStatus = 1
		
		
	IF 	@FlagUpdateComm = 1 OR @FlagUpdateBAStatus = 1 
	BEGIN
		Update LicenseeBAConfig WITH (rowlock, updlock)
		SET 
			groupa = @groupa,
			groupb = @groupb,
			groupc = @groupc,
			groupd = @groupd,
			[1x2Comm] = @1x2Comm,
			OtherComm = @OtherComm,			
			EnableBA = @EnableBA,
			ModifyBy = @UserID,
			ModifyDate = @ModifyDate
		WHERE 
			LicenseeID = @LicenseeID
		
		IF (@EnableBA=0 AND @EnableBA_Old <> @EnableBA) -- Disable BA --> Un-map LicenseeProduct3rd for Product BA
		BEGIN
			DELETE FROM LicenseeProduct3rd WITH (ROWLOCK, UPDLOCK)
			WHERE LicenseeID = @LicenseeID AND ProductID = 3 --BA
		END
		ELSE IF (@EnableBA=1 AND @EnableBA_Old <> @EnableBA) --Enable BA --> Map LicenseeProduct3rd for Product BA
		BEGIN
			IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeProduct3rd WHERE LicenseeID = @LicenseeID AND ProductID = 3)
			BEGIN
				INSERT INTO LicenseeProduct3rd (LicenseeID, ProductID, Comm, Winloss)
				VALUES (@LicenseeID,3,1,0)
			END			
		END
		
		--hardcode Alog username which only allow group a
		DECLARE @SpecialCustomer AS TABLE (CustID INT,ugroup VARCHAR(3))
		INSERT INTO @SpecialCustomer(CustID,ugroup)
		SELECT CustID,ugroup FROM LicenseeSpecialCust (NOLOCK)
		
		--Check the current Member BA running
		IF EXISTS (SELECT 1 FROM LicenseeBAHistory WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND Status = 'Running')
		BEGIN
			DECLARE @TempCustID AS TABLE (ID INT IDENTITY(1,1), CustID INT, currency INT)
			DECLARE @i INT, @Max INT, @BACustID INT
			SET @i = 0
						
			INSERT INTO @TempCustID (CustID,currency)
			SELECT lba.CustID,currency   
			FROM  
				LicenseeBAHistory lba WITH (NOLOCK)
				INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON lba.CustID = c.Custid
			WHERE LicenseeID = @LicenseeID AND Status = 'Running'
			
			
			SELECT @MAX =  MAX(id) FROM @TempCustID
			WHILE @i < @MAX
			BEGIN
				SET @i = @i + 1
				SELECT @BACustID = CustID,@Currency=Currency FROM @TempCustID WHERE id = @i
				
				IF EXISTS (SELECT 1 FROM @SpecialCustomer WHERE Custid = @BACustID)
				BEGIN
					SELECT @ugroup = ugroup FROM @SpecialCustomer WHERE Custid = @BACustID
				END
				ELSE
				BEGIN
					SELECT @ugroup = ugroup 
					FROM LicenseeCurrencyBAGroup lc WITH (NOLOCK)
					WHERE LicenseeID = @LicenseeID AND Currency = @currency
				END
				
				IF @FlagUpdateBAStatus=1 AND @EnableBA=0
				BEGIN
					EXEC CUSTDB.dbo.Lrf_CustomerUpdMemberBAStatus
					@LicenseeID = @LicenseeID,
					@CustID = @BACustID,
					@ModifyBy = @UserID,
					@IsBA = 0,
					@IP = @IP,
					@IsAdmin = 1,
					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg OUTPUT
				END
				ELSE
				BEGIN
					IF @FlagUpdateComm=1
					BEGIN
						--Update commission for BA Member
						EXEC CUSTDB.dbo.Lrf_CustomerUpdMemberBAComm
						@LicenseeID = @LicenseeID,
						@CustID = @BACustID,
						@ModifyBy = @UserID,
						@IsBA = 1,
						@IP = @IP,
						@IsAdmin = 1,
						@ErrCode = @ErrCode OUTPUT,
						@ErrMsg = @ErrMsg OUTPUT
						--Update LicenseeBAHistory for commission
					
						UPDATE LicenseeBAHistory WITH (rowlock, updlock)
						SET 
							GroupComm = CASE WHEN @ugroup = 'a' THEN @groupa
											 WHEN @ugroup = 'b' THEN @groupb
											 WHEN @ugroup = 'c' THEN @groupc
											 WHEN @ugroup = 'd' THEN @groupd
											   ELSE GroupComm END,
							[1x2Comm] = @1x2Comm,
							OtherComm = @OtherComm
						WHERE 
							LicenseeID = @LicenseeID
							AND CustID = @BACustID
							AND Status = 'Running'
					END
				END	
			END	
		END
		--write log 
		
		EXEC Lrf_WriteLog_UserLog_LicenseeBAConfig_Wrapper 
			@LicenseeID = @LicenseeID,
			@groupa = @groupa,
			@groupb = @groupb,
			@groupc = @groupc, 
			@groupd =  @groupd,
			@1x2Comm = @1x2Comm, 
			@OtherComm = @OtherComm, 
			@EnableBA = @EnableBA, 
			@IP = @IP,
			@ActionId = 218,
			@UserID = @UserID			
	END
END
GO



