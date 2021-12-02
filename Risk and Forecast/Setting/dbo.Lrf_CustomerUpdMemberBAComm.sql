/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [CustDB]
GO
 
ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberBAComm]
	@LicenseeID INT,
	@CustID INT,--member
	@ModifyBy INT,
	@IsBA BIT,
	@Langkey VARCHAR(10) = 'en-US',
	@IP VARCHAR(40),
	@IsAdmin BIT = 0,
	@OddsGroup VARCHAR(3) = '' OUTPUT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
Created: 20110606@Henry
Task : Update Commission WHEN BA is ON/OFF
DB: DBCUST/CustDB

Revisions:
	- 20110823@Johnson: change to use commission by group for handicap, odd/even, over/under bettype
	- 20111118@Jim: change ugroup variable  reference 
	- 20111209@Henry: hardcode Alog members to just only allow group a
	- 20120208@Jim:  hardcode to change point spread for members (group a and group d)
	- 20120215@Henry: add more customer for hard-code group a
	- 20120223@Jim: add more customer for spread member (group a and group d)
	- 20120405@Jim:replace hard code and modify @ugroup in case @ugroup belong to HongKong Odds
	- 20120418@Dom:replace table custsetting to dep_custsetting
    - 20130123@Daniel: Change link server alias & failover writelog to DBTXN
	- 20130413@Jim: support multi language 
	- 20150121@Jim: return more @OddsGroup param
	- 20150630@Kathy: add default value for param @OddsGroup 
	- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
	- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
	
Param's Explanation:

*/
BEGIN
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @currency  int 
	DECLARE @duration INT
	SET @startRun = GETDATE()

	DECLARE @Old_GroupComm DECIMAL(9,8) , @Old_ugroup VARCHAR(3) ,@Old_1x2Comm DECIMAL(9,8), @Old_OtherComm DECIMAL(9,8)

	DECLARE @GroupComm DECIMAL(9,8), @ugroup varchar(3), @1x2Comm DECIMAL(9,8), @OtherComm DECIMAL(9,8)

	DECLARE @LogSPData VARCHAR(5000)
	DECLARE @TrackingValue2 VARCHAR(5000)

	DECLARE @username VARCHAR(50)
	SELECT @UserName  = username, @currency =currency
	FROM customer WITH (NOLOCK) 
	WHERE CustID = @CustID
	
	SELECT @ugroup = ugroup 
	FROM bodb_licensee.dbo.LicenseeSpecialCust WITH (NOLOCK) 
	WHERE CustID=@CustID 	

	IF ISNULL (@ugroup,'')=''
	BEGIN
		SELECT @ugroup=ugroup 
		FROM bodb_licensee.dbo.LicenseeCurrencyBAGroup with (nolock) 
		WHERE LicenseeID=@LicenseeID AND Currency=@Currency 
	END

	IF @isBA = 1 --enable BA
		BEGIN
			IF NOT EXISTS (
				SELECT 1 
				FROM bodb_licensee.dbo.LicenseeBAConfig WITH (nolock) 
				WHERE LicenseeID = @LicenseeID)
			BEGIN
				SELECT @ErrMsg = CASE @Langkey
									WHEN 'en-US' THEN 'This Licensee does NOT have any setting!'
									ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](200011,@Langkey)
								END, @ErrCode = 101
				RETURN
			END
			ELSE
			BEGIN
				DECLARE @grouphk VARCHAR(3)
				IF LEFT(@ugroup,2)='hk'
					SELECT @grouphk=RIGHT(@ugroup,1)
				ELSE 
					SELECT @grouphk=@ugroup
				SELECT 
					@GroupComm = CASE WHEN @grouphk = 'a' THEN groupa
										WHEN @grouphk = 'b' THEN groupb
										WHEN @grouphk = 'c' THEN groupc
										WHEN @grouphk = 'd' THEN groupd
										ELSE 0 END ,
					@1x2Comm = lb.[1x2Comm],
					@OtherComm = lb.OtherComm
				FROM bodb_licensee.dbo.LicenseeBAConfig lb WITH (nolock) 
				WHERE lb.LicenseeID = @LicenseeID
				
			END
		
		END
	ELSE --disable BA
	BEGIN	
		SELECT	@GroupComm = 0 
		-- get old group setting before set BA
		SELECT  @ugroup = ugroup FROM bodb_Licensee.dbo.LicenseeBAHistory WITH(NOLOCK) WHERE LicenseeID = @LicenseeID AND Custid = @custid  AND status = 'running'
		SELECT	@1x2Comm = 0
		SELECT  @OtherComm = 0	
	END

		--check param
	IF 
		@GroupComm<0 OR @GroupComm>0.2	
		OR @1x2Comm<0 OR @1x2Comm>0.2
		OR @OtherComm < 0 OR @OtherComm > 0.2		
	BEGIN		
		SELECT @ErrMsg = 	CASE @Langkey 
							WHEN 'en-US' THEN 'Wrong discount.'
							ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200012,@Langkey)
					END, @ErrCode = 102
		RETURN
	END

	--get old value
	SELECT @Old_ugroup = ugroup 
	FROM customer WITH(NOLOCK)
	WHERE custid = @custid

	SELECT 
		@Old_GroupComm = discount
	FROM dep_custsetting WITH (NOLOCK) 
	WHERE custid = @Custid AND bettype = 1 AND sporttype = 1

	SELECT 
		@Old_1x2Comm = discount
	FROM dep_custsetting WITH (nolock)
	WHERE custid = @Custid AND bettype = 5 AND sporttype = 1

	SELECT 
		@Old_OtherComm = discount
	FROM dep_custsetting WITH (nolock)
	WHERE custid = @Custid AND bettype = 4 AND sporttype = 1


	--update Group commission
	UPDATE dep_custsetting WITH (ROWLOCK, UPDLOCK)
	SET
		discount =  CASE WHEN bettype = 2 AND sporttype = 2 THEN discount ELSE @GroupComm END,
		adiscount = CASE WHEN bettype = 2 AND sporttype = 2 THEN adiscount ELSE @GroupComm END,
		sdiscount = CASE WHEN bettype = 2 AND sporttype = 2 THEN sdiscount ELSE @GroupComm END
	FROM dep_custsetting cs INNER JOIN custinfo c WITH (NOLOCK) ON cs.custid = c.custid
	WHERE 
		c.custid=@custid
		AND c.roleid = 1 
		AND bettype IN (1,2,3,7,8)
	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrMsg = @UserName + ': '+
						CASE @Langkey 
							WHEN 'en-US' THEN 'Update process is unsuccessful !'
							ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](90001,@Langkey)
						END, @ErrCode = 103
		RETURN
	END 
	
	--update OtherComm
	UPDATE cs WITH (ROWLOCK, UPDLOCK)
	SET
		cs.discount = @OtherComm,
		cs.adiscount = @OtherComm,
		cs.sdiscount = @OtherComm
	FROM dep_custsetting cs INNER JOIN custinfo c WITH (NOLOCK) ON cs.custid = c.custid
	WHERE 
		c.custid=@custid
		AND c.roleid = 1 
		AND bettype IN (4,6,9,10,20,21,22) 	
	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrMsg = @UserName + ': '+
						CASE @Langkey 
							WHEN 'en-US' THEN 'Update process is unsuccessful !'
							ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](90001,@Langkey)
						END, @ErrCode = 104
		RETURN
	END
	
	--update 1x2Comm
	UPDATE dep_custsetting WITH (ROWLOCK, UPDLOCK)
	SET
		discount = @1x2Comm,
		adiscount = @1x2Comm,
		sdiscount = @1x2Comm
	FROM dep_custsetting cs INNER JOIN custinfo c WITH (NOLOCK) ON cs.custid = c.custid
	WHERE 
		c.custid=@custid
		AND c.roleid = 1 
		AND bettype = 5		
	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrMsg = @UserName + ': '+
						CASE @Langkey 
							WHEN 'en-US' THEN 'Update process is unsuccessful !'
							ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](90001,@Langkey)
						END, @ErrCode = 105
		RETURN
	END

	--Update user group
	-- check old user group in Hong Kong then update new user group in Hong Kong
	IF @old_ugroup IN  ('hka','hkb','hkc','hkd') AND @ugroup IN ('a','b','c','d')
		SELECT @ugroup = 'hk'+ @ugroup

	UPDATE customer WITH(ROWLOCK, UPDLOCK)
	SET ugroup = @ugroup 
	WHERE custid = @custid

	SELECT @OddsGroup = RIGHT(@ugroup,1)

	IF (@@ERROR <> 0)
	BEGIN
		SELECT @ErrMsg = @UserName + ': '+
						CASE @Langkey
							WHEN 'en-US' THEN 'Update process is unsuccessful !'
							ELSE [dbo].[Lrf_f_Get_MsgNamebyMsgID](90001,@Langkey)
						END, @ErrCode = 106
		RETURN
	END


	SELECT @LogSPData = '<Lrf_CustomerUpdMemberBAComm custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupComm="'+ COALESCE(CAST(@GroupComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'Ugroup="'+ COALESCE(CAST(@ugroup as VARCHAR(10)),SPACE(1)) + '" ' +
	'1x2Comm="'+ COALESCE(CAST(@1x2Comm as VARCHAR(50)),SPACE(1)) + '" ' +
	'OtherComm="'+ COALESCE(CAST(@OtherComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@ModifyBy as VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'

	SELECT @TrackingValue2 = '<Lrf_CustomerUpdMemberBAComm custid="'+ COALESCE(CAST(@custid as VARCHAR(50)),SPACE(1)) + '" ' +
	'GroupComm="'+ COALESCE(CAST(@Old_GroupComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'UGroup="'+ COALESCE(CAST(@Old_Ugroup as VARCHAR(10)),SPACE(1)) + '" ' +
	'1x2Comm="'+ COALESCE(CAST(@Old_1x2Comm as VARCHAR(50)),SPACE(1)) + '" ' +
	'OtherComm="'+ COALESCE(CAST(@Old_OtherComm as VARCHAR(50)),SPACE(1)) + '" ' +
	'UserID="'+ COALESCE(CAST(@ModifyBy as VARCHAR(50)),SPACE(1)) + '" ' +
	'Language="'+ COALESCE(CAST(@Langkey as VARCHAR(10)),SPACE(1)) + '" ' +
	'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
	'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
	'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(5000)),SPACE(1))+ '" />'

	SET @endRun = GETDATE()
	SET @duration  = datediff (millisecond,@startRun,@endRun)

	IF @IsAdmin = 0
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @ModifyBy,
			@CustID = @CustID,
			@ActionID = 2600,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @TrackingValue2,
			@duration = @duration						
	END
	ELSE
	BEGIN
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @ModifyBy,
			@CustID = @CustID,
			@ActionID = 219,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @TrackingValue2,
			@duration = @duration					
	END
END
GO